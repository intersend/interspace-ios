import Foundation

// MARK: - MPC Debug Helper
// Utility to enable MPC wallet feature in debug builds

@MainActor
final class MPCDebugHelper {
    
    /// Enable MPC wallet feature for debug builds
    static func enableMPCWallet() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "mpcWalletEnabled")
        print("✅ MPC Wallet enabled in UserDefaults")
        print("   MPCWalletServiceHTTP.isEnabled = \(MPCWalletServiceHTTP.isEnabled)")
        #endif
    }
    
    /// Disable MPC wallet feature for debug builds
    static func disableMPCWallet() {
        #if DEBUG
        UserDefaults.standard.set(false, forKey: "mpcWalletEnabled")
        print("❌ MPC Wallet disabled in UserDefaults")
        #endif
    }
    
    /// Check current MPC wallet status
    static func checkMPCStatus() {
        print("📊 MPC Wallet Status:")
        print("   - MPCWalletServiceHTTP.isEnabled: \(MPCWalletServiceHTTP.isEnabled)")
        #if DEBUG
        print("   - UserDefaults 'mpcWalletEnabled': \(UserDefaults.standard.bool(forKey: "mpcWalletEnabled"))")
        print("   - Build configuration: DEBUG")
        #else
        print("   - Build configuration: RELEASE")
        #endif
    }
    
    /// Initialize MPC wallet for testing
    /// Call this in AppDelegate or during app startup for testing
    static func initializeForTesting() {
        #if DEBUG
        // Enable MPC wallet
        enableMPCWallet()
        
        // Log initialization
        print("🔧 MPC Debug Helper initialized")
        checkMPCStatus()
        #endif
    }
}