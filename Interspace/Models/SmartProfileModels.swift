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
    let needsMpcGeneration: Bool? // Indicates if MPC wallet needs to be generated
    let clientShare: ClientShare? // Only present during initial creation
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
    let clientShare: String? // Optional
    
    init(name: String, clientShare: String? = nil) {
        self.name = name
        self.clientShare = clientShare
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
    let authStrategy: String // "wallet", "email", "social"
    let walletType: String?
    let customName: String?
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    let metadata: String? // JSON metadata for additional info
    
    var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        
        switch authStrategy {
        case "wallet":
            // Use wallet name from metadata if available
            if let walletName = walletDisplayName, !walletName.isEmpty {
                return walletName
            }
            // Fall back to WalletType enum
            return WalletType(rawValue: walletType ?? "")?.displayName ?? walletType?.capitalized ?? "Wallet"
        case "email":
            return "Email"
        case "social":
            return walletType?.capitalized ?? "Social"
        default:
            return authStrategy.capitalized
        }
    }
    
    var shortAddress: String {
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
    
    var displayIdentifier: String {
        switch authStrategy {
        case "email":
            return address // Email addresses are already the identifier
        case "social":
            return "@\(address)" // Social accounts might have usernames
        default:
            return shortAddress // Wallet addresses are shortened
        }
    }
    
    // Parse metadata JSON
    var parsedMetadata: [String: Any]? {
        guard let metadata = metadata,
              let data = metadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
    
    var walletIconURL: String? {
        return parsedMetadata?["icon"] as? String
    }
    
    var walletDisplayName: String? {
        return parsedMetadata?["name"] as? String
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
    let metadata: String?
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
    let profileId: String
    let appIds: [String]
    let folderId: String?
    
    enum CodingKeys: String, CodingKey {
        case profileId = "profileId"
        case appIds = "appIds"
        case folderId = "folderId"
    }
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
    let profileId: String
    let folderOrders: [String]
    
    enum CodingKeys: String, CodingKey {
        case profileId = "profileId"
        case folderOrders = "folderOrders"
    }
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

// MARK: - NFT Models

struct NFTData: Codable {
    let totalNFTs: Int
    let collections: [NFTCollection]
    let nfts: [NFTItem]
}

struct NFTCollection: Codable, Identifiable {
    let contractAddress: String
    let chainId: Int
    let name: String
    let tokenType: String
    let nfts: [NFTItem]
    
    var id: String { "\(chainId):\(contractAddress)" }
}

struct NFTItem: Codable, Identifiable {
    let contractAddress: String
    let tokenId: String
    let name: String?
    let tokenType: String
    let amount: String
    let metadata: NFTMetadata?
    let cachedImage: String?
    let rawMetadata: String?
    let chainId: Int
    let ownerAddress: String
    
    var id: String { "\(chainId):\(contractAddress):\(tokenId)" }
    
    var displayName: String {
        metadata?.name ?? name ?? "NFT #\(tokenId)"
    }
    
    var chainName: String {
        switch chainId {
        case 1: return "Ethereum"
        case 137: return "Polygon"
        case 42161: return "Arbitrum"
        case 10: return "Optimism"
        case 8453: return "Base"
        default: return "Chain \(chainId)"
        }
    }
    
    var imageUrl: String? {
        // Try cached image first, then metadata image, then generate placeholder
        if let cached = cachedImage {
            return cached
        }
        if let metadataImage = metadata?.image {
            // Handle IPFS URLs
            if metadataImage.hasPrefix("ipfs://") {
                let ipfsHash = metadataImage.replacingOccurrences(of: "ipfs://", with: "")
                return "https://ipfs.io/ipfs/\(ipfsHash)"
            }
            // Handle Arweave URLs
            if metadataImage.hasPrefix("ar://") {
                let arHash = metadataImage.replacingOccurrences(of: "ar://", with: "")
                return "https://arweave.net/\(arHash)"
            }
            return metadataImage
        }
        return nil
    }
}

struct NFTMetadata: Codable {
    let name: String?
    let description: String?
    let image: String?
    let attributes: [NFTAttribute]?
    let external_link: String?
}

struct NFTAttribute: Codable {
    let trait_type: String?
    let value: AnyCodableValue
    
    var traitType: String? {
        trait_type
    }
    
    var displayValue: String {
        return value.stringValue
    }
}

struct AnyCodableValue: Codable {
    let value: Any
    
    var stringValue: String {
        if let str = value as? String {
            return str
        } else if let num = value as? NSNumber {
            return num.stringValue
        } else {
            return String(describing: value)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String {
            try container.encode(str)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

// MARK: - NFT Response

struct NFTResponse: Codable {
    let success: Bool
    let data: NFTData
}

// MARK: - NFT Extensions

extension Array where Element == NFTItem {
    func groupedByCollection() -> [NFTCollection] {
        let grouped = Dictionary(grouping: self) { nft in
            "\(nft.chainId):\(nft.contractAddress)"
        }
        
        return grouped.compactMap { (key, nfts) in
            guard let firstNFT = nfts.first else { return nil }
            
            // Create a collection from the grouped NFTs
            return NFTCollection(
                contractAddress: firstNFT.contractAddress,
                chainId: firstNFT.chainId,
                name: firstNFT.metadata?.name ?? firstNFT.name ?? "Unknown Collection",
                tokenType: firstNFT.tokenType,
                nfts: nfts
            )
        }.sorted { $0.name < $1.name }
    }
}
