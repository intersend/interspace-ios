import Foundation
import LocalAuthentication
import CryptoKit
import Security

final class PINCodeManager: ObservableObject {
    static let shared = PINCodeManager()
    
    private let keychainKey = "interspace.pin.hash"
    private let saltKey = "interspace.pin.salt"
    private let pinLengthKey = "interspace.pin.length"
    
    @Published private(set) var pinLength: Int = 6
    
    private let keychain = KeychainManager.shared
    
    private init() {
        loadPINLength()
    }
    
    // MARK: - PIN Setup
    
    func setPIN(_ pin: String) async throws {
        guard pin.count == pinLength, pin.allSatisfy({ $0.isNumber }) else {
            throw PINError.invalidFormat(expectedLength: pinLength)
        }
        
        // Generate salt and hash the PIN
        let salt = generateSalt()
        let hashedPIN = hashPIN(pin, with: salt)
        
        // Store in keychain
        try await keychain.save(hashedPIN, for: keychainKey)
        try await keychain.save(salt, for: saltKey)
        
        // Save PIN length
        savePINLength()
    }
    
    func hasPIN() async -> Bool {
        do {
            let _: Data = try await keychain.load(for: keychainKey)
            return true
        } catch {
            return false
        }
    }
    
    func removePIN() async throws {
        try await keychain.delete(for: keychainKey)
        try await keychain.delete(for: saltKey)
    }
    
    // MARK: - PIN Validation
    
    @discardableResult
    func validatePIN(_ pin: String) async throws -> Bool {
        guard pin.count == pinLength, pin.allSatisfy({ $0.isNumber }) else {
            throw PINError.invalidFormat(expectedLength: pinLength)
        }
        
        do {
            let storedHash: Data = try await keychain.load(for: keychainKey)
            let salt: Data = try await keychain.load(for: saltKey)
            
            let inputHash = hashPIN(pin, with: salt)
            
            if inputHash == storedHash {
                return true
            } else {
                throw PINError.incorrectPIN
            }
        } catch KeychainError.itemNotFound {
            throw PINError.noPINSet
        } catch let error as PINError {
            throw error
        } catch {
            throw PINError.validationFailed
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
    
    private func loadPINLength() {
        let savedLength = UserDefaults.standard.integer(forKey: pinLengthKey)
        if savedLength > 0 {
            pinLength = savedLength
        }
    }
    
    private func savePINLength() {
        UserDefaults.standard.set(pinLength, forKey: pinLengthKey)
    }
    
    // MARK: - Public Methods
    
    func updatePINLength(_ length: Int) {
        guard [4, 6, 8].contains(length) else { return }
        if Thread.isMainThread {
            pinLength = length
        } else {
            DispatchQueue.main.async {
                self.pinLength = length
            }
        }
        savePINLength()
    }
}

// MARK: - Error Types

enum PINError: LocalizedError {
    case invalidFormat(expectedLength: Int)
    case incorrectPIN
    case noPINSet
    case validationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let length):
            return "PIN must be exactly \(length) digits"
        case .incorrectPIN:
            return "Incorrect PIN"
        case .noPINSet:
            return "No PIN has been set"
        case .validationFailed:
            return "Failed to validate PIN"
        }
    }
}