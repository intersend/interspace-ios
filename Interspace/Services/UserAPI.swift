import Foundation

// MARK: - User API Service

final class UserAPI {
    static let shared = UserAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - User Management Endpoints
    
    /// GET /users/me
    func getCurrentUser() async throws -> User {
        let response: CurrentUserResponse = try await apiService.performRequest(
            endpoint: "/users/me",
            method: .GET,
            responseType: CurrentUserResponse.self
        )
        return response.data
    }
    
    /// GET /users/me/social-accounts
    func getSocialAccounts() async throws -> [SocialAccount] {
        let response: SocialAccountsResponse = try await apiService.performRequest(
            endpoint: "/users/me/social-accounts",
            method: .GET,
            responseType: SocialAccountsResponse.self
        )
        return response.data
    }
    
    /// POST /users/me/social-accounts
    func linkSocialAccount(request: LinkSocialAccountRequest) async throws -> SocialAccount {
        let response: SocialAccountResponse = try await apiService.performRequest(
            endpoint: "/users/me/social-accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: SocialAccountResponse.self
        )
        return response.data
    }
    
    /// DELETE /users/me/social-accounts/:id
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

struct CurrentUserResponse: Codable {
    let success: Bool
    let data: User
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