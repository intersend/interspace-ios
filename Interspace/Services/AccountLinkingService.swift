import Foundation
import Combine

// MARK: - Account Linking Service for V2 API

@MainActor
final class AccountLinkingService: ObservableObject {
    static let shared = AccountLinkingService()
    
    @Published var linkedAccounts: [AccountV2] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let authAPI = AuthAPI.shared
    private let authManager = AuthenticationManagerV2.shared
    
    private init() {}
    
    // MARK: - Account Linking Methods
    
    /// Link a new account to the current account
    func linkAccount(
        type: AccountType, 
        identifier: String, 
        provider: String? = nil, 
        linkType: String = "direct", 
        privacyMode: String = "linked",
        message: String? = nil,
        signature: String? = nil,
        walletType: String? = nil,
        chainId: Int? = nil,
        fid: String? = nil
    ) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = LinkAccountRequestV2(
                targetType: type.rawValue,
                targetIdentifier: identifier,
                targetProvider: provider,
                linkType: linkType,
                privacyMode: privacyMode,
                verificationCode: nil, // Only needed for email linking
                message: message,
                signature: signature,
                walletType: walletType,
                chainId: chainId,
                fid: fid
            )
            
            let response = try await authAPI.linkAccountsV2(request: request)
            
            // Update local state with the new linked account
            if !linkedAccounts.contains(where: { $0.id == response.linkedAccount.id }) {
                linkedAccounts.append(response.linkedAccount)
            }
            
            // Refresh the identity graph to get updated accounts
            await refreshIdentityGraph()
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /// Unlink an account
    func unlinkAccount(_ accountId: String, profileId: String) async throws {
        // Removed check for last account - flat identity model allows removing any account
        
        isLoading = true
        error = nil
        
        do {
            // Call unlink endpoint with profileId
            _ = try await ProfileAPI.shared.unlinkAccount(profileId: profileId, accountId: accountId)
            
            // Refresh identity graph
            await refreshIdentityGraph()
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /// Update privacy mode for a linked account
    func updatePrivacyMode(targetAccountId: String, privacyMode: PrivacyMode) async throws {
        isLoading = true
        error = nil
        
        do {
            _ = try await authAPI.updateLinkPrivacyV2(
                targetAccountId: targetAccountId,
                privacyMode: privacyMode.rawValue
            )
            
            // Refresh identity graph
            await refreshIdentityGraph()
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /// Refresh the identity graph
    func refreshIdentityGraph() async {
        guard authManager.isAuthenticated else { return }
        
        do {
            let response = try await authAPI.getIdentityGraph()
            // The response contains accounts array
            linkedAccounts = response.accounts
        } catch {
            print("Failed to refresh identity graph: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Email Linking
    
    /// Link email account
    func linkEmailAccount(email: String, verificationCode: String) async throws {
        // For email linking when already authenticated, we pass the verification code
        // directly to the link-accounts endpoint which will verify it
        
        isLoading = true
        error = nil
        
        do {
            let request = LinkAccountRequestV2(
                targetType: AccountType.email.rawValue,
                targetIdentifier: email,
                targetProvider: nil,
                linkType: "direct",
                privacyMode: "linked",
                verificationCode: verificationCode,
                message: nil,
                signature: nil,
                walletType: nil,
                chainId: nil,
                fid: nil
            )
            
            #if DEBUG
            print("🔗 AccountLinkingService: Linking email account")
            print("🔗 AccountLinkingService: Email: \(email)")
            print("🔗 AccountLinkingService: Verification code: \(verificationCode)")
            print("🔗 AccountLinkingService: Request: \(request)")
            #endif
            
            let response = try await authAPI.linkAccountsV2(request: request)
            
            // Update local state with the new linked account
            if !linkedAccounts.contains(where: { $0.id == response.linkedAccount.id }) {
                linkedAccounts.append(response.linkedAccount)
            }
            
            // Refresh the identity graph to get updated accounts
            await refreshIdentityGraph()
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    // MARK: - Wallet Linking
    
    /// Link wallet account
    func linkWalletAccount(address: String, signature: String, message: String, walletType: String) async throws {
        try await linkAccount(
            type: .wallet,
            identifier: address,
            provider: walletType,
            message: message,
            signature: signature,
            walletType: walletType
        )
    }
    
    // MARK: - Social Linking
    
    /// Link Google account using decoded user ID
    func linkGoogleAccount(userId: String) async throws {
        try await linkAccount(
            type: .social,
            identifier: userId,  // Now expects decoded user ID, not token
            provider: "google",
            linkType: "direct",
            privacyMode: "linked",
            message: nil,
            signature: nil,
            walletType: nil,
            chainId: nil,
            fid: nil
        )
    }
    
    /// Link Apple account using decoded user ID
    func linkAppleAccount(userId: String) async throws {
        try await linkAccount(
            type: .social,
            identifier: userId,  // Expects decoded user ID from JWT
            provider: "apple",
            linkType: "direct",
            privacyMode: "linked",
            message: nil,
            signature: nil,
            walletType: nil,
            chainId: nil,
            fid: nil
        )
    }
    
    /// Link Farcaster account
    func linkFarcasterAccount(fid: String, message: String, signature: String) async throws {
        try await linkAccount(
            type: .social,
            identifier: fid,
            provider: "farcaster",
            linkType: "direct",
            privacyMode: "linked",
            message: message,
            signature: signature,
            walletType: nil,
            chainId: nil,
            fid: fid
        )
    }
    
    // MARK: - Helper Methods
    
    /// Check if a specific account type is already linked
    func isAccountTypeLinked(_ type: AccountType) -> Bool {
        linkedAccounts.contains { $0.accountType == type.rawValue }
    }
    
    /// Get accounts of a specific type
    func getAccountsOfType(_ type: AccountType) -> [AccountV2] {
        linkedAccounts.filter { $0.accountType == type.rawValue }
    }
    
    /// Get primary account
    var primaryAccount: AccountV2? {
        // For now, return the first account as primary
        // TODO: Add isPrimary property to AccountV2 when backend supports it
        linkedAccounts.first
    }
    
    // MARK: - Account Unlinking
    
    /// Unlink an account from the identity graph
    func unlinkAccount(_ account: AccountV2) async throws {
        // Removed check for last account - flat identity model allows removing any account
        
        isLoading = true
        error = nil
        
        do {
            // Call the unlink accounts endpoint
            struct UnlinkRequest: Codable {
                let targetAccountId: String
            }
            
            struct UnlinkResponse: Codable {
                let success: Bool
                let message: String?
            }
            
            let request = UnlinkRequest(targetAccountId: account.id)
            
            let _: UnlinkResponse = try await APIService.shared.performRequest(
                endpoint: "/auth/unlink-accounts",
                method: .POST,
                body: try JSONEncoder().encode(request),
                responseType: UnlinkResponse.self
            )
            
            // Remove from local array
            linkedAccounts.removeAll { $0.id == account.id }
            
            // Refresh identity graph to ensure consistency
            await refreshIdentityGraph()
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
}

// MARK: - Authentication Error Extension
// Removed lastAccountCannotBeUnlinked error - flat identity model allows removing any account
