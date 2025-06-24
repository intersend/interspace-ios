import Foundation
import Combine
import SwiftUI

// MARK: - MPCWalletService

@MainActor
final class MPCWalletService: ObservableObject {
    static let shared = MPCWalletService()
    
    // Published properties
    @Published var isInitialized = false
    @Published var isGeneratingWallet = false
    @Published var isSigning = false
    @Published var currentOperation: MPCOperation?
    @Published var error: MPCError?
    
    // Dependencies
    private let keyShareManager: MPCKeyShareManager
    private let secureStorage: MPCSecureStorage
    private let sessionManager: MPCSessionManager
    private let biometricAuth: BiometricAuthManager
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.keyShareManager = MPCKeyShareManager()
        self.secureStorage = MPCSecureStorage()
        self.sessionManager = MPCSessionManager()
        self.biometricAuth = BiometricAuthManager.shared
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor session state
        sessionManager.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.error = .websocketConnectionFailed
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Generate a new MPC wallet for a profile
    func generateWallet(for profileId: String) async throws -> WalletInfo {
        guard !isGeneratingWallet else {
            throw MPCError.operationInProgress
        }
        
        isGeneratingWallet = true
        currentOperation = .keyGeneration
        error = nil
        
        defer {
            isGeneratingWallet = false
            currentOperation = nil
        }
        
        do {
            // Step 1: Biometric authentication
            try await biometricAuth.authenticate(reason: "Generate MPC Wallet")
            
            // Step 2: Get cloud public key from backend
            let cloudPublicKey = try await fetchCloudPublicKey()
            
            // Step 3: Initialize session
            try await sessionManager.connect()
            try await keyShareManager.initializeSession(
                algorithm: .ecdsa,
                cloudPublicKey: cloudPublicKey
            )
            
            // Step 4: Generate key share
            let keyShare = try await keyShareManager.generateKeyShare()
            
            // Step 5: Store securely
            try await secureStorage.storeKeyShare(keyShare, for: profileId)
            
            // Step 6: Notify backend
            try await notifyBackendOfKeyGeneration(
                profileId: profileId,
                publicKey: keyShare.publicKey,
                address: keyShare.address
            )
            
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
    
    /// Sign a transaction using MPC
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
        
        defer {
            isSigning = false
            currentOperation = nil
        }
        
        do {
            // Step 1: Retrieve key share
            guard let keyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 2: Biometric authentication
            try await biometricAuth.authenticate(reason: "Sign Transaction")
            
            // Step 3: Ensure session is connected
            if !sessionManager.isConnected {
                try await sessionManager.connect()
            }
            
            // Step 4: Sign transaction
            let signature = try await keyShareManager.signMessage(
                keyShare: keyShare,
                message: transaction.hash,
                chainPath: transaction.chainPath
            )
            
            return signature
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Rotate key shares (refresh)
    func rotateKey(for profileId: String) async throws {
        currentOperation = .keyRotation
        error = nil
        
        defer {
            currentOperation = nil
        }
        
        do {
            // Step 1: Retrieve current key share
            guard let currentKeyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 2: Biometric authentication
            try await biometricAuth.authenticate(reason: "Rotate MPC Key")
            
            // Step 3: Connect and refresh
            try await sessionManager.connect()
            let newKeyShare = try await keyShareManager.refreshKeyShare(currentKeyShare)
            
            // Step 4: Store new share
            try await secureStorage.storeKeyShare(newKeyShare, for: profileId)
            
            // Step 5: Notify backend
            try await notifyBackendOfKeyRotation(profileId: profileId)
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Create a verifiable backup
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
            // Step 1: Retrieve key share
            guard let keyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 2: Biometric authentication
            try await biometricAuth.authenticate(reason: "Create Wallet Backup")
            
            // Step 3: Call backend API
            let backup = try await createBackupViaBackend(
                profileId: profileId,
                rsaPublicKey: rsaPublicKey,
                label: label
            )
            
            return backup
            
        } catch {
            self.error = error as? MPCError ?? .unknown(error)
            throw error
        }
    }
    
    /// Export the full private key (critical operation)
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
            // Step 1: Retrieve key share
            guard let keyShare = try await secureStorage.retrieveKeyShare(for: profileId) else {
                throw MPCError.keyShareNotFound
            }
            
            // Step 2: Enhanced biometric authentication
            try await biometricAuth.authenticate(reason: "⚠️ Export Private Key - This is irreversible")
            
            // Step 3: Additional confirmation
            let confirmed = await showExportWarning()
            guard confirmed else {
                throw MPCError.userCancelled
            }
            
            // Step 4: Call backend API
            let exportData = try await exportKeyViaBackend(
                profileId: profileId,
                clientEncryptionKey: clientEncryptionKey
            )
            
            // Step 5: Combine shares locally
            let privateKey = try await keyShareManager.combineShares(
                clientShare: keyShare,
                encryptedServerShare: exportData.encryptedServerShare,
                serverPublicKey: exportData.serverPublicKey,
                clientEncryptionKey: clientEncryptionKey
            )
            
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
    
    // MARK: - Private Methods
    
    private func fetchCloudPublicKey() async throws -> String {
        // Call backend API to get cloud public key
        // This would be implemented based on your API structure
        return try await ProfileAPI.shared.getCloudPublicKey()
    }
    
    private func notifyBackendOfKeyGeneration(
        profileId: String,
        publicKey: String,
        address: String
    ) async throws {
        // Notify backend that key generation is complete
        try await ProfileAPI.shared.confirmKeyGeneration(
            profileId: profileId,
            publicKey: publicKey,
            address: address
        )
    }
    
    private func notifyBackendOfKeyRotation(profileId: String) async throws {
        // Notify backend that key rotation is complete
        try await ProfileAPI.shared.confirmKeyRotation(profileId: profileId)
    }
    
    private func createBackupViaBackend(
        profileId: String,
        rsaPublicKey: String,
        label: String
    ) async throws -> BackupData {
        // Call backend MPC backup endpoint
        return try await ProfileAPI.shared.createMPCBackup(
            profileId: profileId,
            rsaPublicKey: rsaPublicKey,
            label: label
        )
    }
    
    private func exportKeyViaBackend(
        profileId: String,
        clientEncryptionKey: Data
    ) async throws -> ServerExportData {
        // Call backend MPC export endpoint
        return try await ProfileAPI.shared.exportMPCKey(
            profileId: profileId,
            clientEncryptionKey: clientEncryptionKey.base64EncodedString()
        )
    }
    
    private func showExportWarning() async -> Bool {
        // This would show a UI confirmation dialog
        // For now, return true
        return true
    }
}

// MARK: - Supporting Types

enum MPCOperation {
    case keyGeneration
    case signing
    case keyRotation
    case backup
    case export
    
    var description: String {
        switch self {
        case .keyGeneration:
            return "Generating wallet..."
        case .signing:
            return "Signing transaction..."
        case .keyRotation:
            return "Rotating keys..."
        case .backup:
            return "Creating backup..."
        case .export:
            return "Exporting key..."
        }
    }
}

struct WalletInfo {
    let address: String
    let publicKey: String
    let algorithm: MPCAlgorithm
}

struct TransactionRequest {
    let hash: Data
    let chainPath: String?
    let value: String
    let to: String
    let data: String?
}

struct BackupData: Codable {
    let keyId: String
    let algorithm: String
    let verifiableBackup: String
    let timestamp: Date
}

struct ExportData {
    let privateKey: String
    let publicKey: String
    let address: String
    let warning: String
}

struct ServerExportData: Codable {
    let encryptedServerShare: String
    let serverPublicKey: [UInt8]
}

// MARK: - Feature Flag

extension MPCWalletService {
    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "mpcWalletEnabled")
        #else
        return true // Enable in production
        #endif
    }
}