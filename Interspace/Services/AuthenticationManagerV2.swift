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

struct OAuthTokenResponse {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: TimeInterval?
    let provider: String
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
    @Published var currentUser: UserV2?
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
                      let signature = config.signature,
                      let message = config.message else {
                    throw AuthenticationError.invalidCredentials
                }
                identifier = address
                credential = signature
                
            case .google:
                // Handle Google auth - needs oauth code or access token
                if let code = config.oauthCode {
                    oauthCode = code
                } else if let token = config.accessToken {
                    // For AppAuth flow, we get access token directly
                    credential = token
                } else {
                    throw AuthenticationError.invalidCredentials
                }
                
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
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                // Email-specific fields
                email: config.strategy == .email ? config.email : nil,
                verificationCode: config.strategy == .email ? config.verificationCode : nil,
                // Wallet-specific fields
                walletAddress: config.strategy == .wallet ? config.walletAddress : nil,
                signature: config.strategy == .wallet ? config.signature : nil,
                message: config.strategy == .wallet ? config.message : nil,
                walletType: config.strategy == .wallet ? config.walletType : nil,
                // Social-specific fields
                idToken: config.idToken,
                accessToken: config.accessToken,
                shopDomain: config.shopDomain
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
                expiresIn: response.tokens.expiresIn ?? 900 // Default to 15 minutes
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
        isNewUser = response.isNewAccount
        privacyMode = PrivacyMode(rawValue: response.privacyMode) ?? .linked
        sessionToken = response.sessionId
        isAuthenticated = true
        
