import Foundation
import Combine

// MARK: - Core Wallet Protocol

/// Base protocol that all wallet implementations must conform to
/// Provides a standardized interface for wallet operations
protocol WalletProtocol: AnyObject {
    /// Unique identifier for the wallet type
    var walletType: WalletType { get }
    
    /// Current connection state
    var connectionState: CurrentValueSubject<WalletConnectionState, Never> { get }
    
    /// Current session if connected
    var currentSession: WalletSession? { get }
    
    /// Whether this wallet supports a specific chain
    func supportsChain(_ chainId: Int) -> Bool
    
    /// Connect to the wallet
    /// - Parameters:
    ///   - context: Connection context with app metadata
    ///   - completion: Callback with connection result
    func connect(
        context: WalletConnectionContext,
        completion: @escaping (Result<WalletSession, WalletError>) -> Void
    )
    
    /// Disconnect from the wallet
    func disconnect() async throws
    
    /// Sign a message (for SIWE authentication)
    /// - Parameters:
    ///   - message: The message to sign
    ///   - session: Active wallet session
    ///   - completion: Callback with signature result
    func signMessage(
        _ message: String,
        session: WalletSession,
        completion: @escaping (Result<WalletSignature, WalletError>) -> Void
    )
    
    /// Sign a transaction
    /// - Parameters:
    ///   - transaction: Transaction to sign
    ///   - session: Active wallet session
    ///   - completion: Callback with signed transaction
    func signTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    )
    
    /// Send a transaction
    /// - Parameters:
    ///   - transaction: Transaction to send
    ///   - session: Active wallet session
    ///   - completion: Callback with transaction hash
    func sendTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    )
    
    /// Handle incoming deep link
    /// - Parameter url: The deep link URL
    /// - Returns: Whether the URL was handled
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool
}

// MARK: - Supporting Types

/// Wallet connection state
enum WalletConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(WalletSession)
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Wallet session information
struct WalletSession: Codable, Equatable {
    let walletType: WalletType
    let address: String
    let chainId: Int
    let sessionToken: String?
    let walletMetadata: WalletMetadata?
    let connectedAt: Date
    
    /// Additional wallet-specific data
    let additionalData: [String: String]?
}

/// Wallet metadata
struct WalletMetadata: Codable, Equatable {
    let name: String?
    let icon: String?
    let version: String?
}

/// Connection context with app information
struct WalletConnectionContext {
    let appName: String
    let appUrl: String
    let appIcon: String?
    let chainId: Int
    let redirectDeepLink: String
    
    static var `default`: WalletConnectionContext {
        WalletConnectionContext(
            appName: "Interspace",
            appUrl: "https://interspace.fi",
            appIcon: nil,
            chainId: 1, // Ethereum mainnet
            redirectDeepLink: "interspace://wallet-callback"
        )
    }
}

/// Wallet signature result
struct WalletSignature {
    let signature: String
    let address: String
    let message: String
    
    /// Normalized signature for backend compatibility
    var normalizedSignature: String {
        var sig = signature
        if sig.hasPrefix("0x") {
            sig = String(sig.dropFirst(2))
        }
        return "0x" + sig.lowercased()
    }
}

/// Wallet transaction
struct WalletTransaction {
    let from: String
    let to: String
    let value: String?
    let data: String?
    let gasLimit: String?
    let gasPrice: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
    let nonce: String?
    let chainId: Int
    
    /// Create a WalletTransaction from web3 params
    static func from(web3Params params: [String: Any]) -> WalletTransaction? {
        guard let from = params["from"] as? String,
              let to = params["to"] as? String else {
            return nil
        }
        
        return WalletTransaction(
            from: from,
            to: to,
            value: params["value"] as? String,
            data: params["data"] as? String,
            gasLimit: params["gas"] as? String ?? params["gasLimit"] as? String,
            gasPrice: params["gasPrice"] as? String,
            maxFeePerGas: params["maxFeePerGas"] as? String,
            maxPriorityFeePerGas: params["maxPriorityFeePerGas"] as? String,
            nonce: params["nonce"] as? String,
            chainId: (params["chainId"] as? Int) ?? 1
        )
    }
}

// MARK: - Wallet Factory Protocol

/// Factory for creating wallet instances
protocol WalletFactoryProtocol {
    /// Create a wallet instance for the given type
    func createWallet(for type: WalletType) -> WalletProtocol?
    
    /// Check if a wallet type is supported
    func isSupported(_ type: WalletType) -> Bool
    
    /// Get all supported wallet types
    var supportedWallets: [WalletType] { get }
}

// MARK: - Deep Link Handler Protocol

/// Protocol for handling wallet deep links
protocol WalletDeepLinkHandler: AnyObject {
    /// The URL schemes this handler can process
    var supportedSchemes: [String] { get }
    
    /// Handle an incoming URL
    /// - Returns: Whether the URL was handled
    func canHandle(_ url: URL) -> Bool
    
    /// Process the deep link
    func handle(_ url: URL)
}

// MARK: - Session Storage Protocol

/// Protocol for persisting wallet sessions
protocol WalletSessionStorageProtocol {
    /// Save a wallet session
    func save(_ session: WalletSession, for walletType: WalletType) async throws
    
    /// Load a wallet session
    func load(for walletType: WalletType) async throws -> WalletSession?
    
    /// Delete a wallet session
    func delete(for walletType: WalletType) async throws
    
    /// Get all saved sessions
    func getAllSessions() async throws -> [WalletSession]
}
