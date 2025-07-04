import SwiftUI

enum AddSection {
    case none
    case wallet
    case social
    case app
}

struct UniversalAddTray: View {
    @Binding var isPresented: Bool
    let initialSection: AddSection
    var isForAuthentication: Bool = false
    var authViewModel: AuthViewModel? = nil
    
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    @StateObject private var localAuthViewModel = AuthViewModel()
    @State private var showWalletConnection = false
    @State private var showSocialConnection = false
    @State private var selectedWalletType: WalletType?
    @State private var selectedSocialProvider: SocialProvider?
    @State private var showEmailAuth = false
    @State private var showPasskeyAuth = false
    @State private var showAppleSignIn = false
    @State private var showWalletAuthorization = false
    @State private var showAddApp = false
    @State private var showProfileCreation = false
    @State private var availableWalletConnectWallets: [WalletType] = []
    @State private var showOAuthFlow = false
    @State private var selectedOAuthProvider: OAuthProviderInfo?
    @State private var isProcessing = false
    @State private var showFarcasterAuth = false
    // Removed showWalletConnectionTray - using direct authorization
    
    private let walletService = WalletService.shared
    private let oauthService = OAuthProviderService.shared
    
    var body: some View {
        mainContent
            .background(Color.black.opacity(0.001))
            .background(Material.regularMaterial)
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .sheet(isPresented: $showWalletAuthorization) {
                walletAuthorizationSheet
            }
            .sheet(isPresented: $showWalletConnection) {
                walletConnectionSheet
            }
            .sheet(isPresented: $showEmailAuth) {
                emailAuthSheet
            }
            .sheet(isPresented: $showPasskeyAuth) {
                passkeyAuthSheet
            }
            .sheet(isPresented: $showAddApp) {
                addAppSheet
            }
            .sheet(isPresented: $showProfileCreation) {
                profileCreationSheet
            }
            .sheet(isPresented: $showOAuthFlow) {
                oauthFlowSheet
            }
            .sheet(isPresented: $showFarcasterAuth) {
                farcasterAuthSheet
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
            .onAppear {
                onAppearActions()
            }
            .onChange(of: authManager.isAuthenticated) { newValue in
                onAuthenticationChange(newValue)
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                scrollContent
            }
        }
    }
    
    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            headerView
            
            if showSuggestedSection {
                suggestedSection
            }
            
            if showProfileSection {
                profileSection
            }
            
            accountSection
            authenticationMethodsSection
            socialProvidersSection
            
            if showAppSection {
                appSection
            }
            
