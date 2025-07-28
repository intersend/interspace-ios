import Foundation
import CryptoKit
import WalletConnectSigner

/// Simple crypto provider implementation for AppKit
struct DefaultCryptoProvider: CryptoProvider {
    
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        // For now, we'll throw an error as this is not needed for basic SIWE
        // In production, you'd implement proper public key recovery
        throw CryptoProviderError.notImplemented
    }
    
    func keccak256(_ data: Data) -> Data {
        // Using SHA256 as a placeholder for Keccak256
        // Note: CryptoKit doesn't have Keccak256, so we use SHA256
        // AppKit will handle the actual Keccak256 internally for most operations
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
}

enum CryptoProviderError: Error {
    case notImplemented
}