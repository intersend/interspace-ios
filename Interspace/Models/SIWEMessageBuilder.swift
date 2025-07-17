import Foundation
import CryptoKit

// MARK: - Data Extension for SHA256
extension Data {
    var sha256Hash: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - String Extension for Hash
extension String {
    var hash: String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.sha256Hash
    }
}

/// SIWE Message Builder - Ensures consistent message format for One-Click Auth
struct SIWEMessageBuilder {
    
    // MARK: - Constants
    private static let domain = "interspace.fi"
    private static let uri = "https://interspace.fi"
    private static let version = "1"
    private static let statement = "Sign in to Interspace" // Simplified statement
    
    // MARK: - Build Message
    
    /// Builds a simplified, consistent SIWE message
    static func buildSimpleMessage(
        address: String,
        nonce: String,
        chainId: Int = 1
    ) -> String {
        // Use UTC time with exact format matching JavaScript's toISOString()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let issuedAt = formatter.string(from: Date())
        
        // Build message in exact EIP-4361 format
        // CRITICAL: This format must match EXACTLY what wallets expect
        let message = """
        \(domain) wants you to sign in with your Ethereum account:
        \(address)
        
        \(statement)
        
        URI: \(uri)
        Version: \(version)
        Chain ID: \(chainId)
        Nonce: \(nonce)
        Issued At: \(issuedAt)
        """
        
        // Debug logging
        print("🔐 SIWE Message Built:")
        print("   Length: \(message.count) characters")
        print("   Hash: \(message.sha256Hash)")
        print("   Nonce: \(nonce)")
        print("   Address: \(address)")
        print("   Chain ID: \(chainId)")
        print("   Issued At: \(issuedAt)")
        
        return message
    }
    
    // MARK: - Validation
    
    /// Validates that a message matches our expected format
    static func validateMessage(_ message: String, expectedNonce: String) -> Bool {
        let lines = message.split(separator: "\n").map { String($0) }
        
        // Check basic structure
        guard lines.count >= 8 else {
            print("❌ SIWE validation failed: Not enough lines (\(lines.count))")
            return false
        }
        
        // Validate each component
        let checks = [
            lines[0].contains("\(domain) wants you to sign in with your Ethereum account:"),
            lines[3] == statement,
            lines[5] == "URI: \(uri)",
            lines[6] == "Version: \(version)",
            lines[7].starts(with: "Chain ID: "),
            lines[8] == "Nonce: \(expectedNonce)",
            lines[9].starts(with: "Issued At: ")
        ]
        
        for (index, check) in checks.enumerated() {
            if !check {
                print("❌ SIWE validation failed at line \(index)")
                if index < lines.count {
                    print("   Expected pattern for line \(index)")
                    print("   Got: \(lines[index])")
                }
                return false
            }
        }
        
        print("✅ SIWE message validation passed")
        return true
    }
    
    // MARK: - Extract Components
    
    /// Extracts the nonce from a SIWE message
    static func extractNonce(from message: String) -> String? {
        let lines = message.split(separator: "\n")
        for line in lines {
            if line.starts(with: "Nonce: ") {
                return String(line.dropFirst(7))
            }
        }
        return nil
    }
    
    /// Extracts the address from a SIWE message
    static func extractAddress(from message: String) -> String? {
        let lines = message.split(separator: "\n")
        if lines.count >= 2 {
            return String(lines[1])
        }
        return nil
    }
    
    // MARK: - Debug Helpers
    
    /// Compare two messages and log differences
    static func compareMessages(expected: String, actual: String) {
        print("\n🔍 MESSAGE COMPARISON:")
        print("Expected length: \(expected.count)")
        print("Actual length: \(actual.count)")
        
        if expected == actual {
            print("✅ Messages match exactly!")
        } else {
            print("❌ Messages differ!")
            
            // Find first difference
            let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
            let actualLines = actual.split(separator: "\n", omittingEmptySubsequences: false)
            
            let maxLines = max(expectedLines.count, actualLines.count)
            
            for i in 0..<maxLines {
                let expLine = i < expectedLines.count ? String(expectedLines[i]) : "<missing>"
                let actLine = i < actualLines.count ? String(actualLines[i]) : "<missing>"
                
                if expLine != actLine {
                    print("\n   First difference at line \(i + 1):")
                    print("   Expected: '\(expLine)'")
                    print("   Actual:   '\(actLine)'")
                    break
                }
            }
            
            print("\nExpected message:")
            print("---START---")
            print(expected)
            print("---END---")
            
            print("\nActual message:")
            print("---START---")
            print(actual)
            print("---END---")
        }
    }
    
    /// Get expected parameters for validation
    static func getExpectedParams() -> (domain: String, uri: String, statement: String, version: String) {
        return (domain: domain, uri: uri, statement: statement, version: version)
    }
}

// MARK: - String Extension for SHA256 Hash

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}