import Foundation
import Combine
import metamask_ios_sdk
// Temporarily disabled - Coinbase SDK causing crashes
// import CoinbaseWalletSDK
import UIKit

final class WalletService: ObservableObject {
    static let shared = WalletService()
    
    @Published var connectionStatus: WalletConnectionStatus = .disconnected
    @Published var connectedWallet: WalletType?
    @Published var walletAddress: String?
    @Published var error: WalletError?
    
    // MetaMask SDK - made internal for AppDelegate access
    internal var metamaskSDK: MetaMaskSDK?
    
    // Coinbase SDK - temporarily disabled
    // private lazy var coinbaseSDK = CoinbaseWalletSDK.shared
    
    // WalletConnect SDK
    private var isWalletKitConfigured = false
    
    // Connection state management
    private(set) var isConnectionInProgress = false
    private var isAuthenticationFlow = false
    private var lastConnectionAttempt: Date?
    private let connectionCooldown: TimeInterval = 2.0 // 2 seconds cooldown between attempts
    
    // Enhanced connection tracking
    private var currentConnectionId: String?
    private var connectionStartTime: Date?
    private let connectionTimeout: TimeInterval = 30.0 // 30 seconds timeout
    private let connectionWarningTime: TimeInterval = 15.0 // Show warning after 15 seconds
    private var connectionTimeoutTask: Task<Void, Never>?
    
    // Lazy initialization flags
    private var isInitialized = false
    private var initializationTask: Task<Void, Never>?
    
    private init() {
        // Defer all initialization until needed
        print("💼 WalletService: Created (deferred initialization)")
    }
    
    /// Initialize SDKs only when wallet features are needed
    @MainActor
    func initializeSDKsIfNeeded() async {
        guard !isInitialized else { return }
        
        // Prevent multiple initializations
        if let existingTask = initializationTask {
            await existingTask.value
            return
        }
        
        initializationTask = Task {
            print("💼 WalletService: Starting SDK initialization")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Set up observers first
            setupNotificationObservers()
            
            // Initialize SDKs asynchronously
            async let metamaskSetup: Void = setupMetaMaskSDKAsync()
            // Coinbase setup temporarily disabled
            // async let coinbaseSetup: Void = setupCoinbaseSDKAsync()
            
            // Wait for MetaMask to complete
            _ = await (metamaskSetup)
            
            isInitialized = true
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("💼 WalletService: SDK initialization completed in \(String(format: "%.2f", duration))s")
        }
        
        await initializationTask?.value
    }
    
    /// Setup MetaMask SDK asynchronously
    private func setupMetaMaskSDKAsync() async {
        await setupMetaMaskSDK()
    }
    
    /// Setup Coinbase SDK asynchronously - temporarily disabled
    private func setupCoinbaseSDKAsync() async {
        // setupCoinbaseSDK()
    }
    
