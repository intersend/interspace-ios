import SwiftUI
import AVFoundation

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @ObservedObject private var walletService = WalletService.shared
    @State private var showingWalletConnectScanner = false
    @State private var showingEmailAuth = false
    @State private var isLoading = false
    @State private var showWalletConnectionTray = false
    @State private var showSocialConnectionTray = false
    @State private var isShowingAuth = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Native iOS adaptive background
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    
                    // Main content
                    if authManager.isAuthenticated {
                        AuthenticatedView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    } else {
                        NativeAppleAuthView(
                            showingWalletConnectScanner: $showingWalletConnectScanner,
                            showWalletConnectionTray: $showWalletConnectionTray,
                            showSocialConnectionTray: $showSocialConnectionTray,
                            isShowingAuth: $isShowingAuth,
                            onConnectMetaMask: connectMetaMask,
                            onConnectCoinbase: connectCoinbaseWallet,
                            onConnectWalletConnect: connectWalletConnect,
                            onAuthenticateGoogle: authenticateWithGoogle,
                            onAuthenticatePasskey: authenticateWithPasskey,
                            onShowEmailAuth: showEmailAuthentication,
                            screenHeight: geometry.size.height
                        )
                        .transition(.opacity)
                    }
                    
                    // Loading Overlay with native blur
                    if authManager.isLoading || walletService.connectionStatus == .connecting || isLoading {
                        NativeLoadingOverlay()
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
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthenticationView(isPresented: $showingEmailAuth)
        }
        .sheet(isPresented: $showWalletConnectionTray) {
            WalletConnectionTray(
                isPresented: $showWalletConnectionTray,
                isForAuthentication: true,
                authViewModel: viewModel
            )
        }
        .sheet(isPresented: $showSocialConnectionTray) {
            SocialConnectionTray(isPresented: $showSocialConnectionTray)
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
    
    
    // MARK: - Authentication Methods
    
    private func connectMetaMask() async {
        print("🔗 AuthView: MetaMask connection requested")
        viewModel.connectWithMetaMask()
    }
    
    private func connectCoinbaseWallet() async {
        // TODO: Implement wallet connections when ready
        print("🔗 AuthView: Coinbase Wallet connection - coming soon")
    }
    
    private func connectWalletConnect() async {
        // TODO: Implement wallet connections when ready
        print("🔗 AuthView: WalletConnect connection - coming soon")
    }
    
    private func handleWalletConnectURI(_ uri: String) async {
        // TODO: Implement WalletConnect URI handling when ready
        print("🔗 AuthView: WalletConnect URI handling - coming soon")
        
        // Show QR scanner for WalletConnect
        showingWalletConnectScanner = true
    }
    
    private func authenticateWithGoogle() async {
        print("🔗 AuthView: User tapped Google Sign-In button")
        do {
            try await authManager.authenticateWithGoogle()
            print("🔗 AuthView: Google authentication completed successfully")
        } catch {
            print("🔗 AuthView: Google authentication error: \(error)")
            print("🔗 AuthView: Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("🔗 AuthView: Error domain: \(nsError.domain)")
                print("🔗 AuthView: Error code: \(nsError.code)")
                print("🔗 AuthView: Error userInfo: \(nsError.userInfo)")
            }
        }
    }
    
    private func authenticateWithPasskey() async {
        do {
            try await authManager.authenticateWithPasskey()
        } catch {
            print("🔗 AuthView: Passkey authentication error: \(error)")
        }
    }
    
    private func showEmailAuthentication() {
        showingEmailAuth = true
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

// MARK: - Authenticated State View
struct AuthenticatedView: View {
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Native Apple success animation
            VStack(spacing: 32) {
                // Success checkmark with native animation
                ZStack {
                    // Background circle with subtle animation
                    Circle()
                        .fill(Color(UIColor.systemGreen).opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .regular))
                        .foregroundColor(Color(UIColor.systemGreen))
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }
                
                VStack(spacing: 8) {
                    Text("Welcome to Interspace")
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("You're all set!")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Sign out button - native iOS style
            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.impact(.light)
                    Task {
                        await SessionCoordinator.shared.logout()
                    }
                }) {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("You can sign out at any time from Settings")
                    .font(.system(size: 13))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Native Apple Style Auth View
struct NativeAppleAuthView: View {
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @ObservedObject private var walletService = WalletService.shared
    @Binding var showingWalletConnectScanner: Bool
    @Binding var showWalletConnectionTray: Bool
    @Binding var showSocialConnectionTray: Bool
    @Binding var isShowingAuth: Bool
    @State private var showUniversalAddTray = false
    @State private var isAnimating = false
    
    let onConnectMetaMask: () async -> Void
    let onConnectCoinbase: () async -> Void
    let onConnectWalletConnect: () async -> Void
    let onAuthenticateGoogle: () async -> Void
    let onAuthenticatePasskey: () async -> Void
    let onShowEmailAuth: () -> Void
    let screenHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top section with logo - Apple Fitness+ style
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.top + 60)
                    
                    // Subtle app icon - Apple native style
                    VStack(spacing: 28) {
                        // Minimalist icon with subtle branding - Apple Health/Fitness style
                        Image("SplashScreenLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        
                        // Title - Apple native typography
                        Text("Interspace")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 10)
                    }
                    
                    Spacer()
                        .frame(height: 60)
                }
                
                Spacer()
                
                // Bottom section with actions - Apple native style
                VStack(spacing: 12) {
                    // Continue button - Primary action
                    Button(action: {
                        HapticManager.impact(.light)
                        showUniversalAddTray = true
                    }) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.systemBlue))
                            )
                    }
                    .buttonStyle(NativeButtonStyle())
                    
                    // Secondary actions
                    HStack(spacing: 12) {
                        // Sign in with Apple
                        Button(action: {
                            HapticManager.impact(.light)
                            Task {
                                await onAuthenticatePasskey()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Sign in with Apple")
                                    .font(.system(size: 17, weight: .regular))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                            )
                        }
                        .buttonStyle(NativeButtonStyle())
                    }
                    
                    // Privacy note - Apple style
                    Text("By continuing, you agree to our Terms of Service")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                isAnimating = true
            }
        }
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(
                isPresented: $showUniversalAddTray,
                initialSection: .none,
                isForAuthentication: true,
                authViewModel: AuthViewModel()
            )
        }
    }
}

// MARK: - Liquid Glass Auth Button
struct LiquidGlassAuthButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let walletType: WalletType?
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Group {
                    if icon.contains(".") {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                    } else {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }
                .foregroundColor(walletType?.primaryColor ?? DesignTokens.Colors.primary)
                .frame(width: 32, height: 32)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.iOSNavigationSpacing)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Colors.backgroundTertiary)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: isPressed ? Color.clear : DesignTokens.Shadows.level2.color,
                radius: isPressed ? 0 : DesignTokens.Shadows.level2.radius,
                x: 0,
                y: isPressed ? 0 : DesignTokens.Shadows.level2.y
            )
            .animation(DesignTokens.Animation.buttonPress, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Native Loading Overlay
struct NativeLoadingOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Loading indicator
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("Connecting...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .scaleEffect(isAnimating ? 1.0 : 0.9)
            .opacity(isAnimating ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Native Button Style
struct NativeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AuthView()
}
