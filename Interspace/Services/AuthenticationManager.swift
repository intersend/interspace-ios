import Foundation
import Combine
import SwiftUI

// MARK: - AuthenticationManager

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthenticationError?
    
    private let authAPI = AuthAPI.shared
    private let userAPI = UserAPI.shared
    private let keychainManager = KeychainManager.shared
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false
    
    private init() {
        checkAuthenticationStatus()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Session Management
    
    func checkAuthenticationStatus() {
        guard let accessToken = keychainManager.getAccessToken(),
              keychainManager.getRefreshToken() != nil else {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return
        }
        
        // Set the token in API service
        APIService.shared.setAccessToken(accessToken)
        
        // Check if token is expired
        if keychainManager.isTokenExpired() {
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            // Token is valid, fetch user info
            Task {
                await fetchCurrentUser()
            }
        }
    }
    
    func refreshTokenIfNeeded() async {
        guard !isRefreshing else { return }
        
        guard let refreshToken = keychainManager.getRefreshToken() else {
            await logout()
            return
        }
        
        isRefreshing = true
        
        do {
            let response = try await authAPI.refreshToken(refreshToken: refreshToken)
            
            // Save new tokens
            try keychainManager.saveTokens(
                access: response.accessToken,
                refresh: refreshToken, // Keep same refresh token
                expiresIn: response.expiresIn
            )
            
            // Update API service token
            APIService.shared.setAccessToken(response.accessToken)
            
            // Fetch user info if not authenticated
            if !isAuthenticated {
                await fetchCurrentUser()
            }
            
        } catch {
            print("Token refresh failed: \(error)")
            await logout()
        }
        
        isRefreshing = false
    }
    
    /// Validates the current auth token with a lightweight API call
    /// Returns true if token is valid, false otherwise
    func validateAuthToken() async -> Bool {
        guard let accessToken = keychainManager.getAccessToken() else {
            print("🔐 AuthenticationManager: No access token found during validation")
            return false
        }
        
        // Set the token in API service for the validation call
        APIService.shared.setAccessToken(accessToken)
        
        do {
            // Use a lightweight endpoint to validate token
            // We'll use getCurrentUser but could create a dedicated /auth/validate endpoint
            _ = try await userAPI.getCurrentUser()
            print("🔐 AuthenticationManager: Token validation successful")
            return true
        } catch {
            print("🔐 AuthenticationManager: Token validation failed: \(error)")
            
            // If it's a 401, try to refresh the token
            if let apiError = error as? APIError, case .unauthorized = apiError {
                // Check if we have a refresh token
                if keychainManager.getRefreshToken() != nil {
                    print("🔐 AuthenticationManager: Attempting token refresh during validation")
                    await refreshTokenIfNeeded()
                    
                    // Check if refresh was successful
                    return keychainManager.getAccessToken() != nil && isAuthenticated
                }
            }
            
            return false
        }
    }
    
    func authenticate(with config: WalletConnectionConfig) async throws {
        print("🔐 AuthenticationManager: Starting authentication with strategy: \(config.strategy)")
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let response: AuthenticationResponse
            
            // For email authentication, verify the code first, then authenticate
            if config.strategy == .email, 
               let email = config.email, 
               let code = config.verificationCode {
                print("🔐 AuthenticationManager: Email auth flow - verifying code first")
                
                // Step 1: Verify the email code
                let verifyResponse = try await authAPI.verifyEmailCode(email: email, code: code)
                print("🔐 AuthenticationManager: Email verified successfully: \(verifyResponse.message)")
                
                // Step 2: Authenticate after verification
                let authRequest = buildAuthRequest(from: config)
                print("🔐 AuthenticationManager: Authenticating with verified email")
                response = try await authAPI.authenticate(request: authRequest)
                
            } else if config.strategy == .wallet,
                      let address = config.walletAddress,
                      let signature = config.signature,
                      let message = config.message {
                // For wallet authentication, use SIWE flow
                print("🔐 AuthenticationManager: Using SIWE authentication flow")
                response = try await authAPI.authenticateWithSIWE(
                    message: message,
                    signature: signature,
                    address: address
                )
            } else {
                // Use regular authentication for other strategies
                let authRequest = buildAuthRequest(from: config)
                print("🔐 AuthenticationManager: Built auth request - strategy: \(authRequest.authStrategy)")
                response = try await authAPI.authenticate(request: authRequest)
            }
            
            print("🔐 AuthenticationManager: Authentication API call successful!")
            
            // Check wallet profile info for wallet authentication
            if config.strategy == .wallet, let walletProfileInfo = response.data.walletProfileInfo {
                print("🔐 AuthenticationManager: Wallet profile info - isLinked: \(walletProfileInfo.isLinked), profileId: \(walletProfileInfo.profileId ?? "none")")
                
                // If wallet is linked but no profile ID, it's an orphan wallet
                if walletProfileInfo.isLinked && walletProfileInfo.profileId == nil {
                    print("🔐 AuthenticationManager: Orphan wallet detected - has account but no profile")
                    throw AuthenticationError.walletConnectionFailed("This wallet needs a profile. Please create one to continue.")
                }
            }
            
            // Save tokens securely
            try keychainManager.saveTokens(
                access: response.data.accessToken,
                refresh: response.data.refreshToken,
                expiresIn: response.data.expiresIn
            )
            
            // Set token in API service
            APIService.shared.setAccessToken(response.data.accessToken)
            
            // For guest users, create a mock user instead of fetching from API
            if config.strategy == .guest {
                print("🔐 AuthenticationManager: Creating guest user")
                let guestUser = User(
                    id: "guest_\(Date().timeIntervalSince1970)",
                    email: nil,
                    walletAddress: nil,
                    isGuest: true,
                    authStrategies: ["guest"],
                    profilesCount: 0,
                    linkedAccountsCount: 0,
                    activeDevicesCount: 1,
                    socialAccounts: [],
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                await MainActor.run {
                    self.currentUser = guestUser
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            } else {
                // Fetch user info for non-guest users
                await fetchCurrentUser()
                
                await MainActor.run {
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            }
            print("🔐 AuthenticationManager: Authentication completed successfully!")
            
        } catch {
            print("🔐 AuthenticationManager: Authentication failed with error: \(error)")
            let authError = mapAPIError(error)
            await MainActor.run {
                self.error = authError
                self.isLoading = false
            }
            throw authError
        }
    }
    
    func sendEmailCode(_ email: String) async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            _ = try await authAPI.sendEmailCode(email: email)
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            let authError = mapAPIError(error)
            await MainActor.run {
                self.error = authError
                self.isLoading = false
            }
            throw authError
        }
    }
    
    func resendEmailCode(_ email: String) async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            _ = try await authAPI.resendEmailCode(email: email)
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            let authError = mapAPIError(error)
            await MainActor.run {
                self.error = authError
                self.isLoading = false
            }
            throw authError
        }
    }
    
    func authenticateWithGoogle() async throws {
        print("🔐 AuthenticationManager: Starting Google authentication")
        
        // Ensure Google Sign-In is initialized
        await MainActor.run {
            GoogleSignInService.shared.configure()
        }
        
        #if DEBUG
        // Check if development mode is enabled
        if EnvironmentConfiguration.shared.isDevelopmentModeEnabled {
            print("🔐 AuthenticationManager: Using development mode Google Sign-In")
            
            // Create mock Google result
            let mockResult = GoogleSignInResult(
                email: "dev.user@example.com",
                name: "Development User",
                imageURL: nil,
                idToken: "dev_google_id_token_\(UUID().uuidString)",
                userId: "dev_google_user_\(UUID().uuidString)"
            )
            
            let config = WalletConnectionConfig(
                strategy: .google,
                walletType: nil,
                email: mockResult.email,
                verificationCode: nil,
                walletAddress: nil,
                signature: mockResult.idToken,  // Pass the auth token here
                message: nil,
                socialProvider: "google",
                socialProfile: SocialProfile(
                    id: mockResult.userId,
                    email: mockResult.email,
                    name: mockResult.name,
                    picture: mockResult.imageURL
                )
            )
            
            try await authenticate(with: config)
            return
        }
        #endif
        
        do {
            let googleResult = try await GoogleSignInService.shared.signIn()
            print("🔐 AuthenticationManager: Google Sign-In successful, email: \(googleResult.email)")
            
            // Ensure we have an ID token for backend authentication
            guard let idToken = googleResult.idToken else {
                print("🔐 AuthenticationManager: ERROR - No ID token received from Google Sign-In")
                throw AuthenticationError.unknown("Google authentication failed: No ID token received")
            }
            
            print("🔐 AuthenticationManager: Successfully obtained ID token")
            
            let config = WalletConnectionConfig(
                strategy: .google,
                walletType: nil,
                email: googleResult.email,
                verificationCode: nil,
                walletAddress: nil,
                signature: idToken,  // Pass the ID token for backend verification
                message: nil,
                socialProvider: "google",
                socialProfile: SocialProfile(
                    id: googleResult.userId,
                    email: googleResult.email,
                    name: googleResult.name,
                    picture: googleResult.imageURL
                )
            )
            
            try await authenticate(with: config)
            
        } catch let error as GoogleSignInError {
            // Map Google Sign-In errors to authentication errors
            switch error {
            case .noViewController:
                throw AuthenticationError.unknown("Unable to present Google Sign-In")
            case .signInFailed(let message):
                if message.contains("canceled") || message.contains("-5") {
                    // User cancelled - don't show error
                    print("🔐 AuthenticationManager: User cancelled Google Sign-In")
                    throw AuthenticationError.unknown("")
                }
                throw AuthenticationError.unknown("Google Sign-In failed: \(message)")
            case .noUserData:
                throw AuthenticationError.unknown("No user data received from Google")
            }
        } catch {
            // Re-throw other errors
            throw error
        }
    }
    
    @available(iOS 16.0, *)
    func authenticateWithPasskey(email: String? = nil) async throws {
        guard PasskeyService.isPasskeyAvailable() else {
            throw AuthenticationError.passkeyNotSupported
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // Authentication flow - returns tokens directly
            let tokens = try await PasskeyService.shared.authenticateWithPasskey(username: email)
            
            // Store tokens
            KeychainManager.shared.accessToken = tokens.accessToken
            KeychainManager.shared.refreshToken = tokens.refreshToken
            
            // Update authentication state
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Fetch user profile
            await fetchCurrentUser()
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = AuthenticationError.passkeyAuthenticationFailed(error.localizedDescription)
            }
            throw error
        }
    }
    
    func authenticateWithApple() async throws {
        print("🍎 AuthenticationManager: Starting Apple authentication")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        #if DEBUG
        // Check if development mode is enabled
        if EnvironmentConfiguration.shared.isDevelopmentModeEnabled {
            print("🍎 AuthenticationManager: Using development mode Apple Sign-In")
            
            // Create mock Apple result
            let mockResult = AppleSignInResult(
                userId: "dev_apple_user_\(UUID().uuidString)",
                identityToken: "dev_apple_identity_token_\(UUID().uuidString)",
                authorizationCode: "dev_apple_auth_code_\(UUID().uuidString)",
                email: "dev.apple@example.com",
                fullName: PersonNameComponents(
                    givenName: "Dev",
                    familyName: "Apple"
                ),
                realUserStatus: .likelyReal
            )
            
            try await handleAppleSignInResult(mockResult)
            return
        }
        #endif
        
        do {
            let appleResult = try await AppleSignInService.shared.signIn()
            print("🍎 AuthenticationManager: Apple Sign-In successful, user: \(appleResult.userId)")
            
            try await handleAppleSignInResult(appleResult)
            
        } catch let error as AppleSignInError {
            // Map Apple Sign-In errors to authentication errors
            await MainActor.run {
                isLoading = false
            }
            
            switch error {
            case .userCancelled:
                // User cancelled - don't show error
                print("🍎 AuthenticationManager: User cancelled Apple Sign-In")
                throw AuthenticationError.unknown("")
            case .noIdentityToken, .noAuthorizationCode:
                throw AuthenticationError.unknown("Apple Sign-In failed: Missing required tokens")
            case .invalidCredential, .authorizationFailed, .invalidResponse:
                throw AuthenticationError.unknown("Apple Sign-In authorization failed")
            default:
                throw AuthenticationError.unknown(error.localizedDescription)
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            throw error
        }
    }
    
    private func handleAppleSignInResult(_ result: AppleSignInResult) async throws {
        print("🍎 AuthenticationManager: Processing Apple Sign-In result")
        
        // Build Apple auth request
        let appleAuthRequest = AppleAuthRequest(
            identityToken: result.identityToken,
            authorizationCode: result.authorizationCode,
            user: AppleUserInfo(
                id: result.userId,
                email: result.email,
                firstName: result.fullName?.givenName,
                lastName: result.fullName?.familyName
            ),
            deviceId: DeviceInfo.deviceId,
            deviceName: DeviceInfo.deviceName,
            deviceType: DeviceInfo.deviceType
        )
        
        // Authenticate with backend
        let response = try await authAPI.authenticateWithApple(request: appleAuthRequest)
        
        print("🍎 AuthenticationManager: Apple authentication API call successful!")
        
        // Save tokens securely
        try keychainManager.saveTokens(
            access: response.data.accessToken,
            refresh: response.data.refreshToken,
            expiresIn: response.data.expiresIn
        )
        
        // Set token in API service
        APIService.shared.setAccessToken(response.data.accessToken)
        
        // Fetch user info
        await fetchCurrentUser()
        
        await MainActor.run {
            self.isAuthenticated = true
            self.isLoading = false
        }
        
        print("🍎 AuthenticationManager: Apple authentication completed successfully!")
    }
    
    // MARK: - Wallet Profile Management
    
    /// Get wallet profile info without fully authenticating
    // Removed getWalletProfileInfo method for privacy reasons
    // We should not check wallet existence before authentication
    
    /// Create a profile for a wallet address
    func createProfileForWallet(name: String, walletAddress: String) async throws -> SmartProfile {
        // First create the profile
        let profile = try await ProfileAPI.shared.createProfile(
            name: name,
            developmentMode: false
        )
        
        // The wallet will be automatically linked when authentication completes
        return profile
    }
    
    func logout() async {
        print("🔐 AuthenticationManager: Starting logout process")
        
        // Clear API service token immediately
        APIService.shared.setAccessToken(nil)
        
        // Clear stored tokens from keychain immediately
        keychainManager.clearTokens()
        
        // Update state immediately
        await MainActor.run {
            isAuthenticated = false
            currentUser = nil
            isLoading = false
            error = nil
        }
        
        // Call logout endpoint if we have a refresh token (best effort, don't block)
        if let refreshToken = keychainManager.getRefreshToken() {
            Task {
                do {
                    _ = try await authAPI.logout(refreshToken: refreshToken)
                    print("🔐 AuthenticationManager: Logout API call successful")
                } catch {
                    print("🔐 AuthenticationManager: Logout API call failed: \(error)")
                }
            }
        }
        
        // Sign out from external providers
        GoogleSignInService.shared.signOut()
        
        print("🔐 AuthenticationManager: Logout completed")
    }
    
    // Alias for logout to match SessionCoordinator expectations
    func signOut() async {
        await logout()
    }
    
    func fetchCurrentUser() async {
        do {
            let user = try await userAPI.getCurrentUser()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
        } catch {
            print("Failed to fetch current user: \(error)")
            await logout()
        }
    }
    
    private func mapAPIError(_ error: Error) -> AuthenticationError {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return .invalidCredentials
            case .requestFailed(let underlying):
                return .networkError(underlying.localizedDescription)
            case .invalidResponse, .noData:
                return .unknown("Invalid response from server")
            case .decodingFailed(let underlying):
                return .unknown("Failed to decode response: \(underlying.localizedDescription)")
            case .apiError(let message):
                // Map specific API errors to appropriate authentication errors
                if message.lowercased().contains("invalid") && message.lowercased().contains("code") {
                    return .emailVerificationFailed
                }
                return .unknown(message)
            case .invalidURL:
                return .unknown("Invalid URL")
            case .invalidRequest(let message):
                return .unknown(message)
            }
        }
        return .unknown(error.localizedDescription)
    }
    
    private func buildAuthRequest(from config: WalletConnectionConfig) -> AuthenticationRequest {
        var authToken = ""
        var socialData: SocialAuthData? = nil
        
        switch config.strategy {
        case .wallet:
            authToken = config.signature ?? ""
        case .email:
            // For email auth, the authToken should be the email after verification
            authToken = config.email ?? ""
            print("🔐 AuthenticationManager: Email auth - using email as authToken")
        case .guest:
            authToken = "guest"
        case .google:
            // For Google, use the signature field which contains either ID token or user ID
            authToken = config.signature ?? config.socialProfile?.id ?? ""
            // Include social data for backend
            if let profile = config.socialProfile {
                socialData = SocialAuthData(
                    provider: "google",
                    providerId: profile.id,
                    email: profile.email!,
                    displayName: profile.name,
                    avatarUrl: profile.picture
                )
            }
        case .passkey:
            authToken = config.verificationCode ?? ""
        case .apple:
            authToken = config.socialProfile?.id ?? ""
            // Include social data for backend
            if let profile = config.socialProfile {
                socialData = SocialAuthData(
                    provider: "apple",
                    providerId: profile.id,
                    email: profile.email!,
                    displayName: profile.name,
                    avatarUrl: profile.picture
                )
            }
        case .testWallet:
            authToken = "test"
        }
        
        print("🔐 AuthenticationManager: Building auth request - strategy: \(config.strategy.rawValue), authToken: \(authToken)")
        if let socialData = socialData {
            print("🔐 AuthenticationManager: Including social data - provider: \(socialData.provider), email: \(socialData.email)")
        }
        
        return AuthenticationRequest(
            authToken: authToken,
            authStrategy: config.strategy.rawValue,
            deviceId: DeviceInfo.deviceId,
            deviceName: DeviceInfo.deviceName,
            deviceType: "ios",
            walletAddress: config.walletAddress,
            email: config.email,
            verificationCode: config.verificationCode,
            socialData: socialData
        )
    }
}

// MARK: - Development Wallet Authentication Extension

extension AuthenticationManager {
    /// Authenticate with a development wallet for a specific profile
    func authenticateWithDevelopmentWallet(profileId: String) async throws {
        guard EnvironmentConfiguration.shared.isDevelopmentModeEnabled else {
            throw AuthenticationError.unknown("Development mode is not enabled")
        }
        
        let devWalletService = DevelopmentWalletService.shared
        let address = devWalletService.generateAddress(for: profileId)
        let message = "Sign in to Interspace with profile: \(profileId)"
        let signature = devWalletService.signMessage(message, for: profileId)
        
        let config = WalletConnectionConfig(
            strategy: .wallet,
            walletType: "development",
            email: nil,
            verificationCode: nil,
            walletAddress: address,
            signature: signature,
            message: message,
            socialProvider: nil,
            socialProfile: nil
        )
        
        try await authenticate(with: config)
    }
}