    private func setupNotificationObservers() {
        // Add notification observer for debugging
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification(_:)),
            name: nil,
            object: nil
        )
        
        // Add observers for session management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearWalletConnections),
            name: .clearWalletConnections,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionDidEnd),
            name: .sessionDidEnd,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileDidChange),
            name: .profileDidChange,
            object: nil
        )
    }
    
    @objc private func handleNotification(_ notification: Notification) {
        if notification.name.rawValue.contains("MetaMask") || notification.name.rawValue.contains("metamask") {
            print("🔔 WalletService: Received MetaMask notification: \(notification.name.rawValue)")
            if let userInfo = notification.userInfo {
                print("🔔 WalletService: UserInfo: \(userInfo)")
            }
        }
    }
    
    @objc private func handleClearWalletConnections() {
        print("🔔 WalletService: Received clearWalletConnections notification")
        Task {
            await disconnect()
        }
    }
    
    @objc private func handleSessionDidEnd() {
        print("🔔 WalletService: Received sessionDidEnd notification")
        Task {
            await disconnect()
        }
    }
    
    @objc private func handleProfileDidChange(_ notification: Notification) {
        print("🔔 WalletService: Received profileDidChange notification")
        // Clear wallet state when profile changes
        Task {
            await disconnect()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        connectionTimeoutTask?.cancel()
    }
    
    // MARK: - App Lifecycle
    
    /// Call this when app enters background to ensure clean state
    func handleAppBackground() {
        print("💰 WalletService: App entering background, clearing temporary state")
        // Only clear if we're not in an active connected state
        if connectionStatus != .connected {
            Task {
                await MainActor.run {
                    self.connectionStatus = .disconnected
                    self.error = nil
                }
            }
        }
    }
    
    /// Call this when app becomes active to check wallet state
    func handleAppForeground() {
        print("💰 WalletService: App becoming active, checking wallet state")
        print("💰 WalletService: isAuthenticationFlow: \(isAuthenticationFlow), isConnectionInProgress: \(isConnectionInProgress)")
        
        // Check for stuck connections
        if isConnectionInProgress, let startTime = connectionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            print("💰 WalletService: Connection in progress for \(elapsed) seconds")
            
            // If connection has been in progress too long, it's likely stuck
            if elapsed > connectionTimeout {
                print("💰 WalletService: Connection timeout detected, resetting state")
                resetConnectionState(error: WalletError.connectionFailed("Connection timed out. Please try again."))
                return
            }
            
            // If we're returning from MetaMask, check if we have a result
            if let sdk = metamaskSDK, !sdk.account.isEmpty {
                print("💰 WalletService: Returned from MetaMask with account, connection might be incomplete")
                // Don't reset here, let the connection flow complete
            }
        }
        
        // Handle non-connection state mismatches
        if !isConnectionInProgress, let sdk = metamaskSDK {
            let hasAccount = !sdk.account.isEmpty
            let isConnected = connectionStatus == .connected
            
            print("💰 WalletService: SDK has account: \(hasAccount), Connection status: \(connectionStatus)")
            
            // If our state is out of sync with SDK, just update our state
            if isConnected && !hasAccount {
                print("💰 WalletService: State mismatch detected, updating UI state")
                Task { @MainActor in
                    self.connectionStatus = .disconnected
                    self.connectedWallet = nil
                    self.walletAddress = nil
                }
            }
        }
    }
    
    // MARK: - MetaMask Setup
    
    private func setupMetaMaskSDK() async {
        await Task.detached(priority: .userInitiated) {
            let appMetadata = AppMetadata(
                name: "Interspace",
                url: "https://interspace.fi",
                iconUrl: "https://interspace.fi/icon.png"
            )
            
            // Get Infura API key from Info.plist
            let infuraAPIKey = await MainActor.run {
                Bundle.main.object(forInfoDictionaryKey: "INFURA_API_KEY") as? String ?? ""
            }
            
            let sdkOptions = SDKOptions(
                infuraAPIKey: infuraAPIKey,
                readonlyRPCMap: ["0x1": "https://ethereum.publicnode.com"]
            )
            
            // Check if we should use socket transport (for debugging)
            let useSocket = ProcessInfo.processInfo.environment["USE_METAMASK_SOCKET"] == "true"
            
            let transport: Transport
            if useSocket {
                print("💰 WalletService: Using socket transport for MetaMask")
                transport = .socket
            } else {
                print("💰 WalletService: Using deeplink transport for MetaMask")
                transport = .deeplinking(dappScheme: "interspace")
            }
            
            await MainActor.run {
                self.metamaskSDK = MetaMaskSDK.shared(
                    appMetadata,
                    transport: transport,
                    sdkOptions: sdkOptions
                )
                
                // Enable debug for development
                #if DEBUG
                self.metamaskSDK?.enableDebug = true
                #else
                self.metamaskSDK?.enableDebug = false
                #endif
            }
        }.value
        
        // Log SDK configuration
        print("💰 WalletService: MetaMask SDK initialized")
        print("💰 WalletService: Transport: Deeplink")
        print("💰 WalletService: Dapp scheme: interspace")
        print("💰 WalletService: Expected callback: interspace://mmsdk")
        print("💰 WalletService: Debug mode: \(metamaskSDK?.enableDebug ?? false)")
    }
    
    // MARK: - Coinbase Wallet SetupINFURA_API_KEY
    
    private func setupCoinbaseSDK() {
        // Coinbase SDK configuration temporarily disabled
        // CoinbaseWalletSDK.configure(
        //     host: URL(string: "https://interspace.fi")!,
        //     callback: URL(string: "interspace://coinbase")!
        // )
        
        print("💰 WalletService: Coinbase SDK configuration skipped (temporarily disabled)")
    }
    
    // MARK: - WalletConnect Setup
    
    private func setupWalletConnect() {
        // Get project ID from Info.plist or environment
        let projectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECT_PROJECT_ID") as? String ?? "YOUR_PROJECT_ID"
        
        guard !projectId.isEmpty && projectId != "YOUR_PROJECT_ID" else {
            print("WalletConnect: Project ID not configured")
            return
        }
        
        // TODO: Implement proper WalletConnect configuration when API is available
        /*
        Networking.configure(
            groupIdentifier: "group.com.interspace.walletconnect",
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )
        
        let metadata = AppMetadata(
            name: "Interspace",
            description: "Your Digital Universe",
            url: "https://interspace.fi",
            icons: ["https://interspace.fi/icon.png"],
            redirect: try! AppMetadata.Redirect(native: "interspace://wc", universal: nil, linkMode: true)
        )
        
        WalletKit.configure(
            metadata: metadata,
            crypto: DefaultCryptoProvider(),
            environment: .production
        )
        */
        
        isWalletKitConfigured = true
    }
    
    // MARK: - Debug Methods
    
    func debugMetaMaskState() {
        guard let sdk = metamaskSDK else {
            print("🔍 WalletService Debug: MetaMask SDK not initialized")
            return
        }
        
        print("🔍 WalletService Debug: MetaMask State")
        print("🔍 - Connected: \(!sdk.account.isEmpty)")
        print("🔍 - Account: \(sdk.account.isEmpty ? "none" : sdk.account)")
        print("🔍 - Debug Mode: \(sdk.enableDebug)")
        print("🔍 - Can Open MetaMask: \(canOpenMetaMask())")
        
        // Check URL scheme configuration
        if let url = URL(string: "interspace://") {
            print("🔍 - App can handle interspace:// URLs: \(UIApplication.shared.canOpenURL(url))")
        }
    }
    
    // MARK: - Wallet Connection
    
    func connectWallet(_ walletType: WalletType) async throws -> WalletConnectionResult {
        // Initialize SDKs if needed (this is fast if already initialized)
        await initializeSDKsIfNeeded()
        
        // Check if a connection is already in progress
        if isConnectionInProgress {
            // Check if it's a stuck connection
            if let startTime = connectionStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 10 { // If stuck for more than 10 seconds, allow retry
                    print("💰 WalletService: Previous connection appears stuck (\(elapsed)s), allowing retry")
                    resetConnectionState(error: nil)
                } else {
                    print("💰 WalletService: Connection already in progress, please wait")
                    throw WalletError.connectionFailed("Connection in progress. Please wait...")
                }
            }
        }
        
        // Check cooldown period (but not for stuck connections)
        if let lastAttempt = lastConnectionAttempt, !isConnectionInProgress {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < connectionCooldown {
                let remainingCooldown = connectionCooldown - timeSinceLastAttempt
                print("💰 WalletService: Connection cooldown active, \(remainingCooldown) seconds remaining")
                throw WalletError.connectionFailed("Please wait a moment before trying again")
            }
        }
        
        // Mark connection as in progress
        let connectionId = UUID().uuidString
        currentConnectionId = connectionId
        isConnectionInProgress = true
        isAuthenticationFlow = true
        lastConnectionAttempt = Date()
        connectionStartTime = Date()
        
        await MainActor.run {
            connectionStatus = .connecting
            error = nil
        }
        
        // Start connection timeout
        startConnectionTimeout(connectionId: connectionId)
        
        do {
            let result: WalletConnectionResult
            
            switch walletType {
            case .metamask:
                // Try different connection methods based on a flag
                if ProcessInfo.processInfo.environment["USE_METAMASK_CONNECT_AND_SIGN"] == "true" {
                    print("💰 WalletService: Using connectAndSign method")
                    result = try await connectMetaMaskWithSignature()
                } else {
                    print("💰 WalletService: Using standard connect then sign method")
                    result = try await connectMetaMask()
                }
            case .coinbase:
                result = try await connectCoinbaseWallet()
            case .walletConnect:
                result = try await connectWalletConnect()
            case .google, .apple:
                throw WalletError.unsupportedWallet("Social authentication should use AuthenticationManager")
            case .safe, .ledger, .trezor, .unknown:
                throw WalletError.unsupportedWallet("Wallet type \(walletType.rawValue) not yet supported")
            }
            
            await MainActor.run {
                connectionStatus = .connected
                connectedWallet = walletType
                walletAddress = result.address
            }
            
            // Clear connection state on success
            resetConnectionState(error: nil)
            
            return result
        } catch let walletError as WalletError {
            // Clear connection state on error
            resetConnectionState(error: walletError)
            
            await MainActor.run {
                connectionStatus = .disconnected
                connectedWallet = nil
                walletAddress = nil
                error = walletError
            }
            throw walletError
        } catch {
            // Clear connection flags on error
            isConnectionInProgress = false
            isAuthenticationFlow = false
            
            let walletError = WalletError.connectionFailed(error.localizedDescription)
            await MainActor.run {
                connectionStatus = .disconnected
                connectedWallet = nil
                walletAddress = nil
                self.error = walletError
            }
            throw walletError
        }
    }
    
    // MARK: - MetaMask Connection
    
    private func connectMetaMask() async throws -> WalletConnectionResult {
        print("💰 WalletService: Starting MetaMask connection")
        
        // Ensure SDK is initialized before connecting
        if !isInitialized {
            print("💰 WalletService: SDK not initialized, performing lazy initialization")
            await initializeSDKsIfNeeded()
        }
        
        guard let sdk = metamaskSDK else {
            print("💰 WalletService: MetaMask SDK not initialized")
            throw WalletError.sdkNotInitialized
        }
        
        // Check if MetaMask is available
        if !canOpenMetaMask() {
            print("💰 WalletService: MetaMask app not installed or not available")
            throw WalletError.connectionFailed("MetaMask app is not installed. Please install MetaMask from the App Store.")
        }
        
        // Check current SDK state
        print("💰 WalletService: Current SDK account: \(sdk.account.isEmpty ? "none" : sdk.account)")
        print("💰 WalletService: Connection status: \(connectionStatus)")
        print("💰 WalletService: Is authentication flow: \(isAuthenticationFlow)")
        
        // For authentication flows, we MUST start with a clean state
        // This prevents issues with stale connections from previous sessions
        if isAuthenticationFlow && !sdk.account.isEmpty {
            print("💰 WalletService: Authentication flow detected with existing account, clearing first")
            await sdk.disconnect()
            sdk.clearSession()
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            print("💰 WalletService: Cleared stale connection, ready for fresh auth")
        }
        
        // Now proceed with connection
        if !sdk.account.isEmpty {
            print("💰 WalletService: WARNING: SDK still has account after clearing: \(sdk.account)")
        }
        
        // Always connect for authentication
        print("💰 WalletService: Initiating MetaMask connection...")
        
        let connectResult = await sdk.connect()
        
        print("💰 WalletService: Connect result received")
        print("💰 WalletService: Current account after connect: \(sdk.account.isEmpty ? "none" : sdk.account)")
        
        switch connectResult {
        case .success:
            print("💰 WalletService: Connection successful")
        case .failure(let error):
            print("💰 WalletService: MetaMask connection failed: \(error)")
            
            // Check if user cancelled
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user denied") || errorMessage.contains("cancelled") || errorMessage.contains("rejected") {
                resetConnectionState(error: nil)
                throw WalletError.userCancelled
            }
            
            resetConnectionState(error: nil)
            throw WalletError.connectionFailed(error.localizedDescription)
        }
        
        // At this point, we should be connected (either already connected or just connected)
        guard !sdk.account.isEmpty else {
            print("💰 WalletService: No account available after connection attempt")
            throw WalletError.noAccountsFound
        }
        
        let account = sdk.account
        print("💰 WalletService: Account ready for signing: \(account)")
        
        // Store the current account to detect changes
        let initialAccount = account
        
        // Get SIWE nonce from backend
        let nonce = try await getSIWENonce()
        print("💰 WalletService: Got SIWE nonce: \(nonce)")
        
        // Create SIWE message following EIP-4361
        let message = createSIWEMessage(
            address: account,
            nonce: nonce,
            chainId: 1 // Ethereum mainnet, adjust as needed
        )
        print("💰 WalletService: Created SIWE message")
        
        // Now request signature - format params correctly
        let signRequest = EthereumRequest(
            method: .personalSign,
            params: [message, account] // message first, then account
        )
        
        print("💰 WalletService: Requesting signature for message...")
        print("💰 WalletService: Sending personal_sign request to MetaMask")
        print("💰 WalletService: Account: \(account)")
        print("💰 WalletService: Message length: \(message.count) characters")
        
        print("💰 WalletService: Opening MetaMask for signature...")
        
        let signResult = await sdk.request(signRequest)
        
        print("💰 WalletService: Received response from MetaMask")
        
        // Check if account changed during signing
        if sdk.account != initialAccount {
            print("💰 WalletService: Account changed during signing! Initial: \(initialAccount), Current: \(sdk.account)")
            // Disconnect and throw error
            await sdk.disconnect()
            // Clear our state as well
            await MainActor.run {
                self.connectionStatus = .disconnected
                self.connectedWallet = nil
                self.walletAddress = nil
            }
            throw WalletError.connectionFailed("The selected account has changed. Please try connecting again.")
        }
        
        switch signResult {
        case .success(let signature):
            print("💰 WalletService: Signature received")
            
            // Extract signature string
            let signatureString: String
            if let sig = signature as? String {
                signatureString = sig
            } else {
                print("💰 WalletService: Invalid signature format")
                throw WalletError.signatureFailed("Invalid signature format")
            }
            
            guard !signatureString.isEmpty else {
                print("💰 WalletService: Empty signature from MetaMask")
                throw WalletError.signatureFailed("Empty signature")
            }
            
            let connectionResult = WalletConnectionResult(
                address: account,
                signature: signatureString,
                message: message,
                walletType: .metamask
            )
            
            print("💰 WalletService: MetaMask connection successful")
            print("💰 WalletService: Address: \(account)")
            print("💰 WalletService: Signature: \(signatureString.prefix(20))...")
            return connectionResult
            
        case .failure(let error):
            print("💰 WalletService: MetaMask signature failed: \(error)")
            
            // Check if this is a user rejection
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user denied") || errorMessage.contains("user rejected") || errorMessage.contains("cancelled") {
                // User cancelled - disconnect to ensure clean state
                await sdk.disconnect()
                // Clear connection flags immediately on cancellation
                isConnectionInProgress = false
                isAuthenticationFlow = false
                throw WalletError.userCancelled
            }
            
            // If signature fails, disconnect to ensure clean state for retry
            await sdk.disconnect()
            await MainActor.run {
                self.connectionStatus = .disconnected
                self.connectedWallet = nil
                self.walletAddress = nil
            }
            
            // Check if the error message indicates account change
            if errorMessage.contains("account") || errorMessage.contains("changed") || errorMessage.contains("selected") {
                throw WalletError.connectionFailed("The selected account has changed. Please try connecting again.")
            } else {
                throw WalletError.signatureFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Alternative MetaMask Connection Method
    
    private func connectMetaMaskWithSignature() async throws -> WalletConnectionResult {
        print("💰 WalletService: Starting MetaMask connectAndSign")
        guard let sdk = metamaskSDK else {
            print("💰 WalletService: MetaMask SDK not initialized")
            throw WalletError.sdkNotInitialized
        }
        
        // Check if MetaMask is available
        if !canOpenMetaMask() {
            print("💰 WalletService: MetaMask app not installed or not available")
            throw WalletError.connectionFailed("MetaMask app is not installed. Please install MetaMask from the App Store.")
        }
        
        // Create message for authentication
        let timestamp = Int(Date().timeIntervalSince1970)
        let message = "Welcome to Interspace!\n\nSign this message to authenticate your wallet.\n\nTimestamp: \(timestamp)"
        print("💰 WalletService: Message to sign: \(message)")
        
        // Use connectAndSign
        print("💰 WalletService: Using connectAndSign method...")
        let result = await sdk.connectAndSign(message: message)
        
        switch result {
        case .success(let signature):
            print("💰 WalletService: ConnectAndSign successful")
            
            // Get the connected account
            let account = sdk.account
            guard !account.isEmpty else {
                print("💰 WalletService: No account found after connectAndSign")
                throw WalletError.noAccountsFound
            }
            
            let connectionResult = WalletConnectionResult(
                address: account,
                signature: signature,
                message: message,
                walletType: .metamask
            )
            
            print("💰 WalletService: MetaMask connection successful")
            print("💰 WalletService: Address: \(account)")
            print("💰 WalletService: Signature: \(signature.prefix(20))...")
            return connectionResult
            
        case .failure(let error):
            print("💰 WalletService: ConnectAndSign failed: \(error)")
            throw WalletError.connectionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - SIWE Helper Methods
    
    private func getSIWENonce() async throws -> String {
        // Call backend to get SIWE nonce
        let url = URL(string: "\(APIService.shared.getBaseURL())/siwe/nonce")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add ngrok headers if using ngrok URL
        if url.absoluteString.contains("ngrok") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WalletError.networkError("Failed to get nonce: HTTP \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(NonceResponse.self, from: data)
        
        guard result.success, let nonce = result.data?.nonce else {
            throw WalletError.networkError(result.error ?? "Failed to get nonce")
        }
        
        return nonce
    }
    
    private func createSIWEMessage(address: String, nonce: String, chainId: Int) -> String {
        let domain = "interspace.fi"
        let uri = "https://interspace.fi"
        let version = "1"
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let statement = "Sign in with Ethereum to Interspace"
        
        // Format according to EIP-4361
        var message = "\(domain) wants you to sign in with your Ethereum account:\n"
        message += "\(address)\n\n"
        message += "\(statement)\n\n"
        message += "URI: \(uri)\n"
        message += "Version: \(version)\n"
        message += "Chain ID: \(chainId)\n"
        message += "Nonce: \(nonce)\n"
        message += "Issued At: \(issuedAt)"
        
        return message
    }
    
    // MARK: - Coinbase Wallet Connection
    
    private func connectCoinbaseWallet() async throws -> WalletConnectionResult {
        print("💰 WalletService: Coinbase Wallet connection temporarily disabled")
        
        // Return an error indicating Coinbase is coming soon
        throw WalletError.connectionFailed("Coinbase Wallet integration is coming soon. Please use MetaMask or another supported wallet for now.")
    }
    
    // MARK: - WalletConnect Connection
    
    private func connectWalletConnect() async throws -> WalletConnectionResult {
        guard isWalletKitConfigured else {
            throw WalletError.sdkNotInitialized
        }
        
        // This will trigger the UI to show the scanner
        throw WalletError.qrCodeScanRequired
    }
    
    // Method to handle scanned WalletConnect URI
    func connectWithWalletConnectURI(_ uri: String) async throws -> WalletConnectionResult {
        guard isWalletKitConfigured else {
            throw WalletError.sdkNotInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                // Parse the WalletConnect URI
                guard uri.hasPrefix("wc:") else {
                    continuation.resume(throwing: WalletError.connectionFailed("Invalid WalletConnect URI"))
                    return
                }
                
                // For now, we'll return a mock result since the full WalletConnect implementation
                // requires proper session handling and approval flow
                // TODO: Implement proper WalletConnect session management
                
                let mockResult = WalletConnectionResult(
                    address: "0x_walletconnect_address",
                    signature: "0x_walletconnect_signature",
                    message: "WalletConnect authentication",
                    walletType: .walletConnect
                )
                
                continuation.resume(returning: mockResult)
            }
        }
    }
    
    // Method to handle session proposals (would be called from AppDelegate/SceneDelegate)
    // TODO: Implement proper WalletConnect integration with reown-swift
    /*
    func handleSessionProposal(_ proposal: Session.Proposal) async throws -> WalletConnectionResult {
        // Auto-approve the session for simplicity
        // In production, you'd show a UI to let the user approve/reject
        
        // For now, we'll create a mock implementation
        // The correct API should be researched from the reown-swift documentation
        
        // try await WalletKit.instance.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
        
        // For now, we'll use a mock address
        let address = "0x_mock_address"
        
        // Create a message to sign for authentication
        let message = "Welcome to Interspace! Sign this message to authenticate.\n\nTimestamp: \(Date().timeIntervalSince1970)"
        
        // For now, we'll return a mock signature
        // In production, you'd need to implement the actual signing flow
        let result = WalletConnectionResult(
            address: address,
            signature: "0x_mock_signature", // This should be actual signature
            message: message,
            walletType: .walletConnect
        )
        
        return result
    }
    */
    
    // MARK: - Disconnect
    
    func disconnect() async {
        print("💰 WalletService: Starting disconnect process")
        
        // Clear connection flags
        isConnectionInProgress = false
        isAuthenticationFlow = false
        
        // Update UI state immediately
        await MainActor.run {
            connectionStatus = .disconnected
            connectedWallet = nil
            walletAddress = nil
            error = nil
        }
        
        // Reset SDKs
        if let sdk = metamaskSDK {
            print("💰 WalletService: Disconnecting MetaMask SDK")
            print("💰 WalletService: Account before disconnect: \(sdk.account.isEmpty ? "none" : sdk.account)")
            
            // First try disconnect
            await sdk.disconnect()
            
            // If account still exists, use clearSession as shown in MetaMask reference
            if !sdk.account.isEmpty {
                print("💰 WalletService: Account still exists after disconnect, using clearSession()")
                sdk.clearSession()
            }
            
            // Give MetaMask time to clear its state
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("💰 WalletService: MetaMask final state - account: \(sdk.account.isEmpty ? "cleared" : "still connected: \(sdk.account)")")
        }
        
        // Coinbase SDK reset temporarily disabled
        // print("💰 WalletService: Resetting Coinbase session")
        // coinbaseSDK.resetSession()
        
        // Disconnect WalletConnect sessions
        // TODO: Implement proper WalletConnect disconnect when API is available
        /*
        if isWalletKitConfigured {
            Task {
                for session in WalletKit.instance.getSessions() {
                    try? await WalletKit.instance.disconnect(topic: session.topic)
                }
            }
        }
        */
        
        print("💰 WalletService: Disconnect completed")
    }
    
    // MARK: - Wallet Availability
    
    func isWalletAvailable(_ walletType: WalletType) -> Bool {
        switch walletType {
        case .metamask:
            return canOpenMetaMask()
        case .coinbase:
            return canOpenCoinbaseWallet()
        case .walletConnect:
            return true // Always available as it uses QR codes
        case .google, .apple:
            return true // Social authentication is always available
        case .safe, .ledger, .trezor, .unknown:
            return false // Not yet supported
        }
    }
    
    private func canOpenMetaMask() -> Bool {
        // Check multiple URL schemes that MetaMask might use
        let schemes = ["metamask://", "metamask-app://", "https://metamask.app.link"]
        
        for scheme in schemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                print("💰 WalletService: MetaMask found with scheme: \(scheme)")
                return true
            }
        }
        
        print("💰 WalletService: MetaMask not found with any known schemes")
        return false
    }
    
    private func canOpenCoinbaseWallet() -> Bool {
        // Coinbase integration temporarily disabled
        print("💰 WalletService: Coinbase Wallet availability check - disabled (coming soon)")
        return false
    }
    
    // MARK: - Connection State Management
    
    private func resetConnectionState(error: WalletError?) {
        print("💰 WalletService: Resetting connection state")
        
        // Cancel timeout task
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        // Reset flags
        isConnectionInProgress = false
        isAuthenticationFlow = false
        currentConnectionId = nil
        connectionStartTime = nil
        
        // Update UI state if there's an error
        if let error = error {
            Task { @MainActor in
                self.connectionStatus = .disconnected
                self.connectedWallet = nil
                self.walletAddress = nil
                self.error = error
            }
        }
    }
    
    private func startConnectionTimeout(connectionId: String) {
        // Cancel any existing timeout
        connectionTimeoutTask?.cancel()
        
        // Start new timeout
        connectionTimeoutTask = Task {
            // Warning after 15 seconds
            try? await Task.sleep(nanoseconds: UInt64(connectionWarningTime * 1_000_000_000))
            
            // Check if this connection is still active
            guard currentConnectionId == connectionId, isConnectionInProgress else { return }
            
            print("⚠️ WalletService: Connection taking longer than usual...")
            
            // Final timeout after 30 seconds total
            try? await Task.sleep(nanoseconds: UInt64((connectionTimeout - connectionWarningTime) * 1_000_000_000))
            
            // Check again if this connection is still active
            guard currentConnectionId == connectionId, isConnectionInProgress else { return }
            
            print("❌ WalletService: Connection timeout reached")
            await MainActor.run {
                self.resetConnectionState(error: WalletError.connectionFailed("Connection timed out. Please try again."))
            }
        }
    }
    
    func forceResetConnection() {
        print("💰 WalletService: Force resetting connection")
        resetConnectionState(error: nil)
        
        // Also clear any MetaMask state
        if let sdk = metamaskSDK {
            Task {
                await sdk.disconnect()
                sdk.clearSession()
            }
        }
    }
}

