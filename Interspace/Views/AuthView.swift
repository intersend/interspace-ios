import SwiftUI
import AVFoundation
import UIOnboarding

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @ObservedObject private var walletService = WalletService.shared
    @State private var showingWalletConnectScanner = false
    @State private var isLoading = false
    @State private var showWalletConnectionTray = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Native iOS adaptive background
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    
                    // Main content - Only show auth UI, let ContentView handle authenticated states
                    OnboardingViewRepresentable(
                        onContinue: {
                            // Show universal add tray when user taps continue
                            showWalletConnectionTray = true
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    
                    // Loading Overlay
                    if authManager.isLoading || walletService.connectionStatus == .connecting || isLoading {
                        LoadingOverlay()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Reset auth flow to ensure clean state
            viewModel.resetAuthFlow()
            
            // Ensure clean wallet state when showing auth screen
            Task {
                await ensureCleanWalletState()
            }
        }
        .sheet(isPresented: $showingWalletConnectScanner) {
            LiquidGlassWalletConnectScanner { uri in
                Task {
                    await handleWalletConnectURI(uri)
                }
            }
        }
        .sheet(isPresented: $showWalletConnectionTray) {
            UniversalAddTray(
                isPresented: $showWalletConnectionTray,
                initialSection: .none,
                isForAuthentication: true,
                authViewModel: viewModel
            )
        }
        .alert(item: $authManager.error) { error in
            Alert(
                title: Text("Authentication Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $walletService.error) { error in
            if error.localizedDescription.contains("not installed") {
                return Alert(
                    title: Text("Wallet Connection Error"),
                    message: Text(error.localizedDescription),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Open App Store")) {
                        openAppStore(for: error)
                    }
                )
            } else {
                return Alert(
                    title: Text("Wallet Connection Error"),
                    message: Text(error.localizedDescription),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func openAppStore(for error: WalletError) {
        var appStoreURL: URL?
        
        if error.localizedDescription.contains("MetaMask") {
            appStoreURL = URL(string: "https://apps.apple.com/app/metamask/id1438144202")
        } else if error.localizedDescription.contains("Coinbase") {
            appStoreURL = URL(string: "https://apps.apple.com/app/coinbase-wallet/id1278383455")
        }
        
        if let url = appStoreURL {
            UIApplication.shared.open(url)
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func handleWalletConnectURI(_ uri: String) async {
        // TODO: Implement WalletConnect URI handling when ready
        print("🔗 AuthView: WalletConnect URI handling - coming soon")
        
        // Show QR scanner for WalletConnect
        showingWalletConnectScanner = true
    }
    
    private func ensureCleanWalletState() async {
        // Ensure our wallet service state is clean
        if walletService.connectionStatus != .disconnected {
            print("🔐 AuthView: Wallet service not in disconnected state, clearing...")
            await walletService.disconnect()
        }
        
        // Also check WalletServiceV2 for any active connections
        if WalletServiceV2.shared.connectionState.isConnected {
            print("🔐 AuthView: Found active wallet connection at auth screen, clearing...")
            try? await WalletServiceV2.shared.disconnect()
        }
    }
}


// MARK: - Removed NativeAppleAuthView - now using UIOnboarding



#Preview {
    AuthView()
}
