import Foundation
import SwiftUI

// MARK: - Type Aliases for cleaner access
typealias TokenBalance = UnifiedBalance.TokenBalance
typealias ChainBalance = UnifiedBalance.ChainBalance

// MARK: - Extensions to provide expected properties
extension TokenBalance {
    var totalBalance: Double {
        // Convert string to double
        Double(totalAmount) ?? 0.0
    }
    
    var totalBalanceUSD: Double {
        // Convert string to double
        Double(totalUsdValue) ?? 0.0
    }
    
    var chainBalances: [ChainBalance] {
        // Map to the expected property name
        balancesPerChain
    }
}

extension ChainBalance {
    var balance: Double {
        // Convert string to double
        Double(amount) ?? 0.0
    }
    
    var balanceUSD: Double {
        // Calculate USD value based on proportion of total
        // This is an approximation since the API doesn't provide per-chain USD values
        guard let parent = findParentToken(),
              parent.totalBalance > 0 else { return 0.0 }
        
        let proportion = balance / parent.totalBalance
        return parent.totalBalanceUSD * proportion
    }
    
    // Helper to find parent token (would need to be implemented based on app structure)
    private func findParentToken() -> TokenBalance? {
        // This would need to be implemented based on how the app manages the relationship
        // For now, return nil
        return nil
    }
}

// MARK: - MPC Transaction Model
struct MPCTransaction: Identifiable {
    let id: String
    let type: TransactionType
    let status: TransactionStatus
    let from: String
    let to: String
    let value: String
    let tokenSymbol: String?
    let chainId: Int
    let unsignedData: String
    let timestamp: Date
    
    // Additional properties for different use cases
    let amount: String?
    let token: String?
    let recipient: String?
    let network: String?
    let gasEstimate: String?
    let nonce: Int?
    let data: String?
    let messageToSign: Data?
    
    enum TransactionType {
        case send
        case swap
        
        var icon: String {
            switch self {
            case .send:
                return "paperplane.fill"
            case .swap:
                return "arrow.left.arrow.right"
            }
        }
        
        var displayName: String {
            switch self {
            case .send:
                return "Send Transaction"
            case .swap:
                return "Swap Transaction"
            }
        }
    }
    
    enum TransactionStatus {
        case pending
        case signed
        case submitted
        case confirmed
        case failed
    }
    
    // Convenience initializers
    init(id: String, type: TransactionType, status: TransactionStatus = .pending,
         from: String, to: String, value: String, tokenSymbol: String? = nil,
         chainId: Int, unsignedData: String, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.status = status
        self.from = from
        self.to = to
        self.value = value
        self.tokenSymbol = tokenSymbol
        self.chainId = chainId
        self.unsignedData = unsignedData
        self.timestamp = timestamp
        
        // Set optional properties to nil
        self.amount = nil
        self.token = nil
        self.recipient = nil
        self.network = nil
        self.gasEstimate = nil
        self.nonce = nil
        self.data = nil
        self.messageToSign = nil
    }
    
    // Full initializer for swap transactions
    init(id: String, type: TransactionType, amount: String, token: String,
         recipient: String, network: String, gasEstimate: String,
         nonce: Int, data: String, messageToSign: Data) {
        self.id = id
        self.type = type
        self.status = .pending
        self.from = ""
        self.to = recipient
        self.value = amount
        self.tokenSymbol = nil
        self.chainId = 1 // Default chainId
        self.unsignedData = data
        self.timestamp = Date()
        
        // Set optional properties
        self.amount = amount
        self.token = token
        self.recipient = recipient
        self.network = network
        self.gasEstimate = gasEstimate
        self.nonce = nonce
        self.data = data
        self.messageToSign = messageToSign
    }
}

// MARK: - Enhanced Token Balance for UI
struct EnhancedTokenBalance {
    let token: TokenBalance
    
    var id: String { token.id }
    var symbol: String { token.symbol }
    var name: String { token.name }
    var decimals: Int { token.decimals }
    var totalBalance: Double { token.totalBalance }
    var totalBalanceUSD: Double { token.totalBalanceUSD }
    var chainBalances: [ChainBalance] { token.chainBalances }
    
    // Additional UI-specific properties
    var displayBalance: String {
        WalletDesignSystem.formatTokenAmount(totalBalance, decimals: decimals)
    }
    
    var displayBalanceUSD: String {
        WalletDesignSystem.formatCurrency(totalBalanceUSD)
    }
    
    var hasBalance: Bool {
        totalBalance > 0
    }
    
    var primaryChain: ChainBalance? {
        chainBalances.max(by: { $0.balance < $1.balance })
    }
}

// MARK: - Wallet Errors
// Note: WalletViewError is defined in ViewModels/WalletViewModel.swift

// MARK: - Shimmer Effect
// Note: ShimmerModifier is defined in SheetAnimations.swift

// MARK: - Success Animation View
// Note: SuccessAnimationView is defined in SheetAnimations.swift

// MARK: - View Models
// Note: SendTokenViewModel is defined in SendTokenSheet.swift
// Note: SwapTokenViewModel is defined in SwapTokenSheet.swift

// MARK: - Gas Token Model
struct WalletGasToken: Identifiable, Equatable {
    let id: String
    let symbol: String
    let balance: Double
    let decimals: Int
    let priceUSD: Double
    var isAISelected: Bool = false
    
    static func == (lhs: WalletGasToken, rhs: WalletGasToken) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API Request/Response Models
struct CreateIntentRequest: Codable {
    let type: String
    let from: TokenEndpoint
    let to: TokenEndpoint
    let gasToken: String?
    
    struct TokenEndpoint: Codable {
        let token: String?
        let chainId: Int?
        let amount: String?
        let address: String?
    }
}

struct CreateIntentResponse: Codable {
    let operationSetId: String
    let unsignedOperations: [UnsignedOperation]
    let data: IntentData
    
    struct IntentData: Codable {
        let intentId: String
        let operationSetId: String
        let unsignedOperations: UnsignedOperations
    }
    
    struct UnsignedOperations: Codable {
        let intents: [Intent]
    }
    
    struct UnsignedOperation: Codable {
        let operationId: String
        let unsignedData: String
        let chainId: Int
        let to: String
        let value: String
        let data: String
        let nonce: String
    }
    
    struct Intent: Codable {
        let to: String
        let value: String
        let data: String
        let nonce: String
    }
}

// Note: IntentResponse is defined in WalletAPI.swift

// Note: TransactionRequest is defined in MPCWalletService.swift

struct SignedOperation: Codable {
    let index: Int
    let signature: String
    let signedData: String?
    
    init(index: Int, signature: String, signedData: String? = nil) {
        self.index = index
        self.signature = signature
        self.signedData = signedData
    }
}

// MARK: - Utility Functions
// Note: convertToSmallestUnit is defined in SendTokenSheet.swift

// MARK: - Data Extensions
extension Data {
    init?(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: cleanHex.count / 2)
        
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let endIndex = cleanHex.index(index, offsetBy: 2)
            guard let byte = UInt8(cleanHex[index..<endIndex], radix: 16) else { return nil }
            data.append(byte)
            index = endIndex
        }
        
        self = data
    }
    
    func hexEncodedString(uppercased: Bool = false) -> String {
        let format = uppercased ? "%02X" : "%02x"
        return map { String(format: format, $0) }.joined()
    }
}