// MARK: - Supporting Types

enum WalletConnectionStatus {
    case disconnected
    case connecting
    case connected
}

struct WalletConnectionResult {
    let address: String
    let signature: String
    let message: String
    let walletType: WalletType
}

enum WalletError: LocalizedError, Identifiable {
    case sdkNotInitialized
    case connectionFailed(String)
    case signatureFailed(String)
    case noAccountsFound
    case userCancelled
    case unsupportedWallet(String)
    case networkError(String)
    case qrCodeScanRequired
    
    var id: String {
        switch self {
        case .sdkNotInitialized:
            return "sdkNotInitialized"
        case .connectionFailed(let message):
            return "connectionFailed_\(message)"
        case .signatureFailed(let message):
            return "signatureFailed_\(message)"
        case .noAccountsFound:
            return "noAccountsFound"
        case .userCancelled:
            return "userCancelled"
        case .unsupportedWallet(let wallet):
            return "unsupportedWallet_\(wallet)"
        case .networkError(let message):
            return "networkError_\(message)"
        case .qrCodeScanRequired:
            return "qrCodeScanRequired"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Wallet SDK not initialized"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .signatureFailed(let message):
            return "Signature failed: \(message)"
        case .noAccountsFound:
            return "No wallet accounts found"
        case .userCancelled:
            return "User cancelled the operation"
        case .unsupportedWallet(let wallet):
            return "Unsupported wallet: \(wallet)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .qrCodeScanRequired:
            return "QR code scan required"
        }
    }
}

// MARK: - Response Types

private struct NonceResponse: Codable {
    let success: Bool
    let data: NonceData?
    let error: String?
}

private struct NonceData: Codable {
    let nonce: String
}
