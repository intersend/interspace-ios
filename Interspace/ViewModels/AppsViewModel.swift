import Foundation
import Combine
import UIKit
import SwiftUI

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
        setupProfileChangeObserver()
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
                    let profiles = try await profileAPI.getProfiles()
                    guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                        // No active profile - this is normal for new users
                        print("📱 AppsViewModel: No active profile found (new user)")
                        apps = []
                        folders = []
                        isLoading = false
                        return
                    }
                    targetProfileId = activeProfile.id
                }
                
                print("📱 AppsViewModel: Loading apps for profile: \(targetProfileId)")
                
                // Use ProfileAPI methods that handle the wrapped responses correctly
                async let appsTask = profileAPI.getApps(profileId: targetProfileId)
                async let foldersTask = profileAPI.getFolders(profileId: targetProfileId)
                
                let (appsResult, foldersResult) = try await (appsTask, foldersTask)
                
                // Fix duplicate positions in apps
                var fixedApps = appsResult
                var usedPositions = Set<Int>()
                var needsPositionFix = false
                
                // First pass: identify duplicate positions
                for app in fixedApps {
                    if usedPositions.contains(app.position) {
                        needsPositionFix = true
                        break
                    }
                    usedPositions.insert(app.position)
                }
                
                // If duplicates found, reassign positions
                if needsPositionFix {
                    print("⚠️ AppsViewModel: Found duplicate positions, reassigning...")
                    fixedApps = fixedApps.sorted { $0.createdAt < $1.createdAt } // Sort by creation date
                    for (index, app) in fixedApps.enumerated() {
                        fixedApps[index] = BookmarkedApp(
                            id: app.id,
                            name: app.name,
                            url: app.url,
                            iconUrl: app.iconUrl,
                            position: index,
                            folderId: app.folderId,
                            folderName: app.folderName,
                            createdAt: app.createdAt,
                            updatedAt: app.updatedAt
                        )
                    }
                    
                    // Don't automatically reorder on load - only reorder when user explicitly moves items
                }
                
                apps = fixedApps.sorted { $0.position < $1.position }
                folders = foldersResult.sorted { $0.position < $1.position }
                
                print("📱 AppsViewModel: Loaded \(apps.count) apps and \(folders.count) folders")
                
                // Debug logging for apps and their folders
                let appsInFolders = apps.filter { $0.folderId != nil }
                let appsWithoutFolders = apps.filter { $0.folderId == nil }
                
                print("📱 AppsViewModel: Apps in folders: \(appsInFolders.count)")
                for app in appsInFolders {
                    let folderName = folders.first(where: { $0.id == app.folderId })?.name ?? "Unknown Folder"
                    print("  - App: \(app.name) in folder: \(folderName) (ID: \(app.folderId ?? "nil"))")
                }
                
                print("📱 AppsViewModel: Apps without folders: \(appsWithoutFolders.count)")
                for app in appsWithoutFolders {
                    print("  - App: \(app.name) at position \(app.position)")
                }
                
                print("📱 AppsViewModel: Folders:")
                for folder in folders {
                    let appCount = apps.filter { $0.folderId == folder.id }.count
                    print("  - Folder: \(folder.name) at position \(folder.position), contains \(appCount) apps")
                }
                
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
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            // Ensure unique position
            var createRequest = app
            if createRequest.position == nil {
                // Find the next available position
                let maxPosition = apps.filter { $0.folderId == nil }.map { $0.position }.max() ?? -1
                createRequest = CreateAppRequest(
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    folderId: app.folderId,
                    position: maxPosition + 1
                )
            }
            
            let newApp = try await profileAPI.createApp(profileId: activeProfile.id, request: createRequest)
            
            apps.append(newApp)
            apps.sort { $0.position < $1.position }
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func addAppWithMetadata(url: String, to profileId: String? = nil) async throws -> BookmarkedApp {
        // Validate URL
        guard let siteURL = URL(string: url) else {
            throw AppsError.invalidURL
        }
        
        // Get target profile
        let targetProfileId: String
        if let profileId = profileId {
            targetProfileId = profileId
        } else {
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            targetProfileId = activeProfile.id
        }
        
        // Create app immediately with basic info
        let basicName = siteURL.host?.replacingOccurrences(of: "www.", with: "").capitalized ?? "New App"
        let faviconUrl = "\(siteURL.scheme ?? "https")://\(siteURL.host ?? "")/favicon.ico"
        
        // Ensure unique position for new app
        let maxPosition = apps.filter { $0.folderId == nil }.map { $0.position }.max() ?? -1
        let request = CreateAppRequest(
            name: basicName,
            url: url,
            iconUrl: faviconUrl,
            folderId: nil,
            position: maxPosition + 1
        )
        
        // Create app immediately
        let newApp = try await profileAPI.createApp(profileId: targetProfileId, request: request)
        
        // Update local state immediately
        await MainActor.run {
            apps.append(newApp)
            apps.sort { $0.position < $1.position }
        }
        
        // Fetch metadata in background and update if better info is found
        Task {
            do {
                // Try lightweight fetch first (much faster)
                let metadata = try await MetadataFetcher.shared.fetchMetadata(for: siteURL)
                
                // Only update if we got better information
                let betterName = metadata.title
                let betterIcon = metadata.iconURL
                
                if (!betterName.isEmpty && betterName != basicName && betterName != siteURL.host) || 
                   (betterIcon != nil && betterIcon != faviconUrl && !betterIcon!.hasSuffix("/favicon.ico")) {
                    
                    await self.updateApp(
                        newApp,
                        name: betterName.isEmpty ? nil : betterName,
                        iconUrl: betterIcon
                    )
                }
                
                // Optionally, if lightweight fetch was successful, we could try full fetch later
                // for even better metadata (manifest, etc.) but this is usually not necessary
                
            } catch {
                // Silently fail - we already have the basic app created
                print("Failed to fetch enhanced metadata: \(error)")
            }
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
                try await profileAPI.deleteApp(appId: app.id)
                
                // Remove from local array
                apps.removeAll { $0.id == app.id }
                
            } catch {
                handleError(error)
            }
            
            isLoading = false
        }
    }
    
    func reorderApps(_ appIds: [String], folderId: String? = nil) async {
        // Validate input
        guard !appIds.isEmpty else {
            print("⚠️ AppsViewModel: Cannot reorder with empty app IDs")
            return
        }
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
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
    
    func moveAppToFolder(_ app: BookmarkedApp, folderId: String?, position: Int? = nil) async -> Bool {
        print("📱 AppsViewModel: Moving app '\(app.name)' to folder: \(folderId ?? "root") at position: \(position ?? -1)")
        
        do {
            // Call backend API
            let response = try await profileAPI.moveApp(appId: app.id, folderId: folderId, position: position)
            print("✅ AppsViewModel: Successfully moved app to folder in backend")
            
            // Update the app in the local array
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                // Create new app instance with updated folder and position
                let updatedApp = BookmarkedApp(
                    id: app.id,
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    position: position ?? app.position,
                    folderId: folderId,
                    folderName: app.folderName,
                    createdAt: app.createdAt,
                    updatedAt: app.updatedAt
                )
                apps[index] = updatedApp
                
                print("✅ AppsViewModel: Updated local app state - folderId: \(updatedApp.folderId ?? "nil"), position: \(updatedApp.position)")
            }
            
            return true
            
        } catch {
            print("❌ AppsViewModel: Failed to move app to folder: \(error)")
            handleError(error)
            
            // Reload apps to ensure UI is in sync with backend
            await loadApps()
            
            return false
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
    
    func createFolder(name: String, color: String, position: Int? = nil) async -> AppFolder? {
        print("📁 AppsViewModel: createFolder called - name: \(name), color: \(color), position: \(position ?? folders.count)")
        isLoading = true
        error = nil
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                print("❌ AppsViewModel: No active profile found")
                throw AppsError.noActiveProfile
            }
            print("✅ AppsViewModel: Found active profile: \(activeProfile.id)")
            
            let request = CreateFolderRequest(
                name: name,
                color: color,
                position: position ?? folders.count
            )
            print("📤 AppsViewModel: Sending create folder request to backend")
            let newFolder = try await profileAPI.createFolder(
                profileId: activeProfile.id,
                request: request
            )
            print("✅ AppsViewModel: Backend created folder: \(newFolder.name) with ID: \(newFolder.id)")
            
            folders.append(newFolder)
            folders.sort { $0.position < $1.position }
            
            isLoading = false
            return newFolder
            
        } catch {
            print("❌ AppsViewModel: Failed to create folder: \(error)")
            handleError(error)
            isLoading = false
            return nil
        }
    }
    
    // Create folder and immediately move apps into it
    func createFolderWithApps(name: String, color: String, apps: [BookmarkedApp]) async -> Bool {
        print("📱 AppsViewModel: Creating folder '\(name)' with \(apps.count) apps")
        
        // Prevent other updates during folder creation
        isLoading = true
        
        // Create the folder first
        guard let newFolder = await createFolder(name: name, color: color) else {
            print("❌ AppsViewModel: Failed to create folder")
            isLoading = false
            return false
        }
        
        print("✅ AppsViewModel: Created folder: \(newFolder.name) with ID: \(newFolder.id)")
        
        // Move apps to folder one by one, tracking success
        var successCount = 0
        for (index, app) in apps.enumerated() {
            let success = await moveAppToFolder(app, folderId: newFolder.id, position: index)
            if success {
                successCount += 1
                print("✅ AppsViewModel: Moved app \(app.name) to folder (position: \(index))")
            } else {
                print("❌ AppsViewModel: Failed to move app \(app.name) to folder")
            }
        }
        
        print("📱 AppsViewModel: Moved \(successCount)/\(apps.count) apps to folder successfully")
        
        // If any apps failed to move, reload to ensure consistency
        if successCount < apps.count {
            await loadApps()
        }
        
        isLoading = false
        return successCount == apps.count
    }
    
    // Optimized batch operation for folder creation with proper position handling
    func createFolderAndReorganize(
        folderName: String,
        folderColor: String,
        draggedApp: BookmarkedApp,
        targetApp: BookmarkedApp
    ) async -> AppFolder? {
        // Don't show loading to avoid UI flicker
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            // The folder will take targetApp's position
            let folderPosition = targetApp.position
            
            // Step 1: Update local state optimistically with animations
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    // Remove both apps from the grid
                    apps.removeAll { $0.id == draggedApp.id }
                    apps.removeAll { $0.id == targetApp.id }
                    
                    // Create temporary folder at target position
                    let isoDateString = ISO8601DateFormatter().string(from: Date())
                    let tempFolderId = "temp-\(UUID().uuidString)"
                    let newFolder = AppFolder(
                        id: tempFolderId,
                        name: folderName,
                        color: folderColor,
                        position: folderPosition,
                        isPublic: false,
                        appsCount: 2,
                        createdAt: isoDateString,
                        updatedAt: isoDateString
                    )
                    folders.append(newFolder)
                    
                    // Update positions: only shift items AFTER the folder position
                    for i in 0..<apps.count {
                        if apps[i].position > folderPosition {
                            apps[i] = BookmarkedApp(
                                id: apps[i].id,
                                name: apps[i].name,
                                url: apps[i].url,
                                iconUrl: apps[i].iconUrl,
                                position: apps[i].position - 1, // Only -1 because folder replaces one position
                                folderId: apps[i].folderId,
                                folderName: apps[i].folderName,
                                createdAt: apps[i].createdAt,
                                updatedAt: apps[i].updatedAt
                            )
                        }
                    }
                    
                    // Update folder positions after the new folder
                    for i in 0..<folders.count {
                        if folders[i].position > folderPosition && folders[i].id != tempFolderId {
                            folders[i] = AppFolder(
                                id: folders[i].id,
                                name: folders[i].name,
                                color: folders[i].color,
                                position: folders[i].position - 1,
                                isPublic: folders[i].isPublic,
                                appsCount: folders[i].appsCount,
                                createdAt: folders[i].createdAt,
                                updatedAt: folders[i].updatedAt
                            )
                        }
                    }
                    
                    // Sort to maintain order
                    apps.sort { $0.position < $1.position }
                    folders.sort { $0.position < $1.position }
                }
            }
            
            // Step 2: Create folder in backend
            let request = CreateFolderRequest(
                name: folderName,
                color: folderColor,
                position: folderPosition
            )
            let actualFolder = try await profileAPI.createFolder(
                profileId: activeProfile.id,
                request: request
            )
            
            // Replace temp folder with actual one
            await MainActor.run {
                if let index = folders.firstIndex(where: { $0.id.hasPrefix("temp-") }) {
                    folders[index] = actualFolder
                }
            }
            
            // Step 3: Sequential API calls to avoid conflicts
            // First, move the first app to the folder
            _ = try await profileAPI.moveApp(
                appId: draggedApp.id, 
                folderId: actualFolder.id, 
                position: 0
            )
            
            // Then move the second app
            _ = try await profileAPI.moveApp(
                appId: targetApp.id, 
                folderId: actualFolder.id, 
                position: 1
            )
            
            // Step 3.5: Add apps back to local state with folder assignment
            await MainActor.run {
                // Create updated app instances with folder assignment
                let updatedDraggedApp = BookmarkedApp(
                    id: draggedApp.id,
                    name: draggedApp.name,
                    url: draggedApp.url,
                    iconUrl: draggedApp.iconUrl,
                    position: 0,
                    folderId: actualFolder.id,
                    folderName: actualFolder.name,
                    createdAt: draggedApp.createdAt,
                    updatedAt: draggedApp.updatedAt
                )
                
                let updatedTargetApp = BookmarkedApp(
                    id: targetApp.id,
                    name: targetApp.name,
                    url: targetApp.url,
                    iconUrl: targetApp.iconUrl,
                    position: 1,
                    folderId: actualFolder.id,
                    folderName: actualFolder.name,
                    createdAt: targetApp.createdAt,
                    updatedAt: targetApp.updatedAt
                )
                
                // Add them back to the apps array
                apps.append(updatedDraggedApp)
                apps.append(updatedTargetApp)
                
                print("📁 Added apps to folder \(actualFolder.name): \(draggedApp.name), \(targetApp.name)")
            }
            
            // Step 4: Update all positions in a single batch
            // Collect all items with their new positions
            var positionUpdates: [(id: String, position: Int, isFolder: Bool)] = []
            
            // Add apps
            for (index, app) in apps.enumerated() where app.folderId == nil {
                positionUpdates.append((id: app.id, position: index, isFolder: false))
            }
            
            // Add folders
            for (index, folder) in folders.enumerated() {
                positionUpdates.append((id: folder.id, position: index + apps.filter { $0.folderId == nil }.count, isFolder: true))
            }
            
            // Sort by position to get correct order
            positionUpdates.sort { $0.position < $1.position }
            
            // Extract IDs in order
            let orderedAppIds = positionUpdates.filter { !$0.isFolder }.map { $0.id }
            let orderedFolderIds = positionUpdates.filter { $0.isFolder }.map { $0.id }
            
            // Update positions in backend
            if !orderedAppIds.isEmpty {
                _ = try? await profileAPI.reorderApps(
                    profileId: activeProfile.id, 
                    appIds: orderedAppIds, 
                    folderId: nil
                )
            }
            
            if !orderedFolderIds.isEmpty {
                _ = try? await profileAPI.reorderFolders(
                    profileId: activeProfile.id, 
                    folderIds: orderedFolderIds
                )
            }
            
            return actualFolder
            
        } catch {
            print("❌ Failed to create folder and reorganize: \(error)")
            // Revert optimistic updates on failure
            await loadApps()
            return nil
        }
    }
    
    // Simplified folder creation without optimistic updates
    func createFolderAndReorganizeSimple(
        folderName: String,
        folderColor: String,
        draggedApp: BookmarkedApp,
        targetApp: BookmarkedApp
    ) async -> AppFolder? {
        print("📱 AppsViewModel: Creating folder from apps: \(draggedApp.name) + \(targetApp.name)")
        
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                throw AppsError.noActiveProfile
            }
            
            // Calculate folder position (use target app's position)
            let folderPosition = targetApp.position
            
            // Step 1: Create folder in backend first
            let request = CreateFolderRequest(
                name: folderName,
                color: folderColor,
                position: folderPosition
            )
            
            let newFolder = try await profileAPI.createFolder(
                profileId: activeProfile.id,
                request: request
            )
            
            print("✅ AppsViewModel: Created folder '\(newFolder.name)' with ID: \(newFolder.id)")
            
            // Update local folders array immediately
            folders.append(newFolder)
            folders.sort { $0.position < $1.position }
            
            // Step 2: Move apps to folder sequentially
            var movedSuccessfully = true
            
            // Move first app
            let movedApp1Response = try await profileAPI.moveApp(
                appId: draggedApp.id, 
                folderId: newFolder.id, 
                position: 0
            )
            print("✅ AppsViewModel: Moved \(draggedApp.name) to folder")
            print("📱 AppsViewModel: Backend moveApp response - success: \(movedApp1Response.success), message: \(movedApp1Response.message)")
            
            // Update local state for first app
            if let index = apps.firstIndex(where: { $0.id == draggedApp.id }) {
                let updatedApp = BookmarkedApp(
                    id: draggedApp.id,
                    name: draggedApp.name,
                    url: draggedApp.url,
                    iconUrl: draggedApp.iconUrl,
                    position: 0,
                    folderId: newFolder.id,
                    folderName: newFolder.name,
                    createdAt: draggedApp.createdAt,
                    updatedAt: draggedApp.updatedAt
                )
                apps[index] = updatedApp
                print("✅ AppsViewModel: Updated local state for \(draggedApp.name) - folderId: \(updatedApp.folderId ?? "nil")")
            }
            
            // Move second app
            let movedApp2Response = try await profileAPI.moveApp(
                appId: targetApp.id, 
                folderId: newFolder.id, 
                position: 1
            )
            print("✅ AppsViewModel: Moved \(targetApp.name) to folder")
            print("📱 AppsViewModel: Backend moveApp response - success: \(movedApp2Response.success), message: \(movedApp2Response.message)")
            
            // Update local state for second app
            if let index = apps.firstIndex(where: { $0.id == targetApp.id }) {
                let updatedApp = BookmarkedApp(
                    id: targetApp.id,
                    name: targetApp.name,
                    url: targetApp.url,
                    iconUrl: targetApp.iconUrl,
                    position: 1,
                    folderId: newFolder.id,
                    folderName: newFolder.name,
                    createdAt: targetApp.createdAt,
                    updatedAt: targetApp.updatedAt
                )
                apps[index] = updatedApp
                print("✅ AppsViewModel: Updated local state for \(targetApp.name) - folderId: \(updatedApp.folderId ?? "nil")")
            }
            
            // Step 3: Reload apps to get updated positions from backend
            print("🔄 AppsViewModel: Reloading apps to sync positions after folder creation")
            await loadApps()
            
            print("✅ AppsViewModel: Folder creation complete. Apps moved successfully.")
            print("📱 AppsViewModel: Apps in folder '\(newFolder.name)': \(appsInFolder(newFolder.id).count)")
            
            // Return the newly created folder (find it in the reloaded list)
            return folders.first { $0.id == newFolder.id } ?? newFolder
            
        } catch {
            print("❌ AppsViewModel: Failed to create folder: \(error)")
            handleError(error)
            
            // Reload to ensure consistency even on error
            await loadApps()
            
            return nil
        }
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
    
    func deleteFolderWithApps(_ folder: AppFolder) {
        Task {
            isLoading = true
            error = nil
            
            do {
                // Get all apps in the folder
                let appsInFolder = apps.filter { $0.folderId == folder.id }
                
                print("📱 AppsViewModel: Deleting folder '\(folder.name)' with \(appsInFolder.count) apps inside")
                
                // Delete all apps in the folder first
                for app in appsInFolder {
                    try await profileAPI.deleteApp(appId: app.id)
                    apps.removeAll { $0.id == app.id }
                    print("🗑️ AppsViewModel: Deleted app '\(app.name)' from folder")
                }
                
                // Then delete the folder
                try await profileAPI.deleteFolder(folderId: folder.id)
                folders.removeAll { $0.id == folder.id }
                
                print("✅ AppsViewModel: Successfully deleted folder and all apps inside")
                
                // Reorganize remaining app positions
                await reorganizeAppPositions()
                
            } catch {
                handleError(error)
            }
            
            isLoading = false
        }
    }
    
    private func reorganizeAppPositions() async {
        // Sort apps not in folders by current position
        let unfolderedApps = apps.filter { $0.folderId == nil }.sorted { $0.position < $1.position }
        
        // Update positions to be sequential
        for (index, app) in unfolderedApps.enumerated() {
            if let appIndex = apps.firstIndex(where: { $0.id == app.id }) {
                apps[appIndex] = BookmarkedApp(
                    id: app.id,
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    position: index,
                    folderId: app.folderId,
                    folderName: app.folderName,
                    createdAt: app.createdAt,
                    updatedAt: app.updatedAt
                )
            }
        }
        
        print("📱 AppsViewModel: Reorganized app positions")
    }
    
    func reorderFolders(_ folderIds: [String]) async {
        do {
            // Get active profile
            let profiles = try await profileAPI.getProfiles()
            guard let activeProfile = profiles.first(where: { $0.isActive }) else {
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
    
    private func setupProfileChangeObserver() {
        // Listen for profile change notifications
        NotificationCenter.default.publisher(for: .profileDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    print("📱 AppsViewModel: Profile changed, clearing and reloading apps")
                    
                    // Clear current data immediately for smooth transition
                    self.apps = []
                    self.folders = []
                    
                    // Show loading state
                    self.isLoading = true
                    
                    // Reload apps for the new profile
                    await self.loadApps()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Metadata Fetching
    
    func fetchMetadataForApp(url: String) async {
        guard let appUrl = URL(string: url) else { return }
        
        // Find the app with this URL
        guard let appIndex = apps.firstIndex(where: { $0.url == url }) else { return }
        
        do {
            // Fetch metadata
            let metadata = try await MetadataFetcher.shared.fetchMetadata(for: appUrl)
            
            // Update the app with fetched metadata
            let app = apps[appIndex]
            let updatedName = !metadata.title.isEmpty ? metadata.title : app.name
            let updatedIconUrl = metadata.iconURL ?? app.iconUrl
            
            // Update via API
            await updateApp(app, name: updatedName, iconUrl: updatedIconUrl)
            
        } catch {
            print("Failed to fetch metadata for \(url): \(error)")
        }
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
