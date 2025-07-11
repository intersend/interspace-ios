import Foundation
import Combine
import metamask_ios_sdk
import CoinbaseWalletSDK
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
    internal let walletConnectService = WalletConnectService.shared
    private let walletConnectSessionManager = WalletConnectSessionManager.shared
    
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
            async let coinbaseSetup: Void = setupCoinbaseSDKAsync()
            
            // Wait for both SDKs to complete
            _ = await (metamaskSetup, coinbaseSetup)
            
            // Setup WalletConnect
            setupWalletConnect()
            
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
    
    /// Setup Coinbase SDK asynchronously
    private func setupCoinbaseSDKAsync() async {
        setupCoinbaseSDK()
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
        // Coinbase SDK is configured in AppDelegate
        print("💰 WalletService: Coinbase SDK ready (configured in AppDelegate)")
    }
    
    // MARK: - WalletConnect Setup
    
    private func setupWalletConnect() {
        // Get project ID from Info.plist or environment
        var projectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECT_PROJECT_ID") as? String ?? ""
        
        print("💰 WalletService: WalletConnect Project ID from Info.plist: '\(projectId)'")
        
        // Fallback to hardcoded value if not configured properly
        if projectId.isEmpty || projectId == "$(WALLETCONNECT_PROJECT_ID)" {
            print("⚠️ WalletService: Info.plist not configured, using hardcoded project ID")
            // This is the project ID from BuildConfiguration.xcconfig
            projectId = "936ce227c0152a29bdeef7d68794b0ac"
        }
        
        guard !projectId.isEmpty && projectId != "YOUR_PROJECT_ID" else {
            print("⚠️ WalletService: WalletConnect Project ID not properly configured")
            return
        }
        
        // WalletConnectService handles its own initialization
        // Just mark as configured if project ID exists
        isWalletKitConfigured = true
        
        print("✅ WalletService: WalletConnect configured with project ID: \(projectId)")
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
        
        // Haptic feedback for connection start
        await MainActor.run {
            HapticManager.impact(.light)
        }
        
        // Perform preflight checks
        let preflightResult = await PreflightCheckManager.shared.performChecks(for: walletType)
        
        if !preflightResult.passed {
            print("❌ WalletService: Preflight checks failed")
            await MainActor.run {
                HapticManager.notification(.error)
            }
            
            if let blockingIssue = preflightResult.issues.first(where: { $0.severity == .blocking }) {
                let walletError = WalletError.connectionFailed(blockingIssue.resolution ?? blockingIssue.message)
                await MainActor.run {
                    self.error = walletError
                }
                throw walletError
            }
        }
        
        // Show warnings if any
        if let warning = preflightResult.issues.first(where: { $0.severity == .warning }) {
            print("⚠️ WalletService: Preflight warning: \(warning.message)")
        }
        
        // Check if a connection is already in progress
        if isConnectionInProgress {
            // Check if it's a stuck connection
            if let startTime = connectionStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 10 { // If stuck for more than 10 seconds, allow retry
                    print("💰 WalletService: Previous connection appears stuck (\(elapsed)s), allowing retry")
                    resetConnectionState(error: nil as WalletError?)
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
            // Haptic feedback for state change
            HapticManager.impact(.medium)
        }
        
        // Start connection timeout
        startConnectionTimeout(connectionId: connectionId)
        
        do {
            let result: WalletConnectionResult
            
            switch walletType {
            case .metamask:
                // Always use connectAndSign for SIWE authentication
                // This is more reliable than the two-step process
                print("💰 WalletService: Using connectAndSign method for SIWE")
                result = try await connectMetaMaskWithSIWE()
            case .coinbase:
                result = try await connectCoinbaseWallet()
            case .walletConnect, .rainbow, .trust, .argent, .gnosisSafe, .family, .phantom, .oneInch, .zerion, .imToken, .tokenPocket, .spot, .omni:
                // All WalletConnect-compatible wallets use the same connection method
                result = try await connectWalletConnectType(walletType)
            case .google, .apple:
                throw WalletError.unsupportedWallet("Social authentication should use AuthenticationManagerV2")
            case .mpc:
                throw WalletError.unsupportedWallet("MPC wallets should use MPCWalletService")
            case .safe, .ledger, .trezor, .unknown:
                throw WalletError.unsupportedWallet("Wallet type \(walletType.rawValue) not yet supported")
            }
            
            await MainActor.run {
                connectionStatus = .connected
                connectedWallet = walletType
                walletAddress = result.address
                // Success haptic
                HapticManager.notification(.success)
            }
            
            // Clear connection state on success
            resetConnectionState(error: nil as WalletError?)
            
            return result
        } catch let walletError as WalletError {
            // Clear connection state on error
            resetConnectionState(error: walletError)
            
            await MainActor.run {
                connectionStatus = .disconnected
                connectedWallet = nil
                walletAddress = nil
                error = walletError
                // Error haptic
                HapticManager.notification(.error)
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
                // Error haptic
                HapticManager.notification(.error)
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
            sdk.disconnect()
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
        print("💰 WalletService: Current time: \(Date())")
        
        let connectResult = await sdk.connect()
        
        print("💰 WalletService: Connect result received at: \(Date())")
        print("💰 WalletService: Current account after connect: \(sdk.account.isEmpty ? "none" : sdk.account)")
        
        switch connectResult {
        case .success:
            print("💰 WalletService: Connection successful")
        case .failure(let error):
            print("💰 WalletService: MetaMask connection failed: \(error)")
            
            // Check if user cancelled
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user denied") || errorMessage.contains("cancelled") || errorMessage.contains("rejected") {
                resetConnectionState(error: nil as WalletError?)
                throw WalletError.userCancelled
            }
            
            resetConnectionState(error: nil as WalletError?)
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
            sdk.disconnect()
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
            
            // Extract signature string (signature is already String type)
            let signatureString = signature
            
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
                sdk.disconnect()
                // Clear connection flags immediately on cancellation
                isConnectionInProgress = false
                isAuthenticationFlow = false
                throw WalletError.userCancelled
            }
            
            // If signature fails, disconnect to ensure clean state for retry
            sdk.disconnect()
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
    
    // MARK: - MetaMask SIWE Connection Method
    
    private func connectMetaMaskWithSIWE() async throws -> WalletConnectionResult {
        print("💰 WalletService: Starting MetaMask SIWE authentication with connectAndSign")
        
        // Ensure SDK is initialized
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
        
        // For authentication flow, ensure clean state
        // This is important because we want a fresh connection for authentication
        if !sdk.account.isEmpty {
            print("💰 WalletService: Clearing existing connection for fresh authentication")
            sdk.disconnect()
            sdk.clearSession()
            // Give SDK time to clear
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Get SIWE nonce from backend first
        let nonce: String
        do {
            nonce = try await getSIWENonce()
            print("💰 WalletService: Got SIWE nonce: \(nonce)")
        } catch {
            print("💰 WalletService: Failed to get SIWE nonce: \(error)")
            throw WalletError.networkError("Failed to get authentication nonce")
        }
        
        // For initial connection, we can't use connectAndSign directly because
        // it requires an existing connection. We need to use the two-step process:
        // 1. Connect to get the user's MetaMask address
        // 2. Sign the SIWE message with that address
        
        print("💰 WalletService: Step 1: Connecting to MetaMask...")
        let connectResult = await sdk.connect()
        
        switch connectResult {
        case .success:
            print("💰 WalletService: Connection successful")
            
            // Get the connected account (user's MetaMask address)
            guard !sdk.account.isEmpty else {
                print("💰 WalletService: No account found after connection")
                throw WalletError.noAccountsFound
            }
            
            let userAddress = sdk.account
            print("💰 WalletService: Connected to user's MetaMask account: \(userAddress)")
            
            // Now create the proper SIWE message with the user's address
            let siweMessage = createSIWEMessage(
                address: userAddress,
                nonce: nonce,
                chainId: 1 // Ethereum mainnet
            )
            print("💰 WalletService: Created SIWE message for user's address")
            
            // Step 2: Sign the SIWE message
            print("💰 WalletService: Step 2: Requesting signature...")
            let signRequest = EthereumRequest(
                method: .personalSign,
                params: [siweMessage, userAddress] // message first, then address
            )
            
            let signResult = await sdk.request(signRequest)
            
            switch signResult {
            case .success(let signature):
                print("💰 WalletService: Signature received successfully")
                
                let connectionResult = WalletConnectionResult(
                    address: userAddress,
                    signature: signature,
                    message: siweMessage,
                    walletType: .metamask
                )
                
                print("💰 WalletService: SIWE authentication complete")
                print("💰 WalletService: User's address: \(userAddress)")
                print("💰 WalletService: Signature: \(signature.prefix(20))...")
                
                return connectionResult
                
            case .failure(let error):
                print("💰 WalletService: Signature failed: \(error)")
                sdk.disconnect()
                
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("user denied") || errorMessage.contains("cancelled") || errorMessage.contains("rejected") {
                    throw WalletError.userCancelled
                }
                throw WalletError.signatureFailed(error.localizedDescription)
            }
            
        case .failure(let error):
            print("💰 WalletService: MetaMask connection failed: \(error)")
            
            // Check if user cancelled
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user denied") || errorMessage.contains("cancelled") || errorMessage.contains("rejected") {
                // Clear connection flags on user cancellation
                isConnectionInProgress = false
                isAuthenticationFlow = false
                throw WalletError.userCancelled
            }
            
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
        print("💰 WalletService: Starting Coinbase Wallet connection")
        
        // Check if Coinbase Wallet is installed
        if !canOpenCoinbaseWallet() {
            print("💰 WalletService: Coinbase Wallet app not installed")
            throw WalletError.connectionFailed("Coinbase Wallet app is not installed. Please install Coinbase Wallet from the App Store.")
        }
        
        // Get SIWE nonce from backend
        let nonce = try await getSIWENonce()
        print("💰 WalletService: Got SIWE nonce: \(nonce)")
        
        // Create SIWE message (address will be updated after we get it)
        let message = createSIWEMessage(
            address: "pending", // Will be replaced with actual address
            nonce: nonce,
            chainId: 1 // Ethereum mainnet
        )
        
        // Create a personal sign request that includes both account request and signing
        let request = Request(actions: [
            Action(jsonRpc: .eth_requestAccounts),
            Action(jsonRpc: .personal_sign(address: "", message: message))
        ])
        
        print("💰 WalletService: Making request to Coinbase Wallet...")
        
        // Make the request using continuation for async/await
        let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BaseMessage<[ActionResult]>, Error>) in
            CoinbaseWalletSDK.shared.makeRequest(request) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        print("💰 WalletService: Received response from Coinbase Wallet")
        
        // Check we have both responses
        guard response.content.count >= 2 else {
            print("💰 WalletService: Invalid response count: \(response.content.count)")
            throw WalletError.connectionFailed("Invalid response from Coinbase Wallet")
        }
        
        // Extract account from first response
        let accountResult = response.content[0]
        guard case .success(let accountJSON) = accountResult else {
            if case .failure(let error) = accountResult {
                print("💰 WalletService: Account request failed: \(error.message)")
                if error.code == 4001 { // User rejected
                    throw WalletError.userCancelled
                }
            }
            throw WalletError.noAccountsFound
        }
        
        // Decode the JSON response to get addresses
        struct AccountResponse: Codable {
            let result: [String]
        }
        
        let accountResponse = try? accountJSON.decode(as: AccountResponse.self)
        guard let addresses = accountResponse?.result, !addresses.isEmpty else {
            print("💰 WalletService: Failed to decode addresses from response")
            throw WalletError.noAccountsFound
        }
        
        let address = addresses[0]
        print("💰 WalletService: Got address: \(address)")
        
        // Update SIWE message with actual address
        let finalMessage = createSIWEMessage(
            address: address,
            nonce: nonce,
            chainId: 1
        )
        
        // Extract signature from second response
        let signResult = response.content[1]
        guard case .success(let signJSON) = signResult else {
            if case .failure(let error) = signResult {
                print("💰 WalletService: Sign request failed: \(error.message)")
                if error.code == 4001 { // User rejected
                    throw WalletError.userCancelled
                }
            }
            throw WalletError.signatureFailed("Failed to get signature")
        }
        
        // Decode the signature response
        struct SignResponse: Codable {
            let result: String
        }
        
        let signResponse = try? signJSON.decode(as: SignResponse.self)
        guard let signature = signResponse?.result else {
            print("💰 WalletService: Failed to decode signature from response")
            throw WalletError.signatureFailed("Failed to decode signature")
        }
        
        print("💰 WalletService: Got signature: \(signature.prefix(20))...")
        
        let connectionResult = WalletConnectionResult(
            address: address,
            signature: signature,
            message: finalMessage,
            walletType: .coinbase
        )
        
        print("💰 WalletService: Coinbase Wallet connection successful")
        return connectionResult
    }
    
    // MARK: - WalletConnect Connection
    
    private func connectWalletConnect() async throws -> WalletConnectionResult {
        guard isWalletKitConfigured else {
            throw WalletError.sdkNotInitialized
        }
        
        // Use the new deep linking approach, passing the specific wallet type
        return try await handleWalletConnected(walletType: connectedWallet ?? .walletConnect)
    }
    
    private func connectWalletConnectType(_ walletType: WalletType) async throws -> WalletConnectionResult {
        guard isWalletKitConfigured else {
            throw WalletError.sdkNotInitialized
        }
        
        // Use the new deep linking approach with the specific wallet type
        return try await handleWalletConnected(walletType: walletType)
    }
    
    // Method to handle scanned WalletConnect URI
    func connectWithWalletConnectURI(_ uri: String) async throws -> WalletConnectionResult {
        print("💰 WalletService: connectWithWalletConnectURI called for SIWE auth")
        
        // Initialize SDKs if needed
        await initializeSDKsIfNeeded()
        
        print("💰 WalletService: isWalletKitConfigured = \(isWalletKitConfigured)")
        
        guard isWalletKitConfigured else {
            print("❌ WalletService: WalletConnect SDK not initialized - throwing error")
            throw WalletError.sdkNotInitialized
        }
        
        print("💰 WalletService: Connecting with WalletConnect URI for SIWE")
        
        // Connect using WalletConnectService for authentication
        try await walletConnectService.connectForAuth(uri: uri)
        
        // Wait for session to be established
        var attempts = 0
        while await walletConnectService.sessions.isEmpty && attempts < 30 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        guard let session = await walletConnectService.sessions.first else {
            throw WalletError.connectionFailed("Failed to establish WalletConnect session")
        }
        
        // Get wallet address from the connected session
        guard let address = await walletConnectService.getConnectedAddress() else {
            throw WalletError.noAccountsFound
        }
        
        print("💰 WalletService: Connected wallet address: \(address)")
        
        // Get SIWE nonce and create message
        let nonce = try await getSIWENonce()
        let message = createSIWEMessage(address: address, nonce: nonce, chainId: 1)
        
        // Sign SIWE message via WalletConnect
        print("💰 WalletService: Requesting SIWE signature via WalletConnect")
        let signature = try await walletConnectService.signSIWEMessage(message, address: address, session: session)
        
        // Clean up the temporary WalletConnect session after getting signature
        await walletConnectService.cleanupAuthSession()
        
        // Create connection result
        let result = WalletConnectionResult(
            address: address,
            signature: signature,
            message: message,
            walletType: .walletConnect
        )
        
        // Update UI state
        await MainActor.run {
            self.connectionStatus = .connected
            self.connectedWallet = .walletConnect
            self.walletAddress = address
        }
        
        print("💰 WalletService: WalletConnect SIWE authentication successful")
        return result
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
            sdk.disconnect()
            
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
        if isWalletKitConfigured {
            Task {
                await walletConnectService.disconnect()
                // No need to refresh sessions for SIWE-only implementation
            }
        }
        
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
        case .mpc:
            return true // MPC wallets are always available
        case .safe, .ledger, .trezor, .unknown:
            return false // Not yet supported
        default:
            // Use the new WalletDeepLinkGenerator for all WalletConnect-based wallets
            return WalletDeepLinkGenerator.shared.isWalletInstalled(walletType)
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
        if let url = URL(string: "cbwallet://"), UIApplication.shared.canOpenURL(url) {
            print("💰 WalletService: Coinbase Wallet is installed")
            return true
        }
        print("💰 WalletService: Coinbase Wallet is not installed")
        return false
    }
    
    private func canOpenWallet(scheme: String) -> Bool {
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            print("💰 WalletService: Wallet with scheme \(scheme) is installed")
            return true
        }
        print("💰 WalletService: Wallet with scheme \(scheme) is not installed")
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
        resetConnectionState(error: nil as WalletError?)
        
        // Also clear any MetaMask state
        if let sdk = metamaskSDK {
            Task {
                sdk.disconnect()
                sdk.clearSession()
            }
        }
    }
    
    // MARK: - Deep Linking
    
    /// Open wallet app with deep link
    @MainActor
    func openWalletWithDeepLink(walletType: WalletType, uri: String) {
        print("📱 WalletService: Opening wallet app with deep link for \(walletType.displayName)")
        print("📱 WalletService: URI: \(uri)")
        
        // Use the new WalletDeepLinkGenerator
        let deepLinkGenerator = WalletDeepLinkGenerator.shared
        let deepLinkResult = deepLinkGenerator.generateDeepLinks(for: walletType, uri: uri)
        
        // Handle generic WalletConnect type
        if walletType == .walletConnect {
            let walletApps = getAvailableWalletApps()
            if walletApps.isEmpty {
                print("❌ WalletService: No compatible wallet apps found")
                showNoWalletInstalledAlert()
                return
            }
            // For generic WalletConnect, we already have logic in getAvailableWalletApps
            // Just use the first available wallet
        }
        
        // Check if wallet supports WalletConnect
        if !WalletConfiguration.supportsWalletConnect(walletType) {
            print("❌ WalletService: \(walletType.displayName) does not support WalletConnect")
            showWalletOpenFailedAlert(walletType: walletType)
            return
        }
        
        // Open wallet using the deep link generator
        deepLinkGenerator.openWallet(with: deepLinkResult) { success in
            if success {
                print("📱 WalletService: Successfully opened \(walletType.displayName)")
            } else {
                print("❌ WalletService: Failed to open \(walletType.displayName)")
                // The generator already handles fallback to App Store
            }
        }
    }
    
    // Note: tryPhantomUniversalLink is now handled by WalletDeepLinkGenerator
    
    /// Show alert when wallet app is not installed
    @MainActor
    private func showWalletNotInstalledAlert(walletType: WalletType) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "\(walletType.displayName) Not Found",
            message: "The \(walletType.displayName) app doesn't appear to be installed. Would you like to view it on the App Store?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View on App Store", style: .default) { _ in
            if let appStoreUrl = self.getAppStoreUrl(for: walletType),
               let url = URL(string: appStoreUrl) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Show alert when no wallet apps are installed
    @MainActor
    private func showNoWalletInstalledAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "No Wallet Apps Found",
            message: "You need a crypto wallet app to continue. Would you like to browse wallet apps on the App Store?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Browse Wallets", style: .default) { _ in
            // Open App Store search for crypto wallets
            if let url = URL(string: "https://apps.apple.com/search?term=crypto+wallet") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Show alert when wallet connection fails
    @MainActor
    private func showWalletOpenFailedAlert(walletType: WalletType) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Connection Failed",
            message: "Unable to open \(walletType.displayName). Please make sure the app is installed and try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Get App Store URL for wallet apps
    private func getAppStoreUrl(for walletType: WalletType) -> String? {
        switch walletType {
        case .trust:
            return "https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409"
        case .rainbow:
            return "https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021"
        case .metamask:
            return "https://apps.apple.com/app/metamask-blockchain-wallet/id1438144202"
        case .argent:
            return "https://apps.apple.com/app/argent/id1358741926"
        case .coinbase:
            return "https://apps.apple.com/app/coinbase-wallet/id1278383455"
        case .zerion:
            return "https://apps.apple.com/app/zerion-wallet/id1456732565"
        case .oneInch:
            return "https://apps.apple.com/app/1inch-defi-wallet/id1546049391"
        case .imToken:
            return "https://apps.apple.com/app/imtoken-crypto-wallet/id1153230571"
        case .phantom:
            return "https://apps.apple.com/app/phantom-crypto-wallet/id1598432977"
        default:
            return nil
        }
    }
    
    /// Get available wallet apps installed on device
    func getAvailableWalletApps() -> [WalletAppInfo] {
        let walletApps = [
            WalletAppInfo(name: "Rainbow", scheme: "rainbow", icon: "rainbow"),
            WalletAppInfo(name: "Trust Wallet", scheme: "trust", icon: "trust"),
            WalletAppInfo(name: "Argent", scheme: "argent", icon: "argent"),
            WalletAppInfo(name: "Gnosis Safe", scheme: "gnosissafe", icon: "safe"),
            WalletAppInfo(name: "MetaMask", scheme: "metamask", icon: "metamask"),
            WalletAppInfo(name: "Family", scheme: "family", icon: "family"),
            WalletAppInfo(name: "Phantom", scheme: "phantom", icon: "phantom"),
            WalletAppInfo(name: "1inch Wallet", scheme: "oneinch", icon: "oneinch"),
            WalletAppInfo(name: "Zerion", scheme: "zerion", icon: "zerion"),
            WalletAppInfo(name: "imToken", scheme: "imtoken", icon: "imtoken"),
            WalletAppInfo(name: "TokenPocket", scheme: "tokenpocket", icon: "tokenpocket"),
            WalletAppInfo(name: "Spot", scheme: "spot", icon: "spot"),
            WalletAppInfo(name: "Omni", scheme: "omni", icon: "omni")
        ]
        
        // Filter to only installed apps
        return walletApps.filter { app in
            if let url = URL(string: "\(app.scheme)://") {
                return UIApplication.shared.canOpenURL(url)
            }
            return false
        }
    }
    
    /// Handle wallet connection for WalletConnect with deep linking
    func handleWalletConnected(walletType: WalletType = .walletConnect) async throws -> WalletConnectionResult {
        print("📱 WalletService: Handling WalletConnect connection for \(walletType.displayName)")
        
        // Clean up any existing sessions before creating a new one
        await walletConnectService.disconnect()
        
        // Small delay to ensure cleanup is complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Store the actual wallet type for later use
        self.connectedWallet = walletType
        
        // Check if wallet supports Link Mode
        let supportsLinkMode = [WalletType.trust, .family, .phantom, .zerion].contains(walletType)
        
        if supportsLinkMode && walletConnectService.useLinkMode {
            print("🔗 WalletService: Using Link Mode for \(walletType.displayName)")
            
            // Use Link Mode connection
            let linkModeURI = try await walletConnectService.connectWithLinkMode(walletType: walletType)
            
            // Open wallet app with Link Mode deep link
            await openWalletWithDeepLink(walletType: walletType, uri: linkModeURI)
            
            // For Link Mode, we wait for the response via deep link callback
            // The session will be established through the Link Mode response
            return try await waitForLinkModeResponse()
        } else {
            // Use standard WalletConnect flow
            print("📱 WalletService: Using standard WalletConnect for \(walletType.displayName)")
            
            // Generate WalletConnect URI
            let uri = try await walletConnectService.connectToWallet()
            
            // Open wallet app with deep link (must be on main thread)
            await openWalletWithDeepLink(walletType: walletType, uri: uri)
        }
        
        // Wait for session to be established
        var attempts = 0
        while await walletConnectService.sessions.isEmpty && attempts < 60 { // 30 seconds timeout
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        guard let session = await walletConnectService.sessions.first else {
            throw WalletError.connectionFailed("Failed to establish WalletConnect session")
        }
        
        // Get wallet address
        guard let address = await walletConnectService.getConnectedAddress() else {
            throw WalletError.noAccountsFound
        }
        
        print("📱 WalletService: Connected to wallet: \(address)")
        
        // Create SIWE message
        let nonce = try await getSIWENonce()
        let message = createSIWEMessage(address: address, nonce: nonce, chainId: 1)
        
        // Sign SIWE message
        let signature = try await walletConnectService.signSIWEMessage(message, address: address, session: session)
        
        // Clean up session after authentication
        await walletConnectService.cleanupAuthSession()
        
        // Update UI state
        await MainActor.run {
            self.connectionStatus = .connected
            self.connectedWallet = .walletConnect
            self.walletAddress = address
        }
        
        return WalletConnectionResult(
            address: address,
            signature: signature,
            message: message,
            walletType: .walletConnect
        )
    }
    
    // MARK: - Transaction Methods
    
    /// Send a transaction using the active wallet account
    func sendTransaction(
        to address: String,
        value: String? = nil,
        data: String? = nil,
        chainId: String = "1"
    ) async throws {
        // Get the active wallet from the profile
        guard let activeProfile = await SessionCoordinator.shared.activeProfile else {
            throw WalletError.noSession
        }
        
        // Check if user has linked wallet accounts
        // For now, we'll need to check linked accounts through a different approach
        // since SmartProfile doesn't contain linkedAccounts directly
        guard activeProfile.linkedAccountsCount > 0 else {
            throw WalletError.noAccountsFound
        }
        
        // For now, we'll use a placeholder since we need to fetch linked accounts separately
        // This would require accessing ProfileViewModel or making an API call
        let walletAddress = "0x0000000000000000000000000000000000000000" // Placeholder
        
        // TODO: Properly fetch linked accounts for the active profile
        // This should be done through ProfileViewModel.shared.linkedAccounts
        throw WalletError.noAccountsFound
        
        // Determine wallet type - placeholder for now
        let walletType = WalletType.metamask // Default
        
        // Open the wallet app with transaction deeplink
        let deepLinkGenerator = WalletDeepLinkGenerator.shared
        
        await withCheckedContinuation { continuation in
            deepLinkGenerator.openWalletForTransaction(
                walletType: walletType,
                to: address,
                value: value,
                data: data,
                chainId: chainId
            ) { success in
                if success {
                    print("💰 WalletService: Transaction deeplink opened successfully")
                } else {
                    print("❌ WalletService: Failed to open transaction deeplink")
                }
                continuation.resume()
            }
        }
    }
    
    /// Wait for Link Mode response
    private func waitForLinkModeResponse() async throws -> WalletConnectionResult {
        print("🔗 WalletService: Waiting for Link Mode response...")
        
        // Set up a timeout for Link Mode response
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            throw WalletError.timeout("Link Mode connection timed out")
        }
        
        // Wait for Link Mode response notification
        return try await withCheckedThrowingContinuation { continuation in
            var observer: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .linkModeAuthCompleted,
                object: nil,
                queue: .main
            ) { notification in
                timeoutTask.cancel()
                
                if let userInfo = notification.userInfo,
                   let address = userInfo["address"] as? String,
                   let signature = userInfo["signature"] as? String,
                   let message = userInfo["message"] as? String {
                    
                    // Remove observer
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs)
                    }
                    
                    let result = WalletConnectionResult(
                        address: address,
                        signature: signature,
                        message: message,
                        walletType: self.connectedWallet ?? .walletConnect
                    )
                    
                    continuation.resume(returning: result)
                } else if let error = notification.userInfo?["error"] as? Error {
                    // Remove observer
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs)
                    }
                    
                    continuation.resume(throwing: error)
                } else {
                    // Remove observer
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs)
                    }
                    
                    continuation.resume(throwing: WalletError.connectionFailed("Invalid Link Mode response"))
                }
            }
            
            // Handle timeout
            Task {
                do {
                    try await timeoutTask.value
                    // If we reach here, it means timeout occurred
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs)
                    }
                    continuation.resume(throwing: WalletError.timeout("Link Mode response timed out"))
                } catch {
                    // Task was cancelled, which means we got a response
                }
            }
        }
    }
    
    /// Determine wallet type from linked account
    private func determineWalletType(from account: LinkedAccount) -> WalletType {
        // Check the account authStrategy and walletType
        if let walletTypeString = account.walletType?.lowercased() {
            switch walletTypeString {
            case "metamask":
                return .metamask
            case "coinbase":
                return .coinbase
            case "trust":
                return .trust
            case "family":
                return .family
            case "phantom":
                return .phantom
            case "zerion":
                return .zerion
            case "rainbow":
                return .rainbow
            case "argent":
                return .argent
            default:
                return .walletConnect
            }
        }
        
        // Default to WalletConnect
        return .walletConnect
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

// WalletError is now defined in WalletErrors.swift as WalletConnectionError
// The type alias in WalletErrors.swift provides backward compatibility

// MARK: - Response Types
// NonceResponse and NonceData are defined in SIWEModels.swift

// MARK: - Notification Names

extension Notification.Name {
    static let linkModeAuthCompleted = Notification.Name("linkModeAuthCompleted")
}
