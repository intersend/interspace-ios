import Foundation
import CryptoKit

// MARK: - Development Wallet Service
// This service provides mock wallet functionality for development and testing
// It generates deterministic wallet addresses and client shares based on profile IDs

final class DevelopmentWalletService {
    static let shared = DevelopmentWalletService()
    
    private init() {}
    
    /// Generate a deterministic wallet address for a profile
    func generateAddress(for profileId: String) -> String {
        let data = Data((profileId + "address").utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "0x" + hashString.prefix(40)
    }
    
    /// Generate a mock client share for development
    func generateClientShare(for profileId: String) -> ClientShare {
        let address = generateAddress(for: profileId)
        
        // Generate deterministic keys based on profile ID
        let secretData = Data((profileId + "secret").utf8)
        let secretHash = SHA256.hash(data: secretData)
        let secretShare = secretHash.compactMap { String(format: "%02x", $0) }.joined()
        
        let publicData = Data((profileId + "public").utf8)
        let publicHash = SHA256.hash(data: publicData)
        let publicKey = publicHash.compactMap { String(format: "%02x", $0) }.joined().prefix(64)
        
        return ClientShare(
            p1_key_share: ClientShare.KeyShare(
                secret_share: secretShare,
                public_key: String(publicKey)
            ),
            public_key: String(publicKey),
            address: address
        )
    }
    
    /// Sign a message with development wallet (mock implementation)
    func signMessage(_ message: String, for profileId: String) -> String {
        // Generate deterministic signature based on message and profile ID
        let data = Data((message + profileId).utf8)
        let hash = SHA256.hash(data: data)
        let signature = "0x" + hash.compactMap { String(format: "%02x", $0) }.joined()
        return signature
    }
    
    /// Check if a profile is using a development wallet
    func isDevelopmentWallet(profile: SmartProfile) -> Bool {
        return profile.isDevelopmentWallet ?? false
    }
    
    /// Create a development wallet connection result for testing
    func createDevelopmentConnectionResult(for profile: SmartProfile) -> WalletConnectionResult {
        let message = "Development wallet authentication for profile: \(profile.name)"
        let signature = signMessage(message, for: profile.id)
        
        return WalletConnectionResult(
            address: profile.sessionWalletAddress,
            signature: signature,
            message: message,
            walletType: .metamask
        )
    }
}

// MARK: - Development Mode Extensions

extension ProfileViewModel {
    /// Create a development profile without requiring MPC setup
    func createDevelopmentProfile(name: String) async {
        guard EnvironmentConfiguration.shared.isDevelopmentModeEnabled else {
            print("⚠️ Development mode is not enabled")
            return
        }
        
        await createProfile(name: name)
    }
}

// MARK: - Development Authentication

extension AuthenticationManagerV2 {
    /// Authenticate with a development wallet (for testing)
    func authenticateWithDevelopmentWallet() async throws {
        guard EnvironmentConfiguration.shared.isDevelopmentModeEnabled else {
            throw AuthenticationError.unknown("Development mode is not enabled")
        }
        
        let config = WalletConnectionConfig(
            strategy: .testWallet,
            walletType: "development",
            email: nil,
            verificationCode: nil,
            walletAddress: "0xdev_wallet_\(UUID().uuidString.prefix(8))",
            signature: "dev_signature",
            message: nil,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        
        try await authenticate(with: config)
    }
}
