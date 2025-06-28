import SwiftUI

struct UniversalAddTrayV2: View {
    @Binding var isPresented: Bool
    let isForAuthentication: Bool
    var authViewModel: AuthViewModel? = nil
    
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    @StateObject private var localAuthViewModel = AuthViewModel()
    
    @State private var selectedProvider: OAuthProviderInfo?
    @State private var showOAuthFlow = false
    @State private var showEmailAuth = false
    @State private var showPasskeyAuth = false
    @State private var showWalletAuth = false
    @State private var selectedWalletType: WalletType?
    @State private var showAddApp = false
    @State private var showProfileCreation = false
    @State private var isProcessing = false
    
    private let oauthService = OAuthProviderService.shared
    
    var body: some View {
        LiquidGlassSheet(isPresented: $isPresented) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(isForAuthentication ? "Connect to Interspace" : "Add Account")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Choose how you'd like to connect")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Primary Options
                VStack(spacing: 12) {
                    // Email
                    PrimaryOptionButton(
                        icon: "envelope.fill",
                        title: "Continue with Email",
                        subtitle: "Sign in with verification code",
                        tint: .blue
                    ) {
                        showEmailAuth = true
                    }
                    
                    // Wallet
                    PrimaryOptionButton(
                        icon: "wallet.pass.fill",
                        title: "Connect Wallet",
                        subtitle: "MetaMask, Coinbase & more",
                        tint: .orange
                    ) {
                        showWalletAuth = true
                    }
                    
                    // Passkey
                    if #available(iOS 16.0, *) {
                        PrimaryOptionButton(
                            icon: "person.badge.key.fill",
                            title: "Use Passkey",
                            subtitle: "Biometric authentication",
                            tint: .green
                        ) {
                            showPasskeyAuth = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    
                    Text("OR")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
                
                // OAuth Providers
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(OAuthProviderInfo.providers, id: \.id) { provider in
                            OAuthProviderButton(provider: provider) {
                                handleOAuthProvider(provider)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 400)
                
                // App & Profile Section (only when authenticated)
                if !isForAuthentication && authManager.isAuthenticated {
                    VStack(spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 12) {
                            // Add Profile
                            SecondaryActionButton(
                                icon: "person.crop.circle.badge.plus",
                                title: "Add Profile"
                            ) {
                                showProfileCreation = true
                            }
                            
                            // Add App
                            SecondaryActionButton(
                                icon: "square.stack.3d.up.fill",
                                title: "Add App"
                            ) {
                                showAddApp = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showEmailAuth) {
            if isForAuthentication {
                EmailAuthenticationView(viewModel: authViewModel ?? localAuthViewModel) {
                    isPresented = false
                }
            } else {
                EmailLinkingView()
            }
        }
        .sheet(isPresented: $showWalletAuth) {
            WalletSelectionView(isForAuthentication: isForAuthentication) { walletType in
                selectedWalletType = walletType
                showWalletAuth = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let walletType = selectedWalletType {
                        if isForAuthentication {
                            // Show wallet connection for auth
                            // This would trigger the wallet connection flow
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPasskeyAuth) {
            if #available(iOS 16.0, *) {
                PasskeyAuthView(isForAuthentication: isForAuthentication) {
                    isPresented = false
                }
            }
        }
        .sheet(isPresented: $showOAuthFlow) {
            if let provider = selectedProvider {
                OAuthFlowView(provider: provider, isForAuthentication: isForAuthentication) { result in
                    Task {
                        await handleOAuthResult(provider: provider, result: result)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileCreation) {
            CreateProfileView()
        }
        .sheet(isPresented: $showAddApp) {
            AddAppView()
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
            }
        }
    }
    
    private func handleOAuthProvider(_ provider: OAuthProviderInfo) {
        HapticManager.impact(.light)
        selectedProvider = provider
        showOAuthFlow = true
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
                    // Handle account linking
                    try await authManager.linkAccount(
                        type: .social,
                        identifier: "", // Will be determined by backend
                        provider: provider.id
                    )
                    
                    await MainActor.run {
                        isPresented = false
                        showOAuthFlow = false
                    }
                }
                
            case .failure(let error):
                print("OAuth error: \(error)")
                // Show error to user
            }
        } catch {
            print("Authentication error: \(error)")
            // Show error to user
        }
        
        isProcessing = false
    }
}

// MARK: - Primary Option Button
struct PrimaryOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon background
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Secondary Action Button
struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
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
        guard let provider = OAuthProviderService.shared.provider(for: provider.id) else {
            completion(.failure(AuthenticationError.unknown("Provider not configured")))
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(AuthenticationError.unknown("Unable to present OAuth flow")))
            return
        }
        
        OAuthProviderService.shared.authenticate(
            with: provider,
            presentingViewController: viewController
        ) { result in
            completion(result)
        }
    }
}

// MARK: - Wallet Selection View
struct WalletSelectionView: View {
    let isForAuthentication: Bool
    let onSelect: (WalletType) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WalletType.allCases, id: \.self) { walletType in
                    Button {
                        onSelect(walletType)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: walletType.systemIconName)
                                .font(.system(size: 20))
                                .foregroundColor(walletType.primaryColor)
                                .frame(width: 32)
                            
                            Text(walletType.displayName)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}