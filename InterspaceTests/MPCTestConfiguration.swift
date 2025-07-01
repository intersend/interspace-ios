import Foundation
@testable import Interspace

// Test-specific configuration to avoid dependency on app initialization
extension MPCConfiguration {
    
    /// Setup test environment
    static func setupForTesting() {
        // Override any runtime dependencies
        UserDefaults.standard.set(true, forKey: "mpcUseHTTP")
        UserDefaults.standard.set(true, forKey: "mpcWalletEnabled")
    }
    
    /// Reset after tests
    static func tearDownAfterTesting() {
        UserDefaults.standard.removeObject(forKey: "mpcUseHTTP")
        UserDefaults.standard.removeObject(forKey: "mpcWalletEnabled")
    }
}

// Mock keychain for tests
class MockKeychainManager {
    static let shared = MockKeychainManager()
    
    private var storage: [String: String] = [:]
    
    func getAccessToken() -> String? {
        return storage["accessToken"] ?? "mock-test-token"
    }
    
    func setAccessToken(_ token: String) {
        storage["accessToken"] = token
    }
    
    func clearAll() {
        storage.removeAll()
    }
}