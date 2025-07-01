import Foundation
import Combine
import SwiftUI

// MARK: - MPCWalletService with HTTP Communication
// This replaces the WebSocket-based implementation

@MainActor
final class MPCWalletServiceHTTP: ObservableObject {
    static let shared = MPCWalletServiceHTTP()
    
    // Published properties
    @Published var isInitialized = false
    @Published var isGeneratingWallet = false
    @Published var isSigning = false
    @Published var currentOperation: MPCOperation?
    @Published var error: MPCError?
    
    // Dependencies
    private let keyShareManager: MPCKeyShareManagerHTTP
    private let secureStorage: MPCSecureStorage
    private let biometricAuth: BiometricAuthManager
    private let sessionManager: MPCHTTPSessionManager
    
    // Session tracking
    private var currentSessionId: String?
    private var sessionStartTime: Date?
    
    // Polling configuration
    private let pollingInterval: TimeInterval = 1.0
    private let maxPollingDuration: TimeInterval = 120.0
    
    private init() {
        self.keyShareManager = MPCKeyShareManagerHTTP()
        self.secureStorage = MPCSecureStorage()
        self.biometricAuth = BiometricAuthManager.shared
        self.sessionManager = MPCHTTPSessionManager.shared
        
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Generate a new MPC wallet for a profile using HTTP endpoints
    func generateWallet(for profileId: String) async throws -> WalletInfo {
        print("🔵 MPCWalletServiceHTTP.generateWallet called for profile: \(profileId)")
        
        guard !isGeneratingWallet else {
            throw MPCError.operationInProgress
        }
        
        isGeneratingWallet = true
        currentOperation = .keyGeneration
        error = nil
        sessionStartTime = Date()
        
        defer {
            isGeneratingWallet = false
            currentOperation = nil
            currentSessionId = nil
            sessionStartTime = nil
        }
        
        do {
            // Step 1: Biometric authentication
            print("🔵 Step 1: Requesting biometric authentication...")
            try await biometricAuth.authenticate(reason: "Generate MPC Wallet")
            
            // Step 2: Get cloud public key from backend
            print("🔵 Step 2: Getting cloud public key from backend...")
            let cloudKeyResponse = try await ProfileAPI.shared.getCloudPublicKey(profileId: profileId)
            let cloudPublicKey = cloudKeyResponse.data.cloudPublicKey
            print("🔵 Received cloud public key: \(cloudPublicKey.prefix(20))...")
            
            // Step 3: Generate MPC wallet directly with sigpair
            print("🔵 Step 3: Starting MPC key generation with sigpair...")
            // The SDK will handle the entire MPC protocol directly with sigpair
            let keyShare = try await keyShareManager.generateMPCWallet(
                algorithm: .eddsa,
                cloudPublicKey: cloudPublicKey,
                profileId: profileId
            )
            print("🔵 MPC key generation completed successfully")
            print("🔵 Wallet address: \(keyShare.address)")
            print("🔵 Key ID: \(keyShare.keyId)")
            
            // Step 4: Notify backend about the generated key
            print("🔵 Step 4: Notifying backend about generated wallet...")
            try await ProfileAPI.shared.notifyKeyGenerated(
                profileId: profileId,
                keyId: keyShare.keyId,
                publicKey: keyShare.publicKey,
                address: keyShare.address
            )
            
            // Step 5: Store securely
            try await secureStorage.storeKeyShare(keyShare, for: profileId)
            
            return WalletInfo(
                address: keyShare.address,
                publicKey: keyShare.publicKey,
                algorithm: keyShare.algorithm
            )
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Sign a transaction using MPC via HTTP
    func signTransaction(
        profileId: String,
        transaction: TransactionRequest
    ) async throws -> String {
        guard !isSigning else {
            throw MPCError.operationInProgress
        }
        
        isSigning = true
        currentOperation = .signing
        error = nil
        sessionStartTime = Date()
        
        defer {
            isSigning = false
            currentOperation = nil
            currentSessionId = nil
            sessionStartTime = nil
        }
        
        do {
            // Step 1: Retrieve key share
            guard let keyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 2: Biometric authentication
            try await biometricAuth.authenticate(reason: "Sign Transaction")
            
            // Step 3: Generate initial P1 signing messages
            let p1Messages = try await keyShareManager.generateSigningP1Messages(
                keyShare: keyShare,
                message: transaction.hash
            )
            
            // Step 4: Start signing session
            let signResponse = try await ProfileAPI.shared.startSigning(
                profileId: profileId,
                message: transaction.hash.hexString,
                p1Messages: p1Messages
            )
            
            currentSessionId = signResponse.data.sessionId
            
            // Step 5: Exchange P1/P2 messages until signature is complete
            let signature = try await performSigningExchange(
                sessionId: signResponse.data.sessionId,
                keyShare: keyShare
            )
            
            return signature
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Poll session status until completion
    private func pollSessionStatus(
        sessionId: String,
        startTime: Date = Date()
    ) async throws -> SessionStatus {
        // Check if we've exceeded max polling duration
        if Date().timeIntervalSince(startTime) > maxPollingDuration {
            throw MPCError.requestTimeout
        }
        
        let status = try await ProfileAPI.shared.getSessionStatus(sessionId: sessionId)
        
        switch status.data.status {
        case "completed":
            return status.data
            
        case "failed":
            throw MPCError.keyGenerationFailed(status.data.error ?? "Unknown error")
            
        case "pending", "in_progress":
            // Wait and poll again
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            return try await pollSessionStatus(sessionId: sessionId, startTime: startTime)
            
        default:
            throw MPCError.invalidData
        }
    }
    
    /// Create a verifiable backup via HTTP
    func createBackup(
        profileId: String,
        rsaPublicKey: String,
        label: String
    ) async throws -> BackupData {
        currentOperation = .backup
        error = nil
        
        defer {
            currentOperation = nil
        }
        
        do {
            // Verify key share exists
            guard try await secureStorage.hasKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Biometric authentication
            try await biometricAuth.authenticate(reason: "Create Wallet Backup")
            
            // Call backend API
            let response = try await ProfileAPI.shared.createMPCBackup(
                profileId: profileId,
                rsaPubkeyPem: rsaPublicKey,
                label: label,
                twoFactorCode: nil // Would need real 2FA in production
            )
            
            return BackupData(
                keyId: response.data.keyId,
                algorithm: response.data.algorithm,
                verifiableBackup: response.data.verifiableBackup,
                timestamp: ISO8601DateFormatter().date(from: response.data.timestamp) ?? Date()
            )
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Export the full private key via HTTP
    func exportKey(
        profileId: String,
        clientEncryptionKey: Data
    ) async throws -> ExportData {
        currentOperation = .export
        error = nil
        
        defer {
            currentOperation = nil
        }
        
        do {
            // Retrieve key share
            guard let keyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Enhanced biometric authentication
            try await biometricAuth.authenticate(reason: "⚠️ Export Private Key - This is irreversible")
            
            // Additional confirmation
            let confirmed = await showExportWarning()
            guard confirmed else {
                throw MPCError.operationCancelled("User cancelled the operation")
            }
            
            // Call backend API
            let response = try await ProfileAPI.shared.exportMPCKey(
                profileId: profileId,
                clientEncKey: clientEncryptionKey.base64EncodedString(),
                twoFactorCode: nil // Would need real 2FA in production
            )
            
            // Combine shares locally
            // TODO: Implement combineShares in MPCKeyShareManagerHTTP
            let privateKey = "mock-private-key" // Placeholder for now
            
            return ExportData(
                privateKey: privateKey,
                publicKey: keyShare.publicKey,
                address: keyShare.address,
                warning: "⚠️ Keep this private key secure. Anyone with access can control your wallet."
            )
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Check if a profile has an MPC wallet
    func hasWallet(for profileId: String) async -> Bool {
        return await secureStorage.hasKeyShare(for: profileId)
    }
    
    /// Get wallet info if exists
    func getWalletInfo(for profileId: String) async -> WalletInfo? {
        guard let keyShare = try? await secureStorage.retrieveKeyShare(for: profileId) else {
            return nil
        }
        
        return WalletInfo(
            address: keyShare.address,
            publicKey: keyShare.publicKey,
            algorithm: keyShare.algorithm
        )
    }
    
    /// Rotate MPC keys (key refresh)
    func rotateKey(for profileId: String) async throws {
        guard !isGeneratingWallet else {
            throw MPCError.operationInProgress
        }
        
        isGeneratingWallet = true
        currentOperation = .keyRotation
        error = nil
        
        defer {
            isGeneratingWallet = false
            currentOperation = nil
        }
        
        do {
            // Step 1: Biometric authentication
            try await biometricAuth.authenticate(reason: "Rotate MPC Keys")
            
            // Step 2: Retrieve current key share
            guard let currentKeyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 3: Initiate key refresh with backend
            // This would call a key refresh endpoint
            // For now, throw not implemented
            throw MPCError.keyRotationFailed("Key rotation not yet implemented for HTTP mode")
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    private func showExportWarning() async -> Bool {
        // This would show a UI confirmation dialog
        // For now, return true
        return true
    }
    
    // MARK: - P1/P2 Message Exchange
    
    private func performKeyGenerationExchange(
        sessionId: String,
        profileId: String
    ) async throws -> MPCKeyShare {
        // In HTTP mode, the backend proxies our P1 messages to duo-node
        // and returns P2 messages. We need to handle the exchange here.
        
        // For now, this is simplified since the backend handles most of the
        // exchange. In the future, we may need to implement multiple rounds
        // of P1/P2 message exchange through the backend proxy.
        
        // The actual implementation would:
        // 1. Send P1 messages via /api/v2/mpc/message/forward
        // 2. Poll session status to get P2 messages
        // 3. Process P2 messages and generate next P1 messages
        // 4. Repeat until key generation is complete
        
        throw MPCError.keyGenerationFailed("P1/P2 exchange not yet implemented for HTTP mode")
    }
    
    private func performSigningExchange(
        sessionId: String,
        keyShare: MPCKeyShare
    ) async throws -> String {
        
        var round = 1
        let maxRounds = 5 // Signing typically has 5 rounds
        let startTime = Date()
        
        while round <= maxRounds {
            // Check timeout
            if Date().timeIntervalSince(startTime) > 120 {
                throw MPCError.requestTimeout
            }
            
            // Poll for session status
            let session = try await sessionManager.pollSessionStatus(sessionId)
            
            switch session.status {
            case .completed:
                // Extract signature from result
                guard let result = session.result,
                      let signature = result.signature else {
                    throw MPCError.signingFailed("Missing signature in result")
                }
                
                return signature
                
            case .failed:
                throw MPCError.signingFailed(session.error ?? "Unknown error")
                
            case .inProgress:
                // Get P2 messages and process them
                let p2Messages = try await getP2MessagesFromSession(sessionId)
                
                if !p2Messages.isEmpty {
                    // Process P2 messages and generate next P1 messages
                    let nextP1Messages = try await keyShareManager.processP2Messages(
                        sessionId: sessionId,
                        p2Messages: p2Messages,
                        sessionType: .signing
                    )
                    
                    // Send next P1 messages if any
                    if !nextP1Messages.isEmpty {
                        for message in nextP1Messages {
                            _ = try await sessionManager.sendP1Message(
                                sessionId: sessionId,
                                messageType: .sign,
                                message: message
                            )
                        }
                    }
                    
                    round += 1
                }
                
                // Wait before next poll
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
            case .pending:
                // Wait for session to start
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        throw MPCError.signingFailed("Exceeded maximum rounds")
    }
    
    private func getP2MessagesFromSession(_ sessionId: String) async throws -> [[String: Any]] {
        // This would fetch P2 messages from the session
        // For now, return empty array - real implementation would query backend
        return []
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionCompleted),
            name: .mpcSessionCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionFailed),
            name: .mpcSessionFailed,
            object: nil
        )
    }
    
    @objc private func handleSessionCompleted(_ notification: Notification) {
        guard let session = notification.userInfo?["session"] as? MPCSession,
              session.id == currentSessionId else { return }
        
        print("MPC session completed: \(session.id)")
    }
    
    @objc private func handleSessionFailed(_ notification: Notification) {
        guard let session = notification.userInfo?["session"] as? MPCSession,
              session.id == currentSessionId else { return }
        
        let errorMessage = notification.userInfo?["error"] as? String ?? "Unknown error"
        print("MPC session failed: \(errorMessage)")
        
        self.error = MPCError.keyGenerationFailed(errorMessage)
    }
}

// MARK: - Extensions

// Data.hexString is already defined in MPCKeyShareManager.swift

// MARK: - Feature Flag

extension MPCWalletServiceHTTP {
    static var isEnabled: Bool {
        return true
    }
}
