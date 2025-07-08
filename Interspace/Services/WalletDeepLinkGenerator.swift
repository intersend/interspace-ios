import Foundation
import UIKit

/// Service responsible for generating and handling wallet deep links
class WalletDeepLinkGenerator {
    static let shared = WalletDeepLinkGenerator()
    
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
    
    /// Get App Store URL for wallet
    private func getAppStoreURL(for walletType: WalletType) -> URL? {
        let appIds: [WalletType: String] = [
            .trust: "1288339409",
            .rainbow: "1457119021",
            .argent: "1358741926",
            .phantom: "1598432977",
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
            if url.host == "walletconnect" {
                // WalletConnect callback
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

// MARK: - Notification Names

extension Notification.Name {
    static let walletConnectCallback = Notification.Name("walletConnectCallback")
}