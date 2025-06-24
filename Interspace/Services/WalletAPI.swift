import Foundation

// MARK: - Wallet API Service

final class WalletAPI {
    static let shared = WalletAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Balance & Wallet Endpoints
    
    /// GET /profiles/:id/balance
    func getUnifiedBalance(profileId: String) async throws -> UnifiedBalance {
        let response: BalanceResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/balance",
            method: .GET,
            responseType: BalanceResponse.self
        )
        return response.data
    }
    
    /// GET /profiles/:id/orby-rpc-url
    func getOrbyRPCUrl(profileId: String, chainId: Int) async throws -> String {
        let response: OrbyRPCResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/orby-rpc-url?chainId=\(chainId)",
            method: .GET,
            responseType: OrbyRPCResponse.self
        )
        return response.data.rpcUrl
    }
    
    /// GET /profiles/:id/gas-tokens
    func getAvailableGasTokens(profileId: String) async throws -> GasTokensResponse {
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/gas-tokens",
            method: .GET,
            responseType: GasTokensResponse.self
        )
    }
    
    /// POST /profiles/:id/gas-tokens/preference
    func setPreferredGasToken(profileId: String, request: GasTokenPreferenceRequest) async throws -> GasTokenPreferenceResponse {
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/gas-tokens/preference",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: GasTokenPreferenceResponse.self
        )
    }
    
    // MARK: - Transaction Endpoints
    
    /// GET /profiles/:id/transactions
    func getTransactionHistory(profileId: String, page: Int = 1, limit: Int = 20) async throws -> TransactionHistory {
        let response: TransactionHistoryResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/transactions?page=\(page)&limit=\(limit)",
            method: .GET,
            responseType: TransactionHistoryResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:id/intent
    func createIntent(profileId: String, request: CreateIntentRequest) async throws -> IntentResponse {
        return try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/intent",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: IntentResponse.self
        )
    }
    
    /// POST /operations/:operationSetId/submit
    func submitSignedOperations(operationSetId: String, signedOperations: [SignedOperation]) async throws -> SubmitOperationsResponse {
        let request = SubmitOperationsRequest(signedOperations: signedOperations)
        return try await apiService.performRequest(
            endpoint: "/operations/\(operationSetId)/submit",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: SubmitOperationsResponse.self
        )
    }
    
    /// GET /operations/:operationSetId/status
    func getOperationStatus(operationSetId: String) async throws -> OperationStatus {
        let response: OperationStatusResponse = try await apiService.performRequest(
            endpoint: "/operations/\(operationSetId)/status",
            method: .GET,
            responseType: OperationStatusResponse.self
        )
        return response.data
    }
    
    // MARK: - Account Management Endpoints
    
    /// GET /profiles/:profileId/accounts
    func getLinkedAccounts(profileId: String) async throws -> [LinkedAccount] {
        let response: LinkedAccountsResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/accounts",
            method: .GET,
            responseType: LinkedAccountsResponse.self
        )
        return response.data
    }
    
    /// POST /profiles/:profileId/accounts
    func linkAccount(profileId: String, request: LinkAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/profiles/\(profileId)/accounts",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// PUT /accounts/:accountId
    func updateLinkedAccount(accountId: String, request: UpdateAccountRequest) async throws -> LinkedAccount {
        let response: LinkedAccountResponse = try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)",
            method: .PUT,
            body: try JSONEncoder().encode(request),
            responseType: LinkedAccountResponse.self
        )
        return response.data
    }
    
    /// DELETE /accounts/:accountId
    func unlinkAccount(accountId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
    
    // MARK: - Token Allowance Endpoints
    
    /// POST /accounts/:accountId/allowances
    func grantTokenAllowance(accountId: String, request: GrantAllowanceRequest) async throws -> TokenAllowance {
        let response: AllowanceResponse = try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)/allowances",
            method: .POST,
            body: try JSONEncoder().encode(request),
            responseType: AllowanceResponse.self
        )
        return response.data
    }
    
    /// GET /accounts/:accountId/allowances
    func getTokenAllowances(accountId: String) async throws -> [TokenAllowance] {
        let response: AllowancesResponse = try await apiService.performRequest(
            endpoint: "/accounts/\(accountId)/allowances",
            method: .GET,
            responseType: AllowancesResponse.self
        )
        return response.data
    }
    
    /// DELETE /allowances/:allowanceId
    func revokeTokenAllowance(allowanceId: String) async throws -> DeleteResponse {
        return try await apiService.performRequest(
            endpoint: "/allowances/\(allowanceId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }
}

// MARK: - Request Models

struct GasTokenPreferenceRequest: Codable {
    let standardizedTokenId: String
    let tokenSymbol: String
    let chainPreferences: [String: String] // chainId -> tokenAddress mapping
}

struct CreateIntentRequest: Codable {
    let type: String
    let from: IntentEndpoint?
    let to: IntentEndpoint?
    let gasToken: GasTokenSource?
    
    struct IntentEndpoint: Codable {
        let token: String?
        let chainId: Int?
        let amount: String?
        let address: String?
    }
    
    struct GasTokenSource: Codable {
        let standardizedTokenId: String
        let tokenSources: [TokenSource]
        
        struct TokenSource: Codable {
            let chainId: Int
            let address: String
        }
    }
}

struct SubmitOperationsRequest: Codable {
    let signedOperations: [SignedOperation]
}

struct SignedOperation: Codable {
    let index: Int
    let signature: String
    let signedData: String
}

struct GrantAllowanceRequest: Codable {
    let tokenAddress: String
    let allowanceAmount: String
    let chainId: Int
}

// MARK: - Response Models

struct OrbyRPCResponse: Codable {
    let success: Bool
    let data: OrbyRPCData
    
    struct OrbyRPCData: Codable {
        let rpcUrl: String
    }
}

struct GasTokensResponse: Codable {
    let success: Bool
    let data: GasTokensData
    
    struct GasTokensData: Codable {
        let availableTokens: [GasToken]
        let suggestedToken: SuggestedGasToken?
        let nativeGasAvailable: [NativeGas]
        
        struct GasToken: Codable {
            let tokenId: String
            let symbol: String
            let name: String
            let score: Int
            let totalBalance: String
            let totalUsdValue: String
            let availableChains: [Int]
            let isNative: Bool
            let factors: GasTokenFactors
            
            struct GasTokenFactors: Codable {
                let balanceScore: Int
                let efficiencyScore: Int
                let availabilityScore: Int
                let preferenceScore: Int
            }
        }
        
        struct SuggestedGasToken: Codable {
            let tokenId: String
            let symbol: String
            let score: Int
        }
        
        struct NativeGas: Codable {
            let chainId: Int
            let amount: String
            let symbol: String
        }
    }
}

struct GasTokenPreferenceResponse: Codable {
    let success: Bool
    let message: String
}

struct IntentResponse: Codable {
    let success: Bool
    let data: IntentData
    
    struct IntentData: Codable {
        let intentId: String
        let operationSetId: String
        let type: String
        let status: String
        let estimatedTimeMs: Int
        let unsignedOperations: UnsignedOperations
        let summary: IntentSummary
        
        struct UnsignedOperations: Codable {
            let status: String
            let intents: [UnsignedOperation]
            let estimatedTimeInMs: Int
            
            struct UnsignedOperation: Codable {
                let type: String
                let format: String
                let from: String
                let to: String
                let chainId: String
                let data: String
                let value: String
                let nonce: String
                let gasLimit: String
            }
        }
        
        struct IntentSummary: Codable {
            let from: SummaryEndpoint?
            let to: SummaryEndpoint?
            let gasToken: String?
            
            struct SummaryEndpoint: Codable {
                let token: String?
                let chainId: Int?
                let amount: String?
                let address: String?
            }
        }
    }
}

struct SubmitOperationsResponse: Codable {
    let success: Bool
    let data: SubmitData
    
    struct SubmitData: Codable {
        let success: Bool
        let operationSetId: String
        let status: String
        let message: String
    }
}

struct OperationStatusResponse: Codable {
    let success: Bool
    let data: OperationStatus
}

struct OperationStatus: Codable {
    let operationSetId: String
    let status: String
    let type: String
    let createdAt: String
    let completedAt: String?
    let transactions: [OnChainTransaction]
    
    struct OnChainTransaction: Codable {
        let chainId: Int
        let hash: String
        let status: String
        let gasUsed: String?
    }
}

struct AllowanceResponse: Codable {
    let success: Bool
    let data: TokenAllowance
    let message: String
}

struct AllowancesResponse: Codable {
    let success: Bool
    let data: [TokenAllowance]
}

struct TokenAllowance: Codable, Identifiable {
    let id: String
    let tokenAddress: String
    let allowanceAmount: String
    let chainId: Int
    let createdAt: String
    let updatedAt: String
}