        // Load additional data if needed
        if !isNewUser && activeProfile != nil {
            await ProfileViewModel.shared.loadProfile()
        }
    }
    
    /// Process legacy authentication response (for SIWE)
    private func processLegacyAuthResponse(_ response: AuthenticationResponse) async {
        // Save tokens
        do {
            try keychainManager.saveTokens(
                access: response.data.accessToken,
                refresh: response.data.refreshToken,
                expiresIn: response.data.expiresIn
            )
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to save tokens: \(error)")
        }
        
        // Update API service
        APIService.shared.setAccessToken(response.data.accessToken)
        
        // Update authentication state
        isAuthenticated = true
        
        // Check if this is a new user based on wallet profile info
        if let walletInfo = response.data.walletProfileInfo {
            isNewUser = !walletInfo.isLinked || walletInfo.profileId == nil
        }
        
        // Fetch current session data
        await fetchCurrentSession()
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
    
    // MARK: - OAuth Authentication
    
    /// Authenticate with OAuth provider
    func authenticateWithOAuth(provider: String, tokens: OAuthTokenResponse) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = AuthenticationRequestV2(
                strategy: provider.lowercased(),
                identifier: nil,
                credential: nil,
                oauthCode: nil,
                appleAuth: nil,
                privacyMode: privacyMode.rawValue,
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                email: nil,
                verificationCode: nil,
                walletAddress: nil,
                signature: nil,
                message: nil,
                walletType: nil,
                idToken: tokens.idToken,
                accessToken: tokens.accessToken,
                shopDomain: provider.lowercased() == "shopify" ? UserDefaults.standard.string(forKey: "shopify_shop_domain") : nil
            )
            
            // Call V2 authentication endpoint
            let response = try await authAPI.authenticateV2(request: request)
            
            // Process response
            await processAuthResponse(response)
            
            isLoading = false
            
        } catch {
            isLoading = false
            self.error = error as? AuthenticationError ?? .unknown("OAuth authentication failed")
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
            targetType: type.rawValue,
            targetIdentifier: identifier,
            targetProvider: provider,
            linkType: "direct",
            privacyMode: "linked",
            verificationCode: nil // Only needed for email linking
        )
        
        do {
            let response = try await authAPI.linkAccountsV2(request: request)
            
            // The link was successful
            print("🔐 AuthenticationManagerV2: Successfully linked account: \(response.linkedAccount.identifier)")
            
            // Notify that accounts have been updated
            NotificationCenter.default.post(name: .accountsUpdated, object: nil)
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
        
        // Set token in API service immediately
        APIService.shared.setAccessToken(accessToken)
        print("🔐 AuthenticationManagerV2: Access token set in APIService")
        
        // Mark as authenticated immediately since we have valid tokens
        // This prevents race conditions where API calls fail due to missing auth state
        isAuthenticated = true
        print("🔐 AuthenticationManagerV2: Authentication state updated")
        
        // Check if token is expired
        if keychainManager.isTokenExpired() {
            print("🔐 AuthenticationManagerV2: Token expired, refreshing...")
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            // Token is valid, fetch current session in background
            print("🔐 AuthenticationManagerV2: Token valid, fetching session data")
            Task {
                await fetchCurrentSession()
            }
        }
    }
    
    private func fetchCurrentSession() async {
        // For now, use legacy endpoint until backend is fully migrated
        do {
            let user = try await UserAPI.shared.getCurrentUser()
            // Convert User to UserV2
            currentUser = UserV2(
                id: user.id,
                email: user.email,
                isGuest: user.isGuest
            )
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
    
    /// Validate the current auth token
    func validateAuthToken() async -> Bool {
        guard let accessToken = keychainManager.getAccessToken() else {
            print("🔐 AuthenticationManagerV2: No access token to validate")
            return false
        }
        
        // Ensure token is set in APIService
        APIService.shared.setAccessToken(accessToken)
        
        // Check if token is expired locally first
        if keychainManager.isTokenExpired() {
            print("🔐 AuthenticationManagerV2: Token is expired locally")
            return false
        }
        
        // Token appears valid
        return true
    }
    
    func refreshTokenIfNeeded() async {
        // Simple approach: if already refreshing, wait a bit and return
        if isRefreshing {
            #if DEBUG
            print("🔐 AuthenticationManagerV2: Token refresh already in progress, waiting...")
            #endif
            
            // Wait up to 3 seconds for the refresh to complete
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                if !isRefreshing {
                    #if DEBUG
                    print("🔐 AuthenticationManagerV2: Refresh completed, continuing...")
                    #endif
                    return
                }
            }
            
            #if DEBUG
            print("🔐 AuthenticationManagerV2: Refresh timeout, continuing anyway...")
            #endif
            return
        }
        
        guard let refreshToken = keychainManager.getRefreshToken() else {
            await logout()
            return
        }
        
        isRefreshing = true
        defer { 
            isRefreshing = false
        }
        
        do {
            #if DEBUG
            print("🔐 AuthenticationManagerV2: Starting token refresh...")
            #endif
            
            let response = try await authAPI.refreshTokenV2(refreshToken: refreshToken)
            
            try keychainManager.saveTokens(
                access: response.tokens.accessToken,
                refresh: response.tokens.refreshToken,
                expiresIn: response.tokens.expiresIn ?? 900 // Default to 15 minutes
            )
            
            APIService.shared.setAccessToken(response.tokens.accessToken)
            
            #if DEBUG
            print("🔐 AuthenticationManagerV2: Token refreshed successfully")
            print("🔐 AuthenticationManagerV2: New access token prefix: \(String(response.tokens.accessToken.prefix(20)))")
            #endif
            
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
                _ = try await authAPI.logoutV2()
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
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
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
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        try await authenticate(with: config)
    }
    
    func sendEmailCode(_ email: String) async throws -> EmailCodeResponse {
        // Use V2 endpoint for email code
        return try await authAPI.sendEmailCodeV2(email: email)
    }
    
    func resendEmailCode(_ email: String) async throws -> EmailCodeResponse {
        // Use V2 endpoint for resending email code
        return try await authAPI.resendEmailCodeV2(email: email)
    }
    
    // MARK: - Methods for V1 Compatibility
    
    /// Sign out (alias for logout)
    func signOut() async {
        await logout()
    }
    
    /// Fetch current user (updates currentUser property)
    func fetchCurrentUser() async {
        guard isAuthenticated else { return }
        
        do {
            let user = try await UserAPI.shared.getCurrentUser()
            await MainActor.run {
                // Convert User to UserV2
                self.currentUser = UserV2(
                    id: user.id,
                    email: user.email,
                    isGuest: user.isGuest
                )
            }
        } catch {
            print("🔐 AuthenticationManagerV2: Failed to fetch current user: \(error)")
        }
    }
    
    /// Create profile for wallet
    func createProfileForWallet(name: String, walletAddress: String) async throws -> SmartProfile {
        // In V2, profiles are created automatically with accounts
        // This method is here for compatibility but may not be needed
        throw AuthenticationError.unknown("Profile creation is automatic in V2")
    }
    
    /// Authenticate with Google using AppAuth
    func authenticateWithGoogle() async throws {
        isLoading = true
        error = nil
        
        do {
            guard let provider = OAuthProviderService.shared.provider(for: "google") else {
                throw AuthenticationError.unknown("Google provider not configured")
            }
            
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let viewController = await windowScene.windows.first?.rootViewController else {
                throw AuthenticationError.unknown("Unable to present OAuth flow")
            }
            
            let tokens = try await withCheckedThrowingContinuation { continuation in
                OAuthProviderService.shared.authenticate(
                    with: provider,
                    presentingViewController: viewController
                ) { result in
                    continuation.resume(with: result)
                }
            }
            
            try await authenticateWithOAuth(
                provider: "google",
                tokens: OAuthTokenResponse(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken,
                    idToken: tokens.idToken,
                    expiresIn: tokens.expiresIn,
                    provider: tokens.provider
                )
            )
            
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
                account: AppleUserInfo(
                    id: appleResult.accountId,
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
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                email: nil,
                verificationCode: nil,
                walletAddress: nil,
                signature: nil,
                message: nil,
                walletType: nil,
                idToken: nil,
                accessToken: nil,
                shopDomain: nil
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
            strategy: .wallet,
            walletType: "development",
            email: nil,
            verificationCode: nil,
            walletAddress: devAddress,
            signature: devSignature,
            message: devMessage,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        
        try await authenticate(with: config)
        #else
        throw AuthenticationError.unknown("Development authentication not available in release builds")
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let accountsUpdated = Notification.Name("accountsUpdated")
}

