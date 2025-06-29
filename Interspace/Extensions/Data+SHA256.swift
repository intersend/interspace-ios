import Foundation
import CryptoKit

extension Data {
    func sha256String() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}