import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Singleton
    static let shared = ProfileViewModel()
    
    // Private init to ensure singleton usage
    private init() {
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
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
    private let mpcWalletService = MPCWalletServiceHTTP.shared
    private let authManager = AuthenticationManagerV2.shared
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
            
            // Update cache with fresh data
            await updateCachedProfiles(fetchedProfiles)
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
                
                // Check if MPC generation is needed for this profile
                if activeProfile.needsMpcGeneration == true && MPCWalletServiceHTTP.isEnabled {
                    print("🔐 ProfileViewModel: Profile needs MPC generation, triggering...")
                    await generateMPCWallet()
                }
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    private func loadProfileDetails(profileId: String) async {
        // Clear accounts before loading new profile details
        await MainActor.run {
            self.linkedAccounts = []
        }
        
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
            
            // Filter out the session wallet from linked accounts
            let sessionWalletAddress = activeProfile?.sessionWalletAddress ?? ""
            let filteredAccounts = fetchedAccounts.filter { account in
                // Compare addresses case-insensitively (Ethereum addresses)
                account.address.lowercased() != sessionWalletAddress.lowercased()
            }
            
            // Debug logging
            print("🟢 ProfileViewModel.loadLinkedAccounts - Fetched \(fetchedAccounts.count) accounts, filtered to \(filteredAccounts.count):")
            for account in filteredAccounts {
                print("  - ID: \(account.id), Address: \(account.address)")
            }
            if fetchedAccounts.count != filteredAccounts.count {
                print("  - Filtered out session wallet: \(sessionWalletAddress)")
            }
            
            await MainActor.run {
                // Always update the linkedAccounts array with filtered accounts
                self.linkedAccounts = filteredAccounts
            }
        } catch {
            print("Error loading linked accounts: \(error)")
            await MainActor.run {
                // Clear accounts on error as well
                self.linkedAccounts = []
            }
        }
    }
    
    private func loadSocialAccounts() async {
        do {
            let fetchedSocialAccounts = try await userAPI.getSocialAccounts()
            
            // Debug logging for Apple accounts
            print("🍎 ProfileViewModel.loadSocialAccounts - Fetched \(fetchedSocialAccounts.count) social accounts:")
            for account in fetchedSocialAccounts {
                print("  - Provider: \(account.provider.rawValue), DisplayName: \(account.displayName ?? "N/A")")
                if account.provider == .apple {
                    print("  ✅ Apple account found: \(account.displayName ?? account.username ?? "Unknown")")
                }
            }
            
            let appleAccounts = fetchedSocialAccounts.filter { $0.provider == .apple }
            if appleAccounts.isEmpty {
                print("  ⚠️ No Apple accounts found in the response")
            }
            
            await MainActor.run {
                self.socialAccounts = fetchedSocialAccounts
            }
        } catch {
            print("❌ Error loading social accounts: \(error)")
        }
    }
    
    private func loadEmailAccounts() async {
        // Email accounts should be shown if they're linked to this specific profile
        // They would come through the linked accounts API, not from the identity graph
        
        // For now, clear email accounts since they're included in linkedAccounts
        // In the future, we might want to separate them for better UI organization
        await MainActor.run {
            self.emailAccounts = []
        }
        
        print("ProfileViewModel: Email accounts are included in linkedAccounts")
    }
    
    func refreshProfile() async {
        await loadProfile()
    }
    
    func switchProfile(_ profile: SmartProfile) async {
        isLoading = true
        
        do {
            // Update active profile immediately to prevent null state
            await MainActor.run {
                self.activeProfile = profile
            }
            
            // Use SessionCoordinator for the actual switch to ensure state sync
            try await SessionCoordinator.shared.switchProfile(profile)
            
            // Clear and reload profile data after successful switch
            await MainActor.run {
                self.linkedAccounts = []
                self.socialAccounts = []
                self.emailAccounts = []
                self.mpcWalletInfo = nil
            }
            
            // Reload all profile data to reflect the change
            await loadProfile()
            
            // Force reload social accounts after profile switch
            await loadSocialAccounts()
            
            await MainActor.run {
                // Show success feedback
                print("✅ ProfileViewModel: Successfully switched to profile: \(profile.name)")
            }
            
        } catch {
            // Revert to previous profile on error if available
            if let previousProfile = SessionCoordinator.shared.activeProfile {
                await MainActor.run {
                    self.activeProfile = previousProfile
                }
            }
            
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
    func createProfile(name: String) async {
        isLoading = true
        
        // Clear existing accounts data before creating new profile
        await MainActor.run {
            self.linkedAccounts = []
            self.socialAccounts = []
            self.emailAccounts = []
        }
        
        do {
            // Use MPC mode for real wallet generation
            let isDevelopmentMode = false
            
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
            
            // Automatically switch to the newly created profile using SessionCoordinator
            // This ensures proper state synchronization across the app
            try await SessionCoordinator.shared.switchProfile(newProfile)
            
            // Set the active profile locally to ensure it's available for MPC generation
            await MainActor.run {
                self.activeProfile = newProfile
            }
            
            // Generate MPC wallet for the new profile if not in development mode
            if !isDevelopmentMode && MPCWalletServiceHTTP.isEnabled {
                print("✅ MPC wallet generation enabled for profile: \(newProfile.id)")
                
                // Generate MPC wallet
                await generateMPCWallet()
            } else {
                print("❌ MPC wallet generation skipped - developmentMode: \(isDevelopmentMode), isEnabled: \(MPCWalletServiceHTTP.isEnabled)")
            }
            
            await MainActor.run {
                // Show success feedback
                print("✅ ProfileViewModel: Successfully created and switched to profile: \(newProfile.name)")
                isLoading = false
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
            // Check if this is the last profile before deletion
            let isLastProfile = profiles.count <= 1
            let wasActive = profile.isActive
            
            // Store other profiles for switching
            let remainingProfiles = profiles.filter { $0.id != profile.id }
            
            // If deleting active profile, prepare the next profile BEFORE deletion
            var nextProfile: SmartProfile? = nil
            if wasActive && !remainingProfiles.isEmpty {
                // Find the most recently used profile based on updatedAt timestamp
                nextProfile = remainingProfiles
                    .sorted { profile1, profile2 in
                        let dateFormatter = ISO8601DateFormatter()
                        if let date1 = dateFormatter.date(from: profile1.updatedAt),
                           let date2 = dateFormatter.date(from: profile2.updatedAt) {
                            return date1 > date2
                        }
                        return profile1.updatedAt > profile2.updatedAt
                    }
                    .first ?? remainingProfiles.first!
                print("🔄 ProfileViewModel: Pre-selected next profile: \(nextProfile?.name ?? "none")")
            }
            
            // Delete the profile
            let _ = try await profileAPI.deleteProfile(profileId: profile.id)
            
            await MainActor.run {
                // Remove from local profiles array
                self.profiles.removeAll { $0.id == profile.id }
                
                // If we deleted the active profile, DON'T clear it yet if we have a next profile
                if self.activeProfile?.id == profile.id {
                    if nextProfile == nil {
                        // Only clear if no next profile available
                        self.activeProfile = nil
                        self.linkedAccounts = []
                        self.socialAccounts = []
                        self.emailAccounts = []
                        self.mpcWalletInfo = nil
                    }
                    // Otherwise keep the old profile data visible during transition
                }
                
                // Show success feedback
                HapticManager.notification(.success)
            }
            
            // Clear profile from all caches
            await clearProfileFromAllCaches(profile)
            
            // Update cached profiles list - this is now fully synchronous
            await updateCachedProfiles(remainingProfiles)
            
            // Small delay to ensure UserDefaults synchronization completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Post notification for profile deletion after cache is updated
            NotificationCenter.default.post(
                name: .profileDidDelete,
                object: nil,
                userInfo: ["profileId": profile.id, "remainingProfiles": remainingProfiles]
            )
            
            // Handle post-deletion logic
            if isLastProfile {
                // This was the last profile, sign out
                print("🔴 ProfileViewModel: Last profile deleted, signing out...")
                await SessionCoordinator.shared.logout()
            } else if wasActive && nextProfile != nil {
                // Switch to the pre-selected profile smoothly
                print("🔄 ProfileViewModel: Switching to profile: \(nextProfile!.name) after deletion...")
                
                // First update local state to the new profile
                await MainActor.run {
                    self.activeProfile = nextProfile
                }
                
                // Then perform the actual switch
                try await SessionCoordinator.shared.switchProfile(nextProfile!)
                
                // Load the new profile's data
                await loadProfileDetails(profileId: nextProfile!.id)
                
                // Now clear the old profile data
                await MainActor.run {
                    self.isLoading = false
                }
            } else {
                // Non-active profile deleted, just reload
                await loadProfiles()
                await MainActor.run {
                    self.isLoading = false
                }
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
            
            // Don't add session wallet to linked accounts
            guard newAccount.address.lowercased() != activeProfile.sessionWalletAddress.lowercased() else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
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
        // Ensure user is authenticated before linking
        guard authManager.isAuthenticated else {
            throw AuthenticationError.tokenExpired
        }
        
        // Validate token is present in APIService
        guard APIService.shared.getAccessToken() != nil else {
            print("🔴 ProfileViewModel: No access token available for linkWallet")
            throw AuthenticationError.tokenExpired
        }
        
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
            
            // Don't add session wallet to linked accounts
            guard newAccount.address.lowercased() != activeProfile.sessionWalletAddress.lowercased() else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
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
        guard let profileId = activeProfile?.id else {
            await MainActor.run {
                self.error = NSError(domain: "ProfileViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active profile found"])
                self.showError = true
            }
            return
        }
        
        isLoading = true
        
        // Debug logging
        print("🔴 ProfileViewModel.unlinkAccount - Account to delete:")
        print("  - Profile ID: \(profileId)")
        print("  - LinkedAccount ID: \(account.id)")
        print("  - Address: \(account.address)")
        print("  - Wallet Type: \(account.walletType)")
        
        do {
            let _ = try await profileAPI.unlinkAccount(profileId: profileId, accountId: account.id)
            
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
        guard let profileId = activeProfile?.id else {
            await MainActor.run {
                self.error = NSError(domain: "ProfileViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active profile found"])
                self.showError = true
            }
            return
        }
        
        isLoading = true
        
        do {
            let request = UpdateAccountRequest(customName: customName, isPrimary: isPrimary)
            let updatedAccount = try await profileAPI.updateLinkedAccount(
                profileId: profileId,
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
        guard MPCWalletServiceHTTP.isEnabled else {
            print("❌ MPC wallet generation skipped - MPCWalletServiceHTTP.isEnabled = false")
            return
        }
        
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
        guard MPCWalletServiceHTTP.isEnabled else {
            print("❌ MPC wallet check skipped - MPCWalletServiceHTTP.isEnabled = false")
            return
        }
        
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
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for profile changes from SessionCoordinator
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileChange(_:)),
            name: .profileDidChange,
            object: nil
        )
    }
    
    @objc private func handleProfileChange(_ notification: Notification) {
        // Clear all data when profile changes
        Task {
            await MainActor.run {
                // Clear all account data immediately
                self.linkedAccounts = []
                self.socialAccounts = []
                self.emailAccounts = []
                self.mpcWalletInfo = nil
            }
            
            // Reload profile data for the new profile
            if let newProfile = notification.userInfo?["profile"] as? SmartProfile {
                print("🔄 ProfileViewModel: Profile changed to \(newProfile.name), reloading data...")
                self.activeProfile = newProfile
                await loadProfileDetails(profileId: newProfile.id)
            }
        }
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
    
    // MARK: - Cache Management
    
    /// Clear profile from all caches
    private func clearProfileFromAllCaches(_ profile: SmartProfile) async {
        // Clear from UserCacheManager
        if profile.isActive {
            await UserCacheManager.shared.cacheActiveProfile(nil)
        }
        
        // Clear from SessionCoordinator's profile cache
        await SessionCoordinator.shared.clearProfileFromCache(profileId: profile.id)
        
        print("🧹 ProfileViewModel: Cleared profile \(profile.name) from all caches")
    }
    
    /// Update cached profiles list
    private func updateCachedProfiles(_ profiles: [SmartProfile]) async {
        // Update UserCacheManager with new profiles list - wait for completion
        await UserCacheManager.shared.cacheProfiles(profiles)
        
        // If there's an active profile in the remaining profiles, cache it
        if let activeProfile = profiles.first(where: { $0.isActive }) {
            await UserCacheManager.shared.cacheActiveProfile(activeProfile)
        } else {
            // Clear active profile cache if no active profile exists
            await UserCacheManager.shared.cacheActiveProfile(nil)
        }
        
        print("🔄 ProfileViewModel: Updated cached profiles list with \(profiles.count) profiles")
    }
    
    // MARK: - V2 Account Management
    
    /// Unlink any type of account using AccountV2
    func unlinkAccount(_ account: AccountV2) async {
        isLoading = true
        
        do {
            // Use AccountLinkingService to unlink the account
            let linkingService = AccountLinkingService.shared
            try await linkingService.unlinkAccount(account)
            
            // Refresh the identity graph
            await linkingService.refreshIdentityGraph()
            
            // Update local state based on account type
            await MainActor.run {
                switch account.accountType {
                case "email":
                    self.emailAccounts.removeAll { $0.id == account.id }
                case "wallet":
                    // Note: wallet accounts are in linkedAccounts, not identity graph
                    // This case might not be reached for wallets
                    break
                case "social":
                    // Social accounts have their own array
                    break
                default:
                    break
                }
                
                // Reload email accounts from refreshed identity graph
                Task {
                    await loadEmailAccounts()
                }
                
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.showError(error)
                isLoading = false
            }
        }
    }
    
}

// MARK: - Profile Errors

enum ProfileError: LocalizedError {
    case none // Empty enum for future use
    
    var errorDescription: String? {
        switch self {
        case .none:
            return nil
        }
    }
}
