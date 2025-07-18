import Foundation
import Combine
import UIKit
import metamask_ios_sdk

/// MetaMask wallet implementation using the native MetaMask iOS SDK
/// Provides seamless one-click connect with SIWE authentication
final class MetaMaskService: WalletProtocol {
    
    // MARK: - Properties
    
    let walletType: WalletType = .metamask
    let connectionState = CurrentValueSubject<WalletConnectionState, Never>(.disconnected)
    private(set) var currentSession: WalletSession?
    
    // MetaMask SDK
    private var metamaskSDK: MetaMaskSDK?
    
    // Pending operations
    private var pendingConnectCompletion: ((Result<WalletSession, WalletError>) -> Void)?
    private var pendingSignMessageCompletion: ((Result<WalletSignature, WalletError>) -> Void)?
    private var pendingSignTransactionCompletion: ((Result<String, WalletError>) -> Void)?
    private var pendingSendTransactionCompletion: ((Result<String, WalletError>) -> Void)?
    
    // Timeout handling
    private var timeoutTimer: Timer?
    private let requestTimeout: TimeInterval = 60.0
    
    // Session storage
    private let sessionStorage: WalletSessionStorageProtocol
    
    // Connection state
    private var isConnecting = false
    private var lastConnectionAttempt: Date?
    private let connectionCooldown: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init(sessionStorage: WalletSessionStorageProtocol = WalletSessionStorage.shared) {
        self.sessionStorage = sessionStorage
        
        // Initialize MetaMask SDK
        setupMetaMaskSDK()
        
        // Don't restore session automatically - we want fresh connections
        // to allow users to select different accounts each time
        // Task {
        //     await restoreSession()
        // }
    }
    
    // MARK: - SDK Setup
    
    private func setupMetaMaskSDK() {
        let appMetadata = AppMetadata(
            name: MetaMaskConfiguration.appName,
            url: MetaMaskConfiguration.appUrl,
            iconUrl: nil
        )
        
        // Use socket transport by default for better UX
        // Deep links will be handled as fallback
        let sdkOptions = SDKOptions(
            infuraAPIKey: "", // Empty string if no API key
            readonlyRPCMap: [:] // Empty dictionary if no custom RPC
        )
        
        metamaskSDK = MetaMaskSDK.shared(
            appMetadata,
            transport: .socket,
            sdkOptions: sdkOptions
        )
        
        // Enable debug mode if available
        #if DEBUG
        if let sdk = metamaskSDK {
            sdk.enableDebug = true
        }
        #endif
        
        print("🦊 MetaMask SDK initialized with socket transport")
    }
    
    // MARK: - WalletProtocol Implementation
    
    func supportsChain(_ chainId: Int) -> Bool {
        // MetaMask supports all EVM chains
        return true
    }
    
    func connect(
        context: WalletConnectionContext,
        completion: @escaping (Result<WalletSession, WalletError>) -> Void
    ) {
        // IMPORTANT: MetaMask always forces fresh connections to allow account selection
        // This ensures users can link different MetaMask accounts to their SmartProfiles
        // Check if MetaMask is installed
        guard isMetaMaskInstalled() else {
            let error = WalletError.walletNotInstalled
            connectionState.send(.error(MetaMaskConfiguration.ErrorMessage.notInstalled))
            completion(.failure(error))
            return
        }
        
        // Check if already connecting
        if isConnecting {
            print("🦊 MetaMask: Connection already in progress")
            completion(.failure(.connectionFailed("Connection already in progress")))
            return
        }
        
        // Check cooldown
        if let lastAttempt = lastConnectionAttempt {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < connectionCooldown {
                let remainingTime = Int(connectionCooldown - timeSinceLastAttempt) + 1
                completion(.failure(.connectionFailed("Please wait \(remainingTime) seconds before trying again")))
                return
            }
        }
        
        // Validate SDK is initialized
        guard metamaskSDK != nil else {
            print("❌ MetaMask: SDK not initialized")
            setupMetaMaskSDK()
            
            // Retry after setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connect(context: context, completion: completion)
            }
            return
        }
        
        // Cancel any pending connection
        cancelPendingOperations()
        
        // Update state
        connectionState.send(.connecting)
        isConnecting = true
        lastConnectionAttempt = Date()
        
        // Store completion handler
        pendingConnectCompletion = completion
        
        // Start timeout
        startTimeout { [weak self] in
            self?.handleTimeout()
        }
        
