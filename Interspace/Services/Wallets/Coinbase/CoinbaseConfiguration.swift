import Foundation

/// Configuration for Coinbase Wallet integration
enum CoinbaseConfiguration {
    
    // MARK: - App Metadata
    
    static let appName = "Interspace"
    static let appUrl = "https://interspace.fi"
    static let appDescription = "Connect with Interspace"
    static let appIconUrl: String? = nil
    
    // MARK: - Deep Link Configuration
    
    static let deepLinkScheme = "cbwallet"
    static let universalLinkHost = "wallet.coinbase.com"
    static let redirectScheme = "interspace"
    
    // MARK: - SDK Configuration
    
    /// Callback URL for Coinbase responses
    /// Note: Not used for mobile SDK - the SDK handles deep linking internally
    @available(*, deprecated, message: "Mobile SDK handles deep linking internally")
    static var callbackURL: URL {
        URL(string: "\(redirectScheme)://coinbase-callback")!
    }
    
    // MARK: - Timeouts
    
    static let connectionTimeout: TimeInterval = 60.0
    static let signatureTimeout: TimeInterval = 60.0
    static let transactionTimeout: TimeInterval = 120.0
    
    // MARK: - Network Configuration
    
    static let defaultChainId = 1 // Ethereum Mainnet
    static let supportedChainIds = [1, 137, 10, 42161, 8453, 84532] // Mainnet, Polygon, Optimism, Arbitrum, Base, Base Sepolia
    
    // MARK: - Error Messages
    
    enum ErrorMessage {
        static let notInstalled = "Coinbase Wallet is not installed. Please install Coinbase Wallet from the App Store."
        static let connectionFailed = "Failed to connect to Coinbase Wallet. Please try again."
        static let signatureFailed = "Failed to sign message. Please try again."
        static let userCancelled = "Request cancelled by user."
        static let timeout = "Request timed out. Please try again."
        static let unsupportedNetwork = "Please switch to a supported network in Coinbase Wallet."
        static let noActiveSession = "No active wallet session. Please connect first."
        static let sdkNotInitialized = "Coinbase SDK not initialized properly."
    }
    
    // MARK: - URLs
    
    static let appStoreURL = URL(string: "https://apps.apple.com/app/coinbase-wallet/id1278383455")!
    static let supportURL = URL(string: "https://www.coinbase.com/wallet/support")!
}

// MARK: - Coinbase Deep Link Builder

enum CoinbaseDeepLinks {
    
    /// Check if a URL is a Coinbase callback
    static func isCoinbaseCallback(_ url: URL) -> Bool {
        return url.scheme == CoinbaseConfiguration.redirectScheme && 
               url.host == "coinbase-callback"
    }
    
    /// Extract response data from callback URL
    static func extractCallbackData(from url: URL) -> [String: String]? {
        guard isCoinbaseCallback(url) else { return nil }
        
        var params: [String: String] = [:]
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    params[item.name] = value
                }
            }
        }
        
        return params.isEmpty ? nil : params
    }
}

// MARK: - Chain Configuration

extension CoinbaseConfiguration {
    static let chainInfo: [Int: ChainInfo] = [
        1: ChainInfo(chainId: 1, name: "Ethereum Mainnet", currency: "ETH", rpcUrl: nil),
        137: ChainInfo(chainId: 137, name: "Polygon", currency: "MATIC", rpcUrl: "https://polygon-rpc.com"),
        10: ChainInfo(chainId: 10, name: "Optimism", currency: "ETH", rpcUrl: "https://mainnet.optimism.io"),
        42161: ChainInfo(chainId: 42161, name: "Arbitrum One", currency: "ETH", rpcUrl: "https://arb1.arbitrum.io/rpc"),
        8453: ChainInfo(chainId: 8453, name: "Base", currency: "ETH", rpcUrl: "https://mainnet.base.org"),
        84532: ChainInfo(chainId: 84532, name: "Base Sepolia", currency: "ETH", rpcUrl: "https://sepolia.base.org")
    ]
}