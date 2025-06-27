import Foundation
import Combine
import UIKit

@MainActor
final class AppsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var apps: [BookmarkedApp] = []
    @Published var folders: [AppFolder] = []
    @Published var isLoading = false
    @Published var error: AppsError?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private let profileAPI = ProfileAPI.shared
    private let dataSyncManager = DataSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var unfolderedApps: [BookmarkedApp] {
        apps.filter { $0.folderId == nil }
            .sorted { $0.position < $1.position }
    }
    
    // MARK: - Initialization
    
    init() {
        // Initial load will be triggered by the view
    }
    
    // MARK: - Public Methods
    
    func loadApps(for profileId: String? = nil) async {
        isLoading = true
        error = nil
        
        print("📱 AppsViewModel: Loading apps...")
        
        // Check if user is a guest
        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
            // For guest users, show placeholder apps
            apps = createGuestPlaceholderApps()
            folders = []
            print("📱 AppsViewModel: Loaded \(apps.count) guest placeholder apps")
        } else {
            do {
                // Get active profile if profileId not provided
                let targetProfileId: String
                if let profileId = profileId {
                    targetProfileId = profileId
                } else {
                    // Get profiles directly from ProfileAPI to handle response wrapper
                    let profilesArray: [SmartProfile] = DemoMode.isEnabled 
                        ? try await profileAPI.getProfilesDemoMode()
                        : try await profileAPI.getProfiles()
                    guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                        throw AppsError.noActiveProfile
                    }
                    targetProfileId = activeProfile.id
                }
                
                print("📱 AppsViewModel: Loading apps for profile: \(targetProfileId)")
                
                // Use ProfileAPI methods that handle the wrapped responses correctly
                async let appsTask = DemoMode.isEnabled
                    ? profileAPI.getAppsDemoMode(profileId: targetProfileId)
                    : profileAPI.getApps(profileId: targetProfileId)
                async let foldersTask = DemoMode.isEnabled
                    ? profileAPI.getFoldersDemoMode(profileId: targetProfileId)
                    : profileAPI.getFolders(profileId: targetProfileId)
                
                let (appsResult, foldersResult) = try await (appsTask, foldersTask)
                
                apps = appsResult.sorted { $0.position < $1.position }
                folders = foldersResult.sorted { $0.position < $1.position }
                
                print("📱 AppsViewModel: Loaded \(apps.count) apps and \(folders.count) folders")
                
                // Invalidate cache for future updates
                dataSyncManager.invalidate(type: [BookmarkedApp].self)
                dataSyncManager.invalidate(type: [AppFolder].self)
                
            } catch {
                print("📱 AppsViewModel: Error loading apps: \(error)")
                
                // Check if it's a 404 error (new user with no apps/folders)
                if let apiError = error as? APIError,
                   case .invalidResponse(let statusCode) = apiError,
                   statusCode == 404 {
                    // This is normal for new users - just set empty arrays
                    print("📱 AppsViewModel: No apps/folders found (new user)")
                    apps = []
                    folders = []
                } else {
                    // This is a real error
                    handleError(error)
                }
            }
        }
        
        isLoading = false
    }
    
    private func createGuestPlaceholderApps() -> [BookmarkedApp] {
        return [
            BookmarkedApp(
                id: "guest_app_1",
                name: "Interspace Explorer",
                url: "https://interspace.fi",
                iconUrl: nil,
                position: 0,
                folderId: nil
            ),
            BookmarkedApp(
                id: "guest_app_2", 
                name: "OpenSea",
                url: "https://opensea.io",
                iconUrl: nil,
                position: 1,
                folderId: nil
            ),
            BookmarkedApp(
                id: "guest_app_3",
                name: "Uniswap",
                url: "https://app.uniswap.org",
                iconUrl: nil,
                position: 2,
                folderId: nil
            ),
            BookmarkedApp(
                id: "guest_app_4",
                name: "DeBank",
                url: "https://debank.com",
                iconUrl: nil,
                position: 3,
                folderId: nil
            ),
            BookmarkedApp(
                id: "guest_app_5",
                name: "CoinGecko", 
                url: "https://coingecko.com",
                iconUrl: nil,
                position: 4,
                folderId: nil
            ),
            BookmarkedApp(
                id: "guest_app_6",
                name: "Mirror",
                url: "https://mirror.xyz",
                iconUrl: nil,
                position: 5,
                folderId: nil
            )
        ]
    }
    
    func addApp(_ app: CreateAppRequest) async {
        isLoading = true
        error = nil
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            let newApp = try await profileAPI.createApp(profileId: activeProfile.id, request: app)
            
            apps.append(newApp)
            apps.sort { $0.position < $1.position }
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func addAppWithMetadata(url: String, to profileId: String? = nil) async throws -> BookmarkedApp {
        // Fetch metadata
        guard let siteURL = URL(string: url) else {
            throw AppsError.invalidURL
        }
        
        let metadata = try await MetadataFetcher.shared.fetchMetadata(for: siteURL)
        
        // Generate icon if needed
        var iconUrl = metadata.iconURL
        if iconUrl == nil || iconUrl?.isEmpty == true {
            // Generate icon from first letter of title
            if let iconImage = IconGenerator.generateIcon(for: metadata.title),
               let _ = iconImage.pngData() {
                // TODO: Upload generated icon to storage
                // For now, use a placeholder
                iconUrl = nil
            }
        }
        
        // Get target profile
        let targetProfileId: String
        if let profileId = profileId {
            targetProfileId = profileId
        } else {
            let profilesArray: [SmartProfile] = DemoMode.isEnabled
                ? try await profileAPI.getProfilesDemoMode()
                : try await profileAPI.getProfiles()
            guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            targetProfileId = activeProfile.id
        }
        
        // Create app request
        let request = CreateAppRequest(
            name: metadata.title.isEmpty ? siteURL.host ?? "New App" : metadata.title,
            url: url,
            iconUrl: iconUrl,
            folderId: nil,
            position: apps.count
        )
        
        // Create app
        let newApp = DemoMode.isEnabled
            ? try await profileAPI.createAppDemoMode(profileId: targetProfileId, request: request)
            : try await profileAPI.createApp(profileId: targetProfileId, request: request)
        
        // Update local state
        await MainActor.run {
            apps.append(newApp)
            apps.sort { $0.position < $1.position }
        }
        
        return newApp
    }
    
    func updateApp(_ app: BookmarkedApp, name: String? = nil, url: String? = nil, iconUrl: String? = nil, folderId: String? = nil, position: Int? = nil) async {
        isLoading = true
        error = nil
        
        do {
            let request = UpdateAppRequest(name: name, url: url, iconUrl: iconUrl, folderId: folderId, position: position)
            let updatedApp = try await profileAPI.updateApp(
                appId: app.id,
                request: request
            )
            
            // Update the app in the local array
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index] = updatedApp
                apps.sort { $0.position < $1.position }
            }
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func deleteApp(_ app: BookmarkedApp) {
        Task {
            isLoading = true
            error = nil
            
            do {
                if DemoMode.isEnabled {
                    try await profileAPI.deleteAppDemoMode(appId: app.id)
                } else {
                    try await profileAPI.deleteApp(appId: app.id)
                }
                
                // Remove from local array
                apps.removeAll { $0.id == app.id }
                
            } catch {
                handleError(error)
            }
            
            isLoading = false
        }
    }
    
    func reorderApps(_ appIds: [String], folderId: String? = nil) async {
        do {
            let request = ReorderAppsRequest(appIds: appIds, folderId: folderId)
            
            // Get active profile
            let profilesArray: [SmartProfile] = DemoMode.isEnabled
                ? try await profileAPI.getProfilesDemoMode()
                : try await profileAPI.getProfiles()
            guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            _ = try await profileAPI.reorderApps(profileId: activeProfile.id, appIds: appIds, folderId: folderId)
            
            // Update local positions
            for (index, appId) in appIds.enumerated() {
                if let appIndex = apps.firstIndex(where: { $0.id == appId }) {
                    let updatedApp = apps[appIndex]
                    apps[appIndex] = BookmarkedApp(
                        id: updatedApp.id,
                        name: updatedApp.name,
                        url: updatedApp.url,
                        iconUrl: updatedApp.iconUrl,
                        position: index,
                        folderId: folderId,
                        folderName: updatedApp.folderName,
                        createdAt: updatedApp.createdAt,
                        updatedAt: updatedApp.updatedAt
                    )
                }
            }
            
            apps.sort { $0.position < $1.position }
            
        } catch {
            handleError(error)
        }
    }
    
    func moveAppToFolder(_ app: BookmarkedApp, folderId: String?, position: Int? = nil) async {
        do {
            _ = try await profileAPI.moveApp(appId: app.id, folderId: folderId, position: position)
            
            // Update the app in the local array
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                let folderName = folderId != nil ? folders.first(where: { $0.id == folderId })?.name : nil
                apps[index] = BookmarkedApp(
                    id: app.id,
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    position: position ?? app.position,
                    folderId: folderId,
                    folderName: folderName,
                    createdAt: app.createdAt,
                    updatedAt: app.updatedAt
                )
            }
            
        } catch {
            handleError(error)
        }
    }
    
    func searchApps(_ query: String) -> [BookmarkedApp] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let searchQuery = query.lowercased()
        return apps.filter { app in
            app.name.lowercased().contains(searchQuery) ||
            app.url.lowercased().contains(searchQuery)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    func appsInFolder(_ folderId: String) -> [BookmarkedApp] {
        apps.filter { $0.folderId == folderId }
            .sorted { $0.position < $1.position }
    }
    
    // MARK: - Folder Management
    
    func createFolder(name: String, color: String) async {
        isLoading = true
        error = nil
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            let request = CreateFolderRequest(
                name: name,
                color: color,
                position: folders.count
            )
            let newFolder = try await profileAPI.createFolder(
                profileId: activeProfile.id,
                request: request
            )
            
            folders.append(newFolder)
            folders.sort { $0.position < $1.position }
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func updateFolder(_ folder: AppFolder, name: String? = nil, color: String? = nil, isPublic: Bool? = nil) async {
        isLoading = true
        error = nil
        
        do {
            let request = UpdateFolderRequest(name: name, color: color, isPublic: isPublic)
            let updatedFolder = try await profileAPI.updateFolder(
                folderId: folder.id,
                request: request
            )
            
            // Update the folder in the local array
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index] = updatedFolder
            }
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func deleteFolder(_ folder: AppFolder) {
        Task {
            isLoading = true
            error = nil
            
            do {
                try await profileAPI.deleteFolder(folderId: folder.id)
                
                // Remove folder from local array
                folders.removeAll { $0.id == folder.id }
                
                // Move apps out of deleted folder
                for index in apps.indices {
                    if apps[index].folderId == folder.id {
                        apps[index] = BookmarkedApp(
                            id: apps[index].id,
                            name: apps[index].name,
                            url: apps[index].url,
                            iconUrl: apps[index].iconUrl,
                            position: apps[index].position,
                            folderId: nil,
                            folderName: nil,
                            createdAt: apps[index].createdAt,
                            updatedAt: apps[index].updatedAt
                        )
                    }
                }
                
            } catch {
                handleError(error)
            }
            
            isLoading = false
        }
    }
    
    func reorderFolders(_ folderIds: [String]) async {
        do {
            let request = ReorderFoldersRequest(folderIds: folderIds)
            
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profilesArray.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            _ = try await profileAPI.reorderFolders(profileId: activeProfile.id, folderIds: folderIds)
            
            // Update local positions
            for (index, folderId) in folderIds.enumerated() {
                if let folderIndex = folders.firstIndex(where: { $0.id == folderId }) {
                    let updatedFolder = folders[folderIndex]
                    folders[folderIndex] = AppFolder(
                        id: updatedFolder.id,
                        name: updatedFolder.name,
                        color: updatedFolder.color,
                        position: index,
                        isPublic: updatedFolder.isPublic,
                        appsCount: updatedFolder.appsCount,
                        createdAt: updatedFolder.createdAt,
                        updatedAt: updatedFolder.updatedAt
                    )
                }
            }
            
            folders.sort { $0.position < $1.position }
            
        } catch {
            handleError(error)
        }
    }
    
    func shareFolder(_ folder: AppFolder) async -> String? {
        do {
            let response = try await profileAPI.shareFolder(folderId: folder.id)
            return response.data.shareableUrl
            
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func refreshData() async {
        await loadApps()
    }
    
    func dismissError() {
        error = nil
        showError = false
    }
    
    // MARK: - Offline Operations
    
    func addAppOffline(app: BookmarkedApp) async {
        // Add to local array immediately for instant UI update
        apps.append(app)
        apps.sort { $0.position < $1.position }
        
        // Queue the operation for sync when online
        if !NetworkMonitor.shared.isConnected {
            do {
                // Get active profile
                let profilesResponse: ProfilesResponse = try await dataSyncManager.fetch(
                    type: ProfilesResponse.self,
                    endpoint: "profiles",
                    policy: .cacheOnly // Use cache only since we're offline
                )
                guard let activeProfile = profilesResponse.data.first(where: { $0.isActive }) else {
                    print("No active profile found for offline operation")
                    return
                }
                
                let encoder = JSONEncoder()
                let createRequest = CreateAppRequest(
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    folderId: app.folderId,
                    position: app.position
                )
                let appData = try encoder.encode(createRequest)
                
                dataSyncManager.queueOfflineOperation(
                    endpoint: "profiles/\(activeProfile.id)/apps",
                    method: .POST,
                    body: appData,
                    description: "Add app: \(app.name)"
                )
                
                // Invalidate cache so it gets refreshed on next sync
                dataSyncManager.invalidate(type: BookmarkedApp.self)
            } catch {
                print("Failed to queue offline operation: \(error)")
            }
        }
    }
    
    func deleteAppOffline(app: BookmarkedApp) async {
        // Remove from local array immediately
        apps.removeAll { $0.id == app.id }
        
        // Queue the operation for sync when online
        if !NetworkMonitor.shared.isConnected {
            do {
                // Get active profile
                let profilesResponse: ProfilesResponse = try await dataSyncManager.fetch(
                    type: ProfilesResponse.self,
                    endpoint: "profiles",
                    policy: .cacheOnly // Use cache only since we're offline
                )
                guard let activeProfile = profilesResponse.data.first(where: { $0.isActive }) else {
                    print("No active profile found for offline operation")
                    return
                }
                
                dataSyncManager.queueOfflineOperation(
                    endpoint: "profiles/\(activeProfile.id)/apps/\(app.id)",
                    method: .DELETE,
                    body: nil,
                    description: "Delete app: \(app.name)"
                )
                
                // Invalidate cache
                dataSyncManager.invalidate(type: BookmarkedApp.self)
            } catch {
                print("Failed to queue offline operation: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                self.error = .unauthorized
            case .apiError(let message):
                self.error = .serverError(message)
            case .requestFailed(let underlyingError):
                self.error = .networkError(underlyingError.localizedDescription)
            default:
                self.error = .unknown(error.localizedDescription)
            }
        } else {
            self.error = .unknown(error.localizedDescription)
        }
        showError = true
    }
}

// MARK: - Apps Error

enum AppsError: LocalizedError {
    case invalidInput(String)
    case unauthorized
    case serverError(String)
    case networkError(String)
    case noActiveProfile
    case invalidURL
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .invalidURL:
            return "Invalid URL provided"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noActiveProfile:
            return "No active profile found"
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}