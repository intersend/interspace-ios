import SwiftUI
import metamask_ios_sdk
import CoinbaseWalletSDK
import AVFoundation

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @ObservedObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var walletService = WalletService.shared
    @State private var showingWalletConnectScanner = false
    @State private var showingEmailAuth = false
    @State private var isLoading = false
    @State private var showWalletConnectionTray = false
    @State private var showSocialConnectionTray = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Full-screen background - extends to all edges
                    DesignTokens.Colors.backgroundPrimary
                        .ignoresSafeArea(.all)
                    
                    // Main content - proper full-screen layout
                    if authManager.isAuthenticated {
                        AuthenticatedView()
                    } else {
                        UnauthenticatedView(
                            showingWalletConnectScanner: $showingWalletConnectScanner,
                            showWalletConnectionTray: $showWalletConnectionTray,
                            showSocialConnectionTray: $showSocialConnectionTray,
                            onConnectMetaMask: connectMetaMask,
                            onConnectCoinbase: connectCoinbaseWallet,
                            onConnectWalletConnect: connectWalletConnect,
                            onAuthenticateGoogle: authenticateWithGoogle,
                            onAuthenticatePasskey: authenticateWithPasskey,
                            onAuthenticateGuest: authenticateAsGuest,
                            onShowEmailAuth: showEmailAuthentication,
                            screenHeight: geometry.size.height
                        )
                    }
                    
                    // Loading Overlay
                    if authManager.isLoading || walletService.connectionStatus == .connecting || isLoading {
                        LiquidGlassLoadingOverlay()
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
            EmailAuthView(viewModel: viewModel)
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
        // TODO: Implement wallet connections when ready
        print("🔗 AuthView: MetaMask connection - coming soon")
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
    
    private func authenticateAsGuest() async {
        do {
            let config = WalletConnectionConfig(
                strategy: .guest,
                walletType: nil,
                email: nil,
                verificationCode: nil,
                walletAddress: nil,
                signature: nil,
                message: nil,
                socialProvider: nil,
                socialProfile: nil
            )
            try await authManager.authenticate(with: config)
        } catch {
            print("Guest authentication error: \(error)")
        }
    }
    
    private func showEmailAuthentication() {
        showingEmailAuth = true
    }
    
    private func ensureCleanWalletState() async {
        // If we're at the auth screen and MetaMask SDK has an account,
        // it means we have a stale connection that needs to be cleared
        if let metamaskSDK = walletService.metamaskSDK, !metamaskSDK.account.isEmpty {
            print("🔐 AuthView: Found stale MetaMask connection at auth screen, clearing...")
            print("🔐 AuthView: Stale account: \(metamaskSDK.account)")
            await walletService.disconnect()
        }
        
        // Also ensure our wallet service state is clean
        if walletService.connectionStatus != .disconnected {
            print("🔐 AuthView: Wallet service not in disconnected state, clearing...")
            await walletService.disconnect()
        }
    }
}

// MARK: - Authenticated State View
struct AuthenticatedView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section - flows from top
            VStack(spacing: 24) {
                // Success animation
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.success.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.success)
                }
                
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Welcome to Interspace!")
                        .font(DesignTokens.Typography.largeTitle)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Authentication successful")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Bottom action
            VStack {
                Button("Sign Out") {
                    HapticManager.impact(.light)
                    Task {
                        await authManager.logout()
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(variant: .destructive, size: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Unauthenticated State View
struct UnauthenticatedView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var walletService = WalletService.shared
    @Binding var showingWalletConnectScanner: Bool
    @Binding var showWalletConnectionTray: Bool
    @Binding var showSocialConnectionTray: Bool
    
    let onConnectMetaMask: () async -> Void
    let onConnectCoinbase: () async -> Void
    let onConnectWalletConnect: () async -> Void
    let onAuthenticateGoogle: () async -> Void
    let onAuthenticatePasskey: () async -> Void
    let onAuthenticateGuest: () async -> Void
    let onShowEmailAuth: () -> Void
    let screenHeight: CGFloat
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header section - starts at top with minimal spacing
                VStack(spacing: 24) {
                    // App logo/icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignTokens.Colors.primary,
                                        DesignTokens.Colors.primaryVariant
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: DesignTokens.Colors.primary.opacity(0.3),
                                radius: 15,
                                x: 0,
                                y: 8
                            )
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Welcome to Interspace")
                            .font(DesignTokens.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Connect your wallet or sign in to get started with smart profiles and Web3 apps")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
                
                // Authentication Options Section
                VStack(spacing: 32) {
                    // Primary authentication options
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Connect Wallet button (preferred)
                        Button(action: {
                            HapticManager.impact(.medium)
                            showWalletConnectionTray = true
                        }) {
                            HStack {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 22, weight: .medium))
                                
                                Text("Connect Wallet")
                                    .font(DesignTokens.Typography.title3)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.lg)
                            .background(
                                LinearGradient(
                                    colors: [
                                        DesignTokens.Colors.primary,
                                        DesignTokens.Colors.primaryVariant
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                            .shadow(
                                color: DesignTokens.Colors.primary.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Connect Social button
                        Button(action: {
                            HapticManager.impact(.medium)
                            showSocialConnectionTray = true
                        }) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 20, weight: .medium))
                                
                                Text("Connect Social")
                                    .font(DesignTokens.Typography.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .fill(DesignTokens.Colors.backgroundTertiary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                            .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(DesignTokens.Colors.borderSecondary)
                            .frame(height: 0.5)
                        
                        Text("or")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        
                        Rectangle()
                            .fill(DesignTokens.Colors.borderSecondary)
                            .frame(height: 0.5)
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                    
                    // Alternative options
                    VStack(spacing: DesignTokens.Spacing.md) {
                        LiquidGlassAuthButton(
                            title: "Continue with Email",
                            subtitle: "Sign in with email verification",
                            icon: "envelope.fill",
                            walletType: nil
                        ) {
                            HapticManager.impact(.light)
                            onShowEmailAuth()
                        }
                        
                        LiquidGlassAuthButton(
                            title: "Sign in with Passkey",
                            subtitle: "Use Face ID or Touch ID",
                            icon: "faceid",
                            walletType: .apple
                        ) {
                            Task {
                                await onAuthenticatePasskey()
                            }
                        }
                    }
                    
                    // Guest mode button
                    Button("Continue as Guest") {
                        HapticManager.impact(.light)
                        Task {
                            await onAuthenticateGuest()
                        }
                    }
                    .buttonStyle(LiquidGlassButtonStyle(variant: .ghost, size: .medium))
                    .padding(.top, DesignTokens.Spacing.md)
                    
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
            .frame(minHeight: screenHeight)
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

#Preview {
    AuthView()
}
