import Foundation
@testable import Interspace

class MockKeychainManager: KeychainManager {
    private var storage: [String: Any] = [:]
    private var tokenExpirationDate: Date?
    
    override func saveTokens(access: String, refresh: String, expiresIn: Int) throws {
        storage["access_token"] = access
        storage["refresh_token"] = refresh
        tokenExpirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
    
    override func getAccessToken() -> String? {
        return storage["access_token"] as? String
    }
    
    override func getRefreshToken() -> String? {
        return storage["refresh_token"] as? String
    }
    
    override func clearTokens() {
        storage.removeAll()
        tokenExpirationDate = nil
    }
    
    override func isTokenExpired() -> Bool {
        guard let expirationDate = tokenExpirationDate else {
            return true
        }
        return Date() > expirationDate
    }
    
    // Test helpers
    func setTokens(access: String, refresh: String, expired: Bool = false) {
        storage["access_token"] = access
        storage["refresh_token"] = refresh
        
        if expired {
            tokenExpirationDate = Date().addingTimeInterval(-3600) // 1 hour ago
        } else {
            tokenExpirationDate = Date().addingTimeInterval(3600) // 1 hour from now
        }
    }
    
    func reset() {
        clearTokens()
    }
}