import Foundation
import WalletConnectSign

/// Manages WalletConnect session persistence and lifecycle
@MainActor
final class WalletConnectSessionManager: ObservableObject {
    static let shared = WalletConnectSessionManager()
    
    // Session storage keys
    private let kStoredSessionsKey = "com.interspace.walletconnect.sessions"
    private let kActiveSessionKey = "com.interspace.walletconnect.activeSession"
    
    // Published properties
    @Published var activeSessions: [WalletConnectSessionInfo] = []
    @Published var hasActiveSessions: Bool = false
    
    private let keychainManager = KeychainManager.shared
    
    private init() {
        loadStoredSessions()
    }
    
    // MARK: - Public Methods
    
    /// Store a new session
    func storeSession(_ session: Session, walletName: String? = nil) {
        let sessionInfo = WalletConnectSessionInfo(
            topic: session.topic,
            peerName: session.peer.name,
            peerDescription: session.peer.description ?? "",
            peerUrl: session.peer.url ?? "",
            peerIcon: session.peer.icons.first,
            walletName: walletName ?? session.peer.name,
            accounts: extractAccounts(from: session),
            chainIds: extractChainIds(from: session),
            createdAt: Date(),
            expiryDate: session.expiryDate ?? Date().addingTimeInterval(86400 * 7) // Default to 7 days
        )
        
        // Add to active sessions
        if !activeSessions.contains(where: { $0.topic == sessionInfo.topic }) {
            activeSessions.append(sessionInfo)
        }
        
        // Persist to keychain
        saveSessionsToKeychain()
        
        // Update state
        hasActiveSessions = !activeSessions.isEmpty
        
        print("✅ WalletConnectSessionManager: Stored session for \(sessionInfo.walletName)")
    }
    
    /// Remove a session
    func removeSession(topic: String) {
        activeSessions.removeAll { $0.topic == topic }
        saveSessionsToKeychain()
        hasActiveSessions = !activeSessions.isEmpty
        
        print("✅ WalletConnectSessionManager: Removed session with topic: \(topic)")
    }
    
    /// Get session info for a specific address
    func getSessionInfo(for address: String) -> WalletConnectSessionInfo? {
        let normalizedAddress = address.lowercased()
        
        return activeSessions.first { sessionInfo in
            sessionInfo.accounts.contains { account in
                account.address.lowercased() == normalizedAddress
            }
        }
    }
    
    /// Get all addresses from active sessions
    func getAllConnectedAddresses() -> [String] {
        activeSessions.flatMap { $0.accounts.map { $0.address } }
    }
    
    /// Check if an address is connected via WalletConnect
    func isAddressConnected(_ address: String) -> Bool {
        getSessionInfo(for: address) != nil
    }
    
    /// Clean up expired sessions
    func cleanupExpiredSessions() {
        let now = Date()
        let expiredTopics = activeSessions
            .filter { $0.expiryDate < now }
            .map { $0.topic }
        
        for topic in expiredTopics {
            removeSession(topic: topic)
        }
        
        if !expiredTopics.isEmpty {
            print("🧹 WalletConnectSessionManager: Cleaned up \(expiredTopics.count) expired sessions")
        }
    }
    
