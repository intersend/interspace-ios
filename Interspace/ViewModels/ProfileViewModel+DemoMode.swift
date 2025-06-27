import Foundation

// MARK: - Demo Mode Support for ProfileViewModel

extension ProfileViewModel {
    
    /// Load profiles with demo mode support
    func loadProfilesDemoMode() async {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 ProfileViewModel: Loading demo profiles")
            
            // Add artificial delay
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            await MainActor.run {
                self.profiles = MockDataProvider.shared.demoProfiles
                self.activeProfile = MockDataProvider.shared.currentProfile
                self.hasLoadedInitialData = true
                self.isLoading = false
            }
            
            // Load demo profile details
            if let activeProfile = self.activeProfile {
                await loadProfileDetailsDemoMode(profileId: activeProfile.id)
            }
        } else {
            await loadProfiles()
        }
    }
    
    /// Load profile with demo mode support
    func loadProfileDemoMode() async {
        if DemoModeConfiguration.isDemoMode {
            await loadProfilesDemoMode()
        } else {
            await loadProfile()
        }
    }
    
    /// Load profile details with demo mode support
    private func loadProfileDetailsDemoMode(profileId: String) async {
        if DemoModeConfiguration.isDemoMode {
            // Load mock linked accounts
            await MainActor.run {
                self.linkedAccounts = MockDataProvider.shared.getLinkedAccounts(for: profileId)
                
                // Set mock social accounts
                self.socialAccounts = [
                    SocialAccount(
                        id: "social-1",
                        provider: .google,
                        username: "demo.user@gmail.com",
                        displayName: "Demo User",
                        avatarUrl: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
                
                // Set mock email accounts
                self.emailAccounts = [
                    AccountV2(
                        id: "email-1",
                        accountType: "email",
                        strategy: .email,
                        identifier: "demo@interspace.app",
                        metadata: [:],
                        verified: true,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
                
                // No MPC wallet in demo mode
                self.mpcWalletInfo = nil
            }
        } else {
            await loadProfileDetails(profileId: profileId)
        }
    }
    
    /// Switch profile with demo mode support
    func switchProfileDemoMode(_ profile: SmartProfile) async {
        if DemoModeConfiguration.isDemoMode {
            isLoading = true
            
            // Add artificial delay
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // Update mock data provider
            MockDataProvider.shared.switchProfile(to: profile)
            
            // Reload profiles
            await loadProfilesDemoMode()
        } else {
            await switchProfile(profile)
        }
    }
    
    /// Refresh profile with demo mode support
    func refreshProfileDemoMode() async {
        if DemoModeConfiguration.isDemoMode {
            await loadProfilesDemoMode()
        } else {
            await refreshProfile()
        }
    }
    
    // In demo mode, prevent actual profile creation/deletion
    func createProfileDemoMode(name: String) async {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 ProfileViewModel: Profile creation disabled in demo mode")
            await MainActor.run {
                self.showError(ProfileError.operationNotSupported)
            }
        } else {
            await createProfile(name: name)
        }
    }
    
    func deleteProfileDemoMode(_ profile: SmartProfile) async {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 ProfileViewModel: Profile deletion disabled in demo mode")
            await MainActor.run {
                self.showError(ProfileError.operationNotSupported)
            }
        } else {
            await deleteProfile(profile)
        }
    }
}

// Demo mode specific errors
enum ProfileError: LocalizedError {
    case operationNotSupported
    
    var errorDescription: String? {
        switch self {
        case .operationNotSupported:
            return "This operation is not supported in demo mode"
        }
    }
}