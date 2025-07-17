import Foundation
import CryptoKit

// MARK: - Debug Extensions for Wallet Flow

extension Data {
    /// Compute SHA256 hash
    func sha256() -> Data {
        let hash = SHA256.hash(data: self)
        return Data(hash)
    }
    
    /// Convert to hex string
    func toHexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    /// Quick debug hash (lowercase hex, 16 chars)
    var debugHash: String {
        guard let data = self.data(using: .utf8) else { return "error" }
        return data.sha256().toHexString().prefix(16).lowercased()
    }
}
