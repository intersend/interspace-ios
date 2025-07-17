import Foundation

/// Base58 encoding/decoding utility
/// Used by various wallets including Phantom for encoding public keys and data
public enum Base58 {
    private static let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    private static let alphabetArray = Array(alphabet)
    
    /// Encode data to Base58 string
    public static func encode(_ data: Data) -> String {
        var bytes = [UInt8](data)
        var encoded: [Character] = []
        
        // Count leading zeros
        var leadingZeros = 0
        for byte in bytes {
            if byte != 0 { break }
            leadingZeros += 1
        }
        
        // Convert to base58
        while !bytes.allSatisfy({ $0 == 0 }) {
            var remainder: UInt16 = 0
            var newBytes: [UInt8] = []
            
            for byte in bytes {
                let temp = UInt16(byte) + remainder * 256
                newBytes.append(UInt8(temp / 58))
                remainder = temp % 58
            }
            
            encoded.append(alphabetArray[Int(remainder)])
            bytes = Array(newBytes.drop(while: { $0 == 0 }))
        }
        
        // Add leading 1s for leading zeros
        encoded.append(contentsOf: Array(repeating: alphabetArray[0], count: leadingZeros))
        
        return String(encoded.reversed())
    }
    
    /// Decode Base58 string to data
    public static func decode(_ string: String) throws -> Data {
        // Validate input
        guard !string.isEmpty else {
            throw Base58Error.emptyString
        }
        
        // Map characters to values
        var values: [UInt8] = []
        for char in string {
            guard let index = alphabetArray.firstIndex(of: char) else {
                throw Base58Error.invalidCharacter(char)
            }
            values.append(UInt8(index))
        }
        
        // Count leading ones (they represent zeros)
        var leadingZeros = 0
        for value in values {
            if value != 0 { break }
            leadingZeros += 1
        }
        
        // Convert from base58
        var bytes: [UInt8] = []
        for value in values {
            var carry = UInt32(value)
            var newBytes: [UInt8] = []
            
            for byte in bytes {
                carry += UInt32(byte) * 58
                newBytes.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
            
            while carry > 0 {
                newBytes.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
            
            bytes = newBytes
        }
        
        // Remove trailing zeros and add leading zeros
        while bytes.last == 0 && !bytes.isEmpty {
            bytes.removeLast()
        }
        
        let result = Array(repeating: UInt8(0), count: leadingZeros) + bytes.reversed()
        return Data(result)
    }
}

/// Base58 errors
public enum Base58Error: LocalizedError {
    case emptyString
    case invalidCharacter(Character)
    
    public var errorDescription: String? {
        switch self {
        case .emptyString:
            return "Cannot decode empty string"
        case .invalidCharacter(let char):
            return "Invalid Base58 character: '\(char)'"
        }
    }
}

// MARK: - Data Extension

extension Data {
    /// Convert data to Base58 string
    var base58EncodedString: String {
        Base58.encode(self)
    }
    
    /// Initialize data from Base58 string
    init?(base58Encoded string: String) {
        guard let data = try? Base58.decode(string) else {
            return nil
        }
        self = data
    }
}