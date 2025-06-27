import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.interspace.ios"
    private let accessGroup: String? = nil
    
    private init() {}
    
    enum KeychainKey: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiry = "token_expiry"
        case userInfo = "user_info"
        case appleUserID = "apple_user_id"
        case appleUserInfo = "apple_user_info"
        case appleUserEmail = "apple_user_email"
        case appleUserFullName = "apple_user_full_name"
    }
    
    // MARK: - Save
    func save(_ data: Data, for key: KeychainKey) throws {
        try save(data, for: key.rawValue)
    }
    
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func save(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try save(data, for: key)
    }
    
    func save<T: Codable>(_ object: T, for key: KeychainKey) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try save(data, for: key)
    }
    
    // MARK: - Load
    func load(for key: KeychainKey) throws -> Data {
        return try load(for: key.rawValue)
    }
    
    func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = dataTypeRef as? Data else {
            throw KeychainError.dataConversionError
        }
        
        return data
    }
    
    func loadString(for key: KeychainKey) throws -> String {
        let data = try load(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        return string
    }
    
    func load<T: Codable>(_ type: T.Type, for key: KeychainKey) throws -> T {
        let data = try load(for: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    // MARK: - Delete
    func delete(for key: KeychainKey) throws {
        try delete(for: key.rawValue)
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Token Management
    func saveTokens(access: String, refresh: String, expiresIn: Int) throws {
        try save(access, for: .accessToken)
        try save(refresh, for: .refreshToken)
        
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        let expiryTimestamp = String(expiryDate.timeIntervalSince1970)
        try save(expiryTimestamp, for: .tokenExpiry)
    }
    
    func getAccessToken() -> String? {
        try? loadString(for: .accessToken)
    }
    
    func getRefreshToken() -> String? {
        try? loadString(for: .refreshToken)
    }
    
    func get(for key: KeychainKey) -> String? {
        try? loadString(for: key)
    }
    
    func isTokenExpired() -> Bool {
        guard let expiryString = try? loadString(for: .tokenExpiry),
              let expiryTimestamp = Double(expiryString) else {
            return true
        }
        
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        return Date() >= expiryDate
    }
    
    func clearTokens() {
        try? delete(for: .accessToken)
        try? delete(for: .refreshToken)
        try? delete(for: .tokenExpiry)
    }
    
    // MARK: - Development Client Share Management
    
    func saveDevelopmentClientShare(clientShare: ClientShare, profileId: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(clientShare)
        let key = "dev_client_share_\(profileId)"
        try save(data, for: key)
    }
    
    func getDevelopmentClientShare(profileId: String) -> ClientShare? {
        let key = "dev_client_share_\(profileId)"
        guard let data = try? load(for: key) else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(ClientShare.self, from: data)
    }
    
    func deleteDevelopmentClientShare(profileId: String) {
        let key = "dev_client_share_\(profileId)"
        try? delete(for: key)
    }
    
    // MARK: - Cache Encryption Key Management
    
    func getCacheEncryptionKey() -> Data? {
        let key = "cache_encryption_key"
        return try? load(for: key)
    }
    
    func saveCacheEncryptionKey(_ keyData: Data) {
        let key = "cache_encryption_key"
        try? save(keyData, for: key)
    }
    
    // MARK: - Apple User Info Management
    
    func saveAppleUserInfo(_ userInfo: AppleUserInfo) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(userInfo)
        try save(data, for: .appleUserInfo)
        
        // Also save email and name separately for quick access
        if let email = userInfo.email {
            try save(email, for: .appleUserEmail)
        }
        
        if let firstName = userInfo.firstName, let lastName = userInfo.lastName {
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if !fullName.isEmpty {
                try save(fullName, for: .appleUserFullName)
            }
        }
    }
    
    func getAppleUserInfo() -> AppleUserInfo? {
        guard let data = try? load(for: .appleUserInfo) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(AppleUserInfo.self, from: data)
    }
    
    func getAppleUserEmail() -> String? {
        try? loadString(for: .appleUserEmail)
    }
    
    func getAppleUserFullName() -> String? {
        try? loadString(for: .appleUserFullName)
    }
    
    func clearAppleUserInfo() {
        try? delete(for: .appleUserInfo)
        try? delete(for: .appleUserEmail)
        try? delete(for: .appleUserFullName)
        try? delete(for: .appleUserID)
    }
    
    // MARK: - Clear All Data
    
    func clearAll() {
        // Clear tokens
        clearTokens()
        
        // Clear user info and apple user ID
        try? delete(for: .userInfo)
        try? delete(for: .appleUserID)
        
        // Clear Apple user info
        clearAppleUserInfo()
        
        // Clear all items from keychain for this service
        // This is a more thorough approach
        try? deleteAll()
    }
}

// MARK: - Keychain Error
enum KeychainError: LocalizedError {
    case itemNotFound
    case dataConversionError
    case unhandledError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .dataConversionError:
            return "Failed to convert data"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}