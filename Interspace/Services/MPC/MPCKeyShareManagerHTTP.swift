import Foundation
import CryptoKit
import silentshardduo

// MARK: - MPC Key Share Manager for HTTP
// Manages key shares and SDK interactions without WebSocket

final class MPCKeyShareManagerHTTP {
    
    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.interspace.mpc.keyshare.http", qos: .userInitiated)
    private var sessionManager = MPCHTTPSessionManager.shared
    
    // SDK state management
    private var activeKeySessions = [String: Any]() // Store SDK objects
    private var activeSignSessions = [String: Any]() // Store SDK objects
    
    // MARK: - Key Generation
    
    /// Generate MPC wallet by handling the entire protocol with sigpair
    func generateMPCWallet(algorithm: MPCAlgorithm, cloudPublicKey: String, profileId: String) async throws -> MPCKeyShare {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    let sessionId = UUID().uuidString
                    
                    // Create a DuoSession for key generation
                    // Connect directly to sigpair (Silence Labs Duo Server)
                    // For local development, sigpair runs on port 8080
                    // Use the host machine's IP address (not localhost) for iOS simulator/device
                    let websocketHost = "192.168.2.77" // Your Mac's IP address
                    
                    // Build WebsocketConfig without authentication for local dev
                    let websocketConfig = WebsocketConfigBuilder()
                        .withBaseUrl(websocketHost)
                        .withPort("8080")  // sigpair port (direct connection)
                        .withSecure(false)
                        .build()
                    
                    let duoSession: DuoSession
                    switch algorithm {
                    case .ecdsa:
                        duoSession = SilentShardDuo.ECDSA.createDuoSession(
                            cloudVerifyingKey: cloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    case .eddsa:
                        duoSession = SilentShardDuo.EdDSA.createDuoSession(
                            cloudVerifyingKey: cloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    }
                    
                    // Perform key generation - SDK handles the entire MPC protocol
                    Task {
                        let keygenResult = await duoSession.keygen()
                        
                        switch keygenResult {
                        case .success(let keyShareData):
                            // Extract public key from the keyShare data using SDK method
                            let publicKeyResult: Result<String, Error>
                            switch algorithm {
                            case .ecdsa:
                                publicKeyResult = await SilentShardDuo.ECDSA.getKeysharePublicKeyAsHex(keyShareData)
                            case .eddsa:
                                publicKeyResult = await SilentShardDuo.EdDSA.getKeysharePublicKeyAsHex(keyShareData)
                            }
                            
                            switch publicKeyResult {
                            case .success(let publicKeyHex):
                                let keyId = UUID().uuidString
                                let address = self?.generateEthereumAddress(from: publicKeyHex) ?? ""
                                
                                // Create key share wrapper
                                let mpcKeyShare = MPCKeyShare(
                                    shareData: keyShareData,
                                    publicKey: publicKeyHex,
                                    address: address,
                                    algorithm: algorithm,
                                    createdAt: Date(),
                                    keyId: keyId
                                )
                                
                                // Store the duo session for future signing
                                self?.activeKeySessions[keyId] = duoSession
                                
                                continuation.resume(returning: mpcKeyShare)
                                
                            case .failure(let error):
                                continuation.resume(throwing: MPCError.keyGenerationFailed("Failed to extract public key: \(error.localizedDescription)"))
                            }
                            
                        case .failure(let error):
                            continuation.resume(throwing: MPCError.keyGenerationFailed(error.localizedDescription))
                        }
                    }
                } catch {
                    continuation.resume(throwing: MPCError.sdkInitializationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Generate initial P1 messages for key generation (deprecated - for backward compatibility)
    func generateInitialP1Messages(algorithm: MPCAlgorithm, cloudPublicKey: String) async throws -> [[String: Any]] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    // For HTTP mode with backend proxy, we don't need to establish WebSocket
                    // The backend will handle the duo-node connection
                    // We just need to prepare for key generation
                    
                    let sessionId = UUID().uuidString
                    
                    // Create a DuoSession for key generation
                    // Connect directly to sigpair (Silence Labs Duo Server)
                    // For local development, sigpair runs on port 8080
                    // Use the host machine's IP address (not localhost) for iOS simulator/device
                    let websocketHost = "192.168.2.77" // Your Mac's IP address
                    
                    // Build WebsocketConfig without authentication for local dev
                    let websocketConfig = WebsocketConfigBuilder()
                        .withBaseUrl(websocketHost)
                        .withPort("8080")  // sigpair port (direct connection)
                        .withSecure(false)
                        .build()
                    
                    let duoSession: DuoSession
                    switch algorithm {
                    case .ecdsa:
                        duoSession = SilentShardDuo.ECDSA.createDuoSession(
                            cloudVerifyingKey: cloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    case .eddsa:
                        duoSession = SilentShardDuo.EdDSA.createDuoSession(
                            cloudVerifyingKey: cloudPublicKey,
                            websocketConfig: websocketConfig
                        )
                    }
                    
                    // Store the session
                    self?.activeKeySessions[sessionId] = duoSession
                    
                    // Generate initial P1 messages using the SDK
                    // Even in HTTP mode, the client must generate P1 messages
                    // The backend acts as a proxy to forward them to duo-node
                    
                    // Start key generation to get initial P1 messages
                    Task {
                        let keygenResult = await duoSession.keygen()
                        
                        switch keygenResult {
                        case .success(let keyData):
                            // Extract P1 messages from the key generation process
                            // For now, we'll create a proper P1 message structure
                            let p1Message: [String: Any] = [
                                "type": "keyGen",
                                "round": 1,
                                "sessionId": sessionId,
                                "data": keyData.base64EncodedString()
                            ]
                            
                            let p1Messages = [p1Message]
                            continuation.resume(returning: p1Messages)
                            
                        case .failure(let error):
                            continuation.resume(throwing: MPCError.keyGenerationFailed(error.localizedDescription))
                        }
                    }
                } catch {
                    continuation.resume(throwing: MPCError.sdkInitializationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Process P2 messages and generate next P1 messages
    func processP2Messages(
        sessionId: String,
        p2Messages: [[String: Any]],
        sessionType: MPCSessionType
    ) async throws -> [[String: Any]] {
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    var nextP1Messages: [[String: Any]] = []
                    
                    switch sessionType {
                    case .keyGeneration:
                        nextP1Messages = try self?.processKeyGenP2Messages(
                            sessionId: sessionId,
                            p2Messages: p2Messages
                        ) ?? []
                        
                    case .signing:
                        nextP1Messages = try self?.processSigningP2Messages(
                            sessionId: sessionId,
                            p2Messages: p2Messages
                        ) ?? []
                        
                    case .keyRotation:
                        throw MPCError.keyRotationFailed("Key rotation not implemented")
                    }
                    
                    continuation.resume(returning: nextP1Messages)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Complete key generation with data from backend session
    func completeKeyGeneration(
        sessionId: String,
        publicKey: String,
        address: String,
        keyId: String
    ) async throws -> MPCKeyShare {
        
        // Extract key data from the session result
        let keyData = try await extractKeyDataFromSession(
            sessionId: sessionId,
            publicKey: publicKey,
            address: address,
            keyId: keyId,
            algorithm: .ecdsa
        )
        
        // Create key share with keyId
        let keyShare = MPCKeyShare(
            shareData: keyData.p1Share,
            publicKey: keyData.publicKey,
            address: keyData.address,
            algorithm: keyData.algorithm,
            createdAt: Date(),
            keyId: keyData.keyId
        )
        
        // Clean up session
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.activeKeySessions.removeValue(forKey: sessionId)
                continuation.resume()
            }
        }
        
        return keyShare
    }
    
    // MARK: - Signing
    
    /// Generate initial P1 messages for signing
    func generateSigningP1Messages(
        keyShare: MPCKeyShare,
        message: Data
    ) async throws -> [[String: Any]] {
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    let sessionId = UUID().uuidString
                    let messageHash = self?.hashMessage(message) ?? Data()
                    
                    let p1Messages: [[String: Any]] = [
                        [
                            "type": "sign",
                            "round": 1,
                            "sessionId": sessionId,
                            "keyId": keyShare.keyId,
                            "messageHash": messageHash.base64EncodedString(),
                            "data": self?.generateP1SignData(
                                keyShare: keyShare,
                                messageHash: messageHash
                            ) ?? [:]
                        ]
                    ]
                    
                    continuation.resume(returning: p1Messages)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Complete signing and extract signature
    func completeSigning(
        sessionId: String,
        finalP2Messages: [[String: Any]]
    ) async throws -> String {
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                do {
                    // Extract signature from final messages
                    guard let signature = self?.extractSignatureFromP2(finalP2Messages) else {
                        throw MPCError.signingFailed("Failed to extract signature")
                    }
                    
                    // Clean up session
                    self?.activeSignSessions.removeValue(forKey: sessionId)
                    
                    continuation.resume(returning: signature)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateP1KeyGenData(algorithm: MPCAlgorithm) -> [String: Any] {
        // Generate initial P1 data for key generation
        // This would normally use Silence Labs SDK
        
        let randomBytes = generateRandomBytes(32)
        
        return [
            "commitment": randomBytes.base64EncodedString(),
            "publicShare": generatePublicShare(algorithm: algorithm),
            "proof": generateZKProof()
        ]
    }
    
    private func generateP1SignData(keyShare: MPCKeyShare, messageHash: Data) -> [String: Any] {
        // Generate P1 data for signing
        // This would normally use Silence Labs SDK
        
        return [
            "nonce": generateRandomBytes(32).base64EncodedString(),
            "commitment": generateSigningCommitment(messageHash: messageHash),
            "keyId": keyShare.keyId
        ]
    }
    
    private func processKeyGenP2Messages(sessionId: String, p2Messages: [[String: Any]]) throws -> [[String: Any]] {
        // Process P2 messages and generate next round P1 messages
        // This would normally use Silence Labs SDK to process P2 and generate P1
        
        guard let lastMessage = p2Messages.last,
              let round = lastMessage["round"] as? Int else {
            throw MPCError.serializationError("Invalid P2 message format")
        }
        
        // Key generation typically has 3 rounds
        if round >= 3 {
            return [] // No more P1 messages needed
        }
        
        return [
            [
                "type": "keyGen",
                "round": round + 1,
                "sessionId": sessionId,
                "data": generateNextRoundKeyGenData(round: round + 1, p2Messages: p2Messages)
            ]
        ]
    }
    
    private func processSigningP2Messages(sessionId: String, p2Messages: [[String: Any]]) throws -> [[String: Any]] {
        // Process P2 messages for signing
        // Signing typically has 5 rounds
        
        guard let lastMessage = p2Messages.last,
              let round = lastMessage["round"] as? Int else {
            throw MPCError.serializationError("Invalid P2 message format")
        }
        
        if round >= 5 {
            return [] // Signing complete
        }
        
        return [
            [
                "type": "sign",
                "round": round + 1,
                "sessionId": sessionId,
                "data": generateNextRoundSignData(round: round + 1, p2Messages: p2Messages)
            ]
        ]
    }
    
    private func generateNextRoundKeyGenData(round: Int, p2Messages: [[String: Any]]) -> [String: Any] {
        // Generate data for next round of key generation
        // This is a simplified version - real implementation would use SDK
        
        switch round {
        case 2:
            return [
                "decommitment": generateRandomBytes(32).base64EncodedString(),
                "secretShare": generateRandomBytes(32).base64EncodedString()
            ]
        case 3:
            return [
                "finalShare": generateRandomBytes(32).base64EncodedString(),
                "verification": generateRandomBytes(64).base64EncodedString()
            ]
        default:
            return [:]
        }
    }
    
    private func generateNextRoundSignData(round: Int, p2Messages: [[String: Any]]) -> [String: Any] {
        // Generate data for next round of signing
        // Simplified - real implementation would use SDK
        
        return [
            "roundData": generateRandomBytes(32).base64EncodedString(),
            "proof": generateRandomBytes(64).base64EncodedString()
        ]
    }
    
    func extractKeyDataFromSession(
        sessionId: String,
        publicKey: String,
        address: String,
        keyId: String,
        algorithm: MPCAlgorithm
    ) async throws -> (publicKey: String, address: String, algorithm: MPCAlgorithm, p1Share: Data, keyId: String) {
        
        // Get the DuoSession from active sessions
        guard let duoSession = activeKeySessions[sessionId] as? DuoSession else {
            throw MPCError.sessionNotFound
        }
        
        // Perform key generation to get the P1 share
        let keygenResult = await duoSession.keygen()
        
        switch keygenResult {
        case .success(let p1ShareData):
            return (
                publicKey: publicKey,
                address: address,
                algorithm: algorithm,
                p1Share: p1ShareData,
                keyId: keyId
            )
        case .failure(let error):
            throw MPCError.keyGenerationFailed(error.localizedDescription)
        }
    }
    
    private func extractSignatureFromP2(_ messages: [[String: Any]]) -> String? {
        // Extract signature from final P2 messages
        guard let finalMessage = messages.last,
              let signature = finalMessage["signature"] as? String else {
            return nil
        }
        return signature
    }
    
    private func hashMessage(_ message: Data) -> Data {
        // Use proper hashing for the message
        let hash = SHA256.hash(data: message)
        return Data(hash)
    }
    
    private func generateRandomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
    
    private func generatePublicShare(algorithm: MPCAlgorithm) -> String {
        // Generate public share based on algorithm
        // Simplified - real implementation would use proper cryptography
        switch algorithm {
        case .ecdsa:
            return generateRandomBytes(33).base64EncodedString() // Compressed public key
        case .eddsa:
            return generateRandomBytes(32).base64EncodedString()
        }
    }
    
    private func generateZKProof() -> String {
        // Generate zero-knowledge proof
        // Simplified - real implementation would use proper ZK proof
        return generateRandomBytes(64).base64EncodedString()
    }
    
    private func generateSigningCommitment(messageHash: Data) -> String {
        // Generate commitment for signing
        let commitment = SHA256.hash(data: messageHash + generateRandomBytes(32))
        return Data(commitment).base64EncodedString()
    }
    
    private func generateEthereumAddress(from publicKey: String) -> String {
        // Remove any prefix if present
        var cleanPublicKey = publicKey
        if cleanPublicKey.hasPrefix("0x") {
            cleanPublicKey = String(cleanPublicKey.dropFirst(2))
        }
        
        // Convert hex string to data
        guard let publicKeyData = Data(hexString: cleanPublicKey) else {
            return ""
        }
        
        // For Ethereum, we need to hash the public key and take the last 20 bytes
        let hash = SHA256.hash(data: publicKeyData)
        let hashData = Data(hash)
        
        // Take last 20 bytes (40 hex characters)
        let addressBytes = hashData.suffix(20)
        let address = "0x" + addressBytes.hexEncodedString()
        
        return address.lowercased()
    }
}

// MARK: - Data Extension for Hex
extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if nextIndex > hex.endIndex { return nil }
            
            let bytes = hex[index..<nextIndex]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            
            index = nextIndex
        }
        
        self = data
    }
    
    func hexEncodedString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Extensions

extension MPCKeyShare {
    /// Placeholder for Silence Labs key share data
    var silenceLabsKeyShare: Any {
        get { return self }
        set { }
    }
}