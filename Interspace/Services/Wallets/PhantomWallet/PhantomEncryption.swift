import Foundation
import CryptoKit
import TweetNacl

/// Phantom wallet encryption utilities
/// Implements NaCl box encryption for secure communication with Phantom
/// Uses X25519 key exchange + XSalsa20 encryption + Poly1305 authentication
final class PhantomEncryption {
    
    // MARK: - Static Properties
    
    // MARK: - Types
    
    /// Encryption keypair
    struct KeyPair {
        let publicKey: Data
        let privateKey: Data
    }
    
    /// Encrypted payload
    struct EncryptedPayload {
        let nonce: Data
        let ciphertext: Data
        
        /// Combine nonce and ciphertext for transport
        var combined: Data {
            nonce + ciphertext
        }
    }
    
    // MARK: - Key Generation
    
    /// Generate a new keypair for encryption
    static func generateKeyPair() -> KeyPair {
        print("🔐 PhantomEncryption: Generating keypair")
        do {
            let keyPair = try NaclBox.keyPair()
            let publicKeyData = keyPair.publicKey
            let privateKeyData = keyPair.secretKey
            print("🔐 PhantomEncryption: TweetNaCl public key hex: \(publicKeyData.map { String(format: "%02x", $0) }.joined())")
            print("🔐 PhantomEncryption: TweetNaCl private key hex: \(privateKeyData.map { String(format: "%02x", $0) }.joined())")
            
            return KeyPair(
                publicKey: publicKeyData,
                privateKey: privateKeyData
            )
        } catch {
            print("⚠️ PhantomEncryption: TweetNaCl keypair generation failed: \(error), falling back to CryptoKit")
            // Fallback to CryptoKit if TweetNaCl fails
            let privateKey = Curve25519.KeyAgreement.PrivateKey()
            let publicKeyData = privateKey.publicKey.rawRepresentation
            let privateKeyData = privateKey.rawRepresentation
            print("🔐 PhantomEncryption: CryptoKit public key hex: \(publicKeyData.map { String(format: "%02x", $0) }.joined())")
            print("🔐 PhantomEncryption: CryptoKit private key hex: \(privateKeyData.map { String(format: "%02x", $0) }.joined())")
            return KeyPair(
                publicKey: publicKeyData,
                privateKey: privateKeyData
            )
        }
    }
    
    // MARK: - Encryption
    
    /// Encrypt data using NaCl box (X25519 + XSalsa20 + Poly1305)
    /// - Parameters:
    ///   - plaintext: Data to encrypt
    ///   - recipientPublicKey: Recipient's public key
    ///   - senderPrivateKey: Sender's private key
    /// - Returns: Encrypted payload with nonce
    static func encrypt(
        plaintext: Data,
        recipientPublicKey: Data,
        senderPrivateKey: Data
    ) throws -> EncryptedPayload {
        print("🔐 PhantomEncryption: Starting encryption")
        print("🔐 PhantomEncryption: Plaintext length: \(plaintext.count) bytes")
        print("🔐 PhantomEncryption: Plaintext hex: \(plaintext.map { String(format: "%02x", $0) }.joined())")
        print("🔐 PhantomEncryption: Recipient public key length: \(recipientPublicKey.count) bytes")
        print("🔐 PhantomEncryption: Recipient public key hex: \(recipientPublicKey.map { String(format: "%02x", $0) }.joined())")
        print("🔐 PhantomEncryption: Sender private key length: \(senderPrivateKey.count) bytes")
        print("🔐 PhantomEncryption: Sender private key hex: \(senderPrivateKey.map { String(format: "%02x", $0) }.joined())")
        
        // Generate random 24-byte nonce
        let nonce = generateNonce()
        print("🔐 PhantomEncryption: Generated nonce length: \(nonce.count) bytes")
        print("🔐 PhantomEncryption: Generated nonce hex: \(nonce.map { String(format: "%02x", $0) }.joined())")
        
        // Encrypt using TweetNaCl box
        let encryptedData: Data
        do {
            encryptedData = try NaclBox.box(
                message: plaintext,
                nonce: nonce,
                publicKey: recipientPublicKey,
                secretKey: senderPrivateKey
            )
        } catch {
            print("❌ PhantomEncryption: TweetNaCl box failed: \(error)")
            throw PhantomError.encryptionFailed
        }
        
        print("🔐 PhantomEncryption: Encrypted data length: \(encryptedData.count) bytes")
        print("🔐 PhantomEncryption: Encrypted data hex: \(encryptedData.map { String(format: "%02x", $0) }.joined())")
        
        return EncryptedPayload(
            nonce: nonce,
            ciphertext: encryptedData
        )
    }
    
