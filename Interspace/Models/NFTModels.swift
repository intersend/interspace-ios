import Foundation

// MARK: - NFT Models

struct NFTCollection: Identifiable, Codable {
    let id: String
    let name: String
    let nfts: [NFT]
    let floorPrice: Double
    let totalValue: Double
}

struct NFT: Identifiable, Codable {
    let id: String
    let name: String
    let tokenId: String
    let collection: String
    let imageUrl: String
    let rarity: NFTRarity
    let floorPrice: Double
}

enum NFTRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
    
    var color: String {
        switch self {
        case .common: return "#B0B0B0"
        case .uncommon: return "#4CAF50"
        case .rare: return "#2196F3"
        case .epic: return "#9C27B0"
        case .legendary: return "#FF9800"
        }
    }
}