import Foundation
import LocalAuthentication
import CryptoKit
import Security

final class PINCodeManager: ObservableObject {
    static let shared = PINCodeManager()
    
    private let keychainKey = "interspace.pin.hash"
    private let saltKey = "interspace.pin.salt"
    private let pinAttemptKey = "interspace.pin.attempts"
    private let maxAttempts = 5
    
    @Published private(set) var failedAttempts: Int = 0
    @Published private(set) var isLocked: Bool = false
    
    private let keychain = KeychainManager.shared
    
    private init() {
        loadFailedAttempts()
    }
    
    // MARK: - PIN Setup
    
    func setPIN(_ pin: String) async throws {
        guard pin.count == 6, pin.allSatisfy({ $0.isNumber }) else {
            throw PINError.invalidFormat
        }
        
        // Generate salt and hash the PIN
        let salt = generateSalt()
        let hashedPIN = hashPIN(pin, with: salt)
        
        // Store in keychain
        try keychain.save(hashedPIN, for: keychainKey)
        try keychain.save(salt, for: saltKey)
        
        // Reset failed attempts on main thread
        await MainActor.run {
            failedAttempts = 0
            saveFailedAttempts()
        }
    }
    
    func hasPIN() async -> Bool {
        do {
            let _: Data = try keychain.load(for: keychainKey)
            return true
        } catch {
            return false
        }
    }
    
    func removePIN() async throws {
        try keychain.delete(for: keychainKey)
        try keychain.delete(for: saltKey)
        failedAttempts = 0
        saveFailedAttempts()
    }
    
    // MARK: - PIN Validation
    
    @discardableResult
    func validatePIN(_ pin: String) async throws -> Bool {
        guard !isLocked else {
            throw PINError.tooManyAttempts
        }
        
        guard pin.count == 6, pin.allSatisfy({ $0.isNumber }) else {
            throw PINError.invalidFormat
        }
        
        do {
            let storedHash: Data = try keychain.load(for: keychainKey)
            let salt: Data = try keychain.load(for: saltKey)
            
            let inputHash = hashPIN(pin, with: salt)
            
            if inputHash == storedHash {
                // Reset failed attempts on success
                await MainActor.run {
                    failedAttempts = 0
                    isLocked = false
                    saveFailedAttempts()
                }
                return true
            } else {
                // Increment failed attempts
                await MainActor.run {
                    failedAttempts += 1
                    if failedAttempts >= maxAttempts {
                        isLocked = true
                    }
                    saveFailedAttempts()
                }
                
                if isLocked {
                    throw PINError.tooManyAttempts
                } else {
                    throw PINError.incorrectPIN(attemptsRemaining: maxAttempts - failedAttempts)
                }
            }
        } catch KeychainError.itemNotFound {
            throw PINError.noPINSet
        } catch let error as PINError {
            throw error
        } catch {
            throw PINError.validationFailed
        }
    }
    
    func resetFailedAttempts() {
        if Thread.isMainThread {
            failedAttempts = 0
            isLocked = false
            saveFailedAttempts()
        } else {
            DispatchQueue.main.async {
                self.failedAttempts = 0
                self.isLocked = false
                self.saveFailedAttempts()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
    
    private func hashPIN(_ pin: String, with salt: Data) -> Data {
        let pinData = Data(pin.utf8)
        let combinedData = salt + pinData
        return Data(SHA256.hash(data: combinedData))
    }
    
    private func loadFailedAttempts() {
        let attempts = UserDefaults.standard.integer(forKey: pinAttemptKey)
        if Thread.isMainThread {
            failedAttempts = attempts
            isLocked = attempts >= maxAttempts
        } else {
            DispatchQueue.main.async {
                self.failedAttempts = attempts
                self.isLocked = attempts >= self.maxAttempts
            }
        }
    }
    
    private func saveFailedAttempts() {
        UserDefaults.standard.set(failedAttempts, forKey: pinAttemptKey)
    }
}

// MARK: - Error Types

enum PINError: LocalizedError {
    case invalidFormat
    case incorrectPIN(attemptsRemaining: Int)
    case tooManyAttempts
    case noPINSet
    case validationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "PIN must be exactly 6 digits"
        case .incorrectPIN(let remaining):
            return "Incorrect PIN. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining"
        case .tooManyAttempts:
            return "Too many failed attempts. Please try again later"
        case .noPINSet:
            return "No PIN has been set"
        case .validationFailed:
            return "Failed to validate PIN"
        }
    }
}