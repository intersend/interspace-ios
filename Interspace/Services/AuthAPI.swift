import Foundation
import UIKit

// MARK: - Authentication API Service

final class AuthAPI {
    static let shared = AuthAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - V1 Authentication Endpoints (Legacy)
    
    /// POST /api/auth/authenticate
    func authenticate(request: AuthenticationRequest) async throws -> AuthenticationResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/authenticate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthenticationResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/auth/refresh
    func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        return try await apiService.performRequest(
            endpoint: "/auth/refresh",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: RefreshTokenResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/auth/logout
    func logout(refreshToken: String) async throws -> LogoutResponse {
        let request = LogoutRequest(refreshToken: refreshToken)
        return try await apiService.performRequest(
            endpoint: "/auth/logout",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LogoutResponse.self
        )
    }
    
    /// GET /api/auth/me
    func getCurrentUser() async throws -> User {
        let response: UserResponse = try await apiService.performRequest(
            endpoint: "/auth/me",
            method: .GET,
            responseType: UserResponse.self
        )
        return response.data
    }
    
    /// POST /api/auth/link-auth
    func linkAuthMethod(provider: String, oauthCode: String) async throws -> LinkAuthResponse {
        let request = LinkAuthRequest(provider: provider, oauthCode: oauthCode)
        return try await apiService.performRequest(
            endpoint: "/auth/link-auth",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkAuthResponse.self
        )
    }
    
    /// GET /api/auth/devices
    func getDevices() async throws -> [Device] {
        let response: DevicesResponse = try await apiService.performRequest(
            endpoint: "/auth/devices",
            method: .GET,
            responseType: DevicesResponse.self
        )
        return response.data
    }
    
    /// DELETE /api/auth/devices/:deviceId
    func deactivateDevice(deviceId: String) async throws -> DeactivateDeviceResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/devices/\(deviceId)",
            method: .DELETE,
            responseType: DeactivateDeviceResponse.self
        )
    }
    
    /// POST /api/auth/email/send-code
    func sendEmailCode(email: String) async throws -> EmailCodeResponse {
        let request = SendEmailCodeRequest(email: email)
        return try await apiService.performRequest(
            endpoint: "/auth/send-email-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/auth/email/verify-code
    func verifyEmailCode(email: String, code: String) async throws -> EmailVerificationResponse {
        let request = VerifyEmailCodeRequest(email: email, code: code)
        print("📧 AuthAPI: Verifying email code - email: \(email), code: \(code)")
        return try await apiService.performRequest(
            endpoint: "/auth/email/verify-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailVerificationResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/auth/email/resend-code
    func resendEmailCode(email: String) async throws -> EmailCodeResponse {
        let request = SendEmailCodeRequest(email: email)
        return try await apiService.performRequest(
            endpoint: "/auth/email/resend-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    // MARK: - V1 SIWE Authentication
    
    /// POST /api/siwe/authenticate
    /// Combines SIWE verification with JWT generation
    func authenticateWithSIWE(message: String, signature: String, address: String) async throws -> AuthenticationResponse {
        let request = SIWEAuthenticationRequest(
            message: message,
            signature: signature,
            address: address,
            authStrategy: "wallet",
            deviceId: DeviceInfo.deviceId,
            deviceName: DeviceInfo.deviceName,
            deviceType: "ios"
        )
        
        // Use the new combined endpoint that verifies SIWE and generates JWT
        return try await apiService.performRequest(
            endpoint: "/siwe/authenticate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthenticationResponse.self,
            requiresAuth: false
        )
    }
    
    // MARK: - V2 API Methods (Flat Identity Model)
    
    /// POST /api/auth/authenticate
    func authenticateV2(request: AuthenticationRequestV2) async throws -> AuthResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/authenticate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthResponseV2.self,
            requiresAuth: false
        )
    }
    
    /// POST /api/auth/switch-profile/:profileId
    func switchProfileV2(profileId: String) async throws -> AuthResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/switch-profile/\(profileId)",
            method: .POST,
            responseType: AuthResponseV2.self
        )
    }
    
    /// POST /api/auth/link-accounts
    func linkAccountsV2(request: LinkAccountRequestV2) async throws -> LinkAccountResponseV2 {
        return try await apiService.performRequest(
            endpoint: "/auth/link-accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkAccountResponseV2.self
        )
    }
    
    /// PUT /api/auth/link-privacy
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
    
    /// POST /api/auth/refresh
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
    
    /// POST /api/auth/logout
    func logoutV2() async throws -> LogoutResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/logout",
            method: .POST,
            responseType: LogoutResponse.self
        )
    }
    
    /// POST /api/auth/send-email-code
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
    
    /// POST /api/auth/resend-email-code
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
    
    /// POST /api/auth/verify-email-code
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
    
    /// GET /api/auth/identity-graph
    func getIdentityGraph() async throws -> IdentityGraphResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/identity-graph",
            method: .GET,
            responseType: IdentityGraphResponse.self
        )
    }
    
    // MARK: - V2 SIWE Methods
    
    /// GET /api/siwe/nonce
    func getSIWENonceV2() async throws -> SIWENonceResponse {
        return try await apiService.performRequest(
            endpoint: "/siwe/nonce",
            method: .GET,
            responseType: SIWENonceResponse.self,
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
            idToken: nil
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

struct SIWEAuthenticationRequest: Codable {
    let message: String
    let signature: String
    let address: String
    let authStrategy: String
    let deviceId: String?
    let deviceName: String
    let deviceType: String
}

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