    /// Refresh sessions from WalletConnect SDK
    func refreshSessions() {
        let sdkSessions = Sign.instance.getSessions()
        
        // Update existing sessions or add new ones
        for session in sdkSessions {
            if let index = activeSessions.firstIndex(where: { $0.topic == session.topic }) {
                // Update existing session info
                activeSessions[index].expiryDate = session.expiryDate ?? Date().addingTimeInterval(86400 * 7)
                activeSessions[index].accounts = extractAccounts(from: session)
                activeSessions[index].chainIds = extractChainIds(from: session)
            } else {
                // Add new session
                storeSession(session)
            }
        }
        
        // Remove sessions that no longer exist in SDK
        let sdkTopics = Set(sdkSessions.map { $0.topic })
        activeSessions.removeAll { !sdkTopics.contains($0.topic) }
        
        saveSessionsToKeychain()
        hasActiveSessions = !activeSessions.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func loadStoredSessions() {
        do {
            let data = try keychainManager.load(for: kStoredSessionsKey)
            let decoder = JSONDecoder()
            activeSessions = try decoder.decode([WalletConnectSessionInfo].self, from: data)
            hasActiveSessions = !activeSessions.isEmpty
            
            // Clean up expired sessions on load
            cleanupExpiredSessions()
            
            print("✅ WalletConnectSessionManager: Loaded \(activeSessions.count) stored sessions")
        } catch KeychainError.itemNotFound {
            // No stored sessions, this is fine
            print("✅ WalletConnectSessionManager: No stored sessions found")
            activeSessions = []
            hasActiveSessions = false
        } catch {
            print("❌ WalletConnectSessionManager: Failed to load stored sessions: \(error)")
            activeSessions = []
            hasActiveSessions = false
        }
    }
    
    private func saveSessionsToKeychain() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(activeSessions)
            try keychainManager.save(data, for: kStoredSessionsKey)
            print("✅ WalletConnectSessionManager: Saved \(activeSessions.count) sessions to keychain")
        } catch {
            print("❌ WalletConnectSessionManager: Failed to save sessions: \(error)")
        }
    }
    
    private func extractAccounts(from session: Session) -> [WalletConnectAccount] {
        var accounts: [WalletConnectAccount] = []
        
        for namespace in session.namespaces.values {
            for account in namespace.accounts {
                // Parse CAIP-10 format: "eip155:1:0x1234..."
                let accountString = account.absoluteString
                let components = accountString.split(separator: ":")
                if components.count >= 3 {
                    let blockchain = String(components[0])
                    let chainId = String(components[1])
                    let address = String(components[2])
                    
                    accounts.append(WalletConnectAccount(
                        blockchain: blockchain,
                        chainId: chainId,
                        address: address
                    ))
                }
            }
        }
        
        return accounts
    }
    
    private func extractChainIds(from session: Session) -> [String] {
        var chainIds: Set<String> = []
        
        for namespace in session.namespaces.values {
            // Add chains from the namespace if available
            if let chains = namespace.chains {
                for chain in chains {
                    chainIds.insert(chain.absoluteString)
                }
            }
            
            // Also extract from accounts
            for account in namespace.accounts {
                let accountString = account.absoluteString
                let components = accountString.split(separator: ":")
                if components.count >= 2 {
                    chainIds.insert("\(components[0]):\(components[1])")
                }
            }
        }
        
        return Array(chainIds)
    }
}

// MARK: - Models

struct WalletConnectSessionInfo: Codable, Identifiable {
    let id = UUID()
    let topic: String
    let peerName: String
    let peerDescription: String
    let peerUrl: String
    let peerIcon: String?
    let walletName: String
    var accounts: [WalletConnectAccount]
    var chainIds: [String]
    let createdAt: Date
    var expiryDate: Date
    
    var primaryAddress: String? {
        accounts.first?.address
    }
    
    var isExpired: Bool {
        expiryDate < Date()
    }
    
    var formattedExpiry: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expiryDate)
    }
}

struct WalletConnectAccount: Codable, Equatable {
    let blockchain: String
    let chainId: String
    let address: String
    
    var displayAddress: String {
        if address.count > 10 {
            let start = address.prefix(6)
            let end = address.suffix(4)
            return "\(start)...\(end)"
        }
        return address
    }
    
    var chainName: String {
        switch "\(blockchain):\(chainId)" {
        case "eip155:1":
            return "Ethereum"
        case "eip155:137":
            return "Polygon"
        case "eip155:10":
            return "Optimism"
        case "eip155:42161":
            return "Arbitrum"
        case "eip155:8453":
            return "Base"
        default:
            return "\(blockchain):\(chainId)"
        }
    }
}