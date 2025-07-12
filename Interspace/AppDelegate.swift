import SwiftUI
import metamask_ios_sdk
import CoinbaseWalletSDK
import GoogleSignIn
import WalletConnectSign
import AppAuth


public class AppDelegate: UIResponder, UIApplicationDelegate {
  public var window: UIWindow?
  
  // URL handling state
  private var lastMetaMaskURLTime: Date?
  private let urlDebounceInterval: TimeInterval = 0.5 // 500ms debounce
  private var isHandlingMetaMaskURL = false

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    
    // Track app launch performance
    AppLaunchPerformance.shared.markAppDelegateStart()
    
    // Initialize data sync infrastructure
    print("📱 AppDelegate: Initializing data sync infrastructure")
    _ = DataSyncManager.shared
    _ = NetworkMonitor.shared
    
    // Perform Core Data migration if needed
    CoreDataMigrationManager.performMigrationIfNeeded()
    
    // Defer wallet initialization - only create the service instance
    print("📱 AppDelegate: Deferring WalletService initialization")
    _ = WalletService.shared // Just create the instance, don't initialize SDKs
    
    // Configure Coinbase Wallet SDK
    print("📱 AppDelegate: Configuring Coinbase Wallet SDK")
    CoinbaseWalletSDK.configure(
        callback: URL(string: "interspace://coinbase")!
    )
    
    // Configure Google Sign-In
    print("📱 AppDelegate: Configuring Google Sign-In")
    GoogleSignInService.shared.configure()
    
    // Enable MPC wallet for testing in debug builds
    #if DEBUG
    print("📱 AppDelegate: Enabling MPC wallet for debug testing")
    MPCDebugHelper.initializeForTesting()
    #endif
    
    // Track end of app delegate
    AppLaunchPerformance.shared.markAppDelegateEnd()

    return true
  }
  
  public func applicationDidBecomeActive(_ application: UIApplication) {
    print("📱 AppDelegate: App became active")
    print("📱 AppDelegate: Time: \(Date())")
    // Handle wallet state when returning from background
    WalletService.shared.handleAppForeground()
  }
  
  public func applicationWillResignActive(_ application: UIApplication) {
    print("📱 AppDelegate: App will resign active")
    // Handle wallet state when going to background
    WalletService.shared.handleAppBackground()
  }

  public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📱 AppDelegate: ====== URL RECEIVED ======")
    print("📱 AppDelegate: Full URL: \(url.absoluteString)")
    print("📱 AppDelegate: Scheme: \(url.scheme ?? "none")")
    print("📱 AppDelegate: Host: \(url.host ?? "none")")
    print("📱 AppDelegate: Path: \(url.path)")
    print("📱 AppDelegate: Query: \(url.query ?? "none")")
    print("📱 AppDelegate: Fragment: \(url.fragment ?? "none")")
    
    // Check for MetaMask URLs - handle multiple patterns
    if url.scheme == "interspace" {
        print("📱 AppDelegate: Detected interspace:// URL")
        
        // Check if this is a MetaMask callback
        if url.host == "mmsdk" || url.absoluteString.contains("metamask") {
            print("📱 AppDelegate: This is a MetaMask callback URL")
            
            // Prevent re-entrant URL handling
            if isHandlingMetaMaskURL {
                print("📱 AppDelegate: Already handling MetaMask URL, ignoring")
                return true
            }
            
            // Debounce rapid URL calls
            if let lastTime = lastMetaMaskURLTime {
                let timeSinceLastURL = Date().timeIntervalSince(lastTime)
                if timeSinceLastURL < urlDebounceInterval {
                    print("📱 AppDelegate: Ignoring rapid MetaMask URL (debouncing) - \(timeSinceLastURL)s since last URL")
                    return true
                }
            }
            
            isHandlingMetaMaskURL = true
            lastMetaMaskURLTime = Date()
            
            // Get the MetaMask SDK instance and handle the URL
            if let metamaskSDK = WalletService.shared.metamaskSDK {
                print("📱 AppDelegate: Passing URL to MetaMask SDK")
                print("📱 AppDelegate: SDK account before handleUrl: \(metamaskSDK.account.isEmpty ? "none" : metamaskSDK.account)")
                print("📱 AppDelegate: Is connection in progress: \(WalletService.shared.isConnectionInProgress)")
                
                // Handle the URL - this should trigger the SDK's internal callback
                metamaskSDK.handleUrl(url)
                
                print("📱 AppDelegate: MetaMask SDK handled URL successfully")
                print("📱 AppDelegate: SDK account after handleUrl: \(metamaskSDK.account.isEmpty ? "none" : metamaskSDK.account)")
                
                // If we're in a connection flow, the SDK should now have the account
                if WalletService.shared.isConnectionInProgress && !metamaskSDK.account.isEmpty {
                    print("📱 AppDelegate: Connection flow detected with account available")
                }
                
                // Clear the handling flag after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.isHandlingMetaMaskURL = false
                }
            } else {
                print("📱 AppDelegate: Warning - MetaMask SDK not initialized")
            }
            return true
        }
        
        // Check if this is a Coinbase callback
        if url.host == "coinbase" {
            print("📱 AppDelegate: This is a Coinbase Wallet callback URL")
            do {
                let handled = try CoinbaseWalletSDK.shared.handleResponse(url)
                if handled {
                    print("📱 AppDelegate: Successfully handled Coinbase Wallet URL")
                    return true
                } else {
                    print("📱 AppDelegate: Coinbase SDK did not handle URL")
                }
            } catch {
                print("📱 AppDelegate: Error handling Coinbase URL: \(error)")
            }
        }
    }
    
    // Check for Google Sign-In URLs
    // TODO: Uncomment after adding GoogleSignIn via SPM
     if GIDSignIn.sharedInstance.handle(url) {
         print("📱 AppDelegate: Handling Google Sign-In URL")
         return true
     }
    
    // Check for WalletConnect/AppKit URLs
    if url.scheme == "interspace" && (url.host == "walletconnect" || url.host == "auth") {
        print("📱 AppDelegate: Handling WalletConnect/AppKit deep link")
        ServiceInitializer.shared.appKit.handleDeeplink(url)
        
        // Use WalletDeepLinkGenerator for handling
        let handled = WalletDeepLinkGenerator.shared.handleWalletReturn(url: url)
        if handled {
            print("📱 AppDelegate: WalletConnect/AppKit callback handled successfully")
        }
        return true
    }
    
    // Check for WalletConnect universal links
    if url.absoluteString.contains("walletconnect") {
        print("📱 AppDelegate: Detected WalletConnect universal link")
        return true
    }
    
    // Check for OAuth redirect URLs (both custom scheme variants)
    if (url.scheme == "com.interspace.ios" || url.scheme == "interspace") && url.host == "oauth2redirect" {
        print("📱 AppDelegate: Handling OAuth redirect URL: \(url)")
        if OAuthProviderService.shared.handleRedirect(url: url) {
            print("📱 AppDelegate: OAuth redirect handled successfully")
            return true
        }
    }
    
    print("📱 AppDelegate: URL not handled by any service")
    return false
  }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("📱 AppDelegate: Continue user activity: \(userActivity.activityType)")
        
        if let url = userActivity.webpageURL {
            print("📱 AppDelegate: Universal link URL: \(url.absoluteString)")
            
            // Handle Coinbase Wallet universal links
            do {
                let handled = try CoinbaseWalletSDK.shared.handleResponse(url)
                if handled {
                    print("📱 AppDelegate: Successfully handled Coinbase universal link")
                    return true
                } else {
                    print("📱 AppDelegate: Coinbase SDK did not handle universal link")
                }
            } catch {
                print("📱 AppDelegate: Error handling Coinbase universal link: \(error)")
            }
            
            // Handle wallet universal links (Trust, Rainbow, Phantom, etc.)
            let universalLinkDomains = [
                "link.trustwallet.com": WalletType.trust,
                "rnbwapp.com": WalletType.rainbow,
                "phantom.app": WalletType.phantom,
                "argent.link": WalletType.argent,
                "safe.global": WalletType.gnosisSafe,
                "1inch.io": WalletType.oneInch,
                "app.zerion.io": WalletType.zerion,
                "family.co": WalletType.family
            ]
            
            for (domain, walletType) in universalLinkDomains {
                if url.absoluteString.contains(domain) {
                    print("📱 AppDelegate: Detected \(walletType.displayName) universal link")
                    
                    // Check if this is a return from wallet after SIWE signing
                    if url.absoluteString.contains("wc") || url.absoluteString.contains("walletconnect") {
                        // This is likely a WalletConnect/AppKit callback
                        if [WalletType.trust, WalletType.family, WalletType.phantom, WalletType.zerion].contains(walletType) {
                            ServiceInitializer.shared.appKit.handleDeeplink(url)
                        }
                        
                        NotificationCenter.default.post(
                            name: .walletConnectCallback,
                            object: nil,
                            userInfo: ["url": url, "walletType": walletType]
                        )
                        return true
                    }
                }
            }
            
            // Handle generic WalletConnect universal links
            if url.absoluteString.contains("wc") || url.absoluteString.contains("walletconnect") {
                print("📱 AppDelegate: Handling WalletConnect universal link")
                NotificationCenter.default.post(
                    name: .walletConnectCallback,
                    object: nil,
                    userInfo: ["url": url]
                )
                return true
            }
        }
        print("📱 AppDelegate: Universal link not handled")
        return false
    }
}

// Coinbase SDK extension disabled temporarily
// extension UIApplication {
//     static func swizzleOpenURL() {
//         guard
//             let original = class_getInstanceMethod(UIApplication.self, #selector(open(_:options:completionHandler:))),
//             let swizzled = class_getInstanceMethod(UIApplication.self, #selector(swizzledOpen(_:options:completionHandler:)))
//         else { return }
//         method_exchangeImplementations(original, swizzled)
//     }
//     
//     @objc func swizzledOpen(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler completion: ((Bool) -> Void)?) {
//         // it's not recursive. below is actually the original open(_:) method
//         self.swizzledOpen(url, options: options, completionHandler: completion)
//     }
// }
