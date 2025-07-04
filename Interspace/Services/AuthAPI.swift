import Foundation
import UIKit

// MARK: - Farcaster Response Models

struct FarcasterChannelResponse: Codable {
    let success: Bool
    let channel: FarcasterChannel?
    let error: String?
    
    struct FarcasterChannel: Codable {
        let channelToken: String
        let url: String
        let nonce: String
        let domain: String
        let siweUri: String
        let expiresAt: String
    }
}

struct FarcasterChannelStatusResponse: Codable {
    let success: Bool
    let status: String
    let authData: FarcasterAuthData?
    let error: String?
    
    struct FarcasterAuthData: Codable {
        let signature: String
        let message: String
        let fid: String
        let username: String?
        let displayName: String?
        let bio: String?
        let pfpUrl: String?
    }
}

// MARK: - Authentication API Service

final class AuthAPI {
    static let shared = AuthAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - V2 Authentication Endpoints
    
    // Note: V1 endpoints have been removed as they are no longer used.
    // All authentication now goes through V2 endpoints defined below.
    
    // MARK: - V2 API Methods (Flat Identity Model)
    
    /// POST /api/v2/auth/authenticate
    func authenticateV2(request: AuthenticationRequestV2) async throws -> AuthResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/authenticate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthResponseV2.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/switch-profile/:profileId
    func switchProfileV2(profileId: String) async throws -> AuthResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/switch-profile/\(profileId)",
            method: .POST,
            responseType: AuthResponseV2.self
        )
    }
    
    /// POST /api/v2/auth/link-accounts
    func linkAccountsV2(request: LinkAccountRequestV2) async throws -> LinkAccountResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/link-accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkAccountResponseV2.self,
            requiresAuth: true
        )
    }
    
    /// PUT /api/v2/auth/link-privacy
    func updateLinkPrivacyV2(targetAccountId: String, privacyMode: String) async throws -> SuccessResponse {
        struct UpdatePrivacyRequest: Codable {
            let targetAccountId: String
            let privacyMode: String
        }
        let request = UpdatePrivacyRequest(targetAccountId: targetAccountId, privacyMode: privacyMode)
        return try await apiService.performRequest(
            endpoint: "/auth/link-privacy",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: SuccessResponse.self
        )
    }
    
    /// POST /api/v2/auth/refresh
    func refreshTokenV2(refreshToken: String) async throws -> AuthResponseV2 {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        return try await apiService.performRequest(
            endpoint: "/auth/refresh",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthResponseV2.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/logout
    func logoutV2() async throws -> LogoutResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/logout",
            method: .POST,
            responseType: LogoutResponse.self
        )
    }
    
    /// POST /api/v2/auth/send-email-code
    func sendEmailCodeV2(email: String) async throws -> EmailCodeResponse {
        let request = SendEmailCodeRequest(email: email)
        return try await apiService.performRequest(
            endpoint: "/auth/send-email-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/resend-email-code
    func resendEmailCodeV2(email: String) async throws -> EmailCodeResponse {
        let request = SendEmailCodeRequest(email: email)
        return try await apiService.performRequest(
            endpoint: "/auth/resend-email-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/v2/auth/verify-email-code
    func verifyEmailCodeV2(email: String, code: String) async throws -> EmailCodeResponse {
        struct VerifyEmailCodeRequest: Codable {
            let email: String
            let code: String
        }
        let request = VerifyEmailCodeRequest(email: email, code: code)
        return try await apiService.performRequest(
            endpoint: "/auth/verify-email-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    /// GET /api/v2/auth/identity-graph
    func getIdentityGraph() async throws -> IdentityGraphResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/identity-graph",
            method: .GET,
            responseType: IdentityGraphResponse.self
        )
    }
    
    // MARK: - V2 SIWE Methods
    
    /// GET /api/v2/siwe/nonce
    func getSIWENonceV2() async throws -> SIWENonceResponse {
        return try await apiService.performRequest(
            endpoint: "/siwe/nonce",
            method: .GET,
            responseType: SIWENonceResponse.self,
            requiresAuth: false
        )
    }
    
    // MARK: - Farcaster Methods
    
    /// POST /api/v2/auth/farcaster/channel
    func createFarcasterChannel(domain: String, siweUri: String) async throws -> FarcasterChannelResponse {
        let body = [
            "domain": domain,
            "siweUri": siweUri
        ]
        return try await apiService.performRequest(
            endpoint: "/auth/farcaster/channel",
            method: .POST,
            body: try JSONSerialization.data(withJSONObject: body),
            responseType: FarcasterChannelResponse.self,
            requiresAuth: false
        )
    }
    
    /// GET /api/v2/auth/farcaster/channel/:channelToken
    func checkFarcasterChannel(channelToken: String) async throws -> FarcasterChannelStatusResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/farcaster/channel/\(channelToken)",
            method: .GET,
            responseType: FarcasterChannelStatusResponse.self,
            requiresAuth: false
        )
    }
    
    /// For V2 SIWE authentication, use authenticateV2 with strategy: "wallet"
    func authenticateWithSIWEV2(message: String, signature: String, walletAddress: String) async throws -> AuthResponseV2 {
        let request = AuthenticationRequestV2(
            strategy: "wallet",
            identifier: walletAddress,
            credential: signature,
            oauthCode: nil,
            appleAuth: nil,
            privacyMode: "linked",
            deviceId: DeviceInfo.deviceId,
            email: nil,
            verificationCode: nil,
            walletAddress: walletAddress,
            signature: signature,
            message: message,
            walletType: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        
        return try await authenticateV2(request: request)
    }
}

// MARK: - Request Models (Not in AuthModels.swift)

struct LinkAuthRequest: Codable {
    let provider: String
    let oauthCode: String
}

struct SendEmailCodeRequest: Codable {
    let email: String
}

struct VerifyEmailCodeRequest: Codable {
    let email: String
    let code: String
}

// RefreshTokenRequest and LogoutRequest are defined in AuthService.swift
// SIWEAuthenticationRequest is defined in SIWEModels.swift

// MARK: - Response Models (Not in AuthModels.swift)

struct LinkAuthResponse: Codable {
    let success: Bool
    let message: String
}

struct DevicesResponse: Codable {
    let success: Bool
    let data: [Device]
}

struct Device: Codable, Identifiable {
    let id: String
    let name: String
    let lastActive: String
    let deviceType: String?
    let isCurrentDevice: Bool?
}

struct DeactivateDeviceResponse: Codable {
    let success: Bool
    let message: String
}

struct EmailVerificationResponse: Codable {
    let success: Bool
    let message: String
    let email: String
}

struct SIWENonceResponse: Codable {
    let success: Bool
    let data: SIWENonceData
}

struct SIWENonceData: Codable {
    let nonce: String
    let expiresIn: Int
}

struct IdentityGraph: Codable {
    let primaryAccount: AccountV2
    let linkedAccounts: [AccountV2]
    let profiles: [ProfileSummaryV2]
}

struct SuccessResponse: Codable {
    let success: Bool
    let message: String?
}

// LogoutResponse and UserResponse are defined in AuthService.swift


