import Foundation

// MARK: - SIWE Models

/// SIWE Authentication Request for backend
struct SIWEAuthenticationRequest: Codable {
    let message: String
    let signature: String
    let address: String
    let authStrategy: String
    let deviceId: String
    let deviceName: String
    let deviceType: String
}

/// Nonce response from backend
struct NonceResponse: Codable {
    let success: Bool
    let data: NonceData?
    let error: String?
}

struct NonceData: Codable {
    let nonce: String
}

/// SIWE Message components following EIP-4361
struct SIWEMessage {
    let domain: String
    let address: String
    let statement: String
    let uri: String
    let version: String
    let chainId: Int
    let nonce: String
    let issuedAt: String
    let expirationTime: String?
    let notBefore: String?
    let requestId: String?
    let resources: [String]?
    
    /// Format message according to EIP-4361
    func formatted() -> String {
        var message = "\(domain) wants you to sign in with your Ethereum account:\n"
        message += "\(address)\n\n"
        message += "\(statement)\n\n"
        message += "URI: \(uri)\n"
        message += "Version: \(version)\n"
        message += "Chain ID: \(chainId)\n"
        message += "Nonce: \(nonce)\n"
        message += "Issued At: \(issuedAt)"
        
        if let expirationTime = expirationTime {
            message += "\nExpiration Time: \(expirationTime)"
        }
        
        if let notBefore = notBefore {
            message += "\nNot Before: \(notBefore)"
        }
        
        if let requestId = requestId {
            message += "\nRequest ID: \(requestId)"
        }
        
        if let resources = resources, !resources.isEmpty {
            message += "\nResources:"
            for resource in resources {
                message += "\n- \(resource)"
            }
        }
        
        return message
    }
}

/// SIWE verification result
struct SIWEVerificationResult {
    let isValid: Bool
    let address: String?
    let error: String?
}