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
    func linkAccount(type: AccountType, identifier: String, provider: String? = nil, linkType: String = "direct", privacyMode: String = "linked") async throws {
        isLoading = true
        error = nil
        
        do {
            let request = LinkAccountRequestV2(
                targetType: type.rawValue,
                targetIdentifier: identifier,
                targetProvider: provider,
                linkType: linkType,
                privacyMode: privacyMode,
                verificationCode: nil // Only needed for email linking
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
    func unlinkAccount(_ accountId: String) async throws {
        guard linkedAccounts.count > 1 else {
            throw AuthenticationError.lastAccountCannotBeUnlinked
        }
        
        isLoading = true
        error = nil
        
        do {
            // Call unlink endpoint (needs to be added to AuthAPI)
            // For now, we'll use the profile API endpoint
            _ = try await ProfileAPI.shared.unlinkAccount(accountId: accountId)
            
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
                verificationCode: verificationCode
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
    
    // MARK: - Wallet Linking
    
    /// Link wallet account
    func linkWalletAccount(address: String, signature: String, message: String, walletType: String) async throws {
        try await linkAccount(
            type: .wallet,
            identifier: address,
            provider: walletType
        )
    }
    
    // MARK: - Social Linking
    
    /// Link Google account
    func linkGoogleAccount(idToken: String) async throws {
        try await linkAccount(
            type: .social,
            identifier: idToken,
            provider: "google"
        )
    }
    
    /// Link Apple account
    func linkAppleAccount(userId: String, email: String?) async throws {
        try await linkAccount(
            type: .social,
            identifier: userId,
            provider: "apple"
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
}

// MARK: - Authentication Error Extension

extension AuthenticationError {
    static let lastAccountCannotBeUnlinked = AuthenticationError.unknown("Cannot unlink the last remaining account")
}
