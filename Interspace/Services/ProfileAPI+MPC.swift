import Foundation

// MARK: - MPC HTTP Endpoints Extension
// This replaces WebSocket communication with HTTP endpoints

extension ProfileAPI {
    
    /// POST /api/v2/mpc/generate - Get cloud public key
    func getCloudPublicKey(profileId: String) async throws -> CloudPublicKeyResponse {
        print("🌐 ProfileAPI+MPC: Calling POST /api/v2/mpc/generate for profile: \(profileId)")
        
        struct Request: Codable {
            let profileId: String
        }
        
        let request = Request(profileId: profileId)
        return try await apiService.performRequest(
            endpoint: "/mpc/generate",
            method: HTTPMethod.POST,
            body: try JSONEncoder().encode(request),
            responseType: CloudPublicKeyResponse.self
        )
    }
    
    /// POST /api/v2/mpc/keygen/start - Start MPC key generation session
    func startKeyGeneration(profileId: String, p1Messages: [[String: Any]] = []) async throws -> KeyGenSessionResponse {
        print("🌐 ProfileAPI+MPC: Calling POST /api/v2/mpc/keygen/start for profile: \(profileId)")
        print("   P1 messages count: \(p1Messages.count)")
        
        // Create request body as dictionary
        let requestBody: [String: Any] = [
            "profileId": profileId,
            "p1Messages": p1Messages
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        return try await apiService.performRequest(
            endpoint: "/mpc/keygen/start",
            method: HTTPMethod.POST,
            body: jsonData,
            responseType: KeyGenSessionResponse.self
        )
    }
    
    /// POST /api/v2/mpc/message/forward - Forward P1 message to duo-node
    func forwardP1Message(sessionId: String, messageType: MPCMessageType, message: [String: Any]) async throws -> ForwardMessageResponse {
        // Create request body as dictionary
        let requestBody: [String: Any] = [
            "sessionId": sessionId,
            "messageType": messageType.rawValue,
            "message": message
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        return try await apiService.performRequest(
            endpoint: "/mpc/message/forward",
            method: HTTPMethod.POST,
            body: jsonData,
            responseType: ForwardMessageResponse.self
        )
    }
    
    /// POST /api/v2/mpc/sign/start - Start MPC signing session
    func startSigning(profileId: String, message: String, p1Messages: [[String: Any]] = []) async throws -> SignSessionResponse {
        // Create request body as dictionary
        let requestBody: [String: Any] = [
            "profileId": profileId,
            "message": message,
            "p1Messages": p1Messages
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        return try await apiService.performRequest(
            endpoint: "/mpc/sign/start",
            method: HTTPMethod.POST,
            body: jsonData,
            responseType: SignSessionResponse.self
        )
    }
    
    /// GET /api/v2/mpc/session/:sessionId - Get MPC session status
    func getSessionStatus(sessionId: String) async throws -> SessionStatusResponse {
        return try await apiService.performRequest(
            endpoint: "/mpc/session/\(sessionId)",
            method: HTTPMethod.GET,
            responseType: SessionStatusResponse.self
        )
    }
    
    /// POST /api/v2/mpc/key-generated - Notify backend about generated key
    func notifyKeyGenerated(profileId: String, keyId: String, publicKey: String, address: String) async throws {
        print("🌐 ProfileAPI+MPC: Notifying backend about generated key for profile: \(profileId)")
        
        struct Request: Codable {
            let profileId: String
            let keyId: String
            let publicKey: String
            let address: String
        }
        
        let request = Request(
            profileId: profileId,
            keyId: keyId,
            publicKey: publicKey,
            address: address
        )
        
        struct Response: Codable {
            let success: Bool
            let message: String?
        }
        
        // Use a regular MPC endpoint that accepts auth token instead of webhook
        let _: Response = try await apiService.performRequest(
            endpoint: "/mpc/key-generated",
            method: HTTPMethod.POST,
            body: try JSONEncoder().encode(request),
            responseType: Response.self
        )
    }
}

// MARK: - Request Models

// KeyGenStartRequest struct removed - using dictionary directly in startKeyGeneration

// ForwardP1MessageRequest struct removed - using dictionary directly

// SignStartRequest struct removed - using dictionary directly

// MARK: - Response Models

struct CloudPublicKeyResponse: Codable {
    let success: Bool
    let data: CloudPublicKeyData
}

struct CloudPublicKeyData: Codable {
    let cloudPublicKey: String
    let algorithm: String?
    let profileId: String
    let duoNodeUrl: String?
    let message: String?
}

struct KeyGenSessionResponse: Codable {
    let success: Bool
    let data: KeyGenSessionData
}

struct KeyGenSessionData: Codable {
    let sessionId: String
    let profileId: String
    let keyId: String
    let publicKey: String
    let address: String
}

struct ForwardMessageResponse: Codable {
    let success: Bool
    let message: String
}

struct SignSessionResponse: Codable {
    let success: Bool
    let data: SignSessionData
}

struct SignSessionData: Codable {
    let sessionId: String
    let profileId: String
    let signature: String
}

struct SessionStatusResponse: Codable {
    let success: Bool
    let data: SessionStatus
}

struct SessionStatus: Codable {
    let sessionId: String
    let profileId: String
    let type: String
    let status: String
    let createdAt: String
    let expiresAt: String
    let result: SessionResult?
    let error: String?
}

struct SessionResult: Codable {
    // For key generation
    let keyId: String?
    let publicKey: String?
    let address: String?
    
    // For signing
    let signature: String?
}

// MARK: - Enums

// MPCMessageType is already defined in MPCHTTPSessionManager.swift
