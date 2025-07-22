import Foundation
import Combine
import UIKit
import CoinbaseWalletSDK

/// Coinbase wallet implementation using the native Coinbase Wallet SDK
/// Simple implementation using initiateHandshake and makeRequest as documented
final class CoinbaseService: WalletProtocol {
    
    // MARK: - Properties
    
    let walletType: WalletType = .coinbase
    let connectionState = CurrentValueSubject<WalletConnectionState, Never>(.disconnected)
    private(set) var currentSession: WalletSession?
    
    // Coinbase SDK - lazy to ensure configuration happens first
    private lazy var cbwallet: CoinbaseWalletSDK = {
        // Configure the SDK before accessing shared instance
        CoinbaseWalletSDK.configure(
            host: URL(string: CoinbaseConfiguration.appUrl)!,
            callback: CoinbaseConfiguration.callbackURL
        )
        return CoinbaseWalletSDK.shared
    }()
    
    // Pending operations
    private var pendingConnectCompletion: ((Result<WalletSession, WalletError>) -> Void)?
    private var pendingSignMessageCompletion: ((Result<WalletSignature, WalletError>) -> Void)?
    
    // Current account from handshake
    private var currentAccount: Account?
    
    // Session storage
    private let sessionStorage: WalletSessionStorageProtocol
    
    // Connection state
    private var isConnecting = false
    
    // MARK: - Initialization
    
    init(sessionStorage: WalletSessionStorageProtocol = WalletSessionStorage.shared) {
        self.sessionStorage = sessionStorage
        print("🔵 Coinbase: Initialized with SDK")
    }
    
    // MARK: - WalletProtocol Implementation
    
    func supportsChain(_ chainId: Int) -> Bool {
        // Coinbase Wallet supports all EVM chains
        return true
    }
    
    func connect(
        context: WalletConnectionContext,
        completion: @escaping (Result<WalletSession, WalletError>) -> Void
    ) {
        // Check if Coinbase Wallet is installed
        guard isCoinbaseWalletInstalled() else {
            let error = WalletError.walletNotInstalled
            connectionState.send(.error(CoinbaseConfiguration.ErrorMessage.notInstalled))
            completion(.failure(error))
            return
        }
        
        // Check if already connecting
        if isConnecting {
            print("🔵 Coinbase: Connection already in progress")
            completion(.failure(.connectionFailed("Connection already in progress")))
            return
        }
        
        // Update state
        connectionState.send(.connecting)
        isConnecting = true
        pendingConnectCompletion = completion
        
        print("🔵 Coinbase: Initiating handshake...")
        
        // Step 1: Initiate handshake with eth_requestAccounts
        cbwallet.initiateHandshake(
            initialActions: [
                Action(jsonRpc: .eth_requestAccounts)
            ]
        ) { [weak self] result, account in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isConnecting = false
                
                switch result {
                case .success(let response):
                    print("🔵 Coinbase: Handshake successful")
                    self.logObject("Response", response)
                    
                    guard let account = account else {
                        print("❌ Coinbase: No account returned")
                        self.handleError(.noAccountsFound)
                        return
                    }
                    
                    print("🔵 Coinbase: Connected to account: \(account.address)")
                    self.currentAccount = Account(address: account.address, chain: account.chain)
                    
                    // Create session
                    let session = WalletSession(
                        walletType: .coinbase,
                        address: self.normalizeAddress(account.address),
                        chainId: Int(account.chain) ?? 1,
                        sessionToken: nil,
                        walletMetadata: WalletMetadata(
                            name: "Coinbase Wallet",
                            icon: "coinbase",
                            version: nil
                        ),
                        connectedAt: Date(),
                        additionalData: nil
                    )
                    
                    self.currentSession = session
                    self.connectionState.send(.connected(session))
                    
                    // Save session
                    Task {
                        try? await self.sessionStorage.save(session, for: self.walletType)
                    }
                    
                    self.pendingConnectCompletion?(.success(session))
                    self.pendingConnectCompletion = nil
                    
                case .failure(let error):
                    print("❌ Coinbase: Handshake failed: \(error)")
                    self.handleError(.connectionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func disconnect() async throws {
        defer {
            currentSession = nil
            currentAccount = nil
            connectionState.send(.disconnected)
        }
        
        // Clear stored session
        try await sessionStorage.delete(for: walletType)
        
        // Reset SDK session
        cbwallet.resetSession()
        
        print("🔵 Coinbase: Disconnected successfully")
    }
    
    func signMessage(
        _ message: String,
        session: WalletSession,
        completion: @escaping (Result<WalletSignature, WalletError>) -> Void
    ) {
        guard session.walletType == .coinbase,
              currentAccount != nil else {
            completion(.failure(.noSession))
            return
        }
        
        pendingSignMessageCompletion = completion
        
        print("🔵 Coinbase: Signing message with personal_sign")
        
        // Step 2: Use makeRequest with personal_sign for SIWE
        let request = Request(actions: [
            Action(jsonRpc: .personal_sign(
                address: session.address,
                message: message
            ))
        ])
        
        cbwallet.makeRequest(request) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    print("🔵 Coinbase: makeRequest response received")
                    self.logObject("Response", response)
                    
                    // Extract signature from response
                    if let firstReturn = response.content.first,
                       case .success(let value) = firstReturn,
                       let signature = value as? String {
                        
                        print("🔵 Coinbase: Signature successful")
                        
                        // Normalize signature
                        var normalizedSig = signature
                        if !normalizedSig.hasPrefix("0x") {
                            normalizedSig = "0x" + normalizedSig
                        }
                        normalizedSig = normalizedSig.lowercased()
                        
                        let walletSignature = WalletSignature(
                            signature: normalizedSig,
                            address: self.normalizeAddress(session.address),
                            message: message
                        )
                        
                        self.pendingSignMessageCompletion?(.success(walletSignature))
                    } else {
                        print("❌ Coinbase: Failed to extract signature")
                        self.pendingSignMessageCompletion?(.failure(.signatureFailed("Invalid response format")))
                    }
                    
                case .failure(let error):
                    print("❌ Coinbase: makeRequest failed: \(error)")
                    if error.localizedDescription.contains("User rejected") ||
                       error.localizedDescription.contains("User denied") {
                        self.pendingSignMessageCompletion?(.failure(.userCancelled))
                    } else {
                        self.pendingSignMessageCompletion?(.failure(.signatureFailed(error.localizedDescription)))
                    }
                }
                
                self.pendingSignMessageCompletion = nil
            }
        }
    }
    
    func signTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        // Not implemented for now - can add if needed
        completion(.failure(.unsupportedWallet("Transaction signing not implemented")))
    }
    
