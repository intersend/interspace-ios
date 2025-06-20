import Foundation

// MARK: - Authentication API Service

final class AuthAPI {
    static let shared = AuthAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Authentication Endpoints
    
    /// POST /auth/authenticate
    func authenticate(request: AuthenticationRequest) async throws -> AuthenticationResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/authenticate",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AuthenticationResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /auth/refresh
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
    
    /// POST /auth/logout
    func logout(refreshToken: String) async throws -> LogoutResponse {
        let request = LogoutRequest(refreshToken: refreshToken)
        return try await apiService.performRequest(
            endpoint: "/auth/logout",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LogoutResponse.self
        )
    }
    
    // Removed checkWallet method for privacy reasons
    
    /// GET /auth/me
    func getCurrentUser() async throws -> User {
        let response: UserResponse = try await apiService.performRequest(
            endpoint: "/auth/me",
            method: .GET,
            responseType: UserResponse.self
        )
        return response.data
    }
    
    /// POST /auth/link-auth
    func linkAuthMethod(provider: String, oauthCode: String) async throws -> LinkAuthResponse {
        let request = LinkAuthRequest(provider: provider, oauthCode: oauthCode)
        return try await apiService.performRequest(
            endpoint: "/auth/link-auth",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkAuthResponse.self
        )
    }
    
    /// GET /auth/devices
    func getDevices() async throws -> [Device] {
        let response: DevicesResponse = try await apiService.performRequest(
            endpoint: "/auth/devices",
            method: .GET,
            responseType: DevicesResponse.self
        )
        return response.data
    }
    
    /// DELETE /auth/devices/:deviceId
    func deactivateDevice(deviceId: String) async throws -> DeactivateDeviceResponse {
        return try await apiService.performRequest(
            endpoint: "/auth/devices/\(deviceId)",
            method: .DELETE,
            responseType: DeactivateDeviceResponse.self
        )
    }
    
    /// POST /auth/email/request-code
    func sendEmailCode(email: String) async throws -> EmailCodeResponse {
        let request = SendEmailCodeRequest(email: email)
        return try await apiService.performRequest(
            endpoint: "/auth/email/request-code",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: EmailCodeResponse.self,
            requiresAuth: false
        )
    }
    
    /// POST /auth/email/verify-code
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
    
    /// POST /auth/email/resend-code
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
    
    // MARK: - SIWE Authentication
    
    /// POST /siwe/authenticate
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
    
}

// MARK: - Request Models

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

struct SIWEAuthenticationRequest: Codable {
    let message: String
    let signature: String
    let address: String
    let authStrategy: String
    let deviceId: String?
    let deviceName: String
    let deviceType: String
}

struct SIWEVerifyRequest: Codable {
    let message: String
    let signature: String
}

// MARK: - Response Models

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

struct SIWEVerifyResponse: Codable {
    let success: Bool
    let data: SIWEVerifyData?
    let error: String?
}

struct SIWEVerifyData: Codable {
    let valid: Bool
    let address: String?
}

