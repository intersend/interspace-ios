import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Singleton
    static let shared = ProfileViewModel()
    
    // Private init to ensure singleton usage
    private init() {}
    @Published var profiles: [SmartProfile] = []
    @Published var activeProfile: SmartProfile?
    @Published var linkedAccounts: [LinkedAccount] = []
    @Published var socialAccounts: [SocialAccount] = []
    @Published var emailAccounts: [AccountV2] = [] // Email accounts from identity graph
    @Published var isLoading = false
    @Published var showError = false
    @Published var error: Error?
    @Published var showDeveloperSettings = false
    
    // MPC Wallet State
    @Published var mpcWalletInfo: WalletInfo?
    @Published var isGeneratingMPCWallet = false
    @Published var isSigningTransaction = false
    @Published var mpcOperationError: MPCError?
    
    private let profileAPI = ProfileAPI.shared
    private let userAPI = UserAPI.shared
    private let mpcWalletService = MPCWalletService.shared
    private var versionTapCount = 0
    private var tapResetTimer: Timer?
    private var hasLoadedInitialData = false
    
    // MARK: - Profile Management
    
    func loadProfiles() async {
        isLoading = true
        
        do {
            let fetchedProfiles = try await profileAPI.getProfiles()
            await MainActor.run {
                self.profiles = fetchedProfiles
                self.activeProfile = fetchedProfiles.first { $0.isActive }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func loadProfile() async {
        // Prevent showing loading state on subsequent calls if we already have data
        if !hasLoadedInitialData {
            isLoading = true
        }
        
        do {
            // Load all profiles
            let fetchedProfiles = try await profileAPI.getProfiles()
            
            // Find active profile
            let active = fetchedProfiles.first { $0.isActive }
            
            await MainActor.run {
                self.profiles = fetchedProfiles
                self.activeProfile = active
                self.hasLoadedInitialData = true
                isLoading = false
            }
            
            // Load additional data for active profile
            if let activeProfile = active {
                await loadProfileDetails(profileId: activeProfile.id)
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    private func loadProfileDetails(profileId: String) async {
        do {
            // Load linked accounts for the profile
            async let accountsTask = loadLinkedAccounts(profileId: profileId)
            
            // Load social accounts for the user
            async let socialTask = loadSocialAccounts()
            
            // Load email accounts from identity graph
            async let emailTask = loadEmailAccounts()
            
            // Check MPC wallet status
            async let mpcTask = checkMPCWalletStatus()
            
            // Wait for all to complete
            let _ = await (accountsTask, socialTask, emailTask, mpcTask)
            
        } catch {
            await MainActor.run {
                self.showError(error)
            }
        }
    }
    
    
    private func loadLinkedAccounts(profileId: String) async {
        do {
            let fetchedAccounts = try await profileAPI.getLinkedAccounts(profileId: profileId)
            await MainActor.run {
                self.linkedAccounts = fetchedAccounts
            }
        } catch {
            print("Error loading linked accounts: \(error)")
            await MainActor.run {
                self.linkedAccounts = []
            }
        }
    }
    
    private func loadSocialAccounts() async {
        do {
            let fetchedSocialAccounts = try await userAPI.getSocialAccounts()
            await MainActor.run {
                self.socialAccounts = fetchedSocialAccounts
            }
        } catch {
            print("Error loading social accounts: \(error)")
        }
    }
    
    private func loadEmailAccounts() async {
        // Get identity graph from AccountLinkingService
        let linkingService = AccountLinkingService.shared
        
        // Only proceed if authenticated
        guard AuthenticationManagerV2.shared.isAuthenticated else {
            print("ProfileViewModel: Not authenticated, skipping email accounts load")
            await MainActor.run {
                self.emailAccounts = []
            }
            return
        }
        
        // Refresh identity graph
        await linkingService.refreshIdentityGraph()
        
        // Filter email accounts from the linked accounts
        // linkedAccounts contains AccountV2 objects from identity graph
        let emailAccounts = linkingService.linkedAccounts.filter { account in
            account.accountType == "email"
        }
        
        await MainActor.run {
            self.emailAccounts = emailAccounts
        }
        
        print("ProfileViewModel: Loaded \(emailAccounts.count) email accounts")
    }
    
    func refreshProfile() async {
        await loadProfile()
    }
    
    func switchProfile(_ profile: SmartProfile) async {
        isLoading = true
        
        do {
            // Activate the selected profile
            let _ = try await profileAPI.activateProfile(profileId: profile.id)
            
            // Reload all profile data to reflect the change
            await loadProfile()
            
            await MainActor.run {
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func createProfile(name: String) async {
        isLoading = true
        
        do {
            // For now, always create development profiles to simplify testing
            let isDevelopmentMode = true
            
            let newProfile = try await profileAPI.createProfile(
                name: name,
                developmentMode: isDevelopmentMode
            )
            
            // If it's a development wallet, store the clientShare locally
            if let clientShare = newProfile.clientShare {
                // Store in keychain for this profile
                try? KeychainManager.shared.saveDevelopmentClientShare(
                    clientShare: clientShare,
                    profileId: newProfile.id
                )
            }
            
            // Reload profile data to include the new profile
            await loadProfile()
            
            await MainActor.run {
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func deleteProfile(_ profile: SmartProfile) async {
        isLoading = true
        
        do {
            let _ = try await profileAPI.deleteProfile(profileId: profile.id)
            
            // Reload profile data to remove the deleted profile
            await loadProfile()
            
            await MainActor.run {
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func activateProfile(_ profile: SmartProfile) {
        Task {
            await switchProfile(profile)
        }
    }
    
    func updateProfile(_ profile: SmartProfile, name: String) async {
        isLoading = true
        
        do {
            let updatedProfile = try await profileAPI.updateProfile(
                profileId: profile.id,
                name: name,
                isActive: nil
            )
            
            // Update the profile in the local array
            await MainActor.run {
                if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                    self.profiles[index] = updatedProfile
                }
                
                // Update active profile if it's the one being updated
                if self.activeProfile?.id == profile.id {
                    self.activeProfile = updatedProfile
                }
                
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    // MARK: - Account Management
    
    func linkAccount(address: String, walletType: WalletType, customName: String?) async {
        guard let activeProfile = activeProfile else { return }
        
        isLoading = true
        
        do {
            let request = LinkAccountRequest(
                address: address,
                walletType: walletType.rawValue,
                customName: customName,
                isPrimary: linkedAccounts.isEmpty, // First account becomes primary
                signature: nil,
                message: nil,
                chainId: nil
            )
            
            let newAccount = try await profileAPI.linkAccount(profileId: activeProfile.id, request: request)
            
            await MainActor.run {
                self.linkedAccounts.append(newAccount)
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func createApp(_ request: CreateAppRequest) async {
        guard let activeProfile = activeProfile else { return }
        
        isLoading = true
        
        do {
            let newApp = try await profileAPI.createApp(profileId: activeProfile.id, request: request)
            
            await MainActor.run {
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func linkWallet(config: WalletConnectionConfig) async throws {
        // Link wallet to the active profile
        guard let activeProfile = activeProfile,
              let address = config.walletAddress,
              let walletType = config.walletType,
              let signature = config.signature,
              let message = config.message else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Use the existing linkWalletAccount method
        await linkWalletAccount(
            address: address,
            walletType: WalletType(rawValue: walletType) ?? .metamask,
            signature: signature,
            message: message,
            customName: nil
        )
    }
    
    func linkWalletAccount(address: String, walletType: WalletType, signature: String, message: String, customName: String?) async {
        guard let activeProfile = activeProfile else { return }
        
        isLoading = true
        
        do {
            let request = LinkAccountRequest(
                address: address,
                walletType: walletType.rawValue,
                customName: customName,
                isPrimary: linkedAccounts.isEmpty, // First account becomes primary
                signature: signature,
                message: message,
                chainId: nil
            )
            
            let newAccount = try await profileAPI.linkAccount(profileId: activeProfile.id, request: request)
            
            await MainActor.run {
                self.linkedAccounts.append(newAccount)
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func unlinkAccount(_ account: LinkedAccount) async {
        isLoading = true
        
        do {
            let _ = try await profileAPI.unlinkAccount(accountId: account.id)
            
            await MainActor.run {
                self.linkedAccounts.removeAll { $0.id == account.id }
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func updateAccount(_ account: LinkedAccount, customName: String?, isPrimary: Bool?) async {
        isLoading = true
        
        do {
            let request = UpdateAccountRequest(customName: customName, isPrimary: isPrimary)
            let updatedAccount = try await profileAPI.updateLinkedAccount(
                accountId: account.id,
                request: request
            )
            
            await MainActor.run {
                if let index = self.linkedAccounts.firstIndex(where: { $0.id == account.id }) {
                    self.linkedAccounts[index] = updatedAccount
                }
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func setPrimaryAccount(_ account: LinkedAccount) async {
        await updateAccount(account, customName: nil, isPrimary: true)
    }
    
    func updateAccountName(_ account: LinkedAccount, name: String?) async {
        await updateAccount(account, customName: name, isPrimary: nil)
    }
    
    // MARK: - Social Account Management
    
    func linkSocialAccount(provider: SocialProvider, oauthCode: String, redirectUri: String) async {
        isLoading = true
        
        do {
            let request = LinkSocialAccountRequest(
                provider: provider.rawValue,
                oauthCode: oauthCode,
                redirectUri: redirectUri
            )
            let newAccount = try await userAPI.linkSocialAccount(request: request)
            
            await MainActor.run {
                self.socialAccounts.append(newAccount)
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func unlinkSocialAccount(_ account: SocialAccount) async {
        isLoading = true
        
        do {
            let _ = try await userAPI.unlinkSocialAccount(socialAccountId: account.id)
            
            await MainActor.run {
                self.socialAccounts.removeAll { $0.id == account.id }
                isLoading = false
                // Show success feedback
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    // MARK: - MPC Wallet Management
    
    /// Generate MPC wallet for the active profile
    func generateMPCWallet() async {
        guard let activeProfile = activeProfile else { return }
        guard MPCWalletService.isEnabled else { return }
        
        isGeneratingMPCWallet = true
        mpcOperationError = nil
        
        do {
            let walletInfo = try await mpcWalletService.generateWallet(for: activeProfile.id)
            
            await MainActor.run {
                self.mpcWalletInfo = walletInfo
                isGeneratingMPCWallet = false
            }
            
            // Reload profile to reflect wallet creation
            await loadProfile()
            
        } catch let error as MPCError {
            await MainActor.run {
                self.mpcOperationError = error
                self.showError(error)
                isGeneratingMPCWallet = false
            }
        } catch {
            await MainActor.run {
                self.mpcOperationError = .unknown(error)
                self.showError(error)
                isGeneratingMPCWallet = false
            }
        }
    }
    
    /// Sign a transaction using MPC
    func signTransaction(_ transaction: TransactionRequest) async throws -> String {
        guard let activeProfile = activeProfile else {
            throw MPCError.profileNotFound
        }
        
        isSigningTransaction = true
        mpcOperationError = nil
        
        defer {
            Task { @MainActor in
                isSigningTransaction = false
            }
        }
        
        do {
            let signature = try await mpcWalletService.signTransaction(
                profileId: activeProfile.id,
                transaction: transaction
            )
            return signature
        } catch let error as MPCError {
            await MainActor.run {
                self.mpcOperationError = error
                self.showError(error)
            }
            throw error
        } catch {
            let mpcError = MPCError.unknown(error)
            await MainActor.run {
                self.mpcOperationError = mpcError
                self.showError(mpcError)
            }
            throw mpcError
        }
    }
    
    /// Check if active profile has MPC wallet
    func checkMPCWalletStatus() async {
        guard let activeProfile = activeProfile else { return }
        guard MPCWalletService.isEnabled else { return }
        
        let hasWallet = await mpcWalletService.hasWallet(for: activeProfile.id)
        if hasWallet {
            let info = await mpcWalletService.getWalletInfo(for: activeProfile.id)
            await MainActor.run {
                self.mpcWalletInfo = info
            }
        } else {
            await MainActor.run {
                self.mpcWalletInfo = nil
            }
        }
    }
    
    /// Rotate MPC keys
    func rotateMPCKeys() async {
        guard let activeProfile = activeProfile else { return }
        
        isLoading = true
        mpcOperationError = nil
        
        do {
            try await mpcWalletService.rotateKey(for: activeProfile.id)
            
            await MainActor.run {
                isLoading = false
            }
            
            // Reload wallet info
            await checkMPCWalletStatus()
            
        } catch let error as MPCError {
            await MainActor.run {
                self.mpcOperationError = error
                self.showError(error)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.mpcOperationError = .unknown(error)
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    /// Create MPC wallet backup
    func createMPCBackup(rsaPublicKey: String, label: String) async throws -> BackupData {
        guard let activeProfile = activeProfile else {
            throw MPCError.profileNotFound
        }
        
        isLoading = true
        mpcOperationError = nil
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let backup = try await mpcWalletService.createBackup(
                profileId: activeProfile.id,
                rsaPublicKey: rsaPublicKey,
                label: label
            )
            return backup
        } catch let error as MPCError {
            await MainActor.run {
                self.mpcOperationError = error
                self.showError(error)
            }
            throw error
        } catch {
            let mpcError = MPCError.unknown(error)
            await MainActor.run {
                self.mpcOperationError = mpcError
                self.showError(mpcError)
            }
            throw mpcError
        }
    }
    
    /// Export MPC private key (critical operation)
    func exportMPCPrivateKey(clientEncryptionKey: Data) async throws -> ExportData {
        guard let activeProfile = activeProfile else {
            throw MPCError.profileNotFound
        }
        
        isLoading = true
        mpcOperationError = nil
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let exportData = try await mpcWalletService.exportKey(
                profileId: activeProfile.id,
                clientEncryptionKey: clientEncryptionKey
            )
            return exportData
        } catch let error as MPCError {
            await MainActor.run {
                self.mpcOperationError = error
                self.showError(error)
            }
            throw error
        } catch {
            let mpcError = MPCError.unknown(error)
            await MainActor.run {
                self.mpcOperationError = mpcError
                self.showError(mpcError)
            }
            throw mpcError
        }
    }
    
    /// Clear MPC error state
    func clearMPCError() {
        mpcOperationError = nil
    }
    
    // MARK: - Developer Mode
    
    func handleVersionTap() {
        #if DEBUG
        // Reset timer if exists
        tapResetTimer?.invalidate()
        
        // Increment tap count
        versionTapCount += 1
        
        // Check if we've reached the magic number
        if versionTapCount >= 7 {
            // Enable developer mode and show settings
            // TODO: Uncomment when EnvironmentConfiguration is added to project
            // EnvironmentConfiguration.shared.toggleDevelopmentMode()
            showDeveloperSettings = true
            versionTapCount = 0
        }
        
        // Reset tap count after 2 seconds of no taps
        tapResetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.versionTapCount = 0
        }
        #endif
    }
    
    // MARK: - Error Handling
    
    func showError(_ error: Error) {
        self.error = error
        showError = true
    }
    
    func dismissError() {
        error = nil
        showError = false
    }
}
