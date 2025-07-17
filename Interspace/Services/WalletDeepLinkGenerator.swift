import Foundation
import UIKit
import ReownAppKit

/// Service responsible for generating and handling wallet deep links
class WalletDeepLinkGenerator {
    static let shared = WalletDeepLinkGenerator()
    
    private let appKitService = AppKitService.shared
    
    private init() {}
    
    /// Deep link result containing all possible links to try
    struct DeepLinkResult {
        let primaryLinks: [String]
        let universalLink: String?
        let fallbackURL: URL?
        let walletType: WalletType
    }
    
    /// Generate deep links for a wallet with WalletConnect URI
    func generateDeepLinks(for walletType: WalletType, uri: String) -> DeepLinkResult {
        let configuration = WalletConfiguration.configuration(for: walletType)
        
        // Generate primary deep links
        let primaryLinks = configuration.generateDeepLinks(for: uri)
        
        // Generate universal link
        let universalLink = configuration.generateUniversalLink(for: uri)
        
        // Generate fallback URL (App Store)
        let fallbackURL = getAppStoreURL(for: walletType)
        
        return DeepLinkResult(
            primaryLinks: primaryLinks,
            universalLink: universalLink,
            fallbackURL: fallbackURL,
            walletType: walletType
        )
    }
    
    /// Open wallet with deep link, trying multiple strategies
    func openWallet(with result: DeepLinkResult, completion: @escaping (Bool) -> Void) {
        // First, try primary deep links
        tryPrimaryDeepLinks(result.primaryLinks) { success in
            if success {
                completion(true)
                return
            }
            
            // If primary links fail, try universal link
            if let universalLink = result.universalLink {
                self.tryUniversalLink(universalLink) { universalSuccess in
                    if universalSuccess {
                        completion(true)
                        return
                    }
                    
                    // If all else fails, open App Store
                    self.openFallbackURL(result.fallbackURL, completion: completion)
                }
            } else {
                // No universal link, go straight to App Store
                self.openFallbackURL(result.fallbackURL, completion: completion)
            }
        }
    }
    
    /// Try opening primary deep links in order
    private func tryPrimaryDeepLinks(_ links: [String], completion: @escaping (Bool) -> Void) {
        guard !links.isEmpty else {
            completion(false)
            return
        }
        
        var currentIndex = 0
        
        func tryNextLink() {
            guard currentIndex < links.count else {
                completion(false)
                return
            }
            
            let link = links[currentIndex]
            currentIndex += 1
            
            if let url = URL(string: link) {
                // Check if we can open this URL
                if UIApplication.shared.canOpenURL(url) {
                    print("WalletDeepLinkGenerator: Can open deep link: \(link)")
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            print("WalletDeepLinkGenerator: Successfully opened deep link")
                            completion(true)
                        } else {
                            print("WalletDeepLinkGenerator: Failed to open deep link, trying next")
                            tryNextLink()
                        }
                    }
                } else {
                    print("WalletDeepLinkGenerator: Cannot open URL scheme: \(link)")
                    tryNextLink()
                }
            } else {
                print("WalletDeepLinkGenerator: Invalid URL: \(link)")
                tryNextLink()
            }
        }
        
        tryNextLink()
    }
    
    /// Try opening universal link
    private func tryUniversalLink(_ link: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: link) else {
            completion(false)
            return
        }
        
        print("WalletDeepLinkGenerator: Trying universal link: \(link)")
        
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
            if success {
                print("WalletDeepLinkGenerator: Successfully opened universal link")
            } else {
                print("WalletDeepLinkGenerator: Failed to open universal link")
            }
            completion(success)
        }
    }
    
    /// Open fallback URL (App Store)
    private func openFallbackURL(_ url: URL?, completion: @escaping (Bool) -> Void) {
        guard let url = url else {
            completion(false)
            return
        }
        
        print("WalletDeepLinkGenerator: Opening App Store fallback: \(url)")
        
        UIApplication.shared.open(url, options: [:]) { success in
            completion(success)
        }
    }
    
    /// Check if a wallet app is installed
    func isWalletInstalled(_ walletType: WalletType) -> Bool {
        let configuration = WalletConfiguration.configuration(for: walletType)
        let deepLinks = configuration.generateDeepLinks(for: "test")
        
        for link in deepLinks {
            // Extract scheme from deep link
            if let url = URL(string: link),
               let scheme = url.scheme,
               let schemeURL = URL(string: "\(scheme)://") {
                if UIApplication.shared.canOpenURL(schemeURL) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Generate AppKit-compatible deep link for supported wallets
    func generateAppKitDeepLink(for walletType: WalletType, uri: String) -> String? {
        // Map wallet types to AppKit wallet IDs
        let walletIds: [WalletType: String] = [
            .trust: "4622a2b2d6af1c9844944291e5e7351a6aa24cd7b23099efac1b2fd875da31a0",
            .family: "0b415a746fb9ee99cce155c2ceca0c6f6061b1dbca2d722b3ba16381d0562150",
            .phantom: "a797aa35c0fadbfc1a53e7f675162ed5226968b44a19ee3d24385c64d1d3c393",
            .zerion: "ecc4036f814562b41a5268adc86270fba1365471402006302e70169465b7ac18"
        ]
        
        guard let walletId = walletIds[walletType] else { return nil }
        
        // Use existing deeplink generation with AppKit URI
        let encodedUri = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
        
        switch walletType {
        case .trust:
            return "trust://wc?uri=\(encodedUri)"
        case .family:
            return "family://wc?uri=\(encodedUri)"
        case .phantom:
            return "phantom://wc?uri=\(encodedUri)"
        case .zerion:
            return "zerion://wc?uri=\(encodedUri)"
        default:
            return nil
        }
    }
    
    /// Open wallet using AppKit if available
    func openWalletWithAppKit(_ walletType: WalletType) async throws {
        do {
            // Use standard WalletConnect flow for all wallets
            try await WalletService.shared.connectWallet(walletType)
        } catch {
            print("WalletDeepLinkGenerator: Failed to connect wallet: \(error)")
            throw error
        }
    }
    
    /// Generate transaction deeplink for a wallet
    func generateTransactionDeepLink(
        for walletType: WalletType,
        to address: String,
        value: String? = nil,
        data: String? = nil,
        chainId: String = "1"
    ) -> String? {
        // Build the transaction parameters
        var params: [String: String] = [
            "to": address,
            "chainId": chainId
        ]
        
        if let value = value {
            params["value"] = value
        }
        
        if let data = data {
            params["data"] = data
        }
        
        // Generate deeplink based on wallet type
        switch walletType {
        case .trust:
            // Trust Wallet format: trust://send?asset=c60_t0x...&to=0x...&amount=0.01
            let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents()
            components.scheme = "trust"
            components.host = "send"
            components.queryItems = queryItems
            return components.string
            
        case .family:
            // Family Wallet format
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return "family://send?\(queryString)"
            
        case .phantom:
            // Phantom format
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return "phantom://ethereum/send?\(queryString)"
            
        case .zerion:
            // Zerion format
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return "zerion://send?\(queryString)"
            
        case .metamask:
            // MetaMask uses ethereum: URIs
            var ethereumUri = "ethereum:\(address)"
            if let value = value {
                ethereumUri += "@\(chainId)/transfer?value=\(value)"
            }
            return ethereumUri
            
        case .coinbase:
            // Coinbase Wallet format
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return "cbwallet://send?\(queryString)"
            
        default:
            // For other wallets, try WalletConnect transaction request
            return nil
        }
    }
    
    /// Open wallet with transaction deeplink
    func openWalletForTransaction(
        walletType: WalletType,
        to address: String,
        value: String? = nil,
        data: String? = nil,
        chainId: String = "1",
        completion: @escaping (Bool) -> Void
    ) {
        guard let deeplink = generateTransactionDeepLink(
            for: walletType,
            to: address,
            value: value,
            data: data,
            chainId: chainId
        ) else {
            completion(false)
            return
        }
        
        guard let url = URL(string: deeplink) else {
            completion(false)
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("WalletDeepLinkGenerator: Successfully opened transaction deeplink")
                } else {
                    print("WalletDeepLinkGenerator: Failed to open transaction deeplink")
                }
                completion(success)
            }
        } else {
            print("WalletDeepLinkGenerator: Cannot open transaction URL scheme")
            // Fallback to app store
            openFallbackURL(getAppStoreURL(for: walletType), completion: completion)
        }
    }
    
    /// Get App Store URL for wallet
    private func getAppStoreURL(for walletType: WalletType) -> URL? {
        let appIds: [WalletType: String] = [
            .trust: "1288339409",
            .rainbow: "1457119021",
            .argent: "1358741926",
            .phantom: "1598432977",
            .family: "1664952316", // Family Wallet app ID
            .oneInch: "1546049391",
            .zerion: "1456732565",
            .imToken: "1384798940",
            .tokenPocket: "1436028697",
            .gnosisSafe: "1515759131"
        ]
        
        guard let appId = appIds[walletType] else { return nil }
        
        return URL(string: "https://apps.apple.com/app/id\(appId)")
    }
}

// MARK: - WalletService Extension

extension WalletDeepLinkGenerator {
    /// Handle return from wallet app
    func handleWalletReturn(url: URL) -> Bool {
        print("WalletDeepLinkGenerator: Handling wallet return URL: \(url)")
        
        // Extract wallet type from URL if possible
        if url.scheme == "interspace" {
            // Handle different callback paths
            if url.host == "walletconnect" || url.host == "auth" {
                // WalletConnect/AppKit callback
                Task { @MainActor in
                    appKitService.handleDeeplink(url)
                }
                
                NotificationCenter.default.post(
                    name: .walletConnectCallback,
                    object: nil,
                    userInfo: ["url": url]
                )
                return true
            }
        }
        
        return false
    }
}


