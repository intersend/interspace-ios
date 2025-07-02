import Foundation

// MARK: - V2 API Helper
extension AuthAPI {
    /// Helper to ensure v2 endpoints are properly formatted
    private func v2Endpoint(_ path: String) -> String {
        // If the path already starts with /api/v2, return as is
        if path.hasPrefix("/api/v2/") {
            return path
        }
        
        // If it starts with /v2, prepend /api
        if path.hasPrefix("/v2/") {
            return "/api" + path
        }
        
        // If it starts with /, assume it needs /api/v2 prefix
        if path.hasPrefix("/") {
            return "/api/v2" + path
        }
        
        // Otherwise, prepend /api/v2/
        return "/api/v2/" + path
    }
}

// MARK: - Fixed V2 Endpoints
extension AuthAPI {
    
    /// POST /api/v2/auth/authenticate
    func authenticateV2Fixed(request: AuthRequestV2) async throws -> AuthResponseV2 {
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/authenticate"),
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthResponseV2.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/link-accounts
    func linkAccountsV2Fixed(request: LinkAccountRequestV2) async throws -> LinkAccountResponseV2 {
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/link-accounts"),
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkAccountResponseV2.self,
            requiresAuth: true
        )
    }
    
    /// POST /api/v2/auth/send-email-code
    func sendEmailCodeV2Fixed(_ email: String) async throws -> SuccessMessageResponse {
        struct EmailRequest: Codable {
            let email: String
        }
        
        let request = EmailRequest(email: email)
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/send-email-code"),
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: SuccessMessageResponse.self,
            requiresAuth: false
        )
    }
    
    /// GET /api/v2/auth/identity-graph
    func getIdentityGraphFixed() async throws -> IdentityGraphResponse {
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/identity-graph"),
            method: .GET,
            responseType: IdentityGraphResponse.self,
            requiresAuth: true
        )
    }
    
    /// POST /api/v2/auth/refresh
    func refreshTokenV2Fixed(refreshToken: String) async throws -> AuthResponseV2 {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/refresh"),
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthResponseV2.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/logout
    func logoutV2Fixed() async throws -> SuccessResponse {
        return try await apiService.performRequest(
            endpoint: v2Endpoint("/auth/logout"),
            method: .POST,
            responseType: SuccessResponse.self,
            requiresAuth: true
        )
    }
}

// MARK: - Gradual Migration
// Use these methods in AccountLinkingService and AuthenticationManagerV2
// to ensure proper v2 endpoint usage