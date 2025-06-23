import Foundation
import Combine
import UIKit

@MainActor
final class WalletViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var unifiedBalance: UnifiedBalance?
    @Published var transactionHistory: TransactionHistory?
    @Published var isLoading = false
    @Published var isRefreshing = false
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
                    let profiles: [SmartProfile] = try await dataSyncManager.fetch(
                        type: [SmartProfile].self,
                        endpoint: "profiles",
                        policy: .cacheFirst
                    )
                    guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                        throw WalletViewError.noBalance
                    }
                    targetProfileId = activeProfile.id
                }
                
                // Use DataSyncManager for balance with network-first policy (5 min cache)
                unifiedBalance = try await dataSyncManager.fetch(
                    type: UnifiedBalance.self,
                    endpoint: "wallets/\(targetProfileId)/balance",
                    policy: .networkFirst
                )
                
            } catch {
                handleError(error)
            }
        }
        
        isLoading = false
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
                let profiles: [SmartProfile] = try await dataSyncManager.fetch(
                    type: [SmartProfile].self,
                    endpoint: "profiles",
                    policy: .cacheFirst
                )
                guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                    throw WalletViewError.noBalance
                }
                
                // Force refresh balance from network
                unifiedBalance = try await dataSyncManager.fetch(
                    type: UnifiedBalance.self,
                    endpoint: "wallets/\(activeProfile.id)/balance",
                    policy: .networkOnly,
                    forceRefresh: true
                )
                
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
                self.error = .unauthorized
            case .apiError(let message):
                self.error = .serverError(message)
            case .requestFailed(let underlyingError):
                self.error = .networkError(underlyingError.localizedDescription)
            case .noData:
                self.error = .noBalance
            default:
                self.error = .unknown(error.localizedDescription)
            }
        } else {
            self.error = .unknown(error.localizedDescription)
        }
        showError = true
    }
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

