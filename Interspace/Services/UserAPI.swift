import Foundation

// MARK: - Account API Service
// Note: This file maintains the UserAPI name for backward compatibility,
// but represents account management in the flat identity model

final class UserAPI {  // Kept name for backward compatibility
    static let shared = UserAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Account Management Endpoints
    
    /// GET /users/me (Legacy endpoint - returns account information)
    func getCurrentUser() async throws -> User {  // Returns User struct which represents Account
        let response: CurrentUserResponse = try await apiService.performRequest(
            endpoint: "/users/me",
            method: .GET,
            responseType: CurrentUserResponse.self
        )
        return response.data
    }
    
    /// GET /users/me/social-accounts (Returns linked social accounts)
    func getSocialAccounts() async throws -> [SocialAccount] {
        let response: SocialAccountsResponse = try await apiService.performRequest(
            endpoint: "/users/me/social-accounts",
            method: .GET,
            responseType: SocialAccountsResponse.self
        )
        return response.data
    }
    
    /// POST /users/me/social-accounts (Link a social account)
    func linkSocialAccount(request: LinkSocialAccountRequest) async throws -> SocialAccount {
        let response: SocialAccountResponse = try await apiService.performRequest(
            endpoint: "/users/me/social-accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: SocialAccountResponse.self
        )
        return response.data
    }
    
    /// DELETE /users/me/social-accounts/:id (Unlink a social account)
    func unlinkSocialAccount(socialAccountId: String) async throws -> UnlinkSocialAccountResponse {
        return try await apiService.performRequest(
            endpoint: "/users/me/social-accounts/\(socialAccountId)",
            method: .DELETE,
            responseType: UnlinkSocialAccountResponse.self
        )
    }
}

// MARK: - Request Models

struct LinkSocialAccountRequest: Codable {
    let provider: String
    let oauthCode: String
    let redirectUri: String
}

// MARK: - Response Models

struct CurrentUserResponse: Codable {  // Legacy response structure
    let success: Bool
    let data: User  // User struct represents Account in flat identity model
}

struct SocialAccountsResponse: Codable {
    let success: Bool
    let data: [SocialAccount]
}

struct SocialAccountResponse: Codable {
    let success: Bool
    let data: SocialAccount
    let message: String
}

struct UnlinkSocialAccountResponse: Codable {
    let success: Bool
    let message: String
}