    func sendTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        // Not implemented for now - can add if needed
        completion(.failure(.unsupportedWallet("Transaction sending not implemented")))
    }
    
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        // Coinbase SDK handles deep links internally
        return false
    }
    
    // MARK: - Public Methods
    
    /// Cancel any pending connection attempt
    func cancelConnection() {
        print("🔵 Coinbase: Cancelling connection")
        
        // Update state
        isConnecting = false
        connectionState.send(.disconnected)
        
        // Clear pending completion
        if let completion = pendingConnectCompletion {
            completion(.failure(.userCancelled))
            pendingConnectCompletion = nil
        }
        
        // Reset SDK session if needed
        cbwallet.resetSession()
    }
    
    // MARK: - Private Methods
    
    private func isCoinbaseWalletInstalled() -> Bool {
        guard let url = URL(string: "\(CoinbaseConfiguration.deepLinkScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    private func handleError(_ error: WalletError) {
        connectionState.send(.error(error.localizedDescription))
        isConnecting = false
        
        pendingConnectCompletion?(.failure(error))
        pendingConnectCompletion = nil
    }
    
    private func normalizeAddress(_ address: String) -> String {
        var normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure 0x prefix
        if !normalized.hasPrefix("0x") {
            normalized = "0x" + normalized
        }
        
        // Convert to lowercase
        normalized = normalized.lowercased()
        
        return normalized
    }
    
    private func logObject(_ label: String, _ object: Any) {
        print("🔵 Coinbase: \(label):")
        print(object)
    }
}

// MARK: - One-Click Connect with SIWE

extension CoinbaseService {
    /// Perform one-click connect with SIWE authentication
    /// Combines initiateHandshake and makeRequest in a single flow
    func connectAndSignSIWE(
        nonce: String,
        completion: @escaping (Result<(session: WalletSession, signature: WalletSignature), WalletError>) -> Void
    ) {
        print("🔵🔐 Coinbase: Starting one-click connect with SIWE")
        
        // First connect
        connect(context: .default) { [weak self] connectResult in
            switch connectResult {
            case .success(let session):
                print("🔵🔐 Coinbase: Connection successful, now signing SIWE")
                
                // Create SIWE message
                let message = SIWEMessageBuilder.buildSimpleMessage(
                    address: session.address,
                    nonce: nonce,
                    chainId: session.chainId
                )
                
                // Sign the message
                self?.signMessage(message, session: session) { signResult in
                    switch signResult {
                    case .success(let signature):
                        print("🔵🔐 Coinbase: SIWE signature successful")
                        completion(.success((session: session, signature: signature)))
                        
                    case .failure(let error):
                        print("❌ Coinbase: SIWE signature failed: \(error)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ Coinbase: Connection failed: \(error)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Supporting Types

/// Account information from Coinbase SDK
struct Account {
    let address: String
    let chain: String
}
