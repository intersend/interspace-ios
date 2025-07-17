import Foundation

class AppStoreAPI {
    static let shared = AppStoreAPI()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Categories
    
    /// Fetch all app store categories
    func getCategories() async throws -> [AppStoreCategory] {
        let response: AppStoreCategoriesResponse = try await apiService.performRequest(
            endpoint: "app-store/categories",
            method: .GET,
            responseType: AppStoreCategoriesResponse.self,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.apiError("Failed to fetch categories")
        }
        
        return response.data
    }
    
    // MARK: - Apps
    
    /// Fetch featured apps
    func getFeaturedApps() async throws -> [AppStoreApp] {
        let response: AppStoreFeaturedResponse = try await apiService.performRequest(
            endpoint: "app-store/featured",
            method: .GET,
            responseType: AppStoreFeaturedResponse.self,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.apiError("Failed to fetch featured apps")
        }
        
        return response.data
    }
    
    /// Fetch apps with optional filtering
    func getApps(params: AppStoreSearchParams = AppStoreSearchParams()) async throws -> (apps: [AppStoreApp], pagination: PaginationInfo?) {
        var queryItems: [String] = []
        
        if let query = params.query, !query.isEmpty {
            queryItems.append("q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
        }
        
        if let category = params.category {
            queryItems.append("category=\(category)")
        }
        
        if let tags = params.tags, !tags.isEmpty {
            for tag in tags {
                queryItems.append("tags=\(tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag)")
            }
        }
        
        if let chains = params.chains, !chains.isEmpty {
            for chain in chains {
                queryItems.append("chains=\(chain)")
            }
        }
        
        if let sortBy = params.sortBy {
            queryItems.append("sortBy=\(sortBy.rawValue)")
        }
        
        queryItems.append("page=\(params.page)")
        queryItems.append("limit=\(params.limit)")
        
        let queryString = queryItems.isEmpty ? "" : "?\(queryItems.joined(separator: "&"))"
        let endpoint = "app-store/apps\(queryString)"
        
        let response: AppStoreAppsResponse = try await apiService.performRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: AppStoreAppsResponse.self,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.apiError("Failed to fetch apps")
        }
        
        return (response.data, response.pagination)
    }
    
    /// Search apps
    func searchApps(query: String) async throws -> [AppStoreApp] {
        var params = AppStoreSearchParams()
        params.query = query
        let result = try await getApps(params: params)
        return result.apps
    }
    
    /// Get apps by category
    func getAppsByCategory(categorySlug: String, page: Int = 1) async throws -> (apps: [AppStoreApp], pagination: PaginationInfo?) {
        var params = AppStoreSearchParams()
        params.category = categorySlug
        params.page = page
        return try await getApps(params: params)
    }
    
    /// Get app by ID
    func getAppById(id: String) async throws -> AppStoreApp {
        struct SingleAppResponse: Codable {
            let success: Bool
            let data: AppStoreApp
        }
        
        let response: SingleAppResponse = try await apiService.performRequest(
            endpoint: "app-store/apps/\(id)",
            method: .GET,
            responseType: SingleAppResponse.self,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.apiError("Failed to fetch app details")
        }
        
        return response.data
    }
    
    /// Get app by shareable ID
    func getAppByShareableId(shareableId: String) async throws -> AppStoreApp {
        struct SingleAppResponse: Codable {
            let success: Bool
            let data: AppStoreApp
        }
        
        let response: SingleAppResponse = try await apiService.performRequest(
            endpoint: "app-store/apps/share/\(shareableId)",
            method: .GET,
            responseType: SingleAppResponse.self,
            requiresAuth: false
        )
        
        guard response.success else {
            throw APIError.apiError("Failed to fetch app details")
        }
        
        return response.data
    }
}