    // MARK: - Decryption
    
    /// Decrypt data using NaCl box
    /// - Parameters:
    ///   - encryptedPayload: Encrypted data with nonce
    ///   - senderPublicKey: Sender's public key
    ///   - recipientPrivateKey: Recipient's private key
    /// - Returns: Decrypted data
    static func decrypt(
        encryptedPayload: EncryptedPayload,
        senderPublicKey: Data,
        recipientPrivateKey: Data
    ) throws -> Data {
        print("🔐 PhantomEncryption: Starting decryption")
        print("🔐 PhantomEncryption: Nonce length: \(encryptedPayload.nonce.count) bytes")
        print("🔐 PhantomEncryption: Nonce hex: \(encryptedPayload.nonce.map { String(format: "%02x", $0) }.joined())")
        print("🔐 PhantomEncryption: Ciphertext length: \(encryptedPayload.ciphertext.count) bytes")
        print("🔐 PhantomEncryption: Ciphertext hex: \(encryptedPayload.ciphertext.map { String(format: "%02x", $0) }.joined())")
        print("🔐 PhantomEncryption: Sender public key length: \(senderPublicKey.count) bytes")
        print("🔐 PhantomEncryption: Sender public key hex: \(senderPublicKey.map { String(format: "%02x", $0) }.joined())")
        print("🔐 PhantomEncryption: Recipient private key length: \(recipientPrivateKey.count) bytes")
        print("🔐 PhantomEncryption: Recipient private key hex: \(recipientPrivateKey.map { String(format: "%02x", $0) }.joined())")
        
        print("🔐 PhantomEncryption: Attempting NaCl box decryption")
        
        // Use TweetNaCl's NaCl box decryption
        let decryptedData: Data
        do {
            decryptedData = try NaclBox.open(
                message: encryptedPayload.ciphertext,
                nonce: encryptedPayload.nonce,
                publicKey: senderPublicKey,
                secretKey: recipientPrivateKey
            )
        } catch {
            print("❌ PhantomEncryption: TweetNaCl box open failed: \(error)")
            throw PhantomError.authenticationFailure
        }
        
        print("🔐 PhantomEncryption: Decryption successful, plaintext length: \(decryptedData.count) bytes")
        print("🔐 PhantomEncryption: Decrypted plaintext hex: \(decryptedData.map { String(format: "%02x", $0) }.joined())")
        
        return decryptedData
    }
    
    /// Decrypt data from combined format (nonce + ciphertext)
    static func decrypt(
        combined: Data,
        senderPublicKey: Data,
        recipientPrivateKey: Data
    ) throws -> Data {
        guard combined.count > 24 else {
            throw PhantomError.invalidEncryptedData
        }
        
        let nonce = combined.prefix(24)
        let ciphertext = combined.dropFirst(24)
        
        let payload = EncryptedPayload(nonce: nonce, ciphertext: ciphertext)
        return try decrypt(
            encryptedPayload: payload,
            senderPublicKey: senderPublicKey,
            recipientPrivateKey: recipientPrivateKey
        )
    }
    
    // MARK: - Helpers
    
    /// Generate a 24-byte nonce for XSalsa20
    private static func generateNonce() -> Data {
        var nonce = Data(count: 24)
        nonce.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, 24, baseAddress)
        }
        return nonce
    }
}

// MARK: - Phantom Errors

enum PhantomError: LocalizedError {
    case invalidPublicKey
    case invalidEncryptedData
    case decryptionFailed
    case invalidResponse
    case missingSession
    case authenticationFailure
    case encryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt response"
        case .invalidResponse:
            return "Invalid response from Phantom"
        case .missingSession:
            return "No active Phantom session"
        case .authenticationFailure:
            return "Authentication failed during decryption"
        case .encryptionFailed:
            return "Failed to encrypt data"
        }
    }
}

// MARK: - String Extensions for Phantom

extension String {
    /// URL encode for Phantom deep links
    var phantomURLEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}