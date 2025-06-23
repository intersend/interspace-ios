import Foundation
import Combine
import SwiftUI
import UIKit
import AuthenticationServices

// MARK: - Account Types

enum AccountType: String, Codable {
    case email
    case wallet
    case social
    case passkey
    case guest
}

enum PrivacyMode: String, Codable {
    case linked
    case partial
    case isolated
}

// MARK: - Models


struct AccountSession: Codable {
    let id: String
    let accountId: String
    let sessionToken: String
    let privacyMode: PrivacyMode
    let activeProfileId: String?
    let expiresAt: Date
}



// MARK: - AuthenticationManagerV2

@MainActor
final class AuthenticationManagerV2: ObservableObject {
    static let shared = AuthenticationManagerV2()
    
    // Published properties
    @Published var currentAccount: AccountV2?
    @Published var currentUser: User? // For backward compatibility
    @Published var profiles: [ProfileSummaryV2] = []
    @Published var activeProfile: ProfileSummaryV2?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthenticationError?
    @Published var privacyMode: PrivacyMode = .linked
    @Published var isNewUser = false
    
    // Private properties
    private let authAPI = AuthAPI.shared
    private let keychainManager = KeychainManager.shared
    private var sessionToken: String?
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false
    
    private init() {
        checkAuthenticationStatus()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Authentication Methods
    
    /// Authenticate with any supported method
    func authenticate(with config: WalletConnectionConfig) async throws {
        isLoading = true
        error = nil
        
        do {
            // Prepare request based on strategy
            var identifier: String?
            var credential: String?
            var oauthCode: String?
            
            switch config.strategy {
            case .email:
                guard let email = config.email,
                      let code = config.verificationCode else {
                    throw AuthenticationError.invalidCredentials
                }
                identifier = email
                credential = code
                
            case .wallet:
                guard let address = config.walletAddress,
                      let signature = config.signature else {
                    throw AuthenticationError.invalidCredentials
                }
                identifier = address
                credential = signature
                
            case .google:
                // Handle Google auth - needs oauth code
                guard let code = config.oauthCode else {
                    throw AuthenticationError.invalidCredentials
                }
                oauthCode = code
                
            case .guest:
                // No additional data needed
                break
                
            default:
                throw AuthenticationError.unknown("Unsupported authentication strategy")
            }
            
            let request = AuthenticationRequestV2(
                strategy: config.strategy.rawValue,
                identifier: identifier,
                credential: credential,
                oauthCode: oauthCode,
                appleAuth: nil,
                privacyMode: privacyMode.rawValue,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
            
            // Call V2 authentication endpoint
            let response = try await authAPI.authenticateV2(request: request)
            
            // Process response
            await processAuthResponse(response)
            
            isLoading = false
            
        } catch {
            isLoading = false
            self.error = error as? AuthenticationError ?? .unknown("Authentication failed")
            throw error
        }
    }
    
    /// Process authentication response
    private func processAuthResponse(_ response: AuthResponseV2) async {
        // Save tokens
        do {
            try keychainManager.saveTokens(
                access: response.tokens.accessToken,
                refresh: response.tokens.refreshToken,
                expiresIn: response.tokens.expiresIn
            )
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to save tokens: \(error)")
        }
        
        // Update API service
        APIService.shared.setAccessToken(response.tokens.accessToken)
        
        // Update state
        currentAccount = response.account
        currentUser = response.user
        profiles = response.profiles
        activeProfile = response.activeProfile
        isNewUser = response.isNewUser
        privacyMode = PrivacyMode(rawValue: response.privacyMode) ?? .linked
        sessionToken = response.sessionId
        isAuthenticated = true
        
        // Load additional data if needed
        if !isNewUser && activeProfile != nil {
            await ProfileViewModel.shared.loadProfile()
        }
    }
    
    // MARK: - Profile Management
    
    /// Switch to a different profile
    func switchProfile(to profileId: String) async throws {
        guard isAuthenticated else {
            throw AuthenticationError.tokenExpired
        }
        
        do {
            let response = try await authAPI.switchProfileV2(profileId: profileId)
            
            activeProfile = response.activeProfile
            
            // Update profiles list
            profiles = profiles.map { p in
                var updated = p
                updated.isActive = p.id == profileId
                return updated
            }
            
            // Reload profile data
            await ProfileViewModel.shared.loadProfile()
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to switch profile: \(error)")
            throw error
        }
    }
    
    // MARK: - Account Linking
    
    /// Link another account to current identity
    func linkAccount(type: AccountType, identifier: String, provider: String? = nil) async throws {
        guard isAuthenticated else {
            throw AuthenticationError.tokenExpired
        }
        
        let request = LinkAccountRequestV2(
            strategy: type.rawValue,
            identifier: identifier,
            credential: nil,
            oauthCode: nil,
            appleAuth: nil
        )
        
        do {
            let response = try await authAPI.linkAccountsV2(request: request)
            
            // Update accessible profiles
            profiles = response.profiles
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to link account: \(error)")
            throw error
        }
    }
    
    // MARK: - Privacy Management
    
    /// Update privacy mode for current session
    func updatePrivacyMode(_ mode: PrivacyMode) async throws {
        guard isAuthenticated else {
            throw AuthenticationError.tokenExpired
        }
        
        self.privacyMode = mode
        
        // TODO: Update privacy mode on backend
    }
    
    // MARK: - Session Management
    
    func checkAuthenticationStatus() {
        guard let accessToken = keychainManager.getAccessToken(),
              keychainManager.getRefreshToken() != nil else {
            print("🔐 AuthenticationManagerV2: No tokens found")
            isAuthenticated = false
            currentAccount = nil
            currentUser = nil
            profiles = []
            activeProfile = nil
            return
        }
        
        // Set token in API service
        APIService.shared.setAccessToken(accessToken)
        
        // Check if token is expired
        if keychainManager.isTokenExpired() {
            print("🔐 AuthenticationManagerV2: Token expired, refreshing...")
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            // Token is valid, fetch current session
            print("🔐 AuthenticationManagerV2: Token valid, fetching session")
            Task {
                await fetchCurrentSession()
            }
        }
    }
    
    private func fetchCurrentSession() async {
        // For now, use legacy endpoint until backend is fully migrated
        do {
            let user = try await UserAPI.shared.getCurrentUser()
            currentUser = user
            isAuthenticated = true
            
            // Load profiles
            let profiles = try await ProfileAPI.shared.getProfiles()
            self.profiles = profiles.map { profile in
                ProfileSummaryV2(
                    id: profile.id,
                    displayName: profile.name,
                    username: nil,
                    avatarUrl: nil,
                    privacyMode: "linked",
                    isActive: profile.isActive
                )
            }
            
            // Set active profile
            if let active = profiles.first(where: { $0.isActive }) {
                activeProfile = ProfileSummaryV2(
                    id: active.id,
                    displayName: active.name,
                    username: nil,
                    avatarUrl: nil,
                    privacyMode: "linked",
                    isActive: true
                )
            }
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to fetch session: \(error)")
            if let apiError = error as? APIError, case .unauthorized = apiError {
                await logout()
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
        defer { isRefreshing = false }
        
        do {
            let response = try await authAPI.refreshTokenV2(refreshToken: refreshToken)
            
            try keychainManager.saveTokens(
                access: response.tokens.accessToken,
                refresh: response.tokens.refreshToken,
                expiresIn: response.tokens.expiresIn
            )
            
            APIService.shared.setAccessToken(response.tokens.accessToken)
            
            if !isAuthenticated {
                await fetchCurrentSession()
            }
            
        } catch {
            print("🔐 AuthenticationManagerV2: Token refresh failed: \(error)")
            if let apiError = error as? APIError, case .unauthorized = apiError {
                await logout()
            }
        }
    }
    
    func logout() async {
        // Call logout endpoint if authenticated
        if isAuthenticated, let refreshToken = keychainManager.getRefreshToken() {
            do {
                _ = try await authAPI.logoutV2(refreshToken: refreshToken)
            } catch {
                print("🔐 AuthenticationManagerV2: Logout API call failed: \(error)")
            }
        }
        
        // Clear tokens
        keychainManager.clearTokens()
        APIService.shared.clearAccessToken()
        
        // Reset state
        currentAccount = nil
        currentUser = nil
        profiles = []
        activeProfile = nil
        isAuthenticated = false
        isNewUser = false
        privacyMode = .linked
        sessionToken = nil
        
        // Clear profile data
        // ProfileViewModel.shared.clearData() // Not needed in V2
        
        // Notify session coordinator
        // SessionCoordinator.shared.handleLogout() // Not needed in V2
    }
    
    // MARK: - Identity Graph
    
    /// Get identity graph showing all linked accounts
    func getIdentityGraph() async throws -> IdentityGraphResponse {
        guard isAuthenticated else {
            throw AuthenticationError.tokenExpired
        }
        
        return try await authAPI.getIdentityGraph()
    }
}

// MARK: - Backward Compatibility

extension AuthenticationManagerV2 {
    /// Legacy authentication methods for backward compatibility
    
    func authenticateWithEmail(_ email: String, verificationCode: String) async throws {
        let config = WalletConnectionConfig(
            strategy: .email,
            walletType: nil,
            email: email,
            verificationCode: verificationCode,
            walletAddress: nil,
            signature: nil,
            message: nil,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        try await authenticate(with: config)
    }
    
    func authenticateWithWallet(address: String, signature: String, message: String, walletType: String) async throws {
        let config = WalletConnectionConfig(
            strategy: .wallet,
            walletType: walletType,
            email: nil,
            verificationCode: nil,
            walletAddress: address,
            signature: signature,
            message: message,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        try await authenticate(with: config)
    }
    
    func sendEmailCode(_ email: String) async throws {
        try await authAPI.sendEmailCodeV2(email: email)
    }
    
    // MARK: - Methods for V1 Compatibility
    
    /// Sign out (alias for logout)
    func signOut() async {
        await logout()
    }
    
    /// Validate auth token
    func validateAuthToken() async -> Bool {
        // Check if token exists and is not expired
        guard let _ = keychainManager.getAccessToken(),
              !keychainManager.isTokenExpired() else {
            return false
        }
        
        // Try to refresh if needed
        await refreshTokenIfNeeded()
        
        return isAuthenticated
    }
    
    /// Fetch current user (updates currentUser property)
    func fetchCurrentUser() async {
        guard isAuthenticated else { return }
        
        do {
            let user = try await authAPI.getCurrentUser()
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to fetch current user: \(error)")
        }
    }
    
    /// Resend email verification code
    func resendEmailCode(_ email: String) async throws {
        try await sendEmailCode(email)
    }
    
    /// Create profile for wallet
    func createProfileForWallet(name: String, walletAddress: String) async throws -> SmartProfile {
        // In V2, profiles are created automatically with accounts
        // This method is here for compatibility but may not be needed
        throw AuthenticationError.unknown("Profile creation is automatic in V2")
    }
    
    /// Authenticate with Google
    func authenticateWithGoogle() async throws {
        isLoading = true
        error = nil
        
        do {
            let googleResult = try await GoogleSignInService.shared.signIn()
            
            let config = WalletConnectionConfig(
                strategy: .google,
                walletType: nil,
                email: googleResult.email,
                verificationCode: nil,
                walletAddress: nil,
                signature: nil,
                message: nil,
                socialProvider: "google",
                socialProfile: SocialProfile(
                    id: googleResult.userId,
                    email: googleResult.email,
                    name: googleResult.name,
                    picture: googleResult.imageURL
                ),
                oauthCode: googleResult.idToken
            )
            
            try await authenticate(with: config)
            
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error as? AuthenticationError ?? AuthenticationError.unknown(error.localizedDescription)
            }
            throw error
        }
    }
    
    /// Authenticate with Apple
    func authenticateWithApple() async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let appleResult = try await AppleSignInService.shared.signIn()
            
            // Create Apple auth request for V2
            let appleAuth = AppleAuthRequest(
                identityToken: appleResult.identityToken,
                authorizationCode: appleResult.authorizationCode,
                user: AppleUserInfo(
                    id: appleResult.userId,
                    email: appleResult.email,
                    firstName: appleResult.fullName?.givenName,
                    lastName: appleResult.fullName?.familyName
                ),
                deviceId: DeviceInfo.deviceId,
                deviceName: DeviceInfo.deviceName,
                deviceType: DeviceInfo.deviceType
            )
            
            let request = AuthenticationRequestV2(
                strategy: AuthStrategy.apple.rawValue,
                identifier: nil,
                credential: nil,
                oauthCode: nil,
                appleAuth: appleAuth,
                privacyMode: privacyMode.rawValue,
                deviceId: UIDevice.current.identifierForVendor?.uuidString
            )
            
            let response = try await authAPI.authenticateV2(request: request)
            await processAuthResponse(response)
            
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error as? AuthenticationError ?? AuthenticationError.unknown(error.localizedDescription)
            }
            throw error
        }
    }
    
    /// Authenticate with Passkey
    func authenticateWithPasskey(email: String? = nil) async throws {
        isLoading = true
        error = nil
        
        do {
            // For V2, passkeys are treated as another authentication method
            let tokens = try await PasskeyService.shared.authenticateWithPasskey(username: email)
            
            // Store tokens
            try KeychainManager.shared.save(tokens.accessToken, for: .accessToken)
            try KeychainManager.shared.save(tokens.refreshToken, for: .refreshToken)
            
            // Update authentication state
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            // Fetch user profile
            await fetchCurrentUser()
            
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = AuthenticationError.passkeyAuthenticationFailed(error.localizedDescription)
            }
            throw error
        }
    }
    
    /// Authenticate with development wallet
    func authenticateWithDevelopmentWallet(profileId: String) async throws {
        #if DEBUG
        guard EnvironmentConfiguration.shared.isDevelopmentModeEnabled else {
            throw AuthenticationError.unknown("Development mode not enabled")
        }
        
        let devAddress = "0xDEV\(profileId.prefix(8))"
        let devSignature = "dev_signature_\(UUID().uuidString)"
        let devMessage = "Development authentication for testing"
        
        let config = WalletConnectionConfig(
            strategy: .testWallet,
            walletType: "development",
            email: nil,
            verificationCode: nil,
            walletAddress: devAddress,
            signature: devSignature,
            message: devMessage,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        
        try await authenticate(with: config)
        #else
        throw AuthenticationError.unknown("Development authentication not available in release builds")
        #endif
    }
}

