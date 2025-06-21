import Foundation

// MARK: - SmartProfile Models

struct SmartProfile: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let isActive: Bool
    let sessionWalletAddress: String
    let linkedAccountsCount: Int
    let appsCount: Int
    let foldersCount: Int
    let isDevelopmentWallet: Bool? // Indicates if this profile uses a development wallet
    let clientShare: ClientShare? // Only present for development wallets
    let createdAt: String
    let updatedAt: String
    
    // Computed properties for display
    var shortAddress: String {
        let prefix = sessionWalletAddress.prefix(6)
        let suffix = sessionWalletAddress.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
}

// Client share structure for development wallets
struct ClientShare: Codable, Hashable {
    let p1_key_share: KeyShare?
    let public_key: String
    let address: String
    
    struct KeyShare: Codable, Hashable {
        let secret_share: String
        let public_key: String
    }
}

// MARK: - Create Profile Request

struct CreateProfileRequest: Codable {
    let name: String
    let clientShare: String? // Optional, not needed for development mode
    let developmentMode: Bool // Flag to create development wallet (non-optional to ensure it's always sent)
    
    init(name: String, clientShare: String? = nil, developmentMode: Bool = false) {
        self.name = name
        self.clientShare = clientShare
        self.developmentMode = developmentMode
    }
}

// MARK: - Update Profile Request

struct UpdateProfileRequest: Codable {
    let name: String?
    let isActive: Bool?
}

// MARK: - API Response Wrappers

struct ProfilesResponse: Codable {
    let success: Bool
    let data: [SmartProfile]
}

struct ProfileResponse: Codable {
    let success: Bool
    let data: SmartProfile
    let message: String?
}

// MARK: - Linked Account Models

