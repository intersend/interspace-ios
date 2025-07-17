import Foundation

// MARK: - App Store Category

struct AppStoreCategory: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let icon: String?
    let position: Int
    let appsCount: Int?
    let createdAt: String
    let updatedAt: String
}

// MARK: - App Store App

struct AppStoreApp: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let url: String
    let iconUrl: String?
    let category: AppStoreCategory
    let description: String
    let detailedDescription: String?
    let tags: [String]
    let popularity: Int
    let isNew: Bool
    let isFeatured: Bool
    let chainSupport: [String]
    let screenshots: [String]
    let developer: String?
    let version: String?
    let lastUpdated: String
    let shareableId: String?
    let metadata: AppStoreMetadata?
    let createdAt: String
    let updatedAt: String
}

// MARK: - App Store Metadata

struct AppStoreMetadata: Codable, Equatable {
    // Additional metadata fields can be added here
}

// MARK: - API Response Models

struct AppStoreCategoriesResponse: Codable {
    let success: Bool
    let data: [AppStoreCategory]
}

struct AppStoreAppsResponse: Codable {
    let success: Bool
    let data: [AppStoreApp]
    let pagination: PaginationInfo?
}

struct AppStoreFeaturedResponse: Codable {
    let success: Bool
    let data: [AppStoreApp]
}

struct AppStoreSearchResponse: Codable {
    let success: Bool
    let data: [AppStoreApp]
    let pagination: PaginationInfo?
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrev: Bool
}

// MARK: - Search Parameters

struct AppStoreSearchParams {
    var query: String?
    var category: String?
    var tags: [String]?
    var chains: [String]?
    var sortBy: SortOption?
    var page: Int = 1
    var limit: Int = 20
    
    enum SortOption: String {
        case popularity = "popularity"
        case newest = "newest"
        case name = "name"
    }
}

// MARK: - Extensions

extension AppStoreApp {
    /// Check if app supports a specific chain
    func supportsChain(_ chainId: String) -> Bool {
        return chainSupport.contains(chainId)
    }
    
    /// Get display name for developer
    var displayDeveloper: String {
        return developer ?? "Unknown Developer"
    }
    
    /// Check if app has screenshots
    var hasScreenshots: Bool {
        return !screenshots.isEmpty
    }
    
    /// Get primary tag
    var primaryTag: String? {
        return tags.first
    }
}

extension AppStoreCategory {
    /// Get emoji icon or fallback
    var displayIcon: String {
        return icon ?? "📱"
    }
    
    /// Check if category has apps
    var hasApps: Bool {
        return (appsCount ?? 0) > 0
    }
}