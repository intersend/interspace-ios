import SwiftUI
import Foundation

struct DemoModeConfiguration {
    static let isDemoMode: Bool = true
    static let showDemoIndicator: Bool = true
}

@main
struct interspace_iosApp: App {
    @StateObject private var serviceInitializer = ServiceInitializer.shared
    
    // Initialize shared services on app launch
    init() {
        // Perform critical initialization
        if DemoModeConfiguration.isDemoMode {
            print("🎭 Demo Mode: Initializing services for demo")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // TestView() // Works correctly - fills screen
            ContentView()
                .environmentObject(serviceInitializer.auth)
                .environmentObject(serviceInitializer.session)
                .environmentObject(serviceInitializer)
                .preferredColorScheme(.dark)
                .overlay(alignment: .top) {
                    if DemoModeConfiguration.isDemoMode && DemoModeConfiguration.showDemoIndicator {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("DEMO MODE")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(20)
                        .padding(.top, 50)
                    }
                }
                .onAppear {
                    // Configure global app appearance
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.windows.forEach { window in
                            window.overrideUserInterfaceStyle = .dark
                        }
                    }
                    
                    // Initialize services based on mode
                    Task { @MainActor in
                        if DemoModeConfiguration.isDemoMode {
                            // For demo mode, initialize with minimal services
                            await ServiceInitializer.shared.initializeCriticalServices()
                        } else {
                            await ServiceInitializer.shared.initializeCriticalServices()
                        }
                        
                        // Initialize deferred services after UI is ready
                        ServiceInitializer.shared.initializeDeferredServices()
                    }
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

