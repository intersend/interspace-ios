import Foundation

extension WalletAPI {
    
    /// Override methods to return mock data in demo mode
    func handleDemoMode<T>(_ operation: String, mockData: () -> T) async throws -> T {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 WalletAPI: Returning mock data for \(operation)")
            
            // Add artificial delay to simulate network
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...200_000_000))
            
            return mockData()
        }
        
        // This won't be reached in demo mode, but needed for compilation
        throw APIError.noData
    }
}

// MARK: - Demo Mode Overrides

extension WalletAPI {
    
    // Override getUnifiedBalance
    func getUnifiedBalanceDemoMode(profileId: String) async throws -> UnifiedBalance {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getUnifiedBalance") {
                MockDataProvider.shared.getBalance(for: profileId) ?? createEmptyBalance(for: profileId)
            }
        }
        return try await getUnifiedBalance(profileId: profileId)
    }
    
    // Override getTransactionHistory
    func getTransactionHistoryDemoMode(profileId: String, page: Int, limit: Int) async throws -> TransactionHistory {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getTransactionHistory") {
                let allTransactions = MockDataProvider.shared.getTransactions(for: profileId)
                
                // Implement pagination
                let startIndex = (page - 1) * limit
                let endIndex = min(startIndex + limit, allTransactions.count)
                let paginatedTransactions = startIndex < allTransactions.count 
                    ? Array(allTransactions[startIndex..<endIndex])
                    : []
                
                return TransactionHistory(
                    transactions: paginatedTransactions,
                    pagination: TransactionHistory.PaginationInfo(
                        page: page,
                        limit: limit,
                        totalPages: (allTransactions.count + limit - 1) / limit,
                        totalItems: allTransactions.count,
                        hasMore: endIndex < allTransactions.count
                    )
                )
            }
        }
        return try await getTransactionHistory(profileId: profileId, page: page, limit: limit)
    }
    
    // Override getRecentTransactions
    func getRecentTransactionsDemoMode(profileId: String, limit: Int) async throws -> [TransactionHistory.TransactionItem] {
        if DemoModeConfiguration.isDemoMode {
            return try await handleDemoMode("getRecentTransactions") {
                let allTransactions = MockDataProvider.shared.getTransactions(for: profileId)
                return Array(allTransactions.prefix(limit))
            }
        }
        return try await getRecentTransactions(profileId: profileId, limit: limit)
    }
    
    // Helper to create empty balance
    private func createEmptyBalance(for profileId: String) -> UnifiedBalance {
        let profile = MockDataProvider.shared.demoProfiles.first { $0.id == profileId }
        return UnifiedBalance(
            profileId: profileId,
            profileName: profile?.name ?? "Unknown Profile",
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