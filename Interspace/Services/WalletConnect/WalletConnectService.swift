import Foundation
import Combine
import WalletConnectSign
import WalletConnectNetworking
import WalletConnectRelay

@MainActor
final class WalletConnectService: ObservableObject {
    static let shared = WalletConnectService()
    
    // Published properties
    @Published var isConnected = false
    @Published var sessions: [Session] = []
    @Published var pendingProposal: Session.Proposal?
    @Published var connectionError: WalletConnectError?
    
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
        self.projectId = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECT_PROJECT_ID") as? String ?? ""
        
        guard !projectId.isEmpty && projectId != "YOUR_PROJECT_ID" else {
            print("⚠️ WalletConnectService: Project ID not configured in Info.plist")
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
        Networking.configure(
            groupIdentifier: "group.com.interspace",
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )
        
        // Configure pairing
        Pair.configure(metadata: metadata)
        
        // Configure Sign client
        Sign.configure(crypto: DefaultCryptoProvider())
        
        print("✅ WalletConnectService: Configured with project ID: \(projectId)")
    }
    
    private func setupSubscriptions() {
        // Subscribe to session proposals
        Sign.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (proposal, _) in
                self?.handleSessionProposal(proposal)
            }
            .store(in: &cancellables)
        
        // Subscribe to session requests
        Sign.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (request, _) in
                self?.handleSessionRequest(request)
            }
            .store(in: &cancellables)
        
        // Subscribe to session settlements
        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.handleSessionSettled(session)
            }
            .store(in: &cancellables)
        
        // Subscribe to session deletions
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (topic, _) in
                self?.handleSessionDeleted(topic: topic)
            }
            .store(in: &cancellables)
        
        // Load existing sessions
        loadSessions()
    }
    
    // MARK: - Public Methods
    
    /// Connect to a wallet using WalletConnect URI
    func connect(uri: String) async throws {
        guard uri.hasPrefix("wc:") else {
            throw WalletConnectError.invalidURI
        }
        
        do {
            // Parse the URI
            let pairingURI = WalletConnectURI(string: uri)
            
            // Pair with the wallet
            try await Pair.instance.pair(uri: pairingURI!)
            
            print("✅ WalletConnectService: Paired with URI")
            
            // The session proposal will be received via the publisher
            // and handled in handleSessionProposal
            
        } catch {
            print("❌ WalletConnectService: Failed to pair: \(error)")
            throw WalletConnectError.pairingFailed(error.localizedDescription)
        }
    }
    
    /// Sign a message using WalletConnect
    func signMessage(_ message: String, address: String) async throws -> String {
        guard let session = getActiveSession(for: address) else {
            throw WalletConnectError.noActiveSession
        }
        
        // Store current address for verification
        currentAddress = address
        
        // Create personal_sign request
        let params = AnyCodable([message, address])
        let request = Request(
            topic: session.topic,
            method: "personal_sign",
            params: params,
            chainId: Blockchain("eip155:1")! // Ethereum mainnet
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signingCompletion = { result in
                continuation.resume(with: result)
            }
            
            Task {
                do {
                    try await Sign.instance.request(params: request)
                    print("✅ WalletConnectService: Sent signing request")
                } catch {
                    print("❌ WalletConnectService: Failed to send request: \(error)")
                    continuation.resume(throwing: WalletConnectError.signingFailed(error.localizedDescription))
                }
            }
        }
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
            
            await MainActor.run {
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
    
    /// Get active session for a wallet address
    func getActiveSession(for address: String) -> Session? {
        let normalizedAddress = address.lowercased()
        
        return sessions.first { session in
            session.namespaces.values.flatMap { $0.accounts }
                .contains { account in
                    // Extract address from CAIP-10 format (e.g., "eip155:1:0x1234...")
                    let components = account.absoluteString.split(separator: ":")
                    if components.count >= 3 {
                        let accountAddress = String(components[2]).lowercased()
                        return accountAddress == normalizedAddress
                    }
                    return false
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSessions() {
        sessions = Sign.instance.getSessions()
        isConnected = !sessions.isEmpty
        
        if let firstSession = sessions.first {
            sessionTopic = firstSession.topic
            
            // Extract first address
            if let firstAccount = firstSession.namespaces.values.flatMap({ $0.accounts }).first {
                let components = firstAccount.absoluteString.split(separator: ":")
                if components.count >= 3 {
                    currentAddress = String(components[2])
                }
            }
        }
        
        print("✅ WalletConnectService: Loaded \(sessions.count) sessions")
    }
    
    private func handleSessionProposal(_ proposal: Session.Proposal) {
        print("📱 WalletConnectService: Received session proposal from \(proposal.proposer.name)")
        
        // Store the proposal
        pendingProposal = proposal
        
        // Auto-approve for wallet use case
        Task {
            await approveSession(proposal)
        }
    }
    
    private func approveSession(_ proposal: Session.Proposal) async {
        do {
            // Build session namespaces based on proposal
            let sessionNamespaces = try buildSessionNamespaces(from: proposal)
            
            // Approve the session
            try await Sign.instance.approve(
                proposalId: proposal.id,
                namespaces: sessionNamespaces
            )
            
            print("✅ WalletConnectService: Approved session proposal")
            
        } catch {
            print("❌ WalletConnectService: Failed to approve session: \(error)")
            connectionError = WalletConnectError.sessionApprovalFailed(error.localizedDescription)
        }
    }
    
    private func buildSessionNamespaces(from proposal: Session.Proposal) throws -> [String: SessionNamespace] {
        var sessionNamespaces = [String: SessionNamespace]()
        
        // For each required namespace in the proposal
        for (key, requiredNamespace) in proposal.requiredNamespaces {
            // For now, we'll support Ethereum mainnet
            let accounts = Set(requiredNamespace.chains?.compactMap { chain in
                if let address = getCurrentWalletAddress() {
                    return Account("\(chain.absoluteString):\(address)")
                }
                return nil
            } ?? [])
            
            // Include all required methods and events
            let methods = requiredNamespace.methods
            let events = requiredNamespace.events
            
            sessionNamespaces[key] = SessionNamespace(
                accounts: accounts,
                methods: methods,
                events: events
            )
        }
        
        return sessionNamespaces
    }
    
    private func getCurrentWalletAddress() -> String? {
        // This will be set when connecting from a specific wallet
        // For now, return a placeholder that will be replaced when actually connecting
        return "0x0000000000000000000000000000000000000000"
    }
    
    private func handleSessionSettled(_ session: Session) {
        print("✅ WalletConnectService: Session settled with \(session.peer.name)")
        
        sessions.append(session)
        isConnected = true
        sessionTopic = session.topic
        pendingProposal = nil
        
        // Extract wallet address from session
        if let firstAccount = session.namespaces.values.flatMap({ $0.accounts }).first {
            let components = firstAccount.absoluteString.split(separator: ":")
            if components.count >= 3 {
                currentAddress = String(components[2])
            }
        }
    }
    
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
                    let response = Response(
                        id: request.id,
                        topic: request.topic,
                        chainId: request.chainId?.absoluteString ?? "",
                        result: .error(.init(code: -32601, message: "Method not supported"))
                    )
                    try await Sign.instance.respond(
                        topic: request.topic,
                        requestId: request.id,
                        response: .error(.init(code: -32601, message: "Method not supported"))
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
        
        let message = params[0]
        let address = params[1]
        
        print("📝 WalletConnectService: Personal sign request for \(address)")
        
        // Since we're the ones requesting the signature, this shouldn't happen
        // But we'll handle it just in case
        do {
            try await Sign.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(.init(code: -32000, message: "Unexpected signing request"))
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
                response: .error(.init(code: -32601, message: "Transactions not supported"))
            )
        } catch {
            print("❌ WalletConnectService: Failed to respond to request: \(error)")
        }
    }
    
    private func handleSessionDeleted(topic: String) {
        print("🗑 WalletConnectService: Session deleted")
        
        sessions.removeAll { $0.topic == topic }
        
        if sessions.isEmpty {
            isConnected = false
            sessionTopic = nil
            currentAddress = nil
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
    /// Handle response from wallet for signing requests
    func handleSigningResponse(_ response: Response) {
        switch response.result {
        case .response(let value):
            if let signature = try? value.get(String.self) {
                signingCompletion?(.success(signature))
                signingCompletion = nil
            } else {
                signingCompletion?(.failure(WalletConnectError.invalidResponse))
                signingCompletion = nil
            }
            
        case .error(let error):
            signingCompletion?(.failure(WalletConnectError.signingFailed(error.message)))
            signingCompletion = nil
        }
    }
}