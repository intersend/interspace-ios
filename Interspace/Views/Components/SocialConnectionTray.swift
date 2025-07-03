import SwiftUI
import AuthenticationServices

struct SocialConnectionTray: View {
    @Binding var isPresented: Bool
    @ObservedObject private var authManager = AuthenticationManagerV2.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connect Social")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text("Sign in with your social accounts for a seamless experience")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Social Options Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Options")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // Google Sign In
                                SocialOptionButton(
                                    provider: .google,
                                    title: "Continue with Google",
                                    subtitle: "Sign in with your Google account",
                                    isFirst: true,
                                    isLast: false,
                                    action: handleGoogleSignIn
                                )
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // Apple Sign In
                                AppleSignInRow()
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // Passkey
                                SocialOptionButton(
                                    provider: nil,
                                    icon: "faceid",
                                    iconColor: .green,
                                    title: "Sign in with Passkey",
                                    subtitle: "Use Face ID or Touch ID",
                                    isFirst: false,
                                    isLast: true,
                                    action: handlePasskeySignIn
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Additional Providers Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("More Providers")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // Twitter/X - OAuth implementation available
                                SocialOptionButton(
                                    provider: .twitter,
                                    title: "Twitter / X",
                                    subtitle: "Connect with Twitter",
                                    isFirst: true,
                                    isLast: false
                                ) {
                                    handleOAuthProvider("twitter")
                                }
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // GitHub - OAuth implementation available
                                SocialOptionButton(
                                    provider: .github,
                                    title: "GitHub",
                                    subtitle: "Connect with GitHub",
                                    isFirst: false,
                                    isLast: false
                                ) {
                                    handleOAuthProvider("github")
                                }
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // Discord - OAuth implementation available
                                SocialOptionButton(
                                    provider: nil,
                                    icon: "discord",
                                    iconColor: Color(red: 114/255, green: 137/255, blue: 218/255),
                                    title: "Discord",
                                    subtitle: "Connect with Discord",
                                    isFirst: false,
                                    isLast: false
                                ) {
                                    handleOAuthProvider("discord")
                                }
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // Spotify - OAuth implementation available
                                SocialOptionButton(
                                    provider: nil,
                                    icon: "music.note",
                                    iconColor: Color(red: 30/255, green: 215/255, blue: 96/255),
                                    title: "Spotify",
                                    subtitle: "Connect with Spotify",
                                    isFirst: false,
                                    isLast: true
                                ) {
                                    handleOAuthProvider("spotify")
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Loading Overlay
                if isLoading {
                    LiquidGlassLoadingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .background(Circle().fill(DesignTokens.Colors.backgroundSecondary))
                    }
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Social Sign In Methods
    
    private func handleGoogleSignIn() {
        isLoading = true
        Task {
            do {
                try await authManager.authenticateWithGoogle()
                await MainActor.run {
                    isLoading = false
                    HapticManager.notification(.success)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Don't show error for user cancellation (empty error message)
                    if !error.localizedDescription.isEmpty {
                        errorMessage = error.localizedDescription
                        showError = true
                        HapticManager.notification(.error)
                    }
                }
            }
        }
    }
    
    private func handlePasskeySignIn() {
        isLoading = true
        Task {
            do {
                try await authManager.authenticateWithPasskey()
                await MainActor.run {
                    isLoading = false
                    HapticManager.notification(.success)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.notification(.error)
                }
            }
        }
    }
    
    private func handleOAuthProvider(_ providerName: String) {
        // Use the OAuthProviderService to get provider configuration
        guard let provider = OAuthProviderService.shared.provider(for: providerName) else {
            errorMessage = "Provider not configured"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Get presenting view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let viewController = windowScene.windows.first?.rootViewController else {
                    throw AuthenticationError.unknown("Unable to present OAuth flow")
                }
                
                let tokens = try await withCheckedThrowingContinuation { continuation in
                    OAuthProviderService.shared.authenticate(
                        with: provider,
                        presentingViewController: viewController
                    ) { result in
                        continuation.resume(with: result)
                    }
                }
                
                // Use the tokens to authenticate
                try await authManager.authenticateWithOAuth(
                    provider: providerName,
                    tokens: OAuthTokenResponse(
                        accessToken: tokens.accessToken,
                        refreshToken: tokens.refreshToken,
                        idToken: tokens.idToken,
                        expiresIn: tokens.expiresIn,
                        provider: tokens.provider
                    )
                )
                
                await MainActor.run {
                    isLoading = false
                    HapticManager.notification(.success)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.notification(.error)
                }
            }
        }
    }
}

// MARK: - Social Option Button

struct SocialOptionButton: View {
    let provider: SocialProvider?
    var icon: String? = nil
    var iconColor: Color? = nil
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    private var displayIcon: String {
        if let icon = icon {
            return icon
        } else if let provider = provider {
            return socialIcon(for: provider)
        } else {
            return "questionmark.circle"
        }
    }
    
    private var displayColor: Color {
        if let color = iconColor {
            return color
        } else if let provider = provider {
            return socialColor(for: provider)
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(displayColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: displayIcon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(displayColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func socialIcon(for provider: SocialProvider) -> String {
        switch provider {
        case .google:
            return "g.circle.fill"
        case .apple:
            return "apple.logo"
        case .telegram:
            return "paperplane.fill"
        case .farcaster:
            return "f.square.fill"
        case .twitter:
            return "bird.fill"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    private func socialColor(for provider: SocialProvider) -> Color {
        switch provider {
        case .google:
            return .red
        case .apple:
            return .black
        case .telegram:
            return .blue
        case .farcaster:
            return .purple
        case .twitter:
            return .blue
        case .github:
            return .black
        }
    }
}

// MARK: - Apple Sign In Row

struct AppleSignInRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                handleAppleSignIn(result: result)
            }
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        throw AuthenticationError.invalidCredentials
                    }
                    
                    let socialProfile = SocialProfile(
                        id: appleIDCredential.user,
                        email: appleIDCredential.email,
                        name: appleIDCredential.fullName?.formatted(),
                        picture: nil
                    )
                    
                    let config = WalletConnectionConfig(
                        strategy: .apple,
                        walletType: nil,
                        email: appleIDCredential.email,
                        verificationCode: nil,
                        walletAddress: nil,
                        signature: appleIDCredential.user,
                        message: nil,
                        socialProvider: "apple",
                        socialProfile: socialProfile,
                        oauthCode: nil,
                        idToken: nil,
                        accessToken: nil,
                        shopDomain: nil
                    )
                    
                    try await AuthenticationManagerV2.shared.authenticate(with: config)
                    HapticManager.notification(.success)
                    
                case .failure(let error):
                    throw AuthenticationError.unknown(error.localizedDescription)
                }
            } catch {
                print("Apple Sign In error: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
}

// MARK: - Coming Soon Social Row

struct ComingSoonSocialRow: View {
    let provider: SocialProvider
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Colors.textTertiary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: socialIcon(for: provider))
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary.opacity(0.7))
            }
            
            Spacer()
            
            Text("Soon")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.textTertiary.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(0.6)
    }
    
    private func socialIcon(for provider: SocialProvider) -> String {
        switch provider {
        case .google:
            return "g.circle.fill"
        case .apple:
            return "apple.logo"
        case .telegram:
            return "paperplane.fill"
        case .farcaster:
            return "f.square.fill"
        case .twitter:
            return "bird.fill"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Preview

struct SocialConnectionTray_Previews: PreviewProvider {
    static var previews: some View {
        SocialConnectionTray(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}