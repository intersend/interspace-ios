import Foundation
import CryptoKit

/// Ethereum transaction builder and serializer
/// Handles RLP encoding for transaction signing
final class TransactionBuilder {
    
    // MARK: - Transaction Types
    
    enum TransactionType: UInt8 {
        case legacy = 0
        case eip2930 = 1
        case eip1559 = 2
    }
    
    // MARK: - Build Transaction
    
    /// Build a transaction for signing
    static func buildTransaction(
        from: String,
        to: String,
        value: String? = nil,
        data: String? = nil,
        nonce: String? = nil,
        gasLimit: String? = nil,
        gasPrice: String? = nil,
        maxFeePerGas: String? = nil,
        maxPriorityFeePerGas: String? = nil,
        chainId: Int = 1
    ) -> WalletTransaction {
        WalletTransaction(
            from: from,
            to: to,
            value: value ?? "0x0",
            data: data ?? "0x",
            gasLimit: gasLimit ?? "0x5208", // 21000 for simple transfer
            gasPrice: gasPrice,
            nonce: nonce,
            chainId: chainId
        )
    }
    
    // MARK: - RLP Encoding
    
    /// Encode transaction for signing (RLP encoding)
    static func encodeForSigning(_ transaction: WalletTransaction) -> Data? {
        // For now, return a simple hash
        // In production, this would implement proper RLP encoding
        let message = """
        from: \(transaction.from)
        to: \(transaction.to)
        value: \(transaction.value ?? "0x0")
        data: \(transaction.data ?? "0x")
        chainId: \(transaction.chainId)
        """
        
        return message.data(using: .utf8)
    }
    
    /// Create transaction hash
    static func createTransactionHash(_ transaction: WalletTransaction) -> Data {
        guard let encoded = encodeForSigning(transaction) else {
            return Data()
        }
        
        // Use SHA256 for now (ideally should use Keccak256 for Ethereum)
        // Note: For proper Ethereum transaction hashing, you should use Keccak256
        let hash = SHA256.hash(data: encoded)
        return Data(hash)
    }
    
    // MARK: - Hex Utilities
    
    /// Convert hex string to Data
    static func hexToData(_ hex: String) -> Data? {
        var hex = hex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let endIndex = hex.index(index, offsetBy: 2)
            let bytes = hex[index..<endIndex]
            
            if let byte = UInt8(bytes, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            
            index = endIndex
        }
        
        return data
    }
    
    /// Convert Data to hex string
    static func dataToHex(_ data: Data) -> String {
        "0x" + data.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Normalize hex value (ensure 0x prefix and even length)
    static func normalizeHex(_ hex: String) -> String {
        var normalized = hex.lowercased()
        
        if !normalized.hasPrefix("0x") {
            normalized = "0x" + normalized
        }
        
        // Ensure even length (excluding 0x)
        let valueOnly = String(normalized.dropFirst(2))
        if valueOnly.count % 2 == 1 {
            normalized = "0x0" + valueOnly
        }
        
        return normalized
    }
}

// MARK: - Web3 Transaction Extensions

extension WalletTransaction {
    /// Convert to Web3 provider format
    var web3Format: [String: Any] {
        var params: [String: Any] = [
            "from": from,
            "to": to
        ]
        
        if let value = value, value != "0x0" {
            params["value"] = value
        }
        
        if let data = data, data != "0x" {
            params["data"] = data
        }
        
        if let gasLimit = gasLimit {
            params["gas"] = gasLimit
        }
        
        if let gasPrice = gasPrice {
            params["gasPrice"] = gasPrice
        }
        
        if let nonce = nonce {
            params["nonce"] = nonce
        }
        
        params["chainId"] = String(format: "0x%x", chainId)
        
        return params
    }
    
    /// Create from Web3 params
    static func from(web3Params params: [String: Any]) -> WalletTransaction? {
        guard let from = params["from"] as? String,
              let to = params["to"] as? String else {
            return nil
        }
        
        let chainId: Int
        if let chainIdParam = params["chainId"] {
            if let chainIdString = chainIdParam as? String {
                // Handle hex string
                if chainIdString.hasPrefix("0x") {
                    chainId = Int(String(chainIdString.dropFirst(2)), radix: 16) ?? 1
                } else {
                    chainId = Int(chainIdString) ?? 1
                }
            } else if let chainIdInt = chainIdParam as? Int {
                chainId = chainIdInt
            } else {
                chainId = 1
            }
        } else {
            chainId = 1
        }
        
        return WalletTransaction(
            from: from,
            to: to,
            value: params["value"] as? String,
            data: params["data"] as? String,
            gasLimit: params["gas"] as? String ?? params["gasLimit"] as? String,
            gasPrice: params["gasPrice"] as? String,
            nonce: params["nonce"] as? String,
            chainId: chainId
        )
    }
}