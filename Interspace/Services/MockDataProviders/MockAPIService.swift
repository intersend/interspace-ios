import Foundation

/// Mock API Service for demo mode - replaces real API calls with local mock data
class MockAPIService: APIService {
    
    private let mockDataProvider = MockDataProvider.shared
    
    override init() {
        super.init()
        print("🎭 MockAPIService: Initialized for demo mode")
    }
    
    override func setAccessToken(_ token: String?) {
        // No-op in demo mode
        print("🎭 MockAPIService: Ignoring access token in demo mode")
    }
    
    override func request<T: Decodable>(
        _ method: HTTPMethod,
        _ endpoint: String,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        print("🎭 MockAPIService: Intercepting request - \(method.rawValue) \(endpoint)")
        
        // Add artificial delay to simulate network request
        try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...300_000_000)) // 0.1-0.3 seconds
        
        // Route to appropriate mock handler based on endpoint
        if let mockResponse = try await handleMockRequest(method: method, endpoint: endpoint, body: body) as? T {
            return mockResponse
        }
        
        throw APIError.noData
    }
    
    override func requestRaw(
        _ method: HTTPMethod,
        _ endpoint: String,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> Data {
        print("🎭 MockAPIService: Raw request intercepted - \(method.rawValue) \(endpoint)")
        
        // Add artificial delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...300_000_000))
        
        // Return empty data for demo mode
        return Data()
    }
    
    // MARK: - Mock Request Handlers
    
    private func handleMockRequest(method: HTTPMethod, endpoint: String, body: Encodable?) async throws -> Any {
        // Parse endpoint to determine which mock data to return
        let components = endpoint.split(separator: "/").map(String.init)
        
        // Handle authentication endpoints
        if endpoint.contains("auth") {
            return try handleAuthEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle profile endpoints
        if endpoint.contains("profiles") {
            return try handleProfileEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle apps endpoints
        if endpoint.contains("apps") {
            return try handleAppsEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle folders endpoints
        if endpoint.contains("folders") {
            return try handleFoldersEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle wallet endpoints
        if endpoint.contains("wallets") || endpoint.contains("balance") {
            return try handleWalletEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle accounts endpoints
        if endpoint.contains("accounts") {
            return try handleAccountsEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Handle user endpoints (social accounts)
        if endpoint.contains("user") || endpoint.contains("social") {
            return try handleUserEndpoints(method: method, endpoint: endpoint, components: components)
        }
        
        // Default empty response
        return EmptyResponse()
    }
    
    // MARK: - Auth Endpoints
    
    private func handleAuthEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        if endpoint.contains("login") || endpoint.contains("authenticate") {
            // Return mock authentication response
            return AuthenticationResponseV2(
                accessToken: "mock-access-token",
                refreshToken: "mock-refresh-token",
                user: createMockUser(),
                profiles: mockDataProvider.demoProfiles,
                activeProfile: mockDataProvider.currentProfile,
                availableAuthStrategies: [.wallet, .email, .google, .apple]
            )
        }
        
        if endpoint.contains("me") {
            // Return current user
            return createMockUser()
        }
        
        if endpoint.contains("logout") {
            return EmptyResponse()
        }
        
        throw APIError.noData
    }
    
    // MARK: - Profile Endpoints
    
    private func handleProfileEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        if method == .GET && !endpoint.contains("/") {
            // Get all profiles
            return mockDataProvider.demoProfiles
        }
        
        if let profileId = extractProfileId(from: components) {
            if endpoint.contains("apps") {
                // Get apps for profile
                return mockDataProvider.getApps(for: profileId)
            }
            
            if endpoint.contains("folders") {
                // Get folders for profile
                return mockDataProvider.getFolders(for: profileId)
            }
            
            if endpoint.contains("linked-accounts") {
                // Get linked accounts for profile
                return mockDataProvider.getLinkedAccounts(for: profileId)
            }
            
            // Get single profile
            return mockDataProvider.demoProfiles.first { $0.id == profileId } ?? mockDataProvider.currentProfile!
        }
        
        if endpoint.contains("switch") {
            // Switch profile
            if let profileId = components.last,
               let profile = mockDataProvider.demoProfiles.first(where: { $0.id == profileId }) {
                mockDataProvider.switchProfile(to: profile)
                return profile
            }
        }
        
        throw APIError.noData
    }
    
    // MARK: - Apps Endpoints
    
    private func handleAppsEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        guard let currentProfile = mockDataProvider.currentProfile else {
            throw APIError.unauthorized
        }
        
        if method == .GET {
            return mockDataProvider.getApps(for: currentProfile.id)
        }
        
        if method == .POST {
            // Mock creating new app
            return BookmarkedApp(
                id: UUID().uuidString,
                name: "New App",
                url: "https://example.com",
                iconUrl: "https://example.com/icon.png",
                position: mockDataProvider.getApps(for: currentProfile.id).count,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        if method == .PUT && endpoint.contains("reorder") {
            // Mock reordering apps
            return EmptyResponse()
        }
        
        if method == .PUT && endpoint.contains("move") {
            // Mock moving app to folder
            return EmptyResponse()
        }
        
        if method == .PUT {
            // Mock updating app
            if let appId = components.last {
                return BookmarkedApp(
                    id: appId,
                    name: "Updated App",
                    url: "https://updated.com",
                    iconUrl: "https://updated.com/icon.png",
                    position: 0,
                    folderId: nil,
                    folderName: nil,
                    createdAt: Date().addingTimeInterval(-86400),
                    updatedAt: Date()
                )
            }
        }
        
        if method == .DELETE {
            // Mock deleting app
            return EmptyResponse()
        }
        
        return EmptyResponse()
    }
    
    // MARK: - Folders Endpoints
    
    private func handleFoldersEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        guard let currentProfile = mockDataProvider.currentProfile else {
            throw APIError.unauthorized
        }
        
        if method == .GET {
            return mockDataProvider.getFolders(for: currentProfile.id)
        }
        
        if method == .POST {
            // Mock creating new folder
            return AppFolder(
                id: UUID().uuidString,
                name: "New Folder",
                color: "#FF6B6B",
                position: mockDataProvider.getFolders(for: currentProfile.id).count,
                isPublic: false,
                appsCount: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        if method == .PUT && endpoint.contains("reorder") {
            // Mock reordering folders
            return EmptyResponse()
        }
        
        if method == .PUT {
            // Mock updating folder
            if let folderId = components.last {
                return AppFolder(
                    id: folderId,
                    name: "Updated Folder",
                    color: "#4ECDC4",
                    position: 0,
                    isPublic: false,
                    appsCount: 0,
                    createdAt: Date().addingTimeInterval(-86400),
                    updatedAt: Date()
                )
            }
        }
        
        if method == .DELETE {
            // Mock deleting folder
            return EmptyResponse()
        }
        
        if endpoint.contains("share") {
            // Mock sharing folder
            return ["shareUrl": "https://interspace.app/shared/folder/demo"]
        }
        
        return EmptyResponse()
    }
    
    // MARK: - Wallet Endpoints
    
    private func handleWalletEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        guard let currentProfile = mockDataProvider.currentProfile else {
            throw APIError.unauthorized
        }
        
        if endpoint.contains("balance") {
            // Return unified balance
            return mockDataProvider.getBalance(for: currentProfile.id) ?? createEmptyBalance(for: currentProfile)
        }
        
        if endpoint.contains("transactions") || endpoint.contains("history") {
            // Return transaction history
            let transactions = mockDataProvider.getTransactions(for: currentProfile.id)
            return TransactionHistory(
                transactions: transactions,
                pagination: TransactionHistory.PaginationInfo(
                    page: 1,
                    limit: 20,
                    totalPages: 1,
                    totalItems: transactions.count,
                    hasMore: false
                )
            )
        }
        
        if endpoint.contains("nfts") {
            // Return NFT collections
            return mockDataProvider.getNFTCollections(for: currentProfile.id)
        }
        
        return EmptyResponse()
    }
    
    // MARK: - Accounts Endpoints
    
    private func handleAccountsEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        guard let currentProfile = mockDataProvider.currentProfile else {
            throw APIError.unauthorized
        }
        
        if method == .GET {
            return mockDataProvider.getLinkedAccounts(for: currentProfile.id)
        }
        
        if method == .POST && endpoint.contains("link") {
            // Mock linking account
            return LinkedAccount(
                id: UUID().uuidString,
                address: "0xnewaccount1234567890abcdef1234567890abcd",
                walletType: .metamask,
                customName: "New Linked Account",
                isPrimary: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        if method == .DELETE && endpoint.contains("unlink") {
            // Mock unlinking account
            return EmptyResponse()
        }
        
        if method == .PUT {
            // Mock updating account
            if let accountId = components.last {
                return LinkedAccount(
                    id: accountId,
                    address: "0xupdatedaccount1234567890abcdef1234567890",
                    walletType: .metamask,
                    customName: "Updated Account Name",
                    isPrimary: false,
                    createdAt: Date().addingTimeInterval(-86400),
                    updatedAt: Date()
                )
            }
        }
        
        return EmptyResponse()
    }
    
    // MARK: - User Endpoints
    
    private func handleUserEndpoints(method: HTTPMethod, endpoint: String, components: [String]) throws -> Any {
        if endpoint.contains("social-accounts") {
            if method == .GET {
                // Return mock social accounts
                return [
                    SocialAccount(
                        id: "social-1",
                        provider: .google,
                        username: "demo.user@gmail.com",
                        displayName: "Demo User",
                        avatarUrl: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    SocialAccount(
                        id: "social-2",
                        provider: .twitter,
                        username: "@demouser",
                        displayName: "Demo User",
                        avatarUrl: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ]
            }
            
            if method == .POST {
                // Mock linking social account
                return SocialAccount(
                    id: UUID().uuidString,
                    provider: .google,
                    username: "new.account@gmail.com",
                    displayName: "New Account",
                    avatarUrl: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
            
            if method == .DELETE {
                // Mock unlinking social account
                return EmptyResponse()
            }
        }
        
        if endpoint.contains("me") {
            return createMockUser()
        }
        
        return EmptyResponse()
    }
    
    // MARK: - Helper Methods
    
    private func extractProfileId(from components: [String]) -> String? {
        // Look for profile ID in path components
        if let profileIndex = components.firstIndex(of: "profiles"),
           profileIndex + 1 < components.count {
            let nextComponent = components[profileIndex + 1]
            // Check if it's not another endpoint keyword
            if !["apps", "folders", "linked-accounts", "switch"].contains(nextComponent) {
                return nextComponent
            }
        }
        return nil
    }
    
    private func createMockUser() -> User {
        return User(
            id: "demo-user-id",
            email: "demo@interspace.app",
            walletAddress: "0x1234567890abcdef1234567890abcdef12345678",
            isGuest: false,
            authStrategies: [.wallet, .email],
            profilesCount: 3,
            linkedAccountsCount: 5,
            activeDevicesCount: 1,
            socialAccounts: [
                SocialAccount(
                    id: "social-1",
                    provider: .google,
                    username: "demo.user",
                    displayName: "Demo User",
                    avatarUrl: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            createdAt: Date().addingTimeInterval(-30*24*60*60),
            updatedAt: Date()
        )
    }
    
    private func createEmptyBalance(for profile: SmartProfile) -> UnifiedBalance {
        return UnifiedBalance(
            profileId: profile.id,
            profileName: profile.name,
            unifiedBalance: UnifiedBalance.BalanceData(
                totalUsdValue: 0.0,
                tokenBalances: []
            ),
            gasAnalysis: UnifiedBalance.GasAnalysis(
                suggestedGasToken: nil,
                nativeGasAvailable: [:],
                availableGasTokens: []
            )
        )
    }
}

// Empty response for endpoints that don't return data
private struct EmptyResponse: Codable {}