struct LinkedAccount: Codable, Identifiable, Hashable {
    let id: String
    let address: String
    let walletType: String
    let customName: String?
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    
    var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        return WalletType(rawValue: walletType)?.displayName ?? walletType.capitalized
    }
    
    var shortAddress: String {
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Link Account Request

struct LinkAccountRequest: Codable {
    let address: String
    let walletType: String
    let customName: String?
    let isPrimary: Bool
    let signature: String?
    let message: String?
    let chainId: Int?
}

// MARK: - Update Account Request

struct UpdateAccountRequest: Codable {
    let customName: String?
    let isPrimary: Bool?
}

// MARK: - Linked Accounts Response

struct LinkedAccountsResponse: Codable {
    let success: Bool
    let data: [LinkedAccount
    ]
}

struct LinkedAccountResponse: Codable {
    let success: Bool
    let data: LinkedAccount
    let message: String?
}

// MARK: - App Bookmark Models

struct BookmarkedApp: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let iconUrl: String?
    let position: Int
    let folderId: String?
    let folderName: String?
    let createdAt: String
    let updatedAt: String
    
    // Computed properties for compatibility and display
    var profileId: String? {
        // This will be handled by the active profile context
        return nil
    }
    
    var iconData: Data? {
        // Icon data will be cached separately if needed
        return nil
    }
    
    var isNativeApp: Bool {
        // All bookmarked apps are web apps in the backend
        return false
    }
    
    var displayIconUrl: String {
        iconUrl ?? "https://via.placeholder.com/64x64?text=\(name.prefix(1))"
    }
    
    // Custom initializer for creating new apps locally
    init(id: String = UUID().uuidString, 
         name: String, 
         url: String, 
         iconUrl: String? = nil, 
         position: Int, 
         folderId: String? = nil, 
         folderName: String? = nil,
         createdAt: String = ISO8601DateFormatter().string(from: Date()), 
         updatedAt: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.name = name
        self.url = url
        self.iconUrl = iconUrl
        self.position = position
        self.folderId = folderId
        self.folderName = folderName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Create App Request

struct CreateAppRequest: Codable {
    let name: String
    let url: String
    let iconUrl: String?
    let folderId: String?
    let position: Int
}

// MARK: - Update App Request

struct UpdateAppRequest: Codable {
    let name: String?
    let url: String?
    let iconUrl: String?
    let folderId: String?
    let position: Int?
}

// MARK: - App Reorder Request

struct ReorderAppsRequest: Codable {
    let appIds: [String]
    let folderId: String?
}

// MARK: - Move App Request

struct MoveAppRequest: Codable {
    let targetFolderId: String?
    let position: Int?
}

// MARK: - Apps Response

struct AppsResponse: Codable {
    let success: Bool
    let data: [BookmarkedApp]
}

struct AppResponse: Codable {
    let success: Bool
    let data: BookmarkedApp
    let message: String?
}

// MARK: - Folder Models

struct AppFolder: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let color: String
    let position: Int
    let isPublic: Bool
    let appsCount: Int
    let createdAt: String
    let updatedAt: String
    
    var folderColor: String {
        color.isEmpty ? "#6366F1" : color // Default to indigo
    }
}

// MARK: - Create Folder Request

struct CreateFolderRequest: Codable {
    let name: String
    let color: String
    let position: Int
}

// MARK: - Update Folder Request

struct UpdateFolderRequest: Codable {
    let name: String?
    let color: String?
    let isPublic: Bool?
}

// MARK: - Reorder Folders Request

struct ReorderFoldersRequest: Codable {
    let folderIds: [String]
}

// MARK: - Folders Response

struct FoldersResponse: Codable {
    let success: Bool
    let data: [AppFolder]
}

struct FolderResponse: Codable {
    let success: Bool
    let data: AppFolder
    let message: String?
}

// MARK: - Share Folder Response

struct ShareFolderResponse: Codable {
    let success: Bool
    let data: ShareData
    
    struct ShareData: Codable {
        let shareableId: String
        let shareableUrl: String
    }
}

// MARK: - Balance Models

struct UnifiedBalance: Codable {
    let profileId: String
    let profileName: String
    let unifiedBalance: BalanceData
    let gasAnalysis: GasAnalysis
    
    struct BalanceData: Codable {
        let totalUsdValue: String
        let tokens: [TokenBalance]
    }
    
    struct TokenBalance: Codable, Identifiable {
        let standardizedTokenId: String
        let symbol: String
        let name: String
        let totalAmount: String
        let totalUsdValue: String
        let decimals: Int
        let balancesPerChain: [ChainBalance]
        
        var id: String { standardizedTokenId }
    }
    
    struct ChainBalance: Codable {
        let chainId: Int
        let chainName: String
        let amount: String
        let tokenAddress: String
        let isNative: Bool
    }
    
    struct GasAnalysis: Codable {
        let suggestedGasToken: SuggestedGasToken?
        let nativeGasAvailable: [NativeGas]
        let availableGasTokens: [String]
        
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

// MARK: - Balance Response

struct BalanceResponse: Codable {
    let success: Bool
    let data: UnifiedBalance
}

// MARK: - Transaction Models

struct TransactionHistory: Codable {
    var transactions: [TransactionItem]
    var pagination: PaginationInfo
    
    struct TransactionItem: Codable, Identifiable {
        let operationSetId: String
        let type: String
        let status: String
        let from: TransactionEndpoint?
        let to: TransactionEndpoint?
        let gasToken: String?
        let createdAt: String
        let completedAt: String?
        let transactions: [OnChainTransaction]
        
        var id: String { operationSetId }
        
        struct TransactionEndpoint: Codable {
            let token: String?
            let chainId: Int?
            let amount: String?
            let address: String?
        }
        
        struct OnChainTransaction: Codable {
            let chainId: Int
            let hash: String
            let status: String
            let gasUsed: String?
        }
    }
    
    struct PaginationInfo: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
        let hasNext: Bool
        let hasPrev: Bool
    }
}

// MARK: - Transaction History Response

struct TransactionHistoryResponse: Codable {
    let success: Bool
    let data: TransactionHistory
}
