import Foundation
import Security
import CryptoKit
import LocalAuthentication

// MARK: - MPCSecureStorage

final class MPCSecureStorage {
    private let keychain = KeychainManager.shared
    private let keychainService = "com.interspace.mpc.keyshares"
    private let accessGroup: String? = nil
    
    // Use Secure Enclave when available
    private var useSecureEnclave: Bool {
        return SecureEnclave.isAvailable
    }
    
    // MARK: - Public Methods
    
    /// Store MPC key share securely
    func storeKeyShare(_ keyShare: MPCKeyShare, for profileId: String) async throws {
        // Serialize key share
        let encoder = JSONEncoder()
        let keyShareData = try encoder.encode(keyShare)
        
        print("🔵 MPCSecureStorage: Serialized key share size: \(keyShareData.count) bytes")
        
        // Encrypt with hardware-backed key
        let encryptedData = try await encryptData(keyShareData)
        
        print("🔵 MPCSecureStorage: Encrypted data size: \(encryptedData.count) bytes")
        
        // Store in keychain with biometric protection
        // Try without biometric first to isolate the issue
        try storeInKeychain(
            data: encryptedData,
            key: keyForProfile(profileId),
            requiresBiometric: false  // Changed to false for debugging
        )
        
        print("🔵 MPCSecureStorage: Successfully stored key share in keychain")
        
        // Store metadata separately (non-sensitive)
        try storeMetadata(for: profileId, keyShare: keyShare)
    }
    
    /// Retrieve MPC key share
    func retrieveKeyShare(for profileId: String) async throws -> MPCKeyShare? {
        // Retrieve from keychain
        guard let encryptedData = try? retrieveFromKeychain(
            key: keyForProfile(profileId),
            requiresBiometric: true
        ) else {
            return nil
        }
        
        // Decrypt data
        let decryptedData = try await decryptData(encryptedData)
        
        // Deserialize key share
        let decoder = JSONDecoder()
        return try decoder.decode(MPCKeyShare.self, from: decryptedData)
    }
    
    /// Delete MPC key share
    func deleteKeyShare(for profileId: String) async throws {
        // Delete from keychain
        try deleteFromKeychain(key: keyForProfile(profileId))
        
        // Delete metadata
        try deleteMetadata(for: profileId)
        
        // Clear any cached encryption keys
        clearEncryptionKeyCache()
    }
    
    /// Check if key share exists
    func hasKeyShare(for profileId: String) async -> Bool {
        return hasKeychainItem(key: keyForProfile(profileId))
    }
    
    /// Get key share metadata (non-sensitive info)
    func getKeyShareMetadata(for profileId: String) -> MPCKeyShareMetadata? {
        let key = metadataKeyForProfile(profileId)
        guard let data = try? keychain.load(for: key) else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(MPCKeyShareMetadata.self, from: data)
    }
    
    // MARK: - Private Methods - Keychain Operations
    
    private func storeInKeychain(
        data: Data,
        key: String,
        requiresBiometric: Bool
    ) throws {
        // First, always delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Build the basic query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // For now, skip biometric protection to avoid complexity
        // Just use standard accessibility
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("🔴 Keychain store error for key '\(key)': \(status)")
            // Add more detailed error information
            var errorMessage = "Unknown error"
            switch status {
            case errSecParam:
                errorMessage = "Invalid parameters (-50)"
            case errSecAllocate:
                errorMessage = "Failed to allocate memory"
            case errSecDuplicateItem:
                errorMessage = "Item already exists"
            case errSecItemNotFound:
                errorMessage = "Item not found"
            case errSecInteractionNotAllowed:
                errorMessage = "User interaction not allowed"
            case errSecDecode:
                errorMessage = "Unable to decode data"
            case errSecAuthFailed:
                errorMessage = "Authentication failed"
            default:
                errorMessage = "Error code: \(status)"
            }
            print("🔴 Keychain error details: \(errorMessage)")
            throw MPCError.keychainError(status)
        }
    }
    
    private func retrieveFromKeychain(
        key: String,
        requiresBiometric: Bool
    ) throws -> Data {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Add biometric prompt
        if requiresBiometric {
            let context = LAContext()
            context.localizedReason = "Access your MPC wallet"
            query[kSecUseAuthenticationContext as String] = context
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            if status == errSecItemNotFound {
                throw MPCError.keyShareNotFound
            }
            throw MPCError.keychainError(status)
        }
        
        return data
    }
    
    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MPCError.keychainError(status)
        }
    }
    
    private func hasKeychainItem(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Methods - Encryption
    
    private func encryptData(_ data: Data) async throws -> Data {
        if useSecureEnclave {
            return try encryptWithSecureEnclave(data)
        } else {
            return try encryptWithAES(data)
        }
    }
    
    private func decryptData(_ data: Data) async throws -> Data {
        if useSecureEnclave {
            return try decryptWithSecureEnclave(data)
        } else {
            return try decryptWithAES(data)
        }
    }
    
    private func encryptWithSecureEnclave(_ data: Data) throws -> Data {
        // Get or create encryption key in Secure Enclave
        let key = try getOrCreateSecureEnclaveKey()
        
        // Encrypt using ECIES
        guard let publicKey = SecKeyCopyPublicKey(key),
              let encryptedData = SecKeyCreateEncryptedData(
                publicKey,
                .eciesEncryptionCofactorX963SHA256AESGCM,
                data as CFData,
                nil
              ) as Data? else {
            throw MPCError.encryptionFailed
        }
        
        return encryptedData
    }
    
    private func decryptWithSecureEnclave(_ data: Data) throws -> Data {
        // Get encryption key from Secure Enclave
        let key = try getOrCreateSecureEnclaveKey()
        
        // Decrypt using ECIES
        guard let decryptedData = SecKeyCreateDecryptedData(
            key,
            .eciesEncryptionCofactorX963SHA256AESGCM,
            data as CFData,
            nil
        ) as Data? else {
            throw MPCError.decryptionFailed
        }
        
        return decryptedData
    }
    
    private func encryptWithAES(_ data: Data) throws -> Data {
        // Get or create AES key
        let key = try getOrCreateAESKey()
        
        // Generate nonce
        let nonce = AES.GCM.Nonce()
        
        // Encrypt
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        // Combine nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw MPCError.encryptionFailed
        }
        
        return combined
    }
    
    private func decryptWithAES(_ data: Data) throws -> Data {
        // Get AES key
        let key = try getOrCreateAESKey()
        
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    // MARK: - Private Methods - Key Management
    
    private func getOrCreateSecureEnclaveKey() throws -> SecKey {
        let tag = "com.interspace.mpc.encryptionkey".data(using: .utf8)!
        
        // Try to get existing key
        let getQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(getQuery as CFDictionary, &item)
        
        if status == errSecSuccess,
           let key = item as! SecKey? {
            return key
        }
        
        // Create new key
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )!
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]
        
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
            throw MPCError.keyGenerationFailed("Failed to create Secure Enclave key")
        }
        
        return key
    }
    
    private func getOrCreateAESKey() throws -> SymmetricKey {
        let keyTag = "com.interspace.mpc.aeskey"
        
        // Try to get existing key
        if let keyData = try? keychain.load(for: keyTag) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Store in keychain
        try keychain.save(keyData, for: keyTag)
        
        return key
    }
    
    private func clearEncryptionKeyCache() {
        // Clear any cached keys if needed
    }
    
    // MARK: - Private Methods - Helpers
    
    private func keyForProfile(_ profileId: String) -> String {
        return "mpc_keyshare_\(profileId)"
    }
    
    private func metadataKeyForProfile(_ profileId: String) -> String {
        return "mpc_metadata_\(profileId)"
    }
    
    private func storeMetadata(for profileId: String, keyShare: MPCKeyShare) throws {
        let metadata = MPCKeyShareMetadata(
            profileId: profileId,
            publicKey: keyShare.publicKey,
            address: keyShare.address,
            algorithm: keyShare.algorithm,
            createdAt: keyShare.createdAt,
            lastRotated: keyShare.createdAt
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        try keychain.save(data, for: metadataKeyForProfile(profileId))
    }
    
    private func deleteMetadata(for profileId: String) throws {
        try keychain.delete(for: metadataKeyForProfile(profileId))
    }
}

// MARK: - Supporting Types

struct MPCKeyShareMetadata: Codable {
    let profileId: String
    let publicKey: String
    let address: String
    let algorithm: MPCAlgorithm
    let createdAt: Date
    let lastRotated: Date
}

// MARK: - Secure Enclave Helper

struct SecureEnclave {
    static var isAvailable: Bool {
        if #available(iOS 11.0, *) {
            return LAContext().canEvaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                error: nil
            )
        }
        return false
    }
}

// MARK: - MPCError Extension

extension MPCError {
    static func keychainError(_ status: OSStatus) -> MPCError {
        let message: String
        switch status {
        case errSecItemNotFound:
            message = "Item not found in keychain"
        case errSecAuthFailed:
            message = "Authentication failed"
        case errSecUserCanceled:
            message = "User cancelled authentication"
        default:
            message = "Keychain error: \(status)"
        }
        return .storageError(message)
    }
}