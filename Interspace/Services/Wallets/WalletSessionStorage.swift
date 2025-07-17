import Foundation

/// Secure storage for wallet sessions
final class WalletSessionStorage: WalletSessionStorageProtocol {
    
    // MARK: - Singleton
    
    static let shared = WalletSessionStorage()
    
    // MARK: - Properties
    
    private let keychain = KeychainManager.shared
    private let keychainPrefix = "wallet_session_"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - WalletSessionStorageProtocol
    
    func save(_ session: WalletSession, for walletType: WalletType) async throws {
        let key = keychainKey(for: walletType)
        let data = try JSONEncoder().encode(session)
        
        try await keychain.save(data, for: key)
        print("💾 WalletSessionStorage: Saved session for \(walletType.displayName)")
    }
    
    func load(for walletType: WalletType) async throws -> WalletSession? {
        let key = keychainKey(for: walletType)
        
        guard let data = try await keychain.load(for: key) else {
            return nil
        }
        
        let session = try JSONDecoder().decode(WalletSession.self, from: data)
        print("💾 WalletSessionStorage: Loaded session for \(walletType.displayName)")
        return session
    }
    
    func delete(for walletType: WalletType) async throws {
        let key = keychainKey(for: walletType)
        try await keychain.delete(for: key)
        print("💾 WalletSessionStorage: Deleted session for \(walletType.displayName)")
    }
    
    func getAllSessions() async throws -> [WalletSession] {
        var sessions: [WalletSession] = []
        
        // Check all wallet types
        for walletType in WalletType.allCases {
            if let session = try await load(for: walletType) {
                sessions.append(session)
            }
        }
        
        return sessions
    }
    
    // MARK: - Private Methods
    
    private func keychainKey(for walletType: WalletType) -> String {
        "\(keychainPrefix)\(walletType.rawValue)"
    }
}

// MARK: - KeychainManager Extension

extension KeychainManager {
    /// Save data to keychain
    func save(_ data: Data, for key: String) async throws {
        try await Task.detached { [self] in
            try self.save(data, for: key)
        }.value
    }
    
    /// Load data from keychain
    func load(for key: String) async throws -> Data? {
        return try await Task.detached { [self] in
            do {
                return try self.load(for: key)
            } catch KeychainError.itemNotFound {
                return nil
            }
        }.value
    }
    
    /// Delete data from keychain
    func delete(for key: String) async throws {
        try await Task.detached { [self] in
            try self.delete(for: key)
        }.value
    }
}