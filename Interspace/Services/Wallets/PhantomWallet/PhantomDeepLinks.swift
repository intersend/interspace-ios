import Foundation

/// Phantom deep link URL builder and parser
final class PhantomDeepLinks {
    
    // MARK: - Constants
    
    private static let baseURL = "https://phantom.app/ul/v1"
    private static let fallbackScheme = "phantom://"
    
    // MARK: - URL Building
    
    /// Build connect URL for establishing a session
    static func buildConnectURL(
        appUrl: String,
        publicKey: String,
        cluster: String = "mainnet-beta",
        redirectLink: String
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/connect")
        components?.queryItems = [
            URLQueryItem(name: "app_url", value: appUrl),
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "cluster", value: cluster),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        
        // Try universal link first, fallback to custom scheme
        if let url = components?.url {
            return url
        }
        
        // Fallback to custom scheme
        components = URLComponents(string: "\(fallbackScheme)v1/connect")
        components?.queryItems = [
            URLQueryItem(name: "app_url", value: appUrl),
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "cluster", value: cluster),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        
        return components?.url
    }
    
    /// Build disconnect URL
    static func buildDisconnectURL(
        publicKey: String,
        nonce: String,
        payload: String,
        redirectLink: String
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/disconnect")
        components?.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "payload", value: payload),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        return components?.url
    }
    
    /// Build sign message URL
    static func buildSignMessageURL(
        publicKey: String,
        nonce: String,
        payload: String,
        redirectLink: String
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/signMessage")
        components?.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "payload", value: payload),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        return components?.url
    }
    
    /// Build sign transaction URL
    static func buildSignTransactionURL(
        publicKey: String,
        nonce: String,
        payload: String,
        redirectLink: String
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/signTransaction")
        components?.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "payload", value: payload),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        return components?.url
    }
    
    /// Build sign and send transaction URL
    static func buildSignAndSendTransactionURL(
        publicKey: String,
        nonce: String,
        payload: String,
        redirectLink: String
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/signAndSendTransaction")
        components?.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: publicKey),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "payload", value: payload),
            URLQueryItem(name: "redirect_link", value: redirectLink)
        ]
        return components?.url
    }
    
    // MARK: - Response Parsing
    
    /// Parse response from Phantom redirect
    static func parseResponse(from url: URL) -> PhantomResponse? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var params: [String: String] = [:]
        components.queryItems?.forEach { item in
            params[item.name] = item.value
        }
        
        // Check for error
        if let errorCode = params["errorCode"],
           let errorMessage = params["errorMessage"] {
            return .error(code: errorCode, message: errorMessage)
        }
        
        // Parse success response
        if let nonce = params["nonce"],
           let data = params["data"] {
            // For connect response, also get public key
            let publicKey = params["phantom_encryption_public_key"]
            return .success(
                nonce: nonce,
                data: data,
                publicKey: publicKey
            )
        }
        
        return nil
    }
}

// MARK: - Response Types

enum PhantomResponse {
    case success(nonce: String, data: String, publicKey: String?)
    case error(code: String, message: String)
}

// MARK: - Request Payloads

/// Base payload for encrypted requests
protocol PhantomPayload: Codable {
    var session: String? { get }
}

/// Connect payload (no session needed)
struct PhantomConnectPayload: PhantomPayload {
    let session: String? = nil
}

/// Disconnect payload
struct PhantomDisconnectPayload: PhantomPayload {
    let session: String?
}

/// Sign message payload
struct PhantomSignMessagePayload: PhantomPayload {
    let message: String
    let session: String?
}

/// Sign transaction payload
struct PhantomSignTransactionPayload: PhantomPayload {
    let transaction: String // Base58 encoded transaction
    let session: String?
}

/// Sign and send transaction payload
struct PhantomSignAndSendTransactionPayload: PhantomPayload {
    let transaction: String // Base58 encoded transaction
    let sendOptions: PhantomSendOptions?
    let session: String?
}

/// Send options for transactions
struct PhantomSendOptions: Codable {
    let skipPreflight: Bool?
    let preflightCommitment: String?
    let maxRetries: Int?
}

// MARK: - Response Payloads

/// Connect response
struct PhantomConnectResponse: Codable {
    let publicKey: String // Base58 encoded public key
    let session: String   // Session token
    
    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case session = "session"
    }
}

/// Sign message response
struct PhantomSignMessageResponse: Codable {
    let signature: String // Base58 encoded signature
}

/// Sign transaction response
struct PhantomSignTransactionResponse: Codable {
    let signature: String // Base58 encoded signature
    let transaction: String? // Base58 encoded signed transaction
}

/// Send transaction response
struct PhantomSendTransactionResponse: Codable {
    let signature: String // Transaction signature/hash
}