            Spacer(minLength: 40)
        }
    }
    
    private var showSuggestedSection: Bool {
        !isForAuthentication && authManager.isAuthenticated
    }
    
    private var showProfileSection: Bool {
        !isForAuthentication && authManager.isAuthenticated && initialSection != .none
    }
    
    private var showAppSection: Bool {
        !isForAuthentication && authManager.isAuthenticated
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Authentication Handlers
    
    // Wallet connection is now handled by WalletConnectionView directly
    
    private func handleEmailAuthentication() {
        // Show email auth sheet
        showEmailAuth = true
    }
    
    private func handlePasskeyAuthentication() {
        // Initiate passkey authentication
        Task {
            do {
                try await authManager.authenticateWithPasskey()
                await MainActor.run {
                    isPresented = false
                }
                HapticManager.notification(.success)
            } catch {
                print("Passkey authentication failed: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
    
    private func handleAppleAuthentication() {
        // Initiate Apple Sign In
        Task {
            do {
                if authManager.isAuthenticated {
                    // Link Apple account to existing profile
                    try await authManager.linkAppleAccount()
                } else {
                    // New authentication
                    try await authManager.authenticateWithApple()
                }
                await MainActor.run {
                    isPresented = false
                }
                HapticManager.notification(.success)
            } catch {
                print("Apple authentication failed: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
    
    private func handleFarcasterAuthentication() {
        // Show Farcaster auth view
        showFarcasterAuth = true
    }
    
    private func handleOAuthProvider(_ provider: OAuthProviderInfo) {
        if provider.id == "farcaster" {
            // Handle Farcaster authentication separately
            handleFarcasterAuthentication()
        } else {
            selectedOAuthProvider = provider
            showOAuthFlow = true
        }
    }
    
    private func handleOAuthResult(provider: OAuthProviderInfo, result: Result<OAuthTokens, Error>) async {
        isProcessing = true
        
        do {
            switch result {
            case .success(let tokens):
                if isForAuthentication {
                    try await authManager.authenticateWithOAuth(
                        provider: provider.id,
                        tokens: OAuthTokenResponse(
                            accessToken: tokens.accessToken,
                            refreshToken: tokens.refreshToken,
                            idToken: tokens.idToken,
                            expiresIn: tokens.expiresIn,
                            provider: tokens.provider
                        )
                    )
                    
                    await MainActor.run {
                        isPresented = false
                        showOAuthFlow = false
                    }
                } else {
                    // Handle account linking using standardized OAuth flow
                    guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let viewController = await windowScene.windows.first?.rootViewController else {
                        throw AuthenticationError.unknown("Unable to present OAuth flow")
                    }
                    
                    // Use the standardized OAuth flow handler
                    try await authManager.handleOAuthFlow(
                        provider: provider.id,
                        presentingViewController: viewController
                    )
                    
                    await MainActor.run {
                        isPresented = false
                        showOAuthFlow = false
                    }
                }
                
            case .failure(let error):
                print("OAuth error: \(error)")
                await MainActor.run {
                    HapticManager.notification(.error)
                }
            }
        } catch {
            print("Authentication error: \(error)")
            await MainActor.run {
                HapticManager.notification(.error)
            }
        }
        
        isProcessing = false
    }
    
    private func createProfile(name: String) async {
        // Create the profile using the view model
        // This will automatically switch to the new profile
        await profileViewModel.createProfile(name: name)
        
        // Dismiss the add tray after successful creation
        await MainActor.run {
            isPresented = false
        }
        
        // Success feedback is already handled in createProfile
    }
    
    private func checkAvailableWallets() {
        // Check which WalletConnect-compatible apps are installed
        let potentialWallets: [WalletType] = [.rainbow, .trust, .argent, .gnosisSafe, .family, .phantom, .oneInch, .zerion, .imToken, .tokenPocket, .spot, .omni]
        var available: [WalletType] = []
        
        for walletType in potentialWallets {
            let scheme: String
            switch walletType {
            case .rainbow:
                scheme = "rainbow"
            case .trust:
                scheme = "trust"
            case .argent:
                scheme = "argent"
            case .gnosisSafe:
                scheme = "gnosissafe"
            case .family:
                scheme = "family"
            case .phantom:
                scheme = "phantom"
            case .oneInch:
                scheme = "oneinch"
            case .zerion:
                scheme = "zerion"
            case .imToken:
                scheme = "imtoken"
            case .tokenPocket:
                scheme = "tokenpocket"
            case .spot:
                scheme = "spot"
            case .omni:
                scheme = "omni"
            default:
                continue
            }
            
            if let url = URL(string: "\(scheme)://"),
               UIApplication.shared.canOpenURL(url) {
                available.append(walletType)
            }
        }
        
        availableWalletConnectWallets = available
    }
    
    // MARK: - View Components
    
    private var navigationBar: some View {
        HStack {
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color(white: 0.15))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    private var headerView: some View {
        Text(isForAuthentication ? "Connect to Interspace" : "Add to Interspace")
            .font(.system(.largeTitle, design: .rounded))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }
    
    @ViewBuilder
    private var suggestedOptionForSection: some View {
        switch initialSection {
        case .app:
            AddOptionRow(
                icon: "plus.app.fill",
                iconType: .system,
                title: "Add App",
                iconColor: .blue,
                isFirst: true,
                isLast: true
            ) {
                HapticManager.impact(.light)
                showAddApp = true
            }
            
        case .wallet:
            AddOptionRow(
                icon: "wallet.pass.fill",
                iconType: .system,
                title: "Link Wallet",
                iconColor: .orange,
                isFirst: true,
                isLast: true
            ) {
                HapticManager.impact(.light)
                selectedWalletType = .metamask
                showWalletAuthorization = true
            }
            
        default:
            AddOptionRow(
                icon: "person.crop.circle.badge.plus",
                iconType: .system,
                title: "Add Profile",
                iconColor: .green,
                isFirst: true,
                isLast: true
            ) {
                HapticManager.impact(.light)
                showProfileCreation = true
            }
        }
    }
    
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                suggestedOptionForSection
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
            )
            .padding(.horizontal, 20)
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Add Profile
                AddOptionRow(
                    icon: "person.crop.circle.badge.plus",
                    iconType: .system,
                    title: "Add Profile",
                    iconColor: .blue,
                    isFirst: true,
                    isLast: true
                ) {
                    HapticManager.impact(.light)
                    showProfileCreation = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
            )
            .padding(.horizontal, 20)
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isForAuthentication ? "Wallet" : "Account")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            walletOptionsContent
        }
    }
    
    private var walletOptionsContent: some View {
        VStack(spacing: 0) {
            // MetaMask
            AddOptionRow(
                icon: "metamask",
                iconType: .asset,
                title: "MetaMask",
                iconColor: .orange,
                isFirst: true,
                isLast: false
            ) {
                HapticManager.impact(.light)
                selectedWalletType = .metamask
                // Show authorization directly without intermediate tray
                DispatchQueue.main.async {
                    showWalletAuthorization = true
                }
            }
            
            Divider()
                .padding(.leading, 72)
            
            // Coinbase Wallet
            AddOptionRow(
                icon: "coinbase",
                iconType: .asset,
                title: "Coinbase Wallet",
                iconColor: .blue,
                isFirst: false,
                isLast: availableWalletConnectWallets.isEmpty
            ) {
                HapticManager.impact(.light)
                selectedWalletType = .coinbase
                // Show authorization directly without intermediate tray
                DispatchQueue.main.async {
                    showWalletAuthorization = true
                }
            }
            
            if !availableWalletConnectWallets.isEmpty {
                Divider()
                    .padding(.leading, 72)
            }
            
            // Add individual WalletConnect-compatible wallets
            ForEach(availableWalletConnectWallets.indices, id: \.self) { index in
                let walletType = availableWalletConnectWallets[index]
                Group {
                    if index > 0 {
                        Divider()
                            .padding(.leading, 72)
                    }
                    
                    AddOptionRow(
                        icon: walletType.systemIconName,
                        iconType: .system,
                        title: walletType.displayName,
                        iconColor: walletType.primaryColor,
                        isFirst: false,
                        isLast: index == availableWalletConnectWallets.count - 1
                    ) {
                        HapticManager.impact(.light)
                        selectedWalletType = walletType
                        DispatchQueue.main.async {
                            showWalletAuthorization = true
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.15))
        )
        .padding(.horizontal, 20)
    }
    
    private var authenticationMethodsSection: some View {
        VStack(spacing: 0) {
            // Email
            AddOptionRow(
                icon: "envelope.fill",
                iconType: .system,
                title: "Email",
                iconColor: .blue,
                isFirst: true,
                isLast: false
            ) {
                HapticManager.impact(.light)
                if isForAuthentication {
                    handleEmailAuthentication()
                } else {
                    showEmailAuth = true
                }
            }
            
            Divider()
                .padding(.leading, 72)
            
            // Passkey
            AddOptionRow(
                icon: "key.fill",
                iconType: .system,
                title: "Passkey",
                iconColor: .green,
                isFirst: false,
                isLast: false
            ) {
                HapticManager.impact(.light)
                if isForAuthentication {
                    handlePasskeyAuthentication()
                } else {
                    handlePasskeyLinking()
                }
            }
            
            Divider()
                .padding(.leading, 72)
            
            // Apple
            AddOptionRow(
                icon: "apple.logo",
                iconType: .system,
                title: "Apple",
                iconColor: .white,
                isFirst: false,
                isLast: true
            ) {
                HapticManager.impact(.light)
                // Apple Sign In doesn't need a separate sheet
                handleAppleAuthentication()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.15))
        )
        .padding(.horizontal, 20)
    }
    
    private var socialProvidersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Social")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            socialProvidersContent
        }
    }
    
    private var socialProvidersContent: some View {
        let nonAppleProviders = OAuthProviderInfo.providers.filter { $0.id != "apple" }
        
        return VStack(spacing: 0) {
            ForEach(Array(nonAppleProviders.enumerated()), id: \.element.id) { index, provider in
                Group {
                    if index > 0 {
                        Divider()
                            .padding(.leading, 72)
                    }
                    
                    AddOptionRow(
                        icon: provider.iconName,
                        iconType: .asset,
                        title: provider.displayName,
                        iconColor: provider.tintColor,
                        isFirst: index == 0,
                        isLast: index == nonAppleProviders.count - 1
                    ) {
                        HapticManager.impact(.light)
                        handleOAuthProvider(provider)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.15))
        )
        .padding(.horizontal, 20)
    }
    
    private var appSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Add App
                AddOptionRow(
                    icon: "square.grid.2x2",
                    iconType: .system,
                    title: "Add App",
                    iconColor: .orange,
                    isFirst: true,
                    isLast: true
                ) {
                    HapticManager.impact(.light)
                    showAddApp = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
            )
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Sheet Contents
    
    @ViewBuilder
    private var walletAuthorizationSheet: some View {
        if let walletType = selectedWalletType {
            if isForAuthentication {
                WalletConnectionView(
                    walletType: walletType,
                    viewModel: authViewModel ?? AuthViewModel(),
                    onComplete: {
                        isPresented = false
                    },
                    isForAuthentication: true
                )
            } else {
                WalletAuthorizationTray(
                    walletType: walletType,
                    onAuthorize: {
                        showWalletAuthorization = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showWalletConnection = true
                        }
                    },
                    onCancel: {
                        showWalletAuthorization = false
                        selectedWalletType = nil
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var walletConnectionSheet: some View {
        if let walletType = selectedWalletType {
            WalletConnectionView(
                walletType: walletType,
                viewModel: profileViewModel,
                onComplete: {
                    isPresented = false
                }
            )
        }
    }
    
    @ViewBuilder
    private var emailAuthSheet: some View {
        if isForAuthentication {
            EmailAuthenticationView(isPresented: $showEmailAuth)
                .onDisappear {
                    if authManager.isAuthenticated {
                        isPresented = false
                    }
                }
        } else {
            EmailLinkingView(isPresented: $showEmailAuth)
        }
    }
    
    private var passkeyAuthSheet: some View {
        PasskeyAuthenticationView(isPresented: $showPasskeyAuth) {
            if authManager.isAuthenticated {
                isPresented = false
            }
        }
    }
    
    private var addAppSheet: some View {
        AddAppView(viewModel: AppsViewModel())
            .background(Color.black.opacity(0.001))
            .background(Material.ultraThinMaterial)
            .preferredColorScheme(.dark)
    }
    
    private var profileCreationSheet: some View {
        ProfileCreationTray(isPresented: $showProfileCreation) { profileName in
            Task {
                await createProfile(name: profileName)
            }
        }
    }
    
    @ViewBuilder
    private var oauthFlowSheet: some View {
        if let provider = selectedOAuthProvider {
            OAuthFlowView(provider: provider, isForAuthentication: isForAuthentication) { result in
                Task {
                    await handleOAuthResult(provider: provider, result: result)
                }
            }
        }
    }
    
    private var farcasterAuthSheet: some View {
        FarcasterAuthView(isPresented: $showFarcasterAuth) { authResponse in
            Task { @MainActor in
                do {
                    if isForAuthentication {
                        // Authenticate with Farcaster
                        try await authManager.authenticateWithFarcaster(
                            message: authResponse.message,
                            signature: authResponse.signature,
                            fid: authResponse.fid
                        )
                    } else {
                        // Link Farcaster account
                        try await authManager.linkFarcasterAccount(
                            message: authResponse.message,
                            signature: authResponse.signature,
                            fid: authResponse.fid
                        )
                    }
                    isPresented = false
                    HapticManager.notification(.success)
                } catch {
                    print("Farcaster auth error: \(error)")
                    HapticManager.notification(.error)
                }
            }
        }
    }
    
    private var processingOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
    }
    
    // MARK: - Helper Methods
    
    private func onAppearActions() {
        Task {
            if !isForAuthentication {
                await profileViewModel.loadProfile()
            }
        }
        checkAvailableWallets()
    }
    
    private func onAuthenticationChange(_ newValue: Bool) {
        if isForAuthentication && newValue {
            isPresented = false
        }
    }
    
    private func handlePasskeyLinking() {
        Task {
            isProcessing = true
            defer { 
                Task { @MainActor in
                    isProcessing = false
                }
            }
            
            do {
                // Register a new passkey for linking
                _ = try await PasskeyService.shared.registerPasskeyForLinking()
                
                // Refresh profile data
                await profileViewModel.refreshProfile()
                
                // Close the tray
                await MainActor.run {
                    isPresented = false
                }
                
                HapticManager.notification(.success)
            } catch {
                print("🔴 Passkey linking failed: \(error)")
                await MainActor.run {
                    // Show error alert or handle error appropriately
                    HapticManager.notification(.error)
                }
            }
        }
    }
}

// MARK: - Add Option Row

struct AddOptionRow: View {
    let icon: String
    let iconType: IconType
    let title: String
    let iconColor: Color
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon - Apple style with rounded square
                Group {
                    if iconType == .system {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(iconColor)
                            )
                    } else {
                        // Asset icons - check if it's an OAuth provider icon
                        if icon.hasSuffix("_icon") {
                            // Extract provider ID from icon name (e.g., "google_icon" -> "google")
                            let providerId = String(icon.dropLast(5))
                            OAuthProviderIcon(provider: providerId, size: 32)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(iconColor)
                                )
                        } else {
                            // Regular asset icons (MetaMask, Coinbase)
                            Image(icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(white: 0.15))
                                )
                        }
                    }
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .frame(height: 44) // Apple standard row height
            .contentShape(Rectangle()) // Ensures entire row is clickable
        }
        .buttonStyle(.plain) // Use .plain instead of PlainButtonStyle()
    }
}

// MARK: - Wallet Authorization Tray

struct WalletAuthorizationTray: View {
    let walletType: WalletType
    let onAuthorize: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Wallet Icon
            Group {
                if walletType == .metamask {
                    Image("metamask")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else if walletType == .coinbase {
                    Image("coinbase")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                }
            }
            .padding(.top, 32)
            
            // Title
            Text("Connect \(walletType.displayName)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            
            // Authorize Button
            Button(action: {
                HapticManager.impact(.medium)
                onAuthorize()
            }) {
                Text("Authorize")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(walletType.primaryColor)
                    )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(320)])
        .background(Color.black.opacity(0.001))
        .background(Material.regularMaterial)
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Previous Cards Row

struct PreviousCardsRow: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with loading spinner
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.2))
                        .frame(width: 56, height: 40)
                    
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                Text("Previous Cards")
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(0.8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Wallet Option Row V2

enum IconType {
    case system
    case asset
}

struct WalletOptionRowV2: View {
    let icon: String
    let iconType: IconType
    let title: String
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackgroundColor)
                        .frame(width: 56, height: 40)
                    
                    if iconType == .system {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(iconColor)
                    } else {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    }
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconBackgroundColor: Color {
        switch title {
        case "MetaMask":
            return Color.orange.opacity(0.2)
        case "Coinbase Wallet":
            return Color.blue.opacity(0.2)
        default:
            return Color.purple.opacity(0.2)
        }
    }
    
    private var iconColor: Color {
        switch title {
        case "WalletConnect":
            return .purple
        default:
            return .white
        }
    }
}

// MARK: - Social Option Row

struct SocialOptionRow: View {
    let provider: SocialProvider
    let title: String
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(provider.socialColor.opacity(0.2))
                        .frame(width: 56, height: 40)
                    
                    Image(systemName: provider.systemIcon)
                        .font(.system(size: 24))
                        .foregroundColor(provider.socialColor)
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Social Provider Extension

extension SocialProvider {
    var systemIcon: String {
        switch self {
        case .google:
            return "g.circle.fill"
        case .apple:
            return "apple.logo"
        case .twitter:
            return "bird.fill"
        case .telegram:
            return "paperplane.fill"
        case .farcaster:
            return "f.circle.fill"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var socialColor: Color {
        switch self {
        case .google:
            return .red
        case .apple:
            return .white
        case .twitter:
            return .blue
        case .telegram:
            return .blue
        case .farcaster:
            return .purple
        case .github:
            return .gray
        }
    }
}

// MARK: - OAuth Flow View
struct OAuthFlowView: View {
    let provider: OAuthProviderInfo
    let isForAuthentication: Bool
    let completion: (Result<OAuthTokens, Error>) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // OAuth web view or native flow would go here
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Connecting to \(provider.displayName)...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Sign in with \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            initiateOAuthFlow()
        }
    }
    
    private func initiateOAuthFlow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(AuthenticationError.unknown("Unable to present OAuth flow")))
            return
        }
        
        OAuthProviderService.shared.authenticate(
            withProviderNamed: provider.id,
            presentingViewController: viewController
        ) { result in
            completion(result)
        }
    }
}

// MARK: - Preview

struct UniversalAddTray_Previews: PreviewProvider {
    static var previews: some View {
        UniversalAddTray(isPresented: Binding.constant(true), initialSection: AddSection.none)
            .preferredColorScheme(.dark)
    }
}
