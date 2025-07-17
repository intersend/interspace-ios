import Foundation

/// Configuration for MetaMask integration
enum MetaMaskConfiguration {
    
    // MARK: - App Metadata
    
    static let appName = "Interspace"
    static let appUrl = "https://interspace.fi"
    static let appDescription = "Connect with Interspace"
    
    // MARK: - Deep Link Configuration
    
    static let deepLinkScheme = "metamask"
    static let universalLinkHost = "metamask.app.link"
    
    // MARK: - SDK Configuration
    
    /// Transport mode for MetaMask SDK
    enum TransportMode {
        case socket      // Recommended for better UX
        case deeplink    // Fallback option
    }
    
    static let defaultTransportMode: TransportMode = .socket
    
    // MARK: - Timeouts
    
    static let connectionTimeout: TimeInterval = 60.0
    static let signatureTimeout: TimeInterval = 60.0
    static let transactionTimeout: TimeInterval = 120.0
    
    // MARK: - Network Configuration
    
    static let defaultChainId = 1 // Ethereum Mainnet
    static let supportedChainIds = [1, 137, 10, 42161, 8453] // Mainnet, Polygon, Optimism, Arbitrum, Base
    
    // MARK: - Error Messages
    
    enum ErrorMessage {
        static let notInstalled = "MetaMask is not installed. Please install MetaMask from the App Store."
        static let connectionFailed = "Failed to connect to MetaMask. Please try again."
        static let signatureFailed = "Failed to sign message. Please try again."
        static let userCancelled = "Request cancelled by user."
        static let timeout = "Request timed out. Please try again."
        static let unsupportedNetwork = "Please switch to a supported network in MetaMask."
    }
    
    // MARK: - URLs
    
    static let appStoreURL = URL(string: "https://apps.apple.com/app/metamask/id1438144202")!
    static let supportURL = URL(string: "https://support.metamask.io")!
}

// MARK: - MetaMask Deep Link Builder

enum MetaMaskDeepLinks {
    
    /// Build a MetaMask deep link URL
    static func buildDeepLink(
        host: String,
        parameters: [String: String] = [:]
    ) -> URL? {
        var components = URLComponents()
        components.scheme = MetaMaskConfiguration.deepLinkScheme
        components.host = host
        
        if !parameters.isEmpty {
            components.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }
        
        return components.url
    }
    
    /// Check if a URL is a MetaMask callback
    static func isMetaMaskCallback(_ url: URL) -> Bool {
        return url.scheme == "interspace" && url.host == "metamask-callback"
    }
}

// MARK: - Chain Configuration

struct ChainInfo {
    let chainId: Int
    let name: String
    let currency: String
    let rpcUrl: String?
}

extension MetaMaskConfiguration {
    static let chainInfo: [Int: ChainInfo] = [
        1: ChainInfo(chainId: 1, name: "Ethereum Mainnet", currency: "ETH", rpcUrl: nil),
        137: ChainInfo(chainId: 137, name: "Polygon", currency: "MATIC", rpcUrl: "https://polygon-rpc.com"),
        10: ChainInfo(chainId: 10, name: "Optimism", currency: "ETH", rpcUrl: "https://mainnet.optimism.io"),
        42161: ChainInfo(chainId: 42161, name: "Arbitrum One", currency: "ETH", rpcUrl: "https://arb1.arbitrum.io/rpc"),
        8453: ChainInfo(chainId: 8453, name: "Base", currency: "ETH", rpcUrl: "https://mainnet.base.org")
    ]
}