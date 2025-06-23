import Foundation
import CryptoKit

// MARK: - Profile API Service

final class ProfileAPI {
    static let shared = ProfileAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - SmartProfile Endpoints
    
    /// GET /profiles
    func getProfiles() async throws -> [SmartProfile] {
        // The backend returns a wrapped response
        let response: ProfilesResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles",
            method: .GET,
            responseType: ProfilesResponse.self
        )
        return response.data
    }
    
    /// POST /profiles
    func createProfile(name: String, developmentMode: Bool = false) async throws -> SmartProfile {
        var clientShareString: String? = nil
        
        // Generate mock clientShare for development mode
        if developmentMode {
            let mockClientShare = generateMockClientShare()
            if let clientShareData = try? JSONEncoder().encode(mockClientShare),
               let jsonString = String(data: clientShareData, encoding: .utf8) {
                clientShareString = jsonString
            }
        }
        
        let request = CreateProfileRequest(
            name: name, 
            clientShare: clientShareString,
            developmentMode: developmentMode
        )
        
        let requestData = try JSONEncoder().encode(request)
        
        #if DEBUG
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("🌐 ProfileAPI: Creating profile with request: \(jsonString)")
        }
        #endif
        
        let response: ProfileResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles",
            method: .POST,
            body: requestData,
            responseType: ProfileResponse.self
        )
        return response.data
    }
    
    private func generateMockClientShare() -> ClientShare {
        // Generate deterministic values based on current timestamp
        let timestamp = "\(Date().timeIntervalSince1970)"
        let secretShare = Data(timestamp.utf8).sha256String()
        let publicKey = Data("pubkey-\(timestamp)".utf8).sha256String().prefix(64)
        let address = "0x" + Data("address-\(timestamp)".utf8).sha256String().prefix(40)
        
        return ClientShare(
            p1_key_share: ClientShare.KeyShare(
                secret_share: secretShare,
                public_key: String(publicKey)
            ),
            public_key: String(publicKey),
            address: String(address)
        )
    }
    
    /// GET /profiles/:profileId
    func getProfile(profileId: String) async throws -> SmartProfile {
        let response: ProfileResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)",
            method: .GET,
            responseType: ProfileResponse.self
        )
        return response.data
    }
    
    /// PUT /profiles/:profileId
    func updateProfile(profileId: String, name: String?, isActive: Bool?) async throws -> SmartProfile {
        let request = UpdateProfileRequest(name: name, isActive: isActive)
        let response: ProfileResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: ProfileResponse.self
        )
        return response.data
    }
    
    /// DELETE /profiles/:profileId
    func deleteProfile(profileId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/activate
    func activateProfile(profileId: String) async throws -> ActivateProfileResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/activate",
            method: .POST,
            responseType: ActivateProfileResponse.self
        )
    }
    
    // MARK: - App Management Endpoints
    
    /// GET /profiles/:profileId/apps
    func getApps(profileId: String) async throws -> [BookmarkedApp] {
        let response: AppsResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/apps",
            method: .GET,
            responseType: AppsResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/apps
    func createApp(profileId: String, request: CreateAppRequest) async throws -> BookmarkedApp {
        let response: AppResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/apps",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AppResponse.self
        )
        return response.data
    }
    
    /// PUT /apps/:appId
    func updateApp(appId: String, request: UpdateAppRequest) async throws -> BookmarkedApp {
        let response: AppResponse = try await apiService.performRequest(
            endpoint: "/v2/apps/\(appId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: AppResponse.self
        )
        return response.data
    }
    
    /// DELETE /apps/:appId
    func deleteApp(appId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/apps/\(appId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/apps/reorder
    func reorderApps(profileId: String, appIds: [String], folderId: String?) async throws -> ReorderResponse {
        let request = ReorderAppsRequest(appIds: appIds, folderId: folderId)
        return try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/apps/reorder",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: ReorderResponse.self
        )
    }
    
    /// PUT /apps/:appId/move
    func moveApp(appId: String, folderId: String?, position: Int? = nil) async throws -> MoveResponse {
        let request = MoveAppRequest(targetFolderId: folderId, position: position)
        return try await apiService.performRequest(
            endpoint: "/v2/apps/\(appId)/move",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: MoveResponse.self
        )
    }
    
    // MARK: - Linked Account Management Endpoints
    
    /// GET /profiles/:profileId/accounts
    func getLinkedAccounts(profileId: String) async throws -> [LinkedAccount] {
        let response: LinkedAccountsResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/accounts",
            method: .GET,
            responseType: LinkedAccountsResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/accounts
    func linkAccount(profileId: String, request: LinkAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// PUT /accounts/:accountId
    func updateLinkedAccount(accountId: String, request: UpdateAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/v2/accounts/\(accountId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// DELETE /accounts/:accountId
    func unlinkAccount(accountId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/accounts/\(accountId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    // MARK: - Folder Management Endpoints
    
    /// GET /profiles/:profileId/folders
    func getFolders(profileId: String) async throws -> [AppFolder] {
        let response: FoldersResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/folders",
            method: .GET,
            responseType: FoldersResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/folders
    func createFolder(profileId: String, request: CreateFolderRequest) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/folders",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// GET /profiles/:profileId/folders/:folderId
    func getFolder(profileId: String, folderId: String) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/folders/\(folderId)",
            method: .GET,
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// PUT /folders/:folderId
    func updateFolder(folderId: String, request: UpdateFolderRequest) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/v2/folders/\(folderId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// DELETE /folders/:folderId
    func deleteFolder(folderId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/folders/\(folderId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/folders/reorder
    func reorderFolders(profileId: String, folderIds: [String]) async throws -> ReorderResponse {
        let request = ReorderFoldersRequest(folderIds: folderIds)
        return try await apiService.performRequest(
            endpoint: "/v2/profiles/\(profileId)/folders/reorder",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: ReorderResponse.self
        )
    }
    
    /// POST /folders/:folderId/share
    func shareFolder(folderId: String) async throws -> ShareFolderResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/folders/\(folderId)/share",
            method: .POST,
            responseType: ShareFolderResponse.self
        )
    }
    
    /// DELETE /folders/:folderId/share
    func unshareFolder(folderId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/folders/\(folderId)/share",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// GET /folders/:folderId/contents
    func getFolderContents(folderId: String) async throws -> FolderContentsResponse {
        return try await apiService.performRequest(
            endpoint: "/v2/folders/\(folderId)/contents",
            method: .GET,
            responseType: FolderContentsResponse.self
        )
    }
}

// MARK: - Response Models

struct ActivateProfileResponse: Codable {
    let success: Bool
    let data: ActivatedProfile
    let message: String
    
    struct ActivatedProfile: Codable {
        let id: String
        let isActive: Bool
    }
}

struct DeleteResponse: Codable {
    let success: Bool
    let message: String
}

struct ReorderResponse: Codable {
    let success: Bool
    let message: String
}

struct MoveResponse: Codable {
    let success: Bool
    let message: String
}

struct FolderContentsResponse: Codable {
    let success: Bool
    let data: FolderContents
    
    struct FolderContents: Codable {
        let apps: [BookmarkedApp]
    }
}
