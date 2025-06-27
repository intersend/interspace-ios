import SwiftUI
import Foundation

/// Global demo mode configuration
public enum DemoMode {
    public static let isEnabled: Bool = true
    public static let showIndicator: Bool = true
    public static let useMockData: Bool = true
    public static let skipAuthentication: Bool = true
    public static let demoUserEmail: String = "demo@interspace.app"
}

@main
struct interspace_iosApp: App {
    @StateObject private var serviceInitializer = ServiceInitializer.shared
    
    // Initialize shared services on app launch
    init() {
        // Perform critical initialization
        if DemoMode.isEnabled {
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
                    if DemoMode.isEnabled && DemoMode.showIndicator {
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
                        if DemoMode.isEnabled {
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

