import Foundation
import Combine
import UIKit

@MainActor
final class WalletViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var unifiedBalance: UnifiedBalance?
    @Published var transactionHistory: TransactionHistory?
    @Published var nftData: NFTData?
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingNFTs = false
    @Published var error: WalletViewError?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private let walletAPI = WalletAPI.shared
    private let profileAPI = ProfileAPI.shared
    private let dataSyncManager = DataSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupAutoRefresh()
        setupProfileChangeObserver()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    func loadBalance(for profileId: String? = nil) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        // Check if user is a guest
        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
            // For guest users, show empty wallet state
            unifiedBalance = nil
        } else {
            do {
                // Get active profile if profileId not provided
                let targetProfileId: String
                if let profileId = profileId {
                    targetProfileId = profileId
                } else {
                    // Use DataSyncManager for profiles with caching
                    let profilesResponse: ProfilesResponse = try await dataSyncManager.fetch(
                        type: ProfilesResponse.self,
                        endpoint: "profiles",
                        policy: .cacheFirst
                    )
                    guard let activeProfile = profilesResponse.data.first(where: { $0.isActive }) else {
                        throw WalletViewError.noBalance
                    }
                    targetProfileId = activeProfile.id
                }
                
                // Use DataSyncManager for balance with network-first policy (5 min cache)
                unifiedBalance = try await dataSyncManager.fetch(
                    type: UnifiedBalance.self,
                    endpoint: "profiles/\(targetProfileId)/balance",
                    policy: .networkFirst
                )
                
                // Load NFTs in parallel
                Task {
                    await loadNFTs(for: targetProfileId)
                }
                
            } catch {
                handleError(error)
            }
        }
        
        isLoading = false
    }
    
    func loadNFTs(for profileId: String? = nil) async {
        guard !isLoadingNFTs else { return }
        
        isLoadingNFTs = true
        
        // Check if user is a guest
        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
            nftData = nil
        } else {
            do {
                let targetProfileId: String
                if let profileId = profileId {
                    targetProfileId = profileId
                } else {
                    // Get active profile
                    let profilesResponse: ProfilesResponse = try await dataSyncManager.fetch(
                        type: ProfilesResponse.self,
                        endpoint: "profiles",
                        policy: .cacheFirst
                    )
                    guard let activeProfile = profilesResponse.data.first(where: { $0.isActive }) else {
                        throw WalletViewError.noBalance
                    }
                    targetProfileId = activeProfile.id
                }
                
                // Fetch NFT data from API
                nftData = try await walletAPI.getProfileNFTs(profileId: targetProfileId)
                
            } catch {
                // Don't show NFT errors, just log them
                print("❌ Failed to load NFTs: \(error)")
            }
        }
        
        isLoadingNFTs = false
    }
    
    func refreshBalance() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        error = nil
        
        // Check if user is a guest
        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
            // For guest users, just clear the state
            unifiedBalance = nil
        } else {
            do {
                // Get active profile from cache first
                let profilesResponse: ProfilesResponse = try await dataSyncManager.fetch(
                    type: ProfilesResponse.self,
                    endpoint: "profiles",
                    policy: .cacheFirst
                )
                guard let activeProfile = profilesResponse.data.first(where: { $0.isActive }) else {
                    throw WalletViewError.noBalance
                }
                
                // Force refresh balance from network
                unifiedBalance = try await dataSyncManager.fetch(
                    type: UnifiedBalance.self,
                    endpoint: "profiles/\(activeProfile.id)/balance",
                    policy: .networkOnly,
                    forceRefresh: true
                )
                
                // Refresh NFTs in parallel
                Task {
                    await loadNFTs(for: activeProfile.id)
                }
                
                // Add haptic feedback for successful refresh
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
            } catch {
                handleError(error)
            }
        }
        
        isRefreshing = false
    }
    
    func loadTransactionHistory(page: Int = 1, limit: Int = 20) async {
        isLoading = true
        error = nil
        
        // Check if user is a guest
        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
            // For guest users, show empty transaction history
            transactionHistory = nil
        } else {
            do {
                // Get active profile
                let profiles = try await profileAPI.getProfiles()
                guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                    throw WalletViewError.noBalance
                }
                
                let history = try await walletAPI.getTransactionHistory(
                    profileId: activeProfile.id,
                    page: page,
                    limit: limit
                )
                
                if page == 1 {
                    transactionHistory = history
                } else {
                    // Append to existing transactions for pagination
                    if var existing = transactionHistory {
                        existing.transactions.append(contentsOf: history.transactions)
                        existing.pagination = history.pagination
                        transactionHistory = existing
                    }
                }
                
            } catch {
                handleError(error)
            }
        }
        
        isLoading = false
    }
    
    func loadMoreTransactions() async {
        guard let currentHistory = transactionHistory,
              currentHistory.pagination.hasNext,
              !isLoading else { return }
        
        await loadTransactionHistory(
            page: currentHistory.pagination.page + 1,
            limit: currentHistory.pagination.limit
        )
    }
    
    func getTokenBalance(for tokenId: String) -> UnifiedBalance.TokenBalance? {
        unifiedBalance?.unifiedBalance.tokens.first { $0.standardizedTokenId == tokenId }
    }
    
    func getChainBalance(for token: UnifiedBalance.TokenBalance, chainId: Int) -> UnifiedBalance.ChainBalance? {
        token.balancesPerChain.first { $0.chainId == chainId }
    }
    
    func getTotalUSDValue() -> String {
        unifiedBalance?.unifiedBalance.totalUsdValue ?? "0.00"
    }
    
    func getFormattedBalance(for token: UnifiedBalance.TokenBalance) -> String {
        if let doubleValue = Double(token.totalAmount) {
            let adjustedValue = doubleValue / pow(10, Double(token.decimals))
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = min(6, token.decimals)
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: adjustedValue)) ?? token.totalAmount
        }
        return token.totalAmount
    }
    
    func getFormattedUSDValue(for token: UnifiedBalance.TokenBalance) -> String {
        if let doubleValue = Double(token.totalUsdValue) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: doubleValue)) ?? "$\(token.totalUsdValue)"
        }
        return "$\(token.totalUsdValue)"
    }
    
    func getSuggestedGasToken() -> UnifiedBalance.GasAnalysis.SuggestedGasToken? {
        unifiedBalance?.gasAnalysis.suggestedGasToken
    }
    
    func getNativeGasBalances() -> [UnifiedBalance.GasAnalysis.NativeGas] {
        unifiedBalance?.gasAnalysis.nativeGasAvailable ?? []
    }
    
    func getAvailableGasTokens() -> [String] {
        unifiedBalance?.gasAnalysis.availableGasTokens ?? []
    }
    
    func dismissError() {
        error = nil
        showError = false
    }
    
    func startAutoRefresh() {
        setupAutoRefresh()
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        // Refresh balance every 30 seconds when app is active
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshBalance()
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                self.error = WalletViewError.unauthorized
            case .apiError(let message):
                self.error = WalletViewError.serverError(message)
            case .requestFailed(let underlyingError):
                self.error = WalletViewError.networkError(underlyingError.localizedDescription)
            case .noData:
                self.error = WalletViewError.noBalance
            default:
                self.error = WalletViewError.unknown(error.localizedDescription)
            }
        } else {
            self.error = WalletViewError.unknown(error.localizedDescription)
        }
        showError = true
    }
    
    private func setupProfileChangeObserver() {
        // Listen for profile change notifications
        NotificationCenter.default.publisher(for: .profileDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    print("💰 WalletViewModel: Profile changed, clearing and reloading balance")
                    
                    // Clear current data immediately for smooth transition
                    self.unifiedBalance = nil
                    self.transactionHistory = nil
                    self.nftData = nil
                    
                    // Show loading state
                    self.isLoading = true
                    
                    // Reload balance for the new profile
                    await self.loadBalance()
                }
            }
            .store(in: &cancellables)
    }
    
    #if DEBUG
    // Commented out - now using real API data
    /*
    private func mockNFTData() -> NFTData {
        let mockNFTs = [
            NFTItem(
                contractAddress: "0x248139aFB8d3A2e16154FbE4Fb528A3a214fd8E7",
                tokenId: "937",
                name: "Boki",
                tokenType: "ERC721",
                amount: "1",
                metadata: NFTMetadata(
                    name: "Boki #937",
                    description: "A community-focused NFT project",
                    image: "https://i.seadn.io/gcs/files/7b9e89dc9f7b3586b8f23b6cf90e5512.jpg",
                    attributes: nil,
                    external_link: nil
                ),
                cachedImage: nil,
                rawMetadata: nil,
                chainId: 1,
                ownerAddress: "0x0000000000000000000000000000000000000000"
            ),
            NFTItem(
                contractAddress: "0x1485297e942ce64E0870EcE60179dFda34b4C625",
                tokenId: "1234",
                name: "Moonrunners",
                tokenType: "ERC721",
                amount: "1",
                metadata: NFTMetadata(
                    name: "Moonrunner #1234",
                    description: "Protect the Moonrunners at all costs",
                    image: "https://i.seadn.io/gcs/files/b2024e2b23e3b14e4201c7e9f0de0f46.jpg",
                    attributes: nil,
                    external_link: nil
                ),
                cachedImage: nil,
                rawMetadata: nil,
                chainId: 1,
                ownerAddress: "0x0000000000000000000000000000000000000000"
            ),
            NFTItem(
                contractAddress: "0x248139aFB8d3A2e16154FbE4Fb528A3a214fd8E7",
                tokenId: "2023",
                name: "Boki",
                tokenType: "ERC721",
                amount: "1",
                metadata: NFTMetadata(
                    name: "Boki #2023",
                    description: "A community-focused NFT project",
                    image: "https://i.seadn.io/gcs/files/5f2c3f15dc19c2e5e8f33e2a6e0f3d45.jpg",
                    attributes: nil,
                    external_link: nil
                ),
                cachedImage: nil,
                rawMetadata: nil,
                chainId: 1,
                ownerAddress: "0x0000000000000000000000000000000000000000"
            )
        ]
        
        let collection1 = NFTCollection(
            contractAddress: "0x248139aFB8d3A2e16154FbE4Fb528A3a214fd8E7",
            chainId: 1,
            name: "Boki",
            tokenType: "ERC721",
            nfts: mockNFTs.filter { $0.contractAddress == "0x248139aFB8d3A2e16154FbE4Fb528A3a214fd8E7" }
        )
        
        let collection2 = NFTCollection(
            contractAddress: "0x1485297e942ce64E0870EcE60179dFda34b4C625",
            chainId: 1,
            name: "Moonrunners",
            tokenType: "ERC721",
            nfts: mockNFTs.filter { $0.contractAddress == "0x1485297e942ce64E0870EcE60179dFda34b4C625" }
        )
        
        return NFTData(
            totalNFTs: mockNFTs.count,
            collections: [collection1, collection2],
            nfts: mockNFTs
        )
    }
    */
    #endif
}

// MARK: - WalletView Error

enum WalletViewError: LocalizedError {
    case unauthorized
    case serverError(String)
    case networkError(String)
    case noBalance
    case invalidAmount
    case insufficientBalance
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "You are not authorized to access this wallet"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noBalance:
            return "No balance information available"
        case .invalidAmount:
            return "Invalid amount entered"
        case .insufficientBalance:
            return "Insufficient balance for this transaction"
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Please sign in again to access your wallet"
        case .networkError:
            return "Please check your internet connection and try again"
        case .noBalance:
            return "Connect your accounts to see your balance"
        case .insufficientBalance:
            return "Please add funds to your wallet or reduce the amount"
        default:
            return "Please try again later"
        }
    }
}