        // Always ensure fresh connection for MetaMask
        // This allows users to select different accounts each time
        if let sdk = metamaskSDK, !sdk.account.isEmpty {
            print("🦊 MetaMask: Clearing existing connection to allow account selection")
            print("🦊 MetaMask: Previous account: \(sdk.account)")
            
            // Clear the existing connection
            sdk.disconnect()
            sdk.clearSession()
            currentSession = nil
            
            // Give SDK time to clear, then connect fresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("🦊 MetaMask: Starting fresh connection after clearing")
                Task {
                    await self?.performConnection()
                }
            }
            return
        }
        
        // Connect to MetaMask
        Task {
            await performConnection()
        }
    }
    
    func disconnect() async throws {
        defer {
            // Clear session
            currentSession = nil
            connectionState.send(.disconnected)
        }
        
        // Clear stored session
        try await sessionStorage.delete(for: walletType)
        
        // Disconnect SDK
        metamaskSDK?.disconnect()
        metamaskSDK?.clearSession()
        
        print("🦊 MetaMask: Disconnected successfully")
    }
    
    func signMessage(
        _ message: String,
        session: WalletSession,
        completion: @escaping (Result<WalletSignature, WalletError>) -> Void
    ) {
        guard session.walletType == .metamask,
              metamaskSDK != nil else {
            completion(.failure(.noSession))
            return
        }
        
        // Store completion handler
        print("🦊 MetaMask signMessage: Storing completion handler")
        pendingSignMessageCompletion = completion
        
        // Start timeout
        startTimeout { [weak self] in
            self?.handleTimeout()
        }
        
        // Sign message
        print("🦊 MetaMask signMessage: Starting async task to perform signature")
        Task {
            print("🦊 MetaMask signMessage: Inside Task, calling performSignMessage")
            await performSignMessage(message, address: session.address)
            print("🦊 MetaMask signMessage: performSignMessage completed")
        }
    }
    
    func signTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        guard session.walletType == .metamask,
              metamaskSDK != nil else {
            completion(.failure(.noSession))
            return
        }
        
        // Store completion handler
        pendingSignTransactionCompletion = completion
        
        // Start timeout
        startTimeout { [weak self] in
            self?.handleTimeout()
        }
        
        // For transaction signing, we'll convert to a serialized format
        // MetaMask SDK doesn't support direct transaction signing via deep links
        // We'll use eth_signTypedData_v4 or fallback to message signing
        completion(.failure(.unsupportedWallet("Transaction signing not supported via MetaMask deep links. Please use WalletConnect.")))
    }
    
    func sendTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        guard session.walletType == .metamask,
              metamaskSDK != nil else {
            completion(.failure(.noSession))
            return
        }
        
        // Store completion handler
        pendingSendTransactionCompletion = completion
        
        // Start timeout
        startTimeout { [weak self] in
            self?.handleTimeout()
        }
        
        // For transaction sending, we need to serialize the transaction properly
        // MetaMask mobile SDK primarily supports simple operations like signing messages
        // Complex transaction operations should use WalletConnect
        completion(.failure(.unsupportedWallet("Transaction sending not supported via MetaMask deep links. Please use WalletConnect.")))
    }
    
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        // MetaMask SDK handles deep links internally
        // This is called by AppDelegate, but the SDK will process it
        guard url.scheme == "metamask" else {
            return false
        }
        
        // The SDK will handle the response internally and trigger callbacks
        print("🦊 MetaMask: Deep link received: \(url)")
        return true
    }
    
    // MARK: - Private Methods
    
    private func isMetaMaskInstalled() -> Bool {
        guard let url = URL(string: "metamask://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    // DEPRECATED: We now always force fresh connections for account selection
    // private func validateExistingConnection(address: String, completion: @escaping (Result<WalletSession, WalletError>) -> Void) {
    //     // For existing connections, we can directly proceed if the session is valid
    //     if let existingSession = currentSession,
    //        existingSession.address.lowercased() == address.lowercased() {
    //         print("🦊 MetaMask: Valid session exists, reusing")
    //         isConnecting = false
    //         pendingConnectCompletion?(.success(existingSession))
    //         pendingConnectCompletion = nil
    //         cancelTimeout()
    //     } else {
    //         // Create a new session for the existing connection
    //         handleConnectionSuccess(address: address)
    //     }
    // }
    
    private func restoreSession() async {
        do {
            if let session = try await sessionStorage.load(for: walletType) {
                currentSession = session
                connectionState.send(.connected(session))
                print("🦊 MetaMask: Restored session for \(session.address)")
                
                // Verify SDK state matches
                if let sdk = metamaskSDK, sdk.account.isEmpty {
                    // SDK lost connection, clear session
                    currentSession = nil
                    connectionState.send(.disconnected)
                    try? await sessionStorage.delete(for: walletType)
                    print("🦊 MetaMask: SDK disconnected, cleared stale session")
                }
            }
        } catch {
            print("⚠️ MetaMask: Failed to restore session: \(error)")
        }
    }
    
    private func performConnection() async {
        guard let sdk = metamaskSDK else {
            handleError(.sdkNotInitialized)
            return
        }
        
        // Always ensure clean state for fresh connection
        if !sdk.account.isEmpty {
            print("🦊 MetaMask: Clearing existing connection for fresh authentication")
            print("🦊 MetaMask: Previous account was: \(sdk.account)")
            sdk.disconnect()
            sdk.clearSession()
            currentSession = nil
            connectionState.send(.disconnected)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("🦊 MetaMask: Connection cleared, ready for fresh account selection")
        }
        
        print("🦊 MetaMask: Initiating connection...")
        let connectResult = await sdk.connect()
        
        await MainActor.run {
            switch connectResult {
            case .success:
                if !sdk.account.isEmpty {
                    print("🦊 MetaMask: Connected to account: \(sdk.account)")
                    self.handleConnectionSuccess(address: sdk.account)
                } else {
                    self.handleError(.noAccountsFound)
                }
            case .failure(let error):
                print("❌ MetaMask: Connection failed: \(error)")
                self.handleError(.connectionFailed(error.localizedDescription))
            }
        }
    }
    
    private func performSignMessage(_ message: String, address: String) async {
        guard let sdk = metamaskSDK else {
            await MainActor.run {
                self.pendingSignMessageCompletion?(.failure(.sdkNotInitialized))
                self.pendingSignMessageCompletion = nil
            }
            return
        }
        
        // For SIWE, we use personal_sign with message and address as string parameters
        let request = EthereumRequest(
            method: .personalSign,
            params: [message, address] // Both are strings, which conform to Codable
        )
        
        print("🦊 MetaMask: Requesting signature for message")
        let result: Result<String, RequestError> = await sdk.request(request)
        
        await MainActor.run {
            self.cancelTimeout()
            
            switch result {
            case .success(let signature):
                print("🦊 MetaMask: Message signed successfully")
                print("🦊 MetaMask: Raw signature: \(signature)")
                
                // Normalize signature format
                var normalizedSig = signature
                
                // Ensure signature has 0x prefix
                if !normalizedSig.hasPrefix("0x") {
                    normalizedSig = "0x" + normalizedSig
                }
                
                // Ensure lowercase
                normalizedSig = normalizedSig.lowercased()
                
                // Validate signature length (should be 132 chars: 0x + 130 hex chars)
                if normalizedSig.count != 132 {
                    print("⚠️ MetaMask: Unexpected signature length: \(normalizedSig.count)")
                }
                
                print("🦊 MetaMask: Normalized signature: \(normalizedSig)")
                
                let walletSignature = WalletSignature(
                    signature: normalizedSig,
                    address: self.normalizeAddress(address),
                    message: message
                )
                
                print("🦊 MetaMask: Calling pendingSignMessageCompletion on main thread")
                self.pendingSignMessageCompletion?(.success(walletSignature))
                print("🦊 MetaMask: pendingSignMessageCompletion called successfully")
                
            case .failure(let error):
                print("❌ MetaMask: Signature failed: \(error)")
                if error.localizedDescription.contains("User rejected") ||
                   error.localizedDescription.contains("User denied") {
                    self.pendingSignMessageCompletion?(.failure(.userCancelled))
                } else {
                    self.pendingSignMessageCompletion?(.failure(.signatureFailed(error.localizedDescription)))
                }
            }
            
            print("🦊 MetaMask: Clearing pendingSignMessageCompletion")
            self.pendingSignMessageCompletion = nil
        }
    }
    
    private func handleConnectionSuccess(address: String) {
        cancelTimeout()
        
        // Normalize address
        let normalizedAddress = normalizeAddress(address)
        
        // Create session
        let session = WalletSession(
            walletType: .metamask,
            address: normalizedAddress,
            chainId: 1, // Ethereum mainnet
            sessionToken: nil, // MetaMask SDK manages its own session
            walletMetadata: WalletMetadata(
                name: "MetaMask",
                icon: "metamask",
                version: nil
            ),
            connectedAt: Date(),
            additionalData: nil
        )
        
        // Update state
        currentSession = session
        connectionState.send(.connected(session))
        isConnecting = false
        
        // Save session
        Task {
            try? await sessionStorage.save(session, for: walletType)
        }
        
        // Call completion
        print("🦊 MetaMask: Calling pendingConnectCompletion with success")
        pendingConnectCompletion?(.success(session))
        pendingConnectCompletion = nil
        
        print("🦊 MetaMask: Connected successfully to \(address)")
    }
    
    private func handleError(_ error: WalletError) {
        cancelTimeout()
        
        // Update state
        connectionState.send(.error(error.localizedDescription))
        isConnecting = false
        
        // Call appropriate completion handler
        if let completion = pendingConnectCompletion {
            completion(.failure(error))
            pendingConnectCompletion = nil
        } else if let completion = pendingSignMessageCompletion {
            completion(.failure(error))
            pendingSignMessageCompletion = nil
        } else if let completion = pendingSignTransactionCompletion {
            completion(.failure(error))
            pendingSignTransactionCompletion = nil
        } else if let completion = pendingSendTransactionCompletion {
            completion(.failure(error))
            pendingSendTransactionCompletion = nil
        }
    }
    
    private func handleTimeout() {
        print("⏱ MetaMask: Request timed out")
        handleError(.timeout())
    }
    
    private func startTimeout(handler: @escaping () -> Void) {
        cancelTimeout()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: requestTimeout,
            repeats: false
        ) { _ in
            handler()
        }
    }
    
    private func cancelTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func cancelPendingOperations() {
        cancelTimeout()
        
        // Clear all pending completions
        pendingConnectCompletion = nil
        pendingSignMessageCompletion = nil
        pendingSignTransactionCompletion = nil
        pendingSendTransactionCompletion = nil
    }
    
    // MARK: - Helper Methods
    
    /// Normalize Ethereum address to ensure consistency
    private func normalizeAddress(_ address: String) -> String {
        var normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure 0x prefix
        if !normalized.hasPrefix("0x") {
            normalized = "0x" + normalized
        }
        
        // Convert to lowercase (checksum addresses are case-sensitive, but we use lowercase for consistency)
        normalized = normalized.lowercased()
        
        // Validate address format (should be 42 characters: 0x + 40 hex chars)
        if normalized.count != 42 {
            print("⚠️ MetaMask: Invalid address length: \(normalized.count)")
        }
        
        return normalized
    }
    
    /// Validate Ethereum address format
    private func isValidAddress(_ address: String) -> Bool {
        let normalized = normalizeAddress(address)
        
        // Check length
        guard normalized.count == 42 else { return false }
        
        // Check if it's a valid hex string
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        let addressWithoutPrefix = String(normalized.dropFirst(2))
        
        return addressWithoutPrefix.rangeOfCharacter(from: hexCharacters.inverted) == nil
    }
}

// MARK: - One-Click Connect with SIWE

extension MetaMaskService {
    /// Perform one-click connect with SIWE authentication
    /// This method combines connection and message signing in a single flow
    func connectAndSignSIWE(
        nonce: String,
        statement: String = "Sign in with Ethereum to Interspace",
        completion: @escaping (Result<(session: WalletSession, signature: WalletSignature), WalletError>) -> Void
    ) {
        print("🦊🔐 MetaMask connectAndSignSIWE: Starting one-click connect flow")
        print("🦊🔐 MetaMask connectAndSignSIWE: Nonce: \(nonce)")
        
        // First connect
        connect(context: .default) { [weak self] connectResult in
            print("🦊🔐 MetaMask connectAndSignSIWE: Connect result received")
            
            switch connectResult {
            case .success(let session):
                print("🦊🔐 MetaMask connectAndSignSIWE: Connection successful")
                print("🦊🔐 MetaMask connectAndSignSIWE: Session address: \(session.address)")
                
                // Create SIWE message using the standardized builder
                let message = SIWEMessageBuilder.buildSimpleMessage(
                    address: session.address,
                    nonce: nonce,
                    chainId: 1
                )
                
                print("🦊🔐 MetaMask connectAndSignSIWE: SIWE message created, length: \(message.count)")
                print("🦊🔐 MetaMask connectAndSignSIWE: Now requesting signature...")
                
                // Sign the message
                self?.signMessage(message, session: session) { signResult in
                    print("🦊🔐 MetaMask connectAndSignSIWE: Sign result received")
                    
                    switch signResult {
                    case .success(let signature):
                        print("🦊🔐 MetaMask connectAndSignSIWE: Signature successful")
                        print("🦊🔐 MetaMask connectAndSignSIWE: Calling completion handler with success")
                        completion(.success((session: session, signature: signature)))
                        print("🦊🔐 MetaMask connectAndSignSIWE: Completion handler called")
                        
                    case .failure(let error):
                        print("❌ MetaMask connectAndSignSIWE: Signature failed: \(error)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ MetaMask connectAndSignSIWE: Connection failed: \(error)")
                completion(.failure(error))
            }
        }
    }
}