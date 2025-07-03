import Foundation
import Combine
import WalletConnectSign
import WalletConnectNetworking
import WalletConnectPairing
import WalletConnectRelay
import Starscream

final class WalletConnectService: ObservableObject {
    static let shared = WalletConnectService()
    
    // Published properties - remove @MainActor to avoid threading conflicts
    @Published private(set) var isConnected = false
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var pendingProposal: Session.Proposal?
    @Published private(set) var connectionError: WalletConnectError?
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    private var sessionTopic: String?
    private var currentAddress: String?
    private var signingCompletion: ((Result<String, Error>) -> Void)?
    
    // Project configuration
    private let projectId: String
    private let relayHost = "relay.walletconnect.com"
    
    private init() {
        // Get project ID from Info.plist
        var retrievedProjectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECT_PROJECT_ID") as? String ?? ""
        
        print("🔍 WalletConnectService: Retrieved project ID from Info.plist: '\(retrievedProjectId)'")
        
        // Fallback to hardcoded value if not configured properly
        if retrievedProjectId.isEmpty || retrievedProjectId == "$(WALLETCONNECT_PROJECT_ID)" {
            print("⚠️ WalletConnectService: Info.plist not configured, using hardcoded project ID")
            // This is the project ID from BuildConfiguration.xcconfig
            retrievedProjectId = "936ce227c0152a29bdeef7d68794b0ac"
        }
        
        self.projectId = retrievedProjectId
        
        guard !projectId.isEmpty && projectId != "YOUR_PROJECT_ID" else {
            print("⚠️ WalletConnectService: Project ID not configured")
            return
        }
        
        setupWalletConnect()
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    private func setupWalletConnect() {
        // Configure metadata
        let metadata = AppMetadata(
            name: "Interspace",
            description: "Your Digital Universe",
            url: "https://interspace.fi",
            icons: ["https://interspace.fi/icon.png"],
            redirect: try! AppMetadata.Redirect(
                native: "interspace://walletconnect",
                universal: "https://interspace.fi/walletconnect"
            )
        )
        
        // Configure networking
        // Using app group for proper keychain access
        print("📱 WalletConnectService: Configuring networking with relay host: \(relayHost)")
        print("📱 WalletConnectService: Project ID: \(projectId)")
        
        Networking.configure(
            groupIdentifier: "group.com.interspace.walletconnect",
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )
        
        print("📱 WalletConnectService: Networking configured successfully")
        
        // Configure Pair
        Pair.configure(metadata: metadata)
        
        // Configure Sign client
        Sign.configure(crypto: DefaultCryptoProvider())
        
        print("✅ WalletConnectService: Configured with project ID: \(projectId)")
    }
    
    private func setupSubscriptions() {
        // Subscribe to session proposals
        Sign.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal in
                Task { @MainActor in
                    self?.handleSessionProposal(proposal.proposal)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to session requests
        Sign.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (request, _) in
                Task { @MainActor in
                    self?.handleSessionRequest(request)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to session settlements
        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                Task { @MainActor in
                    self?.handleSessionSettled(session)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to session deletions
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (topic, reason) in
                Task { @MainActor in
                    self?.handleSessionDeleted(topic: topic)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to session responses
        Sign.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                Task { @MainActor in
                    self?.handleSessionResponse(response)
                }
            }
            .store(in: &cancellables)
        
        // For SIWE auth only, we don't need profile change notifications or persistent sessions
    }
    
    // MARK: - Public Methods
    
    /// Connect to a wallet using WalletConnect URI for SIWE authentication
    func connectForAuth(uri: String) async throws {
        // For connecting FROM a wallet app TO our dApp
        // This is when a wallet scans our QR code
        guard uri.hasPrefix("wc:") else {
            throw WalletConnectError.invalidURI
        }
        
        do {
            // Parse the URI
            guard let pairingURI = try? WalletConnectURI(string: uri) else {
                throw WalletConnectError.invalidURI
            }
            
            // Pair with the wallet
            try await Pair.instance.pair(uri: pairingURI)
            
            print("✅ WalletConnectService: Paired with URI for authentication")
            
            // The wallet will send us a session proposal
            // We'll handle it in handleSessionProposal
            
        } catch {
            print("❌ WalletConnectService: Failed to pair: \(error)")
            throw WalletConnectError.pairingFailed(error.localizedDescription)
        }
    }
    
    /// Connect to a wallet by generating our own URI
    func connectToWallet() async throws -> String {
        print("📱 WalletConnectService: Creating connection request as dApp")
        
        // Set a timeout for the entire connection process
        let connectionTask = Task { () throws -> String in
            // Give SDK a moment to initialize if needed
            await ensureSocketConnected()
            
            // Create a pairing URI that wallets can use to connect to us
            let uri: WalletConnectURI
            do {
                // The Pair.instance.create() will handle socket connection internally
                uri = try await Pair.instance.create()
                print("📱 URI created: \(uri.absoluteString)")
                print("📱 URI topic: \(uri.topic)")
                print("📱 URI version: \(uri.version)")
                print("📱 URI symKey: \(uri.symKey)")
                print("📱 URI relay protocol: \(uri.relay.protocol)")
            } catch {
                print("❌ WalletConnectService: Failed to create pairing URI: \(error)")
                // Check if this is a network-related error
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("network") || errorMessage.contains("internet") {
                    throw WalletConnectError.pairingFailed("Network connection issue. Please check your internet connection and try again.")
                } else {
                    throw WalletConnectError.pairingFailed(error.localizedDescription)
                }
            }
            
            return uri.absoluteString
        }
        
        // Apply timeout of 15 seconds for the initial connection
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            connectionTask.cancel()
        }
        
        do {
            let uriString = try await connectionTask.value
            timeoutTask.cancel()
            
            // Continue with the rest of the connection process
            return try await continueConnectionProcess(with: uriString)
        } catch {
            timeoutTask.cancel()
            if error is CancellationError {
                throw WalletConnectError.pairingFailed("Connection timeout - please try again")
            }
            throw error
        }
    }
    
    private func continueConnectionProcess(with uriString: String) async throws -> String {
        guard let uri = try? WalletConnectURI(string: uriString) else {
            throw WalletConnectError.invalidURI
        }
        
        // Define the namespaces we require from the wallet
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [Blockchain("eip155:1")!], // Ethereum mainnet
                methods: ["personal_sign", "eth_sign"], // For SIWE
                events: []
            )
        ]
        
        // Create connection proposal with retry logic
        var retryCount = 0
        let maxRetries = 3
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                print("📱 WalletConnectService: Sending connection proposal (attempt \(retryCount + 1)/\(maxRetries))...")
                
                // Small delay between retries
                if retryCount > 0 {
                    try await Task.sleep(nanoseconds: UInt64(retryCount) * 1_000_000_000) // 1-3 seconds
                }
                
                let _ = try await Sign.instance.connect(
                    requiredNamespaces: requiredNamespaces,
                    optionalNamespaces: [:],
                    sessionProperties: nil
                )
                print("📱 WalletConnectService: Connection proposal sent successfully")
                break // Success, exit retry loop
                
            } catch {
                lastError = error
                retryCount += 1
                
                let errorMessage = error.localizedDescription
                if errorMessage.contains("existing") || errorMessage.contains("already") {
                    // This is okay - we're already paired
                    print("ℹ️ WalletConnectService: Already paired, continuing...")
                    break
                } else if retryCount < maxRetries {
                    print("⚠️ WalletConnectService: Connection attempt \(retryCount) failed: \(error)")
                    // Continue to retry
                } else {
                    print("❌ WalletConnectService: All connection attempts failed: \(error)")
                    // Don't throw - the URI is still valid
                }
            }
        }
        
        return uriString
    }
    
    
    /// Sign a SIWE message for authentication
    func signSIWEMessage(_ message: String, address: String, session: Session) async throws -> String {
        // Store current address for verification
        currentAddress = address
        
        // Create personal_sign request
        guard let blockchain = Blockchain("eip155:1") else { // Ethereum mainnet
            throw WalletConnectError.invalidResponse
        }
        
        // For personal_sign, the message needs to be hex encoded
        let messageData = message.data(using: .utf8) ?? Data()
        let hexMessage = "0x" + messageData.map { String(format: "%02x", $0) }.joined()
        
        let request = try Request(
            topic: session.topic,
            method: "personal_sign",
            params: AnyCodable([hexMessage, address]),
            chainId: blockchain
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signingCompletion = { result in
                continuation.resume(with: result)
            }
            
            // Send the request to the wallet
            Task {
                do {
                    try await Sign.instance.request(params: request)
                    print("✅ WalletConnectService: Sent SIWE signing request")
                } catch {
                    print("❌ WalletConnectService: Failed to send request: \(error)")
                    self.signingCompletion = nil
                    continuation.resume(throwing: WalletConnectError.signingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Get the connected wallet address for SIWE auth
    func getConnectedAddress() async -> String? {
        // First check if we have a current address
        if let address = currentAddress {
            return address
        }
        
        // Otherwise extract from the first session
        if let firstSession = sessions.first,
           let firstAccount = firstSession.namespaces.values.flatMap({ $0.accounts }).first {
            let components = firstAccount.absoluteString.split(separator: ":")
            if components.count >= 3 {
                return String(components[2])
            }
        }
        
        return nil
    }
    
    /// Clean up after SIWE authentication
    func cleanupAuthSession() async {
        // Disconnect the temporary session used for auth
        await disconnect()
    }
    
    /// Disconnect a session
    func disconnect(topic: String? = nil) async {
        do {
            if let topic = topic {
                // Disconnect specific session
                try await Sign.instance.disconnect(topic: topic)
            } else {
                // Disconnect all sessions
                for session in sessions {
                    try await Sign.instance.disconnect(topic: session.topic)
                }
            }
            
            await updatePublishedProperties {
                self.sessions.removeAll()
                self.isConnected = false
                self.sessionTopic = nil
                self.currentAddress = nil
            }
            
            print("✅ WalletConnectService: Disconnected")
        } catch {
            print("❌ WalletConnectService: Failed to disconnect: \(error)")
        }
    }
    
    
    // MARK: - Private Methods
    
    // SIWE auth doesn't require persistent session loading
    
    @MainActor
    private func handleSessionProposal(_ proposal: Session.Proposal) {
        print("📱 WalletConnectService: Received session proposal from \(proposal.proposer.name)")
        print("📱 Proposal ID: \(proposal.id)")
        
        // We're a dApp, we shouldn't receive proposals - we make them
        // This might happen if we're testing with demo sites
        print("⚠️ WalletConnectService: Unexpected session proposal - we're a dApp, not a wallet")
        print("⚠️ This usually means you're scanning a QR from another dApp")
        print("⚠️ For production use, Interspace should generate QR codes for wallets to scan")
        
        // Store but don't auto-approve
        self.pendingProposal = proposal
    }
    
    private func approveSessionAsWallet(_ proposal: Session.Proposal) async {
        do {
            // When acting as a wallet, we need to provide our account address
            // For now, we'll use a dummy address for SIWE testing
            let walletAddress = "0x1234567890123456789012345678901234567890"
            
            print("📱 WalletConnectService: Approving session as wallet with address: \(walletAddress)")
            
            var sessionNamespaces = [String: SessionNamespace]()
            
            // Process required namespaces
            for (key, requiredNamespace) in proposal.requiredNamespaces {
                print("📱 Processing required namespace: \(key)")
                
                let chains = requiredNamespace.chains ?? []
                var accounts: [Account] = []
                
                // Create accounts for each chain
                if chains.isEmpty && key == "eip155" {
                    // Default to mainnet if no chains specified
                    if let account = Account(blockchain: Blockchain("eip155:1")!, address: walletAddress) {
                        accounts.append(account)
                    }
                } else {
                    for chain in chains {
                        if let account = Account(blockchain: chain, address: walletAddress) {
                            accounts.append(account)
                        }
                    }
                }
                
                sessionNamespaces[key] = SessionNamespace(
                    accounts: accounts,
                    methods: requiredNamespace.methods,
                    events: requiredNamespace.events
                )
            }
            
            // Process optional namespaces if required is empty
            if sessionNamespaces.isEmpty, let optionalNamespaces = proposal.optionalNamespaces {
                for (key, optionalNamespace) in optionalNamespaces {
                    print("📱 Processing optional namespace: \(key)")
                    
                    let chains = optionalNamespace.chains ?? []
                    var accounts: [Account] = []
                    
                    // Create accounts for requested chains
                    for chain in chains {
                        if let account = Account(blockchain: chain, address: walletAddress) {
                            accounts.append(account)
                        }
                    }
                    
                    // If no specific chains, use mainnet
                    if accounts.isEmpty && key == "eip155" {
                        if let account = Account(blockchain: Blockchain("eip155:1")!, address: walletAddress) {
                            accounts.append(account)
                        }
                    }
                    
                    sessionNamespaces[key] = SessionNamespace(
                        accounts: accounts,
                        methods: optionalNamespace.methods,
                        events: optionalNamespace.events
                    )
                }
            }
            
            print("📱 WalletConnectService: Approving with \(sessionNamespaces.count) namespaces")
            for (key, namespace) in sessionNamespaces {
                print("  - \(key): \(namespace.accounts.count) accounts")
                for account in namespace.accounts {
                    print("    - \(account.absoluteString)")
                }
            }
            
            // Approve the session
            _ = try await Sign.instance.approve(
                proposalId: proposal.id,
                namespaces: sessionNamespaces
            )
            
            print("✅ WalletConnectService: Approved session proposal")
            
        } catch {
            print("❌ WalletConnectService: Failed to approve session: \(error)")
            await updatePublishedProperties {
                self.connectionError = WalletConnectError.sessionApprovalFailed(error.localizedDescription)
            }
        }
    }
    
    private func buildSessionNamespaces(from proposal: Session.Proposal) throws -> [String: SessionNamespace] {
        // Get all supported chains from the proposal
        let requiredChains = proposal.requiredNamespaces.flatMap { namespace in
            namespace.value.chains ?? []
        }
        let optionalChains = proposal.optionalNamespaces?.flatMap { namespace in
            namespace.value.chains ?? []
        } ?? []
        
        // Combine and deduplicate chains
        let allChains = requiredChains + optionalChains
        let supportedChains = allChains.isEmpty ? [Blockchain("eip155:1")!] : Array(Set(allChains))
        
        // Get all methods and events
        let supportedMethods = Set(
            proposal.requiredNamespaces.flatMap { $0.value.methods } + 
            (proposal.optionalNamespaces?.flatMap { $0.value.methods } ?? [])
        )
        let supportedEvents = Set(
            proposal.requiredNamespaces.flatMap { $0.value.events } + 
            (proposal.optionalNamespaces?.flatMap { $0.value.events } ?? [])
        )
        
        // For dApp usage, we're connecting TO a wallet, so we don't have accounts yet
        // The wallet will provide its accounts after approval
        // We need to return an empty namespace that satisfies the requirements
        
        print("📱 WalletConnectService: Building namespaces for proposal")
        print("  - Required namespaces: \(proposal.requiredNamespaces.keys.joined(separator: ", "))")
        print("  - Optional namespaces: \(proposal.optionalNamespaces?.keys.joined(separator: ", ") ?? "none")")
        print("  - Supported chains: \(supportedChains.map { $0.absoluteString }.joined(separator: ", "))")
        print("  - Supported methods: \(Array(supportedMethods).joined(separator: ", "))")
        print("  - Supported events: \(Array(supportedEvents).joined(separator: ", "))")
        
        // Since we're a dApp connecting to a wallet, we need to approve with minimal namespaces
        // The wallet will provide the actual accounts
        var sessionNamespaces = [String: SessionNamespace]()
        
        // Build namespaces based on what the wallet requires
        for (key, requiredNamespace) in proposal.requiredNamespaces {
            let chains = requiredNamespace.chains ?? []
            let methods = requiredNamespace.methods
            let events = requiredNamespace.events
            
            // For a dApp, we don't provide accounts - the wallet does
            sessionNamespaces[key] = SessionNamespace(
                chains: chains.isEmpty ? nil : chains,
                accounts: [],
                methods: methods,
                events: events
            )
        }
        
        // If no required namespaces, check optional
        if sessionNamespaces.isEmpty, let optionalNamespaces = proposal.optionalNamespaces {
            for (key, optionalNamespace) in optionalNamespaces {
                let chains = optionalNamespace.chains ?? []
                let methods = optionalNamespace.methods
                let events = optionalNamespace.events
                
                sessionNamespaces[key] = SessionNamespace(
                    chains: chains.isEmpty ? nil : chains,
                    accounts: [],
                    methods: methods,
                    events: events
                )
            }
        }
        
        print("📱 WalletConnectService: Built \(sessionNamespaces.count) namespaces")
        
        return sessionNamespaces
    }
    
    
    @MainActor
    private func handleSessionSettled(_ session: Session) {
        print("✅ WalletConnectService: Session settled with \(session.peer.name)")
        
        // For SIWE auth, we keep the session temporarily for signing
        self.sessions.append(session)
        self.isConnected = true
        self.sessionTopic = session.topic
        self.pendingProposal = nil
        
        // Extract wallet address from the session
        if let firstAccount = session.namespaces.values.flatMap({ $0.accounts }).first {
            let components = firstAccount.absoluteString.split(separator: ":")
            if components.count >= 3 {
                self.currentAddress = String(components[2])
            }
        }
        
        print("✅ WalletConnectService: Session established for SIWE auth, wallet: \(self.currentAddress ?? "unknown")")
    }
    
    @MainActor
    private func handleSessionRequest(_ request: Request) {
        print("📱 WalletConnectService: Received request: \(request.method)")
        
        Task {
            do {
                switch request.method {
                case "personal_sign":
                    await handlePersonalSign(request)
                    
                case "eth_sign":
                    await handleEthSign(request)
                    
                case "eth_sendTransaction":
                    await handleSendTransaction(request)
                    
                default:
                    // Reject unsupported methods
                    try await Sign.instance.respond(
                        topic: request.topic,
                        requestId: request.id,
                        response: .error(JSONRPCError(code: -32601, message: "Method not supported"))
                    )
                }
            } catch {
                print("❌ WalletConnectService: Failed to handle request: \(error)")
            }
        }
    }
    
    private func handlePersonalSign(_ request: Request) async {
        // For wallet apps, this would show UI for user approval
        // For our dApp use case, we're initiating the signing, so we just handle the response
        
        // Extract parameters
        guard let params = try? request.params.get([String].self),
              params.count >= 2 else {
            print("❌ WalletConnectService: Invalid personal_sign parameters")
            return
        }
        
        let _ = params[0] // message
        let address = params[1]
        
        print("📝 WalletConnectService: Personal sign request for \(address)")
        
        // Since we're the ones requesting the signature, this shouldn't happen
        // But we'll handle it just in case
        do {
            try await Sign.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(JSONRPCError(code: -32000, message: "Unexpected signing request"))
            )
        } catch {
            print("❌ WalletConnectService: Failed to respond to request: \(error)")
        }
    }
    
    private func handleEthSign(_ request: Request) async {
        // Similar to personal_sign
        await handlePersonalSign(request)
    }
    
    private func handleSendTransaction(_ request: Request) async {
        // We don't support transactions in this context
        do {
            try await Sign.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(JSONRPCError(code: -32601, message: "Transactions not supported"))
            )
        } catch {
            print("❌ WalletConnectService: Failed to respond to request: \(error)")
        }
    }
    
    @MainActor
    private func handleSessionDeleted(topic: String) {
        print("🗑 WalletConnectService: Session deleted")
        
        self.sessions.removeAll { $0.topic == topic }
        
        if self.sessions.isEmpty {
            self.isConnected = false
            self.sessionTopic = nil
            self.currentAddress = nil
        }
    }
    
    @MainActor
    private func handleSessionResponse(_ response: Response) {
        print("📱 WalletConnectService: Received response")
        
        // Extract the result based on the response structure
        switch response.result {
        case .response(let anyCodable):
            // Try to extract the signature string from the response
            if let signature = try? anyCodable.get(String.self) {
                print("✅ WalletConnectService: Got signature: \(signature)")
                self.signingCompletion?(.success(signature))
                self.signingCompletion = nil
            } else {
                print("❌ WalletConnectService: Could not extract signature from response")
                self.signingCompletion?(.failure(WalletConnectError.invalidResponse))
                self.signingCompletion = nil
            }
            
        case .error(let jsonRPCError):
            // Handle error response
            print("❌ WalletConnectService: Request failed with error: \(jsonRPCError.message)")
            self.signingCompletion?(.failure(WalletConnectError.signingFailed(jsonRPCError.message)))
            self.signingCompletion = nil
        }
    }
}

// MARK: - WalletConnect Error

enum WalletConnectError: LocalizedError {
    case invalidURI
    case pairingFailed(String)
    case sessionApprovalFailed(String)
    case noActiveSession
    case signingFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURI:
            return "Invalid WalletConnect URI"
        case .pairingFailed(let message):
            return "Pairing failed: \(message)"
        case .sessionApprovalFailed(let message):
            return "Session approval failed: \(message)"
        case .noActiveSession:
            return "No active WalletConnect session"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        case .invalidResponse:
            return "Invalid response from wallet"
        }
    }
}

// MARK: - Extensions

extension WalletConnectService {
    /// Handle response events from wallet
    private func setupResponseHandling() {
        // Response handling is done through the continuation in signMessage
        // The wallet will respond through the WalletConnect protocol
    }
}


// MARK: - Helper Methods

extension WalletConnectService {
    /// Update published properties on main thread
    @MainActor
    private func updatePublishedProperties(_ updates: @escaping () -> Void) async {
        updates()
    }
}

// MARK: - Socket Factory

// Create a wrapper to adapt Starscream's WebSocket to WalletConnectRelay's WebSocketConnecting
class WebSocketAdapter: WebSocketConnecting {
    private let socket: WebSocket
    private let connectionLock = NSLock()
    private var _isConnected: Bool = false
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
    var isConnected: Bool {
        connectionLock.lock()
        defer { connectionLock.unlock() }
        return _isConnected
    }
    
    var request: URLRequest {
        get { socket.request }
        set { socket.request = newValue }
    }
    
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    
    init(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30 // Increase timeout to 30 seconds
        
        // Add required headers for WalletConnect
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        
        socket = WebSocket(request: request)
        
        // Configure socket options for better connectivity
        socket.callbackQueue = DispatchQueue.main
        // socket.enableCompression = true // Not available in current WebSocket implementation
        
        socket.onEvent = { [weak self] event in
            guard let self = self else { return }
            
            // Ensure all callbacks happen on main thread to avoid threading issues
            DispatchQueue.main.async {
                switch event {
                case .connected(_):
                    self.setConnected(true)
                    print("✅ WalletConnect WebSocket: Connected")
                    self.onConnect?()
                case .disconnected(let reason, let code):
                    self.setConnected(false)
                    print("❌ WalletConnect WebSocket: Disconnected - reason: \(reason ?? "unknown"), code: \(code)")
                    self.onDisconnect?(nil)
                    self.scheduleReconnect()
                case .text(let string):
                    self.onText?(string)
                case .error(let error):
                    self.setConnected(false)
                    print("❌ WalletConnect WebSocket: Error - \(error?.localizedDescription ?? "unknown")")
                    self.onDisconnect?(error)
                    self.scheduleReconnect()
                case .cancelled:
                    self.setConnected(false)
                    print("❌ WalletConnect WebSocket: Cancelled")
                    self.onDisconnect?(nil)
                case .viabilityChanged(let isViable):
                    print("🔌 WalletConnect WebSocket: Viability changed - \(isViable)")
                case .reconnectSuggested(let shouldReconnect):
                    print("🔌 WalletConnect WebSocket: Reconnect suggested - \(shouldReconnect)")
                    if shouldReconnect {
                        self.connect()
                    }
                case .pong:
                    break
                case .ping:
                    break
                case .binary:
                    break
                case .peerClosed:
                    self.setConnected(false)
                    print("❌ WalletConnect WebSocket: Peer closed connection")
                    self.onDisconnect?(nil)
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    func connect() {
        connectionLock.lock()
        let alreadyConnected = _isConnected
        connectionLock.unlock()
        
        if alreadyConnected {
            print("🔌 WalletConnect WebSocket: Already connected, skipping connection attempt")
            return
        }
        
        // Cancel any pending reconnect
        cancelReconnect()
        reconnectAttempts = 0
        
        print("🔌 WalletConnect WebSocket: Attempting to connect...")
        socket.connect()
    }
    
    func disconnect() {
        print("🔌 WalletConnect WebSocket: Disconnecting...")
        cancelReconnect()
        socket.disconnect()
    }
    
    func write(string: String, completion: (() -> Void)? = nil) {
        // Ensure write operations happen on the correct queue
        if Thread.isMainThread {
            socket.write(string: string, completion: completion)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.socket.write(string: string, completion: completion)
            }
        }
    }
    
    private func setConnected(_ connected: Bool) {
        connectionLock.lock()
        defer { connectionLock.unlock() }
        _isConnected = connected
        
        if connected {
            reconnectAttempts = 0
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ WalletConnect WebSocket: Max reconnection attempts reached")
            return
        }
        
        cancelReconnect()
        
        reconnectAttempts += 1
        let delay = reconnectDelay * Double(reconnectAttempts)
        
        print("🔄 WalletConnect WebSocket: Scheduling reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay) seconds")
        
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                self?.attemptReconnect()
            }
        }
    }
    
    private func attemptReconnect() {
        connectionLock.lock()
        let alreadyConnected = _isConnected
        connectionLock.unlock()
        
        if !alreadyConnected {
            print("🔄 WalletConnect WebSocket: Attempting reconnection...")
            connect()
        }
    }
    
    private func cancelReconnect() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = nil
        }
    }
}

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocketAdapter(url: url)
    }
}

// MARK: - Socket Reconnection
extension WalletConnectService {
    /// Monitor socket connection and attempt reconnection if needed
    func monitorSocketConnection() {
        // This could be called periodically or when connection issues are detected
        // The WalletConnect SDK should handle reconnection internally, but
        // we can add additional monitoring if needed
        print("🔌 WalletConnectService: Socket monitoring active")
    }
    
    /// Ensure socket is connected before critical operations
    func ensureSocketConnected() async {
        print("🔌 WalletConnectService: Checking socket connection...")
        
        // Give the SDK a moment to initialize its networking stack
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For WalletConnect/Reown SDK, the socket connection is handled internally
        // We don't need to check it repeatedly - the SDK will handle reconnections
        print("🔌 WalletConnectService: Socket initialization period complete")
        
        // The Pair.instance.create() call will establish the connection if needed
        // No need for repeated checks that flood the logs
    }
}

// MARK: - Crypto Provider

import WalletConnectSigner
import CryptoKit

struct DefaultCryptoProvider: CryptoProvider {
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        // This is a simplified implementation
        // In production, you'd use a proper Web3 library
        fatalError("Not implemented - use Web3.swift or similar library")
    }
    
    func keccak256(_ data: Data) -> Data {
        // Using CryptoKit's SHA256 as a placeholder
        // In production, you need actual Keccak256
        return Data(SHA256.hash(data: data))
    }
}