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
                metamaskSDK.handleUrl(url)
                print("📱 AppDelegate: MetaMask SDK handled URL successfully")
                print("📱 AppDelegate: SDK account after handleUrl: \(metamaskSDK.account.isEmpty ? "none" : metamaskSDK.account)")
                
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
    
    // Check for WalletConnect URLs
    if url.scheme == "interspace" && url.host == "walletconnect" {
        print("📱 AppDelegate: Handling WalletConnect deep link")
        // WalletConnect SDK handles these internally
        return true
    }
    
    // Check for WalletConnect universal links
    if url.absoluteString.contains("walletconnect") {
        print("📱 AppDelegate: Detected WalletConnect universal link")
        return true
    }
    
    // Check for OAuth redirect URLs
    if url.scheme == "com.interspace.ios" && url.host == "oauth2redirect" {
        print("📱 AppDelegate: Handling OAuth redirect URL")
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
            
//             if url.absoluteString.contains("wc") {
//                 print("📱 AppDelegate: Handling WalletConnect universal link")
//                 // Handle WalletConnect universal links
//                 do {
//                     try WalletKit.instance.dispatchEnvelope(url.absoluteString)
//                     return true
//                 } catch {
//                     print("📱 AppDelegate: WalletConnect universal link handling error: \(error)")
//                 }
//             }
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


