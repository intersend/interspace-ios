import Foundation
import silentshardduo
import CryptoSwift

// MARK: - MPCKeyShareManager

final class MPCKeyShareManager {
    private var duoSession: DuoSession?
    private var currentAlgorithm: MPCAlgorithm = .ecdsa
    private let queue = DispatchQueue(label: "com.interspace.mpc.keyshare", qos: .userInitiated)
    
    // MARK: - Session Management
    
    func initializeSession(algorithm: MPCAlgorithm, cloudPublicKey: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    // Get WebSocket configuration from environment
                    let config = MPCWebSocketConfiguration.shared
                    
                    // Print debug info in development
                    #if DEBUG
                  MPCWebSocketConfiguration.printConnectionDebugInfo()
                    #endif
                    
                    let websocketConfig = WebsocketConfigBuilder()
                        .withBaseUrl(config.duoNodeUrl)
                        .withPort(config.duoNodePort)
                        .withSecure(config.useSecureConnection)
                        .withAuthenticationToken(config.authToken ?? "")
                        .build()
                    
                    // Store the algorithm for later use
                    self?.currentAlgorithm = algorithm
                    
                    // Workaround: If algorithm is ECDSA but key is EdDSA, modify the key
                    var actualCloudPublicKey = cloudPublicKey
                    if algorithm == .ecdsa && cloudPublicKey.hasPrefix("01") {
                        print("⚠️ MPC: Algorithm mismatch detected - forcing ECDSA with EdDSA key")
                        print("   Original key prefix: 01 (EdDSA)")
                        print("   Forced algorithm: ECDSA")
                        // Change the prefix from 01 (EdDSA) to 02 (ECDSA)
                        let keyWithoutPrefix = String(cloudPublicKey.dropFirst(2))
                        actualCloudPublicKey = "02" + keyWithoutPrefix
                        print("   Modified key prefix: 02 (ECDSA)")
                    }
                    
                    // Create DuoSession based on algorithm
                    switch algorithm {
                    case .ecdsa:
                        self?.duoSession = SilentShardDuo.ECDSA.createDuoSession(
                            cloudVerifyingKey: actualCloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    case .eddsa:
                        self?.duoSession = SilentShardDuo.EdDSA.createDuoSession(
                            cloudVerifyingKey: actualCloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: MPCError.sdkInitializationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Key Generation
    
    func generateKeyShare() async throws -> MPCKeyShare {
        guard let session = duoSession else {
            throw MPCError.sdkNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let result = await session.keygen()
                
                switch result {
                case .success(let keyShareData):
                    do {
                        let publicKeyHex = await getPublicKeyHex(from: keyShareData)
                        let address = deriveAddress(from: publicKeyHex)
                        
                        let keyShare = MPCKeyShare(
                            shareData: keyShareData,
                            publicKey: publicKeyHex,
                            address: address,
                            algorithm: self.currentAlgorithm,
                            createdAt: Date()
                        )
                        
                        continuation.resume(returning: keyShare)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: MPCError.keyGenerationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Signing
    
    func signMessage(
        keyShare: MPCKeyShare,
        message: Data,
        chainPath: String? = nil
    ) async throws -> String {
        guard let session = duoSession else {
            throw MPCError.sdkNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let result = await session.signature(
                    keyshare: keyShare.shareData,
                    message: message.hexString,
                    chainPath: chainPath ?? "m"
                )
                
                switch result {
                case .success(let signatureData):
                    let signature = self.formatSignature(signatureData)
                    continuation.resume(returning: signature)
                    
                case .failure(let error):
                    continuation.resume(throwing: MPCError.signingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Key Refresh (Rotation)
    
    func refreshKeyShare(_ currentShare: MPCKeyShare) async throws -> MPCKeyShare {
        guard let session = duoSession else {
            throw MPCError.sdkNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let result = await session.keyRefresh(keyshare: currentShare.shareData)
                
                switch result {
                case .success(let newShareData):
                    let keyShare = MPCKeyShare(
                        shareData: newShareData,
                        publicKey: currentShare.publicKey, // Public key remains the same
                        address: currentShare.address,      // Address remains the same
                        algorithm: currentShare.algorithm,
                        createdAt: Date()
                    )
                    
                    continuation.resume(returning: keyShare)
                    
                case .failure(let error):
                    continuation.resume(throwing: MPCError.keyRotationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - BIP32 Support
    
    func deriveChildPublicKey(
        keyShare: MPCKeyShare,
        derivationPath: String
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let result: Result<String, Error>
                
                switch keyShare.algorithm {
                case .ecdsa:
                    result = await SilentShardDuo.ECDSA.deriveChildPublicKeyAsHex(
                        keyShare.shareData,
                        derivationPath: derivationPath
                    )
                case .eddsa:
                    result = await SilentShardDuo.EdDSA.deriveChildPublicKeyAsHex(
                        keyShare.shareData,
                        derivationPath: derivationPath
                    )
                }
                
                switch result {
                case .success(let publicKey):
                    continuation.resume(returning: publicKey)
                case .failure(let error):
                    continuation.resume(throwing: MPCError.derivationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Export Support
    
    func combineShares(
        clientShare: MPCKeyShare,
        encryptedServerShare: String,
        serverPublicKey: [UInt8],
        clientEncryptionKey: Data
    ) async throws -> String {
        guard let session = duoSession else {
            throw MPCError.sdkNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Generate decryption key pair
                let keyPairResult = await generateEncryptionKeyPair(for: clientShare.algorithm)
                
                switch keyPairResult {
                case .success(let (privateKey, _)):
                    // Decrypt server share
                    guard let encryptedData = Data(base64Encoded: encryptedServerShare) else {
                        continuation.resume(throwing: MPCError.invalidData)
                        return
                    }
                    
                    let result = await session.export(
                        hostKeyshare: clientShare.shareData,
                        otherEncryptedKeyshare: encryptedData,
                        hostEncryptionKey: privateKey,
                        otherDecryptionKey: Data(serverPublicKey)
                    )
                    
                    switch result {
                    case .success(let privateKeyData):
                        let privateKeyHex = privateKeyData.hexString
                        continuation.resume(returning: privateKeyHex)
                        
                    case .failure(let error):
                        continuation.resume(throwing: MPCError.exportFailed(error.localizedDescription))
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func getPublicKeyHex(from keyShareData: Data) async -> String {
        let result: Result<String, Error>
        
        switch currentAlgorithm {
        case .ecdsa:
            result = await SilentShardDuo.ECDSA.getKeysharePublicKeyAsHex(keyShareData)
        case .eddsa:
            result = await SilentShardDuo.EdDSA.getKeysharePublicKeyAsHex(keyShareData)
        }
        
        switch result {
        case .success(let publicKey):
            return publicKey
        case .failure:
            return "" // Handle error appropriately
        }
    }
    
    private func deriveAddress(from publicKey: String) -> String {
        // Convert public key to Ethereum address
        // This is a simplified version - you might need to use a proper library
        guard let publicKeyData = Data(hex: publicKey) else {
            return "0x0000000000000000000000000000000000000000" // Return zero address if invalid
        }
        // Use explicit namespace to avoid ambiguity with keccak256
        let hashBytes = CryptoSwift.SHA3(variant: .keccak256).calculate(for: [UInt8](publicKeyData))
        let hash = Data(hashBytes)
        let address = "0x" + hash.suffix(20).hexString
        return address
    }
    
    private func formatSignature(_ signatureData: Data) -> String {
        // Format signature as hex string with 0x prefix
        return "0x" + signatureData.hexString
    }
    
    private func generateEncryptionKeyPair(for algorithm: MPCAlgorithm) async -> Result<(Data, Data), Error> {
        switch algorithm {
        case .ecdsa:
            return await SilentShardDuo.ECDSA.generateEncryptionDecryptionKeyPair()
        case .eddsa:
            return await SilentShardDuo.EdDSA.generateEncryptionDecryptionKeyPair()
        }
    }
}

// MARK: - Supporting Types

struct MPCKeyShare: Codable {
    let shareData: Data
    let publicKey: String
    let address: String
    let algorithm: MPCAlgorithm
    let createdAt: Date
    let keyId: String
    
    // Backward compatibility initializer
    init(shareData: Data, publicKey: String, address: String, algorithm: MPCAlgorithm, createdAt: Date, keyId: String? = nil) {
        self.shareData = shareData
        self.publicKey = publicKey
        self.address = address
        self.algorithm = algorithm
        self.createdAt = createdAt
        // Use provided keyId or generate from share data
        self.keyId = keyId ?? shareData.prefix(32).base64EncodedString()
    }
}

enum MPCAlgorithm: String, Codable {
    case ecdsa = "ecdsa"
    case eddsa = "eddsa"
}

// MARK: - MPC WebSocket Configuration

final class MPCWebSocketConfiguration {
    static let shared = MPCWebSocketConfiguration()
    
    enum Environment {
        case development
        case staging
        case production
    }
    
    var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
      var duoNodeUrl: String {
        #if DEBUG
        // For local development, connect directly to sigpair
        // Note: Don't include ws:// prefix - WebsocketConfigBuilder adds it
        // For iOS simulator: use localhost (will be resolved by the simulator)
        return "localhost"
        #else
        return "interspace-duo-node-prod.a.run.app"
        #endif
    }
    
    var duoNodePort: String {
        #if DEBUG
        return "8080"  // Sigpair local port
        #else
        return "443"
        #endif
    }
    
    var useSecureConnection: Bool {
        #if DEBUG
        return false  // Local development uses ws://
        #else
        return true
        #endif
    }
    
    var authToken: String? {
        // Get auth token from keychain
        return KeychainManager.shared.getAccessToken()
    }
    
    var websocketTimeout: TimeInterval {
        return 30.0
    }
    
    var maxReconnectAttempts: Int {
        return 3
    }
    
    #if DEBUG
    static func printConnectionDebugInfo() {
        let config = MPCWebSocketConfiguration.shared
        print("[MPC DEBUG] duoNodeUrl: \(config.duoNodeUrl)")
        print("[MPC DEBUG] duoNodePort: \(config.duoNodePort)")
        print("[MPC DEBUG] useSecureConnection: \(config.useSecureConnection)")
        print("[MPC DEBUG] authToken exists: \(config.authToken != nil)")
    }
    #endif
}

// MARK: - Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    // init?(hex:) is already defined in SendTokenSheet.swift
    // Removed duplicate definition to avoid redeclaration error
}

// Note: You'll need to add a SHA3/Keccak256 implementation
// Consider using CryptoSwift or similar library
extension Data {
    func sha3(_ variant: SHA3Variant) -> Data {
        // Placeholder - implement with actual SHA3 library
        return self
    }
    
    enum SHA3Variant {
        case keccak256
    }
}
