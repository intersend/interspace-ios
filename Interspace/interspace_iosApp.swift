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
                    
                    // Handle MetaMask URLs
                    if url.scheme == "interspace" && url.host == "mmsdk" {
                        print("📱 SwiftUI App: Detected MetaMask callback URL")
                        if let metamaskSDK = WalletService.shared.metamaskSDK {
                            print("📱 SwiftUI App: Passing URL to MetaMask SDK")
                            metamaskSDK.handleUrl(url)
                            print("📱 SwiftUI App: MetaMask SDK handled URL")
                        }
                    }
                }
            }
        }
    }
}
