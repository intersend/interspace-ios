import Foundation
import Combine
import SwiftUI

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
            var request: [String: Any] = ["strategy": config.strategy.rawValue]
            
            switch config.strategy {
            case .email:
                guard let email = config.email,
                      let code = config.verificationCode else {
                    throw AuthenticationError.invalidCredentials
                }
                request["email"] = email
                request["code"] = code // V2 API expects 'code' not 'verificationCode'
                
            case .wallet:
                guard let address = config.walletAddress,
                      let signature = config.signature,
                      let message = config.message else {
                    throw AuthenticationError.invalidCredentials
                }
                request["walletAddress"] = address
                request["signature"] = signature
                request["message"] = message
                request["walletType"] = config.walletType
                
            case .google:
                // Handle Google auth
                break
                
            case .guest:
                // No additional data needed
                break
                
            default:
                throw AuthenticationError.unknown("Unsupported authentication strategy")
            }
            
            // Add privacy mode and device info
            request["privacyMode"] = privacyMode.rawValue
            request["deviceId"] = UIDevice.current.identifierForVendor?.uuidString
            
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
                expiresIn: response.tokens.expiresIn ?? 900
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
            targetType: type.rawValue,
            targetIdentifier: identifier,
            targetProvider: provider,
            linkType: "direct",
            privacyMode: privacyMode.rawValue
        )
        
        do {
            let response = try await authAPI.linkAccountsV2(request: request)
            
            // Update accessible profiles
            profiles = response.accessibleProfiles
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
                    name: profile.name,
                    isActive: profile.isActive,
                    sessionWalletAddress: profile.sessionWalletAddress,
                    linkedAccountsCount: profile.linkedAccountsCount
                )
            }
            
            // Set active profile
            if let active = profiles.first(where: { $0.isActive }) {
                activeProfile = ProfileSummaryV2(
                    id: active.id,
                    name: active.name,
                    isActive: true,
                    sessionWalletAddress: active.sessionWalletAddress,
                    linkedAccountsCount: active.linkedAccountsCount
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
                expiresIn: response.tokens.expiresIn ?? 900 ?? 900
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
        if isAuthenticated {
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
        await ProfileViewModel.shared.clearData()
        
        // Notify session coordinator
        await SessionCoordinator.shared.handleLogout()
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
            socialProfile: nil
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
            socialProfile: nil
        )
        try await authenticate(with: config)
    }
    
    func sendEmailCode(_ email: String) async throws {
        try await authAPI.sendEmailCodeV2(email: email)
    }
}

