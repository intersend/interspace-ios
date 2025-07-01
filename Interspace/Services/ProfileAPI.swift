import Foundation
import CryptoKit

// MARK: - Profile API Service

final class ProfileAPI {
    static let shared = ProfileAPI()
    let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - SmartProfile Endpoints
    
    /// GET /profiles
    func getProfiles() async throws -> [SmartProfile] {
        // Check if we have a token before making the request
        if apiService.getAccessToken() == nil {
            print("🔴 ProfileAPI: No access token available for getProfiles request")
            throw APIError.unauthorized
        }
        
        // The backend returns a wrapped response
        let response: ProfilesResponse = try await apiService.performRequest(
            endpoint: "/profiles",
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
            endpoint: "/profiles",
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
            endpoint: "/profiles/\(profileId)",
            method: .GET,
            responseType: ProfileResponse.self
        )
        return response.data
    }
    
    /// PUT /profiles/:profileId
    func updateProfile(profileId: String, name: String?, isActive: Bool?) async throws -> SmartProfile {
        let request = UpdateProfileRequest(name: name, isActive: isActive)
        let response: ProfileResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: ProfileResponse.self
        )
        return response.data
    }
    
    /// DELETE /profiles/:profileId
    func deleteProfile(profileId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/activate
    func activateProfile(profileId: String) async throws -> ActivateProfileResponse {
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/activate",
            method: .POST,
            responseType: ActivateProfileResponse.self
        )
    }
    
    // MARK: - App Management Endpoints
    
    /// GET /profiles/:profileId/apps
    func getApps(profileId: String) async throws -> [BookmarkedApp] {
        let response: AppsResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/apps",
            method: .GET,
            responseType: AppsResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/apps
    func createApp(profileId: String, request: CreateAppRequest) async throws -> BookmarkedApp {
        let response: AppResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/apps",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AppResponse.self
        )
        return response.data
    }
    
    /// PUT /apps/:appId
    func updateApp(appId: String, request: UpdateAppRequest) async throws -> BookmarkedApp {
        let response: AppResponse = try await apiService.performRequest(
            endpoint: "/apps/\(appId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: AppResponse.self
        )
        return response.data
    }
    
    /// DELETE /apps/:appId
    func deleteApp(appId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/apps/\(appId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/apps/reorder
    func reorderApps(profileId: String, appIds: [String], folderId: String?) async throws -> ReorderResponse {
        let request = ReorderAppsRequest(appIds: appIds, folderId: folderId)
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/apps/reorder",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: ReorderResponse.self
        )
    }
    
    /// PUT /apps/:appId/move
    func moveApp(appId: String, folderId: String?, position: Int? = nil) async throws -> MoveResponse {
        let request = MoveAppRequest(targetFolderId: folderId, position: position)
        return try await apiService.performRequest(
            endpoint: "/apps/\(appId)/move",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: MoveResponse.self
        )
    }
    
    // MARK: - Linked Account Management Endpoints
    
    /// GET /profiles/:profileId/accounts
    func getLinkedAccounts(profileId: String) async throws -> [LinkedAccount] {
        let response: LinkedAccountsResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/accounts",
            method: .GET,
            responseType: LinkedAccountsResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/accounts
    func linkAccount(profileId: String, request: LinkAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// PUT /accounts/:accountId
    func updateLinkedAccount(accountId: String, request: UpdateAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// DELETE /accounts/:accountId
    func unlinkAccount(accountId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    // MARK: - Folder Management Endpoints
    
    /// GET /profiles/:profileId/folders
    func getFolders(profileId: String) async throws -> [AppFolder] {
        let response: FoldersResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/folders",
            method: .GET,
            responseType: FoldersResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/folders
    func createFolder(profileId: String, request: CreateFolderRequest) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/folders",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// GET /profiles/:profileId/folders/:folderId
    func getFolder(profileId: String, folderId: String) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/folders/\(folderId)",
            method: .GET,
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// PUT /folders/:folderId
    func updateFolder(folderId: String, request: UpdateFolderRequest) async throws -> AppFolder {
        let response: FolderResponse = try await apiService.performRequest(
            endpoint: "/folders/\(folderId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: FolderResponse.self
        )
        return response.data
    }
    
    /// DELETE /folders/:folderId
    func deleteFolder(folderId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/folders/\(folderId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// POST /profiles/:profileId/folders/reorder
    func reorderFolders(profileId: String, folderIds: [String]) async throws -> ReorderResponse {
        let request = ReorderFoldersRequest(folderIds: folderIds)
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/folders/reorder",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: ReorderResponse.self
        )
    }
    
    /// POST /folders/:folderId/share
    func shareFolder(folderId: String) async throws -> ShareFolderResponse {
        return try await apiService.performRequest(
            endpoint: "/folders/\(folderId)/share",
            method: .POST,
            responseType: ShareFolderResponse.self
        )
    }
    
    /// DELETE /folders/:folderId/share
    func unshareFolder(folderId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/folders/\(folderId)/share",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    /// GET /folders/:folderId/contents
    func getFolderContents(folderId: String) async throws -> FolderContentsResponse {
        return try await apiService.performRequest(
            endpoint: "/folders/\(folderId)/contents",
            method: .GET,
            responseType: FolderContentsResponse.self
        )
    }
    
    // MARK: - MPC Endpoints
    
    /// POST /mpc/webhook/key-generated - Confirm key generation (internal use)
    func confirmKeyGeneration(profileId: String, keyId: String, publicKey: String, address: String) async throws -> MPCConfirmResponse {
        let request = MPCKeyGeneratedRequest(
            profileId: profileId,
            keyId: keyId,
            publicKey: publicKey,
            address: address
        )
        return try await apiService.performRequest(
            endpoint: "/mpc/webhook/key-generated",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: MPCConfirmResponse.self
        )
    }
    
    /// POST /mpc/rotate - Initiate key rotation
    func confirmKeyRotation(profileId: String, twoFactorCode: String?) async throws -> MPCRotateResponse {
        let request = MPCRotateRequest(
            profileId: profileId,
            twoFactorCode: twoFactorCode
        )
        return try await apiService.performRequest(
            endpoint: "/mpc/rotate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: MPCRotateResponse.self
        )
    }
    
    /// POST /mpc/backup - Create MPC backup
    func createMPCBackup(profileId: String, rsaPubkeyPem: String, label: String, twoFactorCode: String?) async throws -> MPCBackupResponse {
        let request = MPCBackupRequest(
            profileId: profileId,
            rsaPubkeyPem: rsaPubkeyPem,
            label: label,
            twoFactorCode: twoFactorCode
        )
        return try await apiService.performRequest(
            endpoint: "/mpc/backup",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: MPCBackupResponse.self
        )
    }
    
    /// POST /mpc/export - Export MPC key
    func exportMPCKey(profileId: String, clientEncKey: String, twoFactorCode: String?) async throws -> MPCExportResponse {
        let request = MPCExportRequest(
            profileId: profileId,
            clientEncKey: clientEncKey,
            twoFactorCode: twoFactorCode
        )
        return try await apiService.performRequest(
            endpoint: "/mpc/export",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: MPCExportResponse.self
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

// MARK: - MPC Request Models

struct MPCGenerateRequest: Codable {
    let profileId: String
}

struct MPCKeyGeneratedRequest: Codable {
    let profileId: String
    let keyId: String
    let publicKey: String
    let address: String
}

struct MPCRotateRequest: Codable {
    let profileId: String
    let twoFactorCode: String?
}

struct MPCBackupRequest: Codable {
    let profileId: String
    let rsaPubkeyPem: String
    let label: String
    let twoFactorCode: String?
}

struct MPCExportRequest: Codable {
    let profileId: String
    let clientEncKey: String
    let twoFactorCode: String?
}

// MARK: - MPC Response Models

struct MPCGenerateResponse: Codable {
    let success: Bool
    let data: MPCGenerateData
    
    struct MPCGenerateData: Codable {
        let profileId: String
        let cloudPublicKey: String
        let duoNodeUrl: String
        let message: String
    }
}

struct MPCConfirmResponse: Codable {
    let success: Bool
    let message: String
}

struct MPCRotateResponse: Codable {
    let success: Bool
    let message: String
    let data: MPCRotateData
    
    struct MPCRotateData: Codable {
        let profileId: String
        let status: String
    }
}

struct MPCBackupResponse: Codable {
    let success: Bool
    let data: MPCBackupData
    
    struct MPCBackupData: Codable {
        let profileId: String
        let keyId: String
        let algorithm: String
        let verifiableBackup: String
        let timestamp: String
    }
}

struct MPCExportResponse: Codable {
    let success: Bool
    let data: MPCExportData
    
    struct MPCExportData: Codable {
        let profileId: String
        let keyId: String
        let serverPublicKey: String
        let encryptedServerShare: String
        let timestamp: String
    }
}
