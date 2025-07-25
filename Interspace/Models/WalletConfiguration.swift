import Foundation

/// Configuration for wallet-specific deep linking and connection parameters
struct WalletConfiguration {
    let walletType: WalletType
    let deepLinkFormat: DeepLinkFormat
    let universalLinkDomain: String?
    let supportsWalletConnect: Bool
    let connectionTimeout: TimeInterval
    let customParameters: [String: String]
    
    /// Defines how deep links should be constructed for this wallet
    enum DeepLinkFormat {
        /// Standard WalletConnect format: scheme://wc?uri={encodedUri}
        case standard
        
        /// Custom format with pattern substitution
        case custom(pattern: String)
        
        /// Multiple formats to try in order
        case multiple([String])
        
        /// No deep link support (QR code only)
        case none
    }
    
    /// Generate deep link URLs for this wallet
    func generateDeepLinks(for uri: String) -> [String] {
        let encodedUri = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
        
        switch deepLinkFormat {
        case .standard:
            return ["\(walletType.rawValue)://wc?uri=\(encodedUri)"]
            
        case .custom(let pattern):
            let deepLink = pattern
                .replacingOccurrences(of: "{scheme}", with: walletType.rawValue)
                .replacingOccurrences(of: "{uri}", with: encodedUri)
                .replacingOccurrences(of: "{encodedUri}", with: encodedUri)
            
            // Add custom parameters
            var finalLink = deepLink
            for (key, value) in customParameters {
                finalLink = finalLink.replacingOccurrences(of: "{\(key)}", with: value)
            }
            
            return [finalLink]
            
        case .multiple(let patterns):
            return patterns.map { pattern in
                var link = pattern
                    .replacingOccurrences(of: "{scheme}", with: walletType.rawValue)
                    .replacingOccurrences(of: "{uri}", with: encodedUri)
                    .replacingOccurrences(of: "{encodedUri}", with: encodedUri)
                
                // Add custom parameters
                for (key, value) in customParameters {
                    link = link.replacingOccurrences(of: "{\(key)}", with: value)
                }
                
                return link
            }
            
        case .none:
            return []
        }
    }
    
    /// Generate universal link URL if supported
    func generateUniversalLink(for uri: String) -> String? {
        guard let domain = universalLinkDomain else { return nil }
        
        let encodedUri = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
        
        // Handle different universal link formats
        switch walletType {
        case .trust:
            return "\(domain)/wc?uri=\(encodedUri)"
        case .phantom:
            // Phantom uses a different format for universal links
            return "\(domain)/ul/v1/connect?app_url=interspace://&dapp_encryption_public_key=\(customParameters["encryptionKey"] ?? "")&redirect_link=interspace://phantom"
        default:
            return "\(domain)/wc?uri=\(encodedUri)"
        }
    }
}

// MARK: - Wallet Configurations

extension WalletConfiguration {
    /// Get configuration for a specific wallet type
    static func configuration(for walletType: WalletType) -> WalletConfiguration {
        switch walletType {
        case .metamask:
            // MetaMask uses native SDK, not WalletConnect
            return WalletConfiguration(
                walletType: .metamask,
                deepLinkFormat: .none,
                universalLinkDomain: nil,
                supportsWalletConnect: false,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .coinbase:
            // Coinbase uses native SDK, not WalletConnect
            return WalletConfiguration(
                walletType: .coinbase,
                deepLinkFormat: .none,
                universalLinkDomain: nil,
                supportsWalletConnect: false,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .trust:
            return WalletConfiguration(
                walletType: .trust,
                deepLinkFormat: .multiple([
                    "trust://wc?uri={encodedUri}&returnUrl=interspace://",
                    "trust://wc?uri={encodedUri}"
                ]),
                universalLinkDomain: "https://link.trustwallet.com",
                supportsWalletConnect: true,
                connectionTimeout: 45,
                customParameters: ["returnUrl": "interspace://"]
            )
            
        case .rainbow:
            return WalletConfiguration(
                walletType: .rainbow,
                deepLinkFormat: .custom(pattern: "rainbow://wc?uri={encodedUri}"),
                universalLinkDomain: "https://rnbwapp.com",
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .argent:
            return WalletConfiguration(
                walletType: .argent,
                deepLinkFormat: .custom(pattern: "argent://wc?uri={encodedUri}"),
                universalLinkDomain: "https://argent.link",
                supportsWalletConnect: true,
                connectionTimeout: 45, // Argent may need more time for SIWE
                customParameters: [:]
            )
            
        case .phantom:
            return WalletConfiguration(
                walletType: .phantom,
                deepLinkFormat: .multiple([
                    "phantom://wc?uri={encodedUri}",
                    "phantom://v1/connect?uri={encodedUri}"
                ]),
                universalLinkDomain: "https://phantom.app",
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: ["encryptionKey": ""] // Will be set dynamically
            )
            
        case .gnosisSafe:
            return WalletConfiguration(
                walletType: .gnosisSafe,
                deepLinkFormat: .custom(pattern: "gnosissafe://wc?uri={encodedUri}"),
                universalLinkDomain: "https://safe.global",
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .family:
            return WalletConfiguration(
                walletType: .family,
                deepLinkFormat: .custom(pattern: "family://wc?uri={encodedUri}"),
                universalLinkDomain: nil,
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .oneInch:
            return WalletConfiguration(
                walletType: .oneInch,
                deepLinkFormat: .custom(pattern: "oneinch://wc?uri={encodedUri}"),
                universalLinkDomain: "https://1inch.io",
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .zerion:
            return WalletConfiguration(
                walletType: .zerion,
                deepLinkFormat: .custom(pattern: "zerion://wc?uri={encodedUri}"),
                universalLinkDomain: "https://app.zerion.io",
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .imToken:
            return WalletConfiguration(
                walletType: .imToken,
                deepLinkFormat: .custom(pattern: "imtoken://wc?uri={encodedUri}"),
                universalLinkDomain: nil,
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .tokenPocket:
            return WalletConfiguration(
                walletType: .tokenPocket,
                deepLinkFormat: .custom(pattern: "tokenpocket://wc?uri={encodedUri}"),
                universalLinkDomain: nil,
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .spot:
            return WalletConfiguration(
                walletType: .spot,
                deepLinkFormat: .standard,
                universalLinkDomain: nil,
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
        case .omni:
            return WalletConfiguration(
                walletType: .omni,
                deepLinkFormat: .standard,
                universalLinkDomain: nil,
                supportsWalletConnect: true,
                connectionTimeout: 30,
                customParameters: [:]
            )
            
//        case .walletConnect:
//            // Generic WalletConnect (for unknown wallets)
//            return WalletConfiguration(
//                walletType: .walletConnect,
//                deepLinkFormat: .standard,
//                universalLinkDomain: nil,
//                supportsWalletConnect: true,
//                connectionTimeout: 30,
//                customParameters: [:]
//            )
            
        default:
            // For safe, ledger, trezor, google, apple, mpc, unknown
            return WalletConfiguration(
                walletType: walletType,
                deepLinkFormat: .none,
                universalLinkDomain: nil,
                supportsWalletConnect: false,
                connectionTimeout: 30,
                customParameters: [:]
            )
        }
    }
    
    /// Check if a wallet type supports WalletConnect
    static func supportsWalletConnect(_ walletType: WalletType) -> Bool {
        let config = configuration(for: walletType)
        return config.supportsWalletConnect
    }
    
    /// Get all wallet types that support WalletConnect
    static var walletConnectSupportedWallets: [WalletType] {
        WalletType.allCases.filter { configuration(for: $0).supportsWalletConnect }
    }
}
