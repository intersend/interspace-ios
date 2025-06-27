import Foundation

extension ProfileAPI {
    
    /// Override methods to return mock data in demo mode
    func handleDemoMode<T>(_ operation: String, mockData: () -> T) async throws -> T {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 ProfileAPI: Returning mock data for \(operation)")
            
            // Add artificial delay to simulate network
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...200_000_000))
            
            return mockData()
        }
        
        // This won't be reached in demo mode, but needed for compilation
        throw APIError.noData
    }
}

// MARK: - Demo Mode Overrides

extension ProfileAPI {
    
    // Override getProfiles
    func getProfilesDemoMode() async throws -> [SmartProfile] {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getProfiles") {
                MockDataProvider.shared.demoProfiles
            }
        }
        return try await getProfiles()
    }
    
    // Override getApps
    func getAppsDemoMode(profileId: String) async throws -> [BookmarkedApp] {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getApps") {
                MockDataProvider.shared.getApps(for: profileId)
            }
        }
        return try await getApps(profileId: profileId)
    }
    
    // Override getFolders
    func getFoldersDemoMode(profileId: String) async throws -> [AppFolder] {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getFolders") {
                MockDataProvider.shared.getFolders(for: profileId)
            }
        }
        return try await getFolders(profileId: profileId)
    }
    
    // Override getLinkedAccounts
    func getLinkedAccountsDemoMode(profileId: String) async throws -> [LinkedAccount] {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getLinkedAccounts") {
                MockDataProvider.shared.getLinkedAccounts(for: profileId)
            }
        }
        return try await getLinkedAccounts(profileId: profileId)
    }
    
    // Override activateProfile
    func activateProfileDemoMode(profileId: String) async throws -> SmartProfile {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("activateProfile") {
                if let profile = MockDataProvider.shared.demoProfiles.first(where: { $0.id == profileId }) {
                    MockDataProvider.shared.switchProfile(to: profile)
                    return profile
                }
                return MockDataProvider.shared.currentProfile!
            }
        }
        return try await activateProfile(profileId: profileId)
    }
    
    // Override createApp
    func createAppDemoMode(profileId: String, request: CreateAppRequest) async throws -> BookmarkedApp {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("createApp") {
                BookmarkedApp(
                    id: UUID().uuidString,
                    name: request.name,
                    url: request.url,
                    iconUrl: request.iconUrl ?? "https://\(request.url)/favicon.ico",
                    position: MockDataProvider.shared.getApps(for: profileId).count,
                    folderId: request.folderId,
                    folderName: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        return try await createApp(profileId: profileId, request: request)
    }
    
    // Override deleteApp
    func deleteAppDemoMode(appId: String) async throws {
        if DemoModeConfiguration.isDemoMode {
            _ = try await handleDemoMode("deleteApp") {
                // In demo mode, just return success
                print("🎭 ProfileAPI: Mock deleted app \(appId)")
            }
            return
        }
        try await deleteApp(appId: appId)
    }
    
    // Override createFolder
    func createFolderDemoMode(profileId: String, request: CreateFolderRequest) async throws -> AppFolder {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("createFolder") {
                AppFolder(
                    id: UUID().uuidString,
                    name: request.name,
                    color: request.color ?? "#FF6B6B",
                    position: MockDataProvider.shared.getFolders(for: profileId).count,
                    isPublic: false,
                    appsCount: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        return try await createFolder(profileId: profileId, request: request)
    }
}