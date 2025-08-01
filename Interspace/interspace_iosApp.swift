import SwiftUI

@main
struct interspace_iosApp: App {
    @StateObject private var serviceInitializer = ServiceInitializer.shared
    
    // Initialize shared services on app launch
    init() {
        // Skip initialization if running tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            print("Running in test mode - skipping service initialization")
            return
        }
        
        // Perform critical initialization synchronously
        Task { @MainActor in
            await ServiceInitializer.shared.initializeCriticalServices()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Check if running tests
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                // Minimal view for tests
                EmptyView()
            } else {
                // TestView() // Works correctly - fills screen
                ContentView()
                    .environmentObject(serviceInitializer.auth)
                    .environmentObject(serviceInitializer.session)
                    .environmentObject(serviceInitializer)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // Configure global app appearance
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.windows.forEach { window in
                                window.overrideUserInterfaceStyle = .dark
                            }
                        }
                        
                        // Initialize deferred services after UI is ready
                        ServiceInitializer.shared.initializeDeferredServices()
                    }
                .onOpenURL { url in
                    print("📱 SwiftUI App: Received URL: \(url.absoluteString)")
                    print("📱 SwiftUI App: URL scheme: \(url.scheme ?? "none")")
                    print("📱 SwiftUI App: URL host: \(url.host ?? "none")")
                    
                    // Handle AppKit URLs first
                    if url.scheme == "interspace" {
                        print("📱 SwiftUI App: Processing interspace:// URL")
                        
                        // Try AppKit handling first
                        print("📱 SwiftUI App: Getting AppKitService...")
                        let appKitService = ServiceInitializer.shared.getAppKitService()
                        print("📱 SwiftUI App: Attempting AppKit deep link handling...")
                        if appKitService.handleDeepLink(url) {
                            print("✅ SwiftUI App: AppKit successfully handled the deep link")
                            return
                        } else {
                            print("⚠️ SwiftUI App: AppKit did not handle the deep link")
                        }
                        
                        // Handle MetaMask URLs
                        if url.host == "mmsdk" || url.host == "metamask-callback" {
                            print("📱 SwiftUI App: Detected MetaMask callback URL")
                            Task { @MainActor in
                                let handled = WalletServiceV2.shared.handleDeepLink(url)
                                print("📱 SwiftUI App: MetaMask deep link handled: \(handled)")
                            }
                        } else {
                            print("⚠️ SwiftUI App: Unknown interspace:// URL host: \(url.host ?? "nil")")
                        }
                    } else {
                        print("⚠️ SwiftUI App: Non-interspace URL scheme: \(url.scheme ?? "nil")")
                    }
                }
            }
        }
    }
}
