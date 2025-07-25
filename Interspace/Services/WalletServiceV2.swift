import Foundation
import Combine
import UIKit

// MARK: - WalletConnectionResult (for compatibility)
struct WalletConnectionResult {
    let address: String
    let signature: String
    let message: String
    let walletName: String?
    let walletIcon: String?
    let walletType: WalletType
    
    var normalizedSignature: String {
        return signature
    }
}

/// Modernized wallet service using protocol-based architecture
/// Supports custom wallet implementations for better control and UX
@MainActor
final class WalletServiceV2: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WalletServiceV2()
    
    // MARK: - Published Properties
    
    @Published var activeWallet: WalletProtocol?
    @Published var connectionState: WalletConnectionState = .disconnected
    @Published var isConnecting = false
    @Published var error: WalletError?
    @Published var isWalletFlowActive = false
    @Published var currentPairingURI: String?
    
    // MARK: - Properties
    
    let factory = WalletFactory.shared
    private let sessionStorage = WalletSessionStorage.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Deep link handling
    private var pendingDeepLinkHandler: WalletProtocol?
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        restoreActiveWallet()
    }
    
    // MARK: - Public Methods
    
    /// Connect to a wallet
    func connect(
        walletType: WalletType,
        context: WalletConnectionContext = .default
    ) async throws -> WalletSession {
        // Check if wallet is supported
        guard factory.isSupported(walletType) else {
            throw WalletError.unsupportedWallet("Wallet type \(walletType.displayName) is not supported yet")
        }
        
        // Create wallet instance
        guard let wallet = factory.createWallet(for: walletType) else {
            throw WalletError.connectionFailed("Failed to create wallet instance")
        }
        
        // Update state
        isConnecting = true
        isWalletFlowActive = true
        error = nil
        activeWallet = wallet
        
        // Store for deep link handling
        pendingDeepLinkHandler = wallet
        
        // Check if wallet should be handled by AppKit
        if wallet == nil {
            // AppKit handles these wallet connections
            print("🔄 WalletServiceV2: Using AppKit modal for \(walletType.displayName)")
            
            // Present AppKit modal
            let appKitService = AppKitService.shared
            appKitService.presentModal()
            
            // Wait for connection
            throw WalletError.connectionFailed("Please complete wallet connection in AppKit modal")
        } else {
            // Non-AppKit wallets use the original flow (e.g., Coinbase native SDK)
            return try await withCheckedThrowingContinuation { continuation in
                wallet.connect(context: context) { [weak self] result in
                    Task { @MainActor in
                        self?.isConnecting = false
                        self?.isWalletFlowActive = false
                        self?.pendingDeepLinkHandler = nil
                        
                        switch result {
                        case .success(let session):
                            self?.handleConnectionSuccess(session, wallet: wallet)
                            continuation.resume(returning: session)
                            
                        case .failure(let error):
                            self?.handleConnectionError(error)
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    /// Disconnect active wallet
    func disconnect() async throws {
        guard let wallet = activeWallet else { return }
        
        try await wallet.disconnect()
        
        // Clear state
        activeWallet = nil
        connectionState = .disconnected
        error = nil
    }
    
    /// Sign message for SIWE authentication
    func signMessage(
        _ message: String,
        walletType: WalletType? = nil
    ) async throws -> WalletSignature {
        // Use active wallet or create new one
        let wallet: WalletProtocol
        let session: WalletSession
        
        if let activeWallet = activeWallet,
           let currentSession = activeWallet.currentSession,
           walletType == nil || walletType == activeWallet.walletType {
            // Use existing connection
            wallet = activeWallet
            session = currentSession
        } else if let walletType = walletType {
            // Connect to specific wallet
            session = try await connect(walletType: walletType)
            wallet = activeWallet!
        } else {
            throw WalletError.noSession
        }
        
        // Sign message
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WalletSignature, Error>) in
            wallet.signMessage(message, session: session) { result in
                switch result {
                case .success(let signature):
                    continuation.resume(returning: signature)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Sign transaction
    func signTransaction(
        _ transaction: WalletTransaction,
        walletType: WalletType? = nil
    ) async throws -> String {
        // Similar to signMessage, use active wallet or connect
        let wallet: WalletProtocol
        let session: WalletSession
        
        if let activeWallet = activeWallet,
           let currentSession = activeWallet.currentSession,
           walletType == nil || walletType == activeWallet.walletType {
            wallet = activeWallet
            session = currentSession
        } else if let walletType = walletType {
            session = try await connect(walletType: walletType)
            wallet = activeWallet!
        } else {
            throw WalletError.noSession
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            wallet.signTransaction(transaction, session: session) { result in
                switch result {
                case .success(let signature):
                    continuation.resume(returning: signature)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Send transaction
    func sendTransaction(
        _ transaction: WalletTransaction,
        walletType: WalletType? = nil
    ) async throws -> String {
        let wallet: WalletProtocol
        let session: WalletSession
        
        if let activeWallet = activeWallet,
           let currentSession = activeWallet.currentSession,
           walletType == nil || walletType == activeWallet.walletType {
            wallet = activeWallet
            session = currentSession
        } else if let walletType = walletType {
            session = try await connect(walletType: walletType)
            wallet = activeWallet!
        } else {
            throw WalletError.noSession
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            wallet.sendTransaction(transaction, session: session) { result in
                switch result {
                case .success(let txHash):
                    continuation.resume(returning: txHash)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    
    /// Get SIWE nonce from backend
    func getSIWENonce() async throws -> String {
        let authAPI = AuthAPI.shared
        let response = try await authAPI.getSIWENonceV2()
        return response.data.nonce
    }
    
    /// Create SIWE message
    func createSIWEMessage(address: String, nonce: String) async throws -> String {
        // Use the standardized SIWE message builder
        return SIWEMessageBuilder.buildSimpleMessage(
            address: address,
            nonce: nonce,
            chainId: 1
        )
    }
    
    /// Check if wallet is available
    func isWalletAvailable(_ walletType: WalletType) -> Bool {
        switch walletType {
        case .phantom:
            return UIApplication.shared.canOpenURL(URL(string: "phantom://")!)
        case .metamask:
            return UIApplication.shared.canOpenURL(URL(string: "metamask://")!)
        case .coinbase:
            return UIApplication.shared.canOpenURL(URL(string: "cbwallet://")!)
        default:
            return false
        }
    }
    
    /// Handle deep link
    func handleDeepLink(_ url: URL) -> Bool {
        // Try pending handler first
        if let handler = pendingDeepLinkHandler,
           handler.handleDeepLink(url) {
            return true
        }
        
        // Try active wallet
        if let wallet = activeWallet,
           wallet.handleDeepLink(url) {
            return true
        }
        
        // Try all supported wallets
        for walletType in factory.supportedWallets {
            if let wallet = factory.wallet(for: walletType),
               wallet.handleDeepLink(url) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if wallet is installed
    func isWalletInstalled(_ walletType: WalletType) -> Bool {
        factory.isWalletInstalled(walletType)
    }
    
    /// Get supported wallets
    var supportedWallets: [WalletType] {
        factory.supportedWallets
    }
    
    /// Get installed wallets
    var installedWallets: [WalletType] {
        supportedWallets.filter { isWalletInstalled($0) }
    }
    
    // MARK: - Authentication Helpers
    
    /// Authenticate with wallet (connect + sign SIWE)
    func authenticateWithWallet(
        walletType: WalletType,
        context: WalletConnectionContext = .default
    ) async throws -> WalletAuthResult {
        // Connect to wallet
        let session = try await connect(walletType: walletType, context: context)
        
        // Get SIWE nonce
        let nonce = try await getSIWENonce()
        
        // Build SIWE message
        let message = SIWEMessageBuilder.buildSimpleMessage(
            address: session.address,
            nonce: nonce,
            chainId: session.chainId
        )
        
        // Sign message
        let signature = try await signMessage(message, walletType: walletType)
        
        return WalletAuthResult(
            address: session.address,
            signature: signature.normalizedSignature,
            message: message,
            walletType: walletType,
            walletName: session.walletMetadata?.name,
            walletIcon: session.walletMetadata?.icon
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor active wallet state changes
        $activeWallet
            .compactMap { $0 }
            .sink { [weak self] wallet in
                // Subscribe to wallet's connection state
                wallet.connectionState
                    .sink { [weak self] state in
                        self?.connectionState = state
                    }
                    .store(in: &self!.cancellables)
            }
            .store(in: &cancellables)
    }
    
    private func restoreActiveWallet() {
        Task {
            // Try to restore the last connected wallet
            let sessions = try? await sessionStorage.getAllSessions()
            
            if let lastSession = sessions?.first,
               let wallet = factory.createWallet(for: lastSession.walletType) {
                activeWallet = wallet
                connectionState = .connected(lastSession)
            }
        }
    }
    
    private func handleConnectionSuccess(_ session: WalletSession, wallet: WalletProtocol) {
        activeWallet = wallet
        connectionState = .connected(session)
        error = nil
        
        print("✅ WalletServiceV2: Connected to \(wallet.walletType.displayName)")
    }
    
    private func handleConnectionError(_ error: WalletError) {
        self.error = error
        connectionState = .error(error.localizedDescription)
        
        print("❌ WalletServiceV2: Connection error: \(error)")
    }
}

// MARK: - Supporting Types

/// Result of wallet authentication (connect + SIWE)
struct WalletAuthResult {
    let address: String
    let signature: String
    let message: String
    let walletType: WalletType
    let walletName: String?
    let walletIcon: String?
}

// MARK: - Migration Helpers

extension WalletServiceV2 {
    /// Helper to migrate from old WalletService
    /// Maps old connection methods to new architecture
    func connectWallet(_ walletType: WalletType) async throws -> WalletConnectionResult {
        print("🔄 WalletServiceV2.connectWallet: Starting connection for \(walletType.displayName)")
        
        // Check if wallet is handled by AppKit
        if factory.createWallet(for: walletType) == nil {
            print("🔄 WalletServiceV2.connectWallet: \(walletType.displayName) is handled by AppKit")
            
            // Present AppKit modal
            let appKitService = AppKitService.shared
            appKitService.presentModal()
            
            throw WalletError.connectionFailed("Please complete wallet connection in AppKit modal")
        }
        
        // For wallets with custom implementations (like Coinbase), use standard flow
        let session = try await connect(walletType: walletType)
        
        // Get SIWE nonce and create message
        let nonce = try await getSIWENonce()
        let message = try await createSIWEMessage(address: session.address, nonce: nonce)
        
        // Sign the message
        let signature = try await signMessage(message, walletType: walletType)
        
        return WalletConnectionResult(
            address: session.address,
            signature: signature.normalizedSignature,
            message: message,
            walletName: session.walletMetadata?.name ?? walletType.displayName,
            walletIcon: session.walletMetadata?.icon,
            walletType: walletType
        )
    }
  
    
    /// Get connected address
    var connectedAddress: String? {
        activeWallet?.currentSession?.address
    }
    
    /// Check if connected
    var isConnected: Bool {
        connectionState.isConnected
    }
}
