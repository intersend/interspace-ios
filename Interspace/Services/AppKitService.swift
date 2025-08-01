import Foundation
import SwiftUI
import ReownAppKit
import WalletConnectNetworking
import WalletConnectSign
import WalletConnectRelay
import WalletConnectUtils
import Combine

/// Auth event for external consumption
struct AppKitAuthEvent {
    let address: String
    let signature: String
    let message: String
    let isAuthenticated: Bool
}

/// Authentication flow state for tracking multi-step wallet connections
enum AuthFlowState: Equatable {
    case idle
    case connecting
    case awaitingSiwe
    case authenticating
    case complete
    case failed(String)
}

/// Simple AppKit service following official Reown examples
@MainActor
final class AppKitService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppKitService()
    
    // MARK: - Constants
    
    /// Properly formatted dummy signature for bypassing SIWE
    /// Format: 0x + 65 bytes (130 hex characters)
    /// - r: 32 bytes (64 hex chars)
    /// - s: 32 bytes (64 hex chars)
    /// - v: 1 byte (2 hex chars)
    private let dummySignature = "0x" + String(repeating: "0", count: 130)
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var address: String?
    @Published var isConfigured: Bool = false
    @Published var isModalPresented: Bool = false
    @Published var authenticationFlowState: AuthFlowState = .idle
    @Published var siweMessage: String?
    @Published var siweSignature: String?
    @Published var isAuthenticating: Bool = false
    @Published var authEvent: AppKitAuthEvent?
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var bindingsSetUp = false
    private let authEventPublisher = PassthroughSubject<AppKitAuthEvent, Never>()
    private var lastProcessedAuthId: RPCID?
    private var lastSignature: String?
    private var signatureReuseCount: Int = 0
    private var modalCheckTimer: Timer?
    private var lastSIWEMessage: String?
    private var currentSession: Session?
    
    // MARK: - Initialization
    
    private init() {
        // Don't set up bindings here - wait until after configure()
    }
    
    // MARK: - Configuration
    
    /// Configure AppKit with project metadata
    func configure() {
        guard !isConfigured else { 
            print("⚠️ AppKitService: Already configured, skipping")
            return 
        }
        
        print("🔧 AppKitService: Starting configuration...")
        
        // Get project ID from configuration
        guard let projectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECT_PROJECT_ID") as? String,
              !projectId.isEmpty else {
            print("❌ AppKitService: Missing WALLETCONNECT_PROJECT_ID in configuration")
            print("❌ AppKitService: Bundle keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "none")")
            return
        }
        
        print("🔧 AppKitService: Configuring with project ID: \(projectId)")
        
        // Initialize metadata
        let metadata = AppMetadata(
            name: "Interspace",
            description: "The unified social app for web3",
            url: "https://interspace.fi",
            icons: ["https://interspace.fi/icon.png"],
            redirect: try! .init(native: "interspace://", universal: "https://interspace.fi", linkMode: true)
        )
        
        print("🔧 AppKitService: Created metadata: \(metadata.name)")
        
        // Configure networking with simple socket factory (following example pattern)
        print("🔧 AppKitService: Configuring Networking...")
        Networking.configure(
            groupIdentifier: "group.com.interspace.walletconnect",
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )
        print("✅ AppKitService: Networking configured")
        
        // CRITICAL WARNING: AppKit.configure() MUST be called before ANY access to AppKit.instance
        // This includes AppKit.instance.logger, publishers, or any other instance properties.
        // Accessing AppKit.instance before configure() will cause a FATAL ERROR:
        // "Fatal error: Error - you must call AppKit.configure(_:) before accessing the shared instance."
        // Many AI agents and developers miss this - ALWAYS configure first!
        
        // Create auth request params for One-Click Auth
        var authRequestParams: AuthRequestParams? = nil
        do {
            // Create auth params with a placeholder nonce (will be replaced when modal opens)
            authRequestParams = try AuthRequestParams(
                domain: "interspace.fi",
                chains: ["eip155:1"],
                nonce: "placeholder", // Will be updated when modal opens
                uri: "https://interspace.fi",
                nbf: nil,
                exp: nil,
                statement: "Sign in to Interspace",
                requestId: nil,
                resources: nil,
                methods: ["personal_sign", "eth_sendTransaction"]
            )
            print("🔧 AppKitService: Created authRequestParams for One-Click Auth")
        } catch {
            print("⚠️ AppKitService: Failed to create authRequestParams: \(error)")
        }
        
        // Configure AppKit using the official example pattern
        print("🔧 AppKitService: Configuring AppKit...")
        AppKit.configure(
            projectId: projectId,
            metadata: metadata,
            crypto: DefaultCryptoProvider(),
            authRequestParams: nil // Disable One-Click Auth for now - use traditional flow
        ) { error in
            print("❌ AppKitService: Configuration error: \(error)")
        }
        
        isConfigured = true
        print("✅ AppKitService: Configuration completed successfully")
        
        // Enable debug logging for all components - MUST be after AppKit.configure()
        print("🔧 AppKitService: Enabling debug logging...")
        AppKit.instance.logger.setLogging(level: .debug)
        Sign.instance.setLogging(level: .debug)
        Networking.instance.setLogging(level: .debug)
        Relay.instance.setLogging(level: .debug)
        print("✅ AppKitService: Debug logging enabled")
        
        // Set up bindings after configuration (only for initial config)
        if !bindingsSetUp {
            print("🔧 AppKitService: Setting up bindings...")
            setupBindings()
            bindingsSetUp = true
            print("✅ AppKitService: Bindings set up")
        }
    }
    
    
    // MARK: - SIWE Authentication
    
    /// Fetch SIWE nonce from backend
    private func fetchSIWENonce() async throws -> String {
        let authAPI = AuthAPI.shared
        let response = try await authAPI.getSIWENonceV2()
        return response.data.nonce
    }
    
    /// Trigger SIWE authentication after session establishment
    private func triggerSIWEAuthentication() async {
        print("🔏 AppKitService: Triggering SIWE authentication...")
        print("🔏 AppKitService: ========== SIWE REQUEST START ==========")
        
        // Check if we're already authenticated or authenticating
        guard !isAuthenticating else {
            print("⚠️ AppKitService: Already authenticating, skipping...")
            return
        }
        
        // Get the current address
        guard let address = getAddress() else {
            print("❌ AppKitService: No address available for SIWE")
            return
        }
        
        print("🔏 AppKitService: Starting SIWE for address: \(address)")
        isAuthenticating = true
        
        do {
            // Fetch fresh nonce
            let nonce = try await fetchSIWENonce()
            print("🔏 AppKitService: Got nonce: \(nonce)")
            
            // Create SIWE message
            let message = SIWEMessageBuilder.buildSimpleMessage(
                address: address,
                nonce: nonce,
                chainId: 1
            )
            
            print("🔏 AppKitService: Created SIWE message")
            print("🔏 AppKitService: Message length: \(message.count)")
            print("🔏 AppKitService: ========== SIWE MESSAGE ==========")
            print(message)
            print("🔏 AppKitService: ========== END MESSAGE ==========")
            print("🔏 AppKitService: Message hash: \(message.data(using: .utf8)?.sha256().toHexString() ?? "unknown")")
            
            // Store the message for session response handler
            self.siweMessage = message
            self.lastSIWEMessage = message
            
            // Request personal_sign using the existing session
            print("🔏 AppKitService: Requesting personal_sign...")
            print("🔏 AppKitService: The signature will come through sessionResponsePublisher")
            
            // The request method returns void - the actual response comes through the publisher
            try await AppKit.instance.request(.personal_sign(address: address, message: message))
            
            print("🔏 AppKitService: Personal sign request sent successfully")
            
            // Launch the current wallet to keep user in wallet for signing
            print("🚀 AppKitService: Launching current wallet for SIWE signing...")
            AppKit.instance.launchCurrentWallet()
            
            // Modal will be dismissed when launching wallet, but we're still in the flow
            isModalPresented = false
            
            print("🔏 AppKitService: Waiting for signature response in sessionResponsePublisher...")
            
            // The signature will be handled in sessionResponsePublisher
            // Don't reset isAuthenticating here - it will be reset when we get the response
            
        } catch {
            print("❌ AppKitService: SIWE authentication failed: \(error)")
            isAuthenticating = false
        }
        
        print("🔏 AppKitService: ========== SIWE REQUEST END ==========")
    }
    
    // MARK: - Modal Presentation
    
    /// Present the AppKit modal
    func presentModal() {
        print("🎭 AppKitService: presentModal() called")
        print("🎭 AppKitService: Current flow state: \(authenticationFlowState)")
        
        guard isConfigured else {
            print("⚠️ AppKitService: Not configured, configuring now...")
            configure()
            
            // Try again after configuration
            if isConfigured {
                print("🎭 AppKitService: Retrying modal presentation after configuration")
                presentModal()
            }
            return
        }
        
        print("🎭 AppKitService: About to present modal")
        print("🎭 AppKitService: Current sessions: \(AppKit.instance.getSessions().count)")
        print("🎭 AppKitService: Is connected: \(isConnected)")
        
        // Check if we're in the middle of authentication flow
        switch authenticationFlowState {
        case .awaitingSiwe:
            print("🎭 AppKitService: Re-presenting modal for SIWE completion")
            isModalPresented = true
            AppKit.present()
            // The SIWE flow will continue automatically
            return
            
        case .connecting, .authenticating:
            print("🎭 AppKitService: Authentication already in progress, re-presenting modal")
            isModalPresented = true
            AppKit.present()
            return
            
        case .complete:
            print("🎭 AppKitService: Previous authentication complete, resetting for new connection")
            resetAuthenticationFlow()
            // Continue with normal flow
            
        default:
            break
        }
        
        // Always start fresh - disconnect any existing session
        print("🎭 AppKitService: Always starting fresh - disconnecting any existing session")
        
        Task { @MainActor in
            // Disconnect existing session if connected
            if isConnected {
                print("🎭 AppKitService: Disconnecting existing session...")
                do {
                    try await disconnect()
                    print("✅ AppKitService: Disconnected successfully")
                } catch {
                    print("⚠️ AppKitService: Error disconnecting: \(error)")
                }
                
                // Small delay to ensure disconnection completes
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Reset authentication flow state
            resetAuthenticationFlow()
            
            // Now present the modal
            self.authenticationFlowState = .connecting
            self.isModalPresented = true
            self.startModalCheckTimer()
            
            print("🎭 AppKitService: Presenting modal with fresh session")
            AppKit.present()
        }
        
        print("✅ AppKitService: Modal presentation called")
    }
    
    /// Present modal from specific view controller
    func presentModal(from viewController: UIViewController) {
        print("🎭 AppKitService: presentModal(from:) called")
        
        guard isConfigured else {
            print("⚠️ AppKitService: Not configured, configuring now...")
            configure()
            
            // Try again after configuration
            if isConfigured {
                print("🎭 AppKitService: Retrying modal presentation after configuration")
                presentModal(from: viewController)
            }
            return
        }
        
        print("🎭 AppKitService: Always starting fresh - disconnecting any existing session")
        
        Task { @MainActor in
            // Disconnect existing session if connected
            if isConnected {
                print("🎭 AppKitService: Disconnecting existing session...")
                do {
                    try await disconnect()
                    print("✅ AppKitService: Disconnected successfully")
                } catch {
                    print("⚠️ AppKitService: Error disconnecting: \(error)")
                }
                
                // Small delay to ensure disconnection completes
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Reset authentication flow state
            resetAuthenticationFlow()
            
            // Now present the modal
            self.authenticationFlowState = .connecting
            self.isModalPresented = true
            self.startModalCheckTimer()
            
            print("🎭 AppKitService: Presenting modal from view controller with fresh session")
            print("🎭 AppKitService: View controller: \(type(of: viewController))")
            
            AppKit.present(from: viewController)
            
            print("✅ AppKitService: Modal presentation from VC called")
        }
    }
    
    // MARK: - Modal Management
    
    /// Check if modal needs to be re-presented
    func checkAndRepresentModalIfNeeded() {
        print("🔍 AppKitService: Checking if modal needs re-presentation")
        print("🔍 AppKitService: Current flow state: \(authenticationFlowState)")
        print("🔍 AppKitService: Is modal presented: \(isModalPresented)")
        print("🔍 AppKitService: Is connected: \(isConnected)")
        
        // Check if we're in a state where modal should be shown but isn't
        switch authenticationFlowState {
        case .connecting, .awaitingSiwe, .authenticating:
            // Check if modal is not visible
            if !isModalVisible() {
                print("🔄 AppKitService: Modal not visible - re-presenting modal")
                isModalPresented = false // Reset flag since modal was dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.presentModal()
                }
            }
        default:
            break
        }
    }
    
    /// Check if AppKit modal is currently visible
    private func isModalVisible() -> Bool {
        // Check if there's a presented view controller that looks like AppKit modal
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return false
        }
        
        // Check for presented view controller
        var currentVC = rootVC
        while let presented = currentVC.presentedViewController {
            currentVC = presented
            // Check if this is likely the AppKit modal
            if String(describing: type(of: currentVC)).contains("Web3Modal") ||
               String(describing: type(of: currentVC)).contains("AppKit") {
                return true
            }
        }
        
        return false
    }
    
    /// Reset authentication flow
    func resetAuthenticationFlow() {
        print("🔄 AppKitService: Resetting authentication flow")
        authenticationFlowState = .idle
        isModalPresented = false
        isAuthenticating = false
        siweMessage = nil
        siweSignature = nil
        stopModalCheckTimer()
    }
    
    /// Force reset connection state
    func forceResetConnection() async {
        print("🔄 AppKitService: Force resetting connection")
        
        // Reset all state
        resetAuthenticationFlow()
        
        // Disconnect if connected
        if isConnected {
            try? await disconnect()
        }
        
        // Clear cached state
        address = nil
        isConnected = false
    }
    
    /// Start monitoring for modal dismissal
    private func startModalCheckTimer() {
        stopModalCheckTimer() // Stop any existing timer
        
        print("⏰ AppKitService: Starting modal check timer")
        modalCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAndRepresentModalIfNeeded()
        }
    }
    
    /// Stop monitoring for modal dismissal
    private func stopModalCheckTimer() {
        modalCheckTimer?.invalidate()
        modalCheckTimer = nil
        print("⏰ AppKitService: Stopped modal check timer")
    }
    
    // MARK: - Connection Management
    
    /// Get current connected address
    func getAddress() -> String? {
        // First try to get from our stored address (which is filtered for Ethereum)
        if let storedAddress = self.address {
            print("🔍 AppKitService: getAddress() -> \(storedAddress) (from stored)")
            return storedAddress
        }
        
        // Fallback to AppKit's method
        let address = AppKit.instance.getAddress()
        print("🔍 AppKitService: getAddress() -> \(address ?? "nil") (from AppKit)")
        
        // Validate it's an Ethereum address
        if let addr = address, addr.starts(with: "0x") && addr.count == 42 {
            return addr
        }
        
        return nil
    }
    
    /// Disconnect current session
    func disconnect() async throws {
        print("🔌 AppKitService: disconnect() called")
        
        // Get the current session topic
        guard let session = AppKit.instance.getSessions().first else {
            print("⚠️ AppKitService: No session to disconnect")
            // Still reset state even if no session
            resetAuthenticationFlow()
            return
        }
        
        print("🔌 AppKitService: Disconnecting session topic: \(session.topic)")
        
        try await AppKit.instance.disconnect(topic: session.topic)
        address = nil
        isConnected = false
        
        // Reset authentication flow state
        resetAuthenticationFlow()
        
        print("✅ AppKitService: Disconnected successfully")
    }
    
    /// Handle deep link
    func handleDeepLink(_ url: URL) -> Bool {
        print("🔗 AppKitService: handleDeepLink() called with URL: \(url.absoluteString)")
        let handled = AppKit.instance.handleDeeplink(url)
        print("🔗 AppKitService: Deep link handled: \(handled)")
        return handled
    }
    
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        print("🔧 AppKitService: Setting up event bindings...")
        
        // Monitor session changes
        AppKit.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                print("📱 AppKitService: Sessions changed - count: \(sessions.count)")
                
                let connected = !sessions.isEmpty
                self?.isConnected = connected
                
                if connected, let session = sessions.first {
                    print("📱 AppKitService: Session info:")
                    print("  - Topic: \(session.topic)")
                    print("  - Namespaces: \(session.namespaces.keys.joined(separator: ", "))")
                    
                    // Extract Ethereum address specifically from eip155 namespace
                    if let eip155Namespace = session.namespaces["eip155"],
                       let ethereumAccount = eip155Namespace.accounts.first(where: { account in
                           // Ensure it's an Ethereum mainnet or compatible chain
                           let chainId = account.reference
                           return ["1", "137", "10", "42161", "8453", "56", "43114"].contains(chainId)
                       }) {
                        self?.address = ethereumAccount.address
                        print("📱 AppKitService: Connected with Ethereum address: \(ethereumAccount.address)")
                        print("  - Blockchain: \(ethereumAccount.blockchain)")
                        print("  - Chain ID: \(ethereumAccount.reference)")
                    } else {
                        // Fallback to any eip155 address if no mainnet address found
                        if let eip155Namespace = session.namespaces["eip155"],
                           let anyEthereumAccount = eip155Namespace.accounts.first {
                            self?.address = anyEthereumAccount.address
                            print("📱 AppKitService: Connected with Ethereum address (any chain): \(anyEthereumAccount.address)")
                            print("  - Blockchain: \(anyEthereumAccount.blockchain)")
                            print("  - Chain ID: \(anyEthereumAccount.reference)")
                        } else {
                            // Check if user connected with wrong chain type
                            if session.namespaces.keys.contains("solana") {
                                print("❌ AppKitService: Wrong chain type - Solana wallet detected")
                                print("❌ AppKitService: Please connect with an Ethereum wallet instead")
                                
                                // Show error to user
                                NotificationCenter.default.post(
                                    name: .appKitWrongChainType,
                                    object: nil,
                                    userInfo: ["chainType": "solana", "message": "Please connect with an Ethereum wallet"]
                                )
                                
                                // Disconnect the wrong chain
                                Task { @MainActor in
                                    try? await self?.disconnect()
                                }
                            } else {
                                print("⚠️ AppKitService: No Ethereum address found in session")
                                print("⚠️ AppKitService: Available namespaces: \(session.namespaces.keys.joined(separator: ", "))")
                            }
                            self?.address = nil
                        }
                    }
                } else {
                    self?.address = nil
                    print("📱 AppKitService: Disconnected - no sessions")
                }
            }
            .store(in: &cancellables)
        
        // Monitor socket connection status
        AppKit.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
                print("🔌 AppKitService: Socket status changed to: \(status)")
            }
            .store(in: &cancellables)
        
        // Monitor session settlement and trigger direct authentication
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                print("✅ AppKitService: Session settled!")
                print("  - Topic: \(session.topic)")
                print("  - Peer: \(session.peer.name)")
                print("  - Namespaces: \(session.namespaces.keys.joined(separator: ", "))")
                
                // Store session for metadata access
                self?.currentSession = session
                
                // Update flow state
                self?.authenticationFlowState = .authenticating
                
                // Directly authenticate without SIWE
                Task { @MainActor in
                    await self?.performDirectAuthentication()
                }
            }
            .store(in: &cancellables)
        
        // Monitor session rejection
        AppKit.instance.sessionRejectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { (proposal, reason) in
                print("❌ AppKitService: Session rejected!")
                print("  - Proposal ID: \(proposal.id)")
                print("  - Reason: \(reason.message)")
            }
            .store(in: &cancellables)
        
        // Monitor session deletion
        AppKit.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { (topic, reason) in
                print("🗑️ AppKitService: Session deleted!")
                print("  - Topic: \(topic)")
                print("  - Reason: \(reason.message)")
            }
            .store(in: &cancellables)
        
        // Monitor session responses (disabled for direct auth flow)
        /*
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                print("📨 AppKitService: Session response received")
                print("📨 AppKitService: ========== RESPONSE DETAILS ==========")
                print("  - Topic: \(response.topic)")
                print("  - Chain ID: \(response.chainId ?? "none")")
                
                switch response.result {
                case .response(let value):
                    print("  - Success - Response type: \(type(of: value))")
                    
                    // Check if this is a string response (personal_sign signature)
                    if let signature = value.stringValue {
                        print("✅ AppKitService: Received signature from personal_sign!")
                        print("  - Signature: \(signature.prefix(20))...")
                        print("  - Full signature: \(signature)")
                        
                        // Check for signature reuse
                        if let lastSig = self?.lastSignature, lastSig == signature {
                            self?.signatureReuseCount += 1
                            print("⚠️ AppKitService: SIGNATURE REUSE DETECTED!")
                            print("⚠️ AppKitService: Same signature used \(self?.signatureReuseCount ?? 0) times")
                            print("⚠️ AppKitService: This will cause authentication to fail!")
                        } else {
                            self?.lastSignature = signature
                            self?.signatureReuseCount = 1
                        }
                        
                        // Get the current address
                        if let address = self?.address {
                            print("📨 AppKitService: Have address: \(address)")
                            
                            // Use the stored SIWE message if available
                            if let siweMessage = self?.siweMessage {
                                print("📨 AppKitService: Using stored SIWE message")
                                Task { @MainActor in
                                    await self?.performAuthentication(address: address, signature: signature, message: siweMessage)
                                    // Reset authentication flag after processing
                                    self?.isAuthenticating = false
                                }
                            } else {
                                print("⚠️ AppKitService: No SIWE message available, signature response ignored")
                                print("⚠️ AppKitService: This response might be from a different request")
                            }
                        } else {
                            print("⚠️ AppKitService: No address available for authentication")
                        }
                    } else {
                        print("  - Response value: \(value)")
                        print("  - Response value type: \(type(of: value))")
                    }
                    
                case .error(let error):
                    print("  - Error: \(error)")
                }
                
                print("📨 AppKitService: ========== END RESPONSE ==========")
            }
            .store(in: &cancellables)
        */
        
        // Monitor auth responses (One-Click Auth)
        AppKit.instance.authResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (id: RPCID, result: Result<(Session?, [Cacao]), AuthError>) in
                print("🔐 AppKitService: Auth response received")
                print("  - ID: \(id)")
                
                // Debounce: Check if we've already processed this auth response
                if self?.lastProcessedAuthId == id {
                    print("  - Already processed this auth response, skipping...")
                    return
                }
                self?.lastProcessedAuthId = id
                
                switch result {
                case .success(let (session, cacaos)):
                    print("  - Success: Session: \(session?.topic ?? "nil"), Cacaos: \(cacaos.count)")
                    if let cacao = cacaos.first {
                        self?.handleAuthResponse(session: session, cacao: cacao, id: id)
                    }
                case .failure(let error):
                    print("  - Error: \(error)")
                    self?.authEvent = AppKitAuthEvent(
                        address: "",
                        signature: "",
                        message: "",
                        isAuthenticated: false
                    )
                }
            }
            .store(in: &cancellables)
        
        // Monitor SIWE authentication (disabled for direct auth flow)
        /*
        AppKit.instance.SIWEAuthenticationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                print("🔏 AppKitService: SIWE authentication event received")
                print("🔏 AppKitService: ========== SIWE AUTH FLOW START ==========")
                
                switch result {
                case .success(let (message, signature)):
                    print("🔏 AppKitService: SIWE Success!")
                    print("🔏 AppKitService: Message length: \(message.count)")
                    print("🔏 AppKitService: Signature length: \(signature.count)")
                    print("🔏 AppKitService: Current address: \(self?.address ?? "none")")
                    
                    self?.siweMessage = message
                    self?.siweSignature = signature
                    self?.isAuthenticating = false
                    
                    // Get the address
                    guard let address = self?.address else {
                        print("❌ AppKitService: No address available for SIWE auth")
                        return
                    }
                    
                    // DIRECTLY TRIGGER AUTHENTICATION HERE
                    print("🔏 AppKitService: Starting backend authentication from SIWE publisher...")
                    Task { @MainActor in
                        await self?.performAuthentication(address: address, signature: signature, message: message)
                    }
                    
                    // Post notification for legacy compatibility
                    NotificationCenter.default.post(
                        name: .appKitSIWEAuthenticated,
                        object: nil,
                        userInfo: [
                            "message": message,
                            "signature": signature,
                            "address": address
                        ]
                    )
                    
                case .failure(let error):
                    print("❌ AppKitService: SIWE authentication failed: \(error)")
                    self?.isAuthenticating = false
                    
                    // Post notification for authentication failure
                    NotificationCenter.default.post(
                        name: .appKitSIWEFailed,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
                
                print("🔏 AppKitService: ========== SIWE AUTH FLOW END ==========")
            }
            .store(in: &cancellables)
        */
        
        print("✅ AppKitService: All event bindings set up")
    }
    
    private func handleAuthResponse(session: Session?, cacao: Cacao, id: RPCID) {
        print("🔐 AppKitService: Processing CACAO auth response for ID: \(id)")
        print("🔐 AppKitService: ========== AUTH FLOW START ==========")
        
        // Extract wallet address from CACAO payload ISS (did:pkh format)
        // Format: did:pkh:eip155:1:0x...
        let issComponents = cacao.p.iss.split(separator: ":")
        let address = issComponents.last.map(String.init) ?? ""
        
        print("🔐 AppKitService: Raw ISS: \(cacao.p.iss)")
        print("🔐 AppKitService: Extracted address: \(address)")
        
        // Extract signature
        let signature = cacao.s.s
        print("🔐 AppKitService: Signature length: \(signature.count)")
        print("🔐 AppKitService: Signature preview: \(String(signature.prefix(20)))...")
        
        // Reconstruct SIWE message from CACAO payload
        let formatter = SIWEFromCacaoPayloadFormatter()
        do {
            let message = try formatter.formatMessage(from: cacao.p)
            print("🔐 AppKitService: Formatted SIWE message successfully")
            print("🔐 AppKitService: Message length: \(message.count)")
            
            // Check if this is a duplicate event
            if let existingEvent = self.authEvent,
               existingEvent.address.lowercased() == address.lowercased() &&
               existingEvent.signature == signature {
                print("⚠️ AppKitService: Duplicate auth event detected, skipping...")
                return
            }
            
            // Create auth event
            let event = AppKitAuthEvent(
                address: address,
                signature: signature,
                message: message,
                isAuthenticated: true
            )
            
            print("🔐 AppKitService: Publishing auth event...")
            self.authEvent = event
            self.authEventPublisher.send(event)
            
            print("✅ AppKitService: Auth event published to publisher")
            
            // DIRECTLY TRIGGER AUTHENTICATION HERE
            print("🔐 AppKitService: Starting authentication with backend...")
            Task { @MainActor in
                await self.performAuthentication(address: address, signature: signature, message: message)
            }
            
        } catch {
            print("❌ AppKitService: Failed to format SIWE message: \(error)")
            
            // Check for duplicate even in error case
            if let existingEvent = self.authEvent,
               existingEvent.address.lowercased() == address.lowercased() &&
               existingEvent.signature == signature {
                print("⚠️ AppKitService: Duplicate auth event detected, skipping...")
                return
            }
            
            // Still try to authenticate with raw data
            let event = AppKitAuthEvent(
                address: address,
                signature: signature,
                message: cacao.p.statement ?? "",
                isAuthenticated: true
            )
            
            print("🔐 AppKitService: Publishing auth event with raw data...")
            self.authEvent = event
            self.authEventPublisher.send(event)
            
            // Try authentication with raw statement
            print("🔐 AppKitService: Starting authentication with raw statement...")
            Task { @MainActor in
                await self.performAuthentication(address: address, signature: signature, message: cacao.p.statement ?? "")
            }
        }
        
        print("🔐 AppKitService: ========== AUTH FLOW END ==========")
    }
    
    /// Perform direct authentication without SIWE signature
    private func performDirectAuthentication() async {
        print("🔑 AppKitService: performDirectAuthentication() called")
        
        guard let address = getAddress() else {
            print("❌ AppKitService: No address available for authentication")
            authenticationFlowState = .failed("No wallet address available")
            return
        }
        
        print("🔑 AppKitService: Address: \(address)")
        
        // Check if we're already authenticated (for account linking)
        let authManager = AuthenticationManagerV2.shared
        let isAuthenticated = authManager.isAuthenticated
        
        if isAuthenticated {
            print("🔗 AppKitService: User already authenticated, performing account linking")
            await performAccountLinking(address: address)
        } else {
            print("🔐 AppKitService: User not authenticated, performing authentication")
            await performAuthentication(address: address, signature: dummySignature, message: "Wallet connection approved")
        }
    }
    
    /// Perform account linking for authenticated users
    private func performAccountLinking(address: String) async {
        print("🔗 AppKitService: performAccountLinking() called")
        print("🔗 AppKitService: Address: \(address)")
        
        do {
            // Get active profile
            guard let activeProfile = SessionCoordinator.shared.activeProfile else {
                print("❌ AppKitService: No active profile found")
                authenticationFlowState = .failed("No active profile")
                return
            }
            
            print("🔗 AppKitService: Linking to profile: \(activeProfile.name)")
            
            // Extract wallet metadata from session
            var walletName = "Wallet"
            var walletIcon: String? = nil
            var walletMetadata: [String: Any] = [:]
            
            if let session = currentSession {
                walletName = session.peer.name
                
                // Extract icon URL from peer metadata
                if !session.peer.icons.isEmpty {
                    walletIcon = session.peer.icons.first
                }
                
                walletMetadata = [
                    "name": walletName,
                    "icon": walletIcon ?? ""
                ]
                
                print("🔗 AppKitService: Wallet metadata - Name: \(walletName), Icon: \(walletIcon ?? "none")")
            }
            
            // Create link request with dummy signature and metadata
            let linkRequest = LinkAccountRequest(
                address: address,
                walletType: walletName.lowercased().replacingOccurrences(of: " ", with: ""),
                customName: walletName,
                isPrimary: false,
                signature: dummySignature,
                message: "Wallet connection approved",
                chainId: 1,
                metadata: try? String(data: JSONSerialization.data(withJSONObject: walletMetadata), encoding: .utf8)
            )
            
            // Link the account
            let linkedAccount = try await ProfileAPI.shared.linkAccount(
                profileId: activeProfile.id,
                request: linkRequest
            )
            
            print("✅ AppKitService: Account linked successfully!")
            print("✅ AppKitService: Linked account ID: \(linkedAccount.id)")
            
            // Update flow state
            authenticationFlowState = .complete
            isModalPresented = false
            stopModalCheckTimer()
            
            // Refresh profile data
            await ProfileViewModel.shared.refreshProfile()
            
            // Post success notification
            NotificationCenter.default.post(
                name: .appKitAccountLinked,
                object: nil,
                userInfo: ["address": address, "accountId": linkedAccount.id]
            )
            
        } catch {
            print("❌ AppKitService: Account linking failed: \(error)")
            authenticationFlowState = .failed(error.localizedDescription)
            stopModalCheckTimer()
        }
    }
    
    /// Perform authentication with our backend
    private func performAuthentication(address: String, signature: String, message: String) async {
        print("🔑 AppKitService: performAuthentication() called")
        print("🔑 AppKitService: Address: \(address)")
        print("🔑 AppKitService: Message length: \(message.count)")
        print("🔑 AppKitService: Signature length: \(signature.count)")
        print("🔑 AppKitService: Signature format: \(signature.hasPrefix("0x") ? "Valid hex (0x prefix)" : "Invalid format")")
        
        // Compare with last SIWE message if available
        if let lastMessage = lastSIWEMessage {
            if lastMessage == message {
                print("✅ AppKitService: Message matches the one sent to wallet")
            } else {
                print("❌ AppKitService: MESSAGE MISMATCH!")
                print("❌ AppKitService: Expected message hash: \(lastMessage.data(using: .utf8)?.sha256().toHexString() ?? "unknown")")
                print("❌ AppKitService: Received message hash: \(message.data(using: .utf8)?.sha256().toHexString() ?? "unknown")")
                print("❌ AppKitService: This will cause signature verification to fail!")
            }
        }
        
        // Validate address format
        guard address.starts(with: "0x") && address.count == 42 else {
            print("❌ AppKitService: Invalid address format: \(address)")
            print("❌ AppKitService: Expected Ethereum address (0x...)")
            
            // Show error to user
            NotificationCenter.default.post(
                name: .appKitWrongChainType,
                object: nil,
                userInfo: ["chainType": "unknown", "message": "Invalid wallet address format. Please use an Ethereum wallet."]
            )
            
            // Disconnect the session
            if let session = AppKit.instance.getSessions().first {
                try? await AppKit.instance.disconnect(topic: session.topic)
            }
            return
        }
        
        // Update flow state
        authenticationFlowState = .authenticating
        
        do {
            let authManager = AuthenticationManagerV2.shared
            print("🔑 AppKitService: Calling authenticateWithWallet...")
            print("🔑 AppKitService: ========== BACKEND AUTH REQUEST ==========")
            print("🔑 AppKitService: Address: \(address)")
            print("🔑 AppKitService: Signature: \(signature)")
            print("🔑 AppKitService: Message being sent to backend:")
            print(message)
            print("🔑 AppKitService: ========== END REQUEST ==========")
            
            // Extract wallet name from session
            var walletName = "wallet"
            if let session = currentSession {
                walletName = session.peer.name.lowercased().replacingOccurrences(of: " ", with: "")
            }
            
            try await authManager.authenticateWithWallet(
                address: address,
                signature: signature,
                message: message,
                walletType: walletName
            )
            
            print("✅ AppKitService: Authentication successful!")
            print("✅ AppKitService: User is now logged in")
            
            // Update flow state to complete
            authenticationFlowState = .complete
            isModalPresented = false
            stopModalCheckTimer()
            
            // Add a small delay to ensure token is fully propagated
            print("⏱️ AppKitService: Waiting 2 seconds for token propagation...")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            print("⏱️ AppKitService: Delay complete")
            
            // TEMPORARILY DISABLED: Don't disconnect immediately after auth
            // This might be causing the token expiration issue
            print("🔌 AppKitService: SKIPPING automatic session disconnect for debugging")
            /*
            if let session = AppKit.instance.getSessions().first {
                print("🔌 AppKitService: Disconnecting AppKit session...")
                try? await AppKit.instance.disconnect(topic: session.topic)
            }
            */
            
        } catch {
            print("❌ AppKitService: Authentication failed: \(error)")
            print("❌ AppKitService: Error type: \(type(of: error))")
            print("❌ AppKitService: Error description: \(error.localizedDescription)")
            
            // Update flow state to failed
            authenticationFlowState = .failed(error.localizedDescription)
            stopModalCheckTimer()
            
            // Check for specific error types
            if let authError = error as? AuthenticationError {
                switch authError {
                case .unknown(let message) where message.contains("Unknown error"):
                    print("❌ AppKitService: Likely wrong chain/address type")
                    NotificationCenter.default.post(
                        name: .appKitWrongChainType,
                        object: nil,
                        userInfo: ["chainType": "unknown", "message": "Authentication failed. Please ensure you're using an Ethereum wallet."]
                    )
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appKitSIWEAuthenticated = Notification.Name("appKitSIWEAuthenticated")
    static let appKitSIWEFailed = Notification.Name("appKitSIWEFailed")
    static let appKitWrongChainType = Notification.Name("appKitWrongChainType")
    static let appKitAccountLinked = Notification.Name("appKitAccountLinked")
}

// MARK: - AnyCodable Extension

extension AnyCodable {
    var stringValue: String? {
        if let string = self.value as? String {
            return string
        }
        return nil
    }
}

