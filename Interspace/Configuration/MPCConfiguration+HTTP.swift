import Foundation

// MARK: - MPC Configuration for HTTP
// Updates MPC configuration to use HTTP endpoints instead of WebSocket

extension MPCConfiguration {
    
    /// Backend base URL for MPC operations
    var backendBaseURL: String {
        switch environment {
        case .development:
            return "http://localhost:3000"
        case .staging:
            return "https://interspace-backend-staging.run.app"
        case .production:
            return "https://api.interspace.chat"
        }
    }
    
    /// Use HTTP instead of WebSocket
    var useHTTP: Bool {
        // Feature flag to enable HTTP mode
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "mpcUseHTTP") ?? true
        #else
        return true // Always use HTTP in production
        #endif
    }
    
    /// HTTP request timeout
    var httpTimeout: TimeInterval {
        return 30.0 // 30 seconds
    }
    
    /// Polling interval for session status
    var pollingInterval: TimeInterval {
        return 1.0 // 1 second
    }
    
    /// Maximum polling duration
    var maxPollingDuration: TimeInterval {
        return 120.0 // 2 minutes
    }
}

// MARK: - Update ProfileAPI Configuration

extension ProfileAPI {
    
    /// Configure API for MPC operations
    func configureMPCEndpoints() {
        // Configuration is handled through EnvironmentConfiguration
        // MPC-specific headers can be added to individual requests if needed
    }
}

// MARK: - MPC Service Factory

@MainActor
final class MPCServiceFactory {
    
    static func createWalletService() -> any MPCWalletServiceProtocol {
        let config = MPCConfiguration.shared
        
        if config.useHTTP {
            // Use HTTP-based service
            return MPCWalletServiceHTTP.shared
        } else {
            // Use WebSocket-based service (legacy)
            return MPCWalletService.shared
        }
    }
}

// MARK: - Protocol for common interface

protocol MPCWalletServiceProtocol: ObservableObject {
    var isInitialized: Bool { get }
    var isGeneratingWallet: Bool { get }
    var isSigning: Bool { get }
    var currentOperation: MPCOperation? { get }
    var error: MPCError? { get }
    
    func generateWallet(for profileId: String) async throws -> WalletInfo
    func signTransaction(profileId: String, transaction: TransactionRequest) async throws -> String
    func hasWallet(for profileId: String) async -> Bool
    func getWalletInfo(for profileId: String) async -> WalletInfo?
    func createBackup(profileId: String, rsaPublicKey: String, label: String) async throws -> BackupData
    func exportKey(profileId: String, clientEncryptionKey: Data) async throws -> ExportData
    func rotateKey(for profileId: String) async throws
}

// Make both services conform to the protocol
extension MPCWalletService: MPCWalletServiceProtocol {}
extension MPCWalletServiceHTTP: MPCWalletServiceProtocol {}