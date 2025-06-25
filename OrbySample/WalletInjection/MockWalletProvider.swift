import Foundation

// Mock wallet provider for testing different scenarios
class MockWalletProvider {
    
    // Test accounts for different scenarios
    struct TestAccounts {
        static let primary = "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEDb"
        static let secondary = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"
        static let whale = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" // WETH contract
        
        static let all = [primary, secondary, whale]
    }
    
    // Test transactions for different types
    struct TestTransactions {
        static func simpleTransfer(from: String, to: String, value: String = "0x1BC16D674EC80000") -> [String: Any] {
            return [
                "from": from,
                "to": to,
                "value": value, // 2 ETH in wei
                "gas": "0x5208", // 21000
                "gasPrice": "0x9184E72A000" // 10 Gwei
            ]
        }
        
        static func contractCall(from: String, contract: String, data: String) -> [String: Any] {
            return [
                "from": from,
                "to": contract,
                "data": data,
                "gas": "0x186A0", // 100000
                "gasPrice": "0x9184E72A000"
            ]
        }
        
        static func tokenApprove(from: String, token: String, spender: String) -> [String: Any] {
            // ERC20 approve(address spender, uint256 amount)
            let data = "0x095ea7b3" +
                spender.replacingOccurrences(of: "0x", with: "").padding(toLength: 64, withPad: "0", startingAt: 0) +
                "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" // Max uint256
            
            return contractCall(from: from, contract: token, data: data)
        }
    }
    
    // Mock responses for different RPC methods
    static func mockResponse(for method: String, params: [Any], address: String?, chainId: Int) -> Any {
        switch method {
        case "eth_requestAccounts", "eth_accounts":
            return address != nil ? [address!] : []
            
        case "eth_chainId":
            return "0x" + String(chainId, radix: 16)
            
        case "net_version":
            return String(chainId)
            
        case "eth_blockNumber":
            return "0x" + String(Int.random(in: 15000000...16000000), radix: 16)
            
        case "eth_getBalance":
            // Return different balances based on address
            if let addr = params.first as? String {
                switch addr.lowercased() {
                case TestAccounts.whale.lowercased():
                    return "0x3635C9ADC5DEA00000" // 1000 ETH
                case TestAccounts.primary.lowercased():
                    return "0x1BC16D674EC80000" // 2 ETH
                default:
                    return "0xDE0B6B3A7640000" // 1 ETH
                }
            }
            return "0x0"
            
        case "eth_gasPrice":
            return "0x9184E72A000" // 10 Gwei
            
        case "eth_estimateGas":
            return "0x5208" // 21000 for simple transfer
            
        case "eth_getTransactionCount":
            return "0x" + String(Int.random(in: 0...100), radix: 16)
            
        case "eth_call":
            // Mock some common contract calls
            if let data = (params.first as? [String: Any])?["data"] as? String {
                if data.hasPrefix("0x70a08231") { // balanceOf
                    return "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
                } else if data.hasPrefix("0x06fdde03") { // name
                    return encodeString("Mock Token")
                } else if data.hasPrefix("0x95d89b41") { // symbol
                    return encodeString("MOCK")
                } else if data.hasPrefix("0x313ce567") { // decimals
                    return "0x0000000000000000000000000000000000000000000000000000000000000012" // 18
                }
            }
            return "0x"
            
        case "personal_sign", "eth_sign":
            let message = params.first as? String ?? "test message"
            let signature = generateMockSignature(for: message)
            return signature
            
        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            return generateMockSignature(for: "typed data")
            
        case "eth_sendTransaction":
            // Return mock transaction hash
            return "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(64)
            
        case "wallet_watchAsset":
            return true
            
        case "wallet_addEthereumChain":
            return nil // Success
            
        case "wallet_switchEthereumChain":
            return nil // Success
            
        case "eth_getCode":
            // Return empty for EOA, bytecode for contracts
            if let addr = params.first as? String {
                if addr.lowercased() == TestAccounts.whale.lowercased() {
                    return "0x606060405260043610..." // Mock contract bytecode
                }
            }
            return "0x"
            
        default:
            print("[MockWallet] Unhandled method: \(method)")
            return nil
        }
    }
    
    // Generate a mock signature
    private static func generateMockSignature(for message: String) -> String {
        let hash = message.data(using: .utf8)?.hashValue ?? 0
        let r = String(format: "%064x", abs(hash))
        let s = String(format: "%064x", abs(hash &* 2))
        let v = "1b" // 27 in hex
        return "0x" + r + s + v
    }
    
    // Encode string for eth_call response
    private static func encodeString(_ string: String) -> String {
        let data = string.data(using: .utf8)!
        let offset = String(format: "%064x", 32)
        let length = String(format: "%064x", data.count)
        let hex = data.map { String(format: "%02x", $0) }.joined()
        let padding = String(repeating: "0", count: (64 - hex.count % 64) % 64)
        return "0x" + offset + length + hex + padding
    }
    
    // Generate test events
    static func generateTestEvents() -> [String] {
        return [
            """
            // Simulate account change
            setTimeout(() => {
                const newAccounts = ['\(TestAccounts.secondary.lowercased())'];
                window.ethereum.emit('accountsChanged', newAccounts);
                console.log('📢 Simulated account change:', newAccounts);
            }, 5000);
            """,
            
            """
            // Simulate chain change
            setTimeout(() => {
                const newChainId = '0x89'; // Polygon
                window.ethereum.emit('chainChanged', newChainId);
                console.log('📢 Simulated chain change:', newChainId);
            }, 10000);
            """,
            
            """
            // Simulate disconnect
            setTimeout(() => {
                window.ethereum.emit('disconnect', { code: 4900, message: 'User disconnected' });
                console.log('📢 Simulated disconnect');
            }, 15000);
            """
        ]
    }
}