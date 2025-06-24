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
    // Removed showWalletConnectionTray - using direct authorization
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar to avoid black background
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header - iOS 18 Apple style
                    Text(isForAuthentication ? "Connect to Interspace" : "Add to Interspace")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    
                    // Profile Section - only show when authenticated and not in auth mode
                    if !isForAuthentication && authManager.isAuthenticated {
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
                        
                    // Account Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(isForAuthentication ? "Wallet" : "Account")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
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
                                isLast: false
                            ) {
                                HapticManager.impact(.light)
                                selectedWalletType = .coinbase
                                // Show authorization directly without intermediate tray
                                DispatchQueue.main.async {
                                    showWalletAuthorization = true
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                            
                            // WalletConnect
                            AddOptionRow(
                                icon: "link.circle.fill",
                                iconType: .system,
                                title: "WalletConnect",
                                iconColor: .purple,
                                isFirst: false,
                                isLast: true
                            ) {
                                HapticManager.impact(.light)
                                selectedWalletType = .walletConnect
                                // Show authorization directly without intermediate tray
                                DispatchQueue.main.async {
                                    showWalletAuthorization = true
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.15))
                        )
                        .padding(.horizontal, 20)
                    }
                        
                    // Authentication Methods (with visual gap)
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
                                showPasskeyAuth = true
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
                            if isForAuthentication {
                                handleAppleAuthentication()
                            } else {
                                showAppleSignIn = true
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.15))
                    )
                    .padding(.horizontal, 20)
                    
                    // App Section - only show when authenticated and not in auth mode
                    if !isForAuthentication && authManager.isAuthenticated {
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
                        
                        Spacer(minLength: 40)
                }
            }
        }
        .background(Color.black.opacity(0.001))
        .background(Material.regularMaterial)
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showWalletAuthorization) {
            if let walletType = selectedWalletType {
                if isForAuthentication {
                    // For authentication, use WalletConnectionView with AuthViewModel
                    WalletConnectionView(
                        walletType: walletType,
                        viewModel: authViewModel ?? AuthViewModel(),
                        onComplete: {
                            isPresented = false
                        },
                        isForAuthentication: true
                    )
                } else {
                    // For account linking, show authorization tray first
                    WalletAuthorizationTray(
                        walletType: walletType,
                        onAuthorize: {
                            showWalletAuthorization = false
                            // Small delay to ensure smooth transition
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
        .onChange(of: showWalletAuthorization) { newValue in
            if newValue && selectedWalletType == nil {
                // This should never happen, but handle it gracefully
                showWalletAuthorization = false
            }
        }
        .sheet(isPresented: $showWalletConnection) {
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
        // Removed WalletConnectionTray - now using direct wallet authorization
        .sheet(isPresented: $showEmailAuth) {
            if isForAuthentication {
                EmailAuthenticationView(isPresented: $showEmailAuth)
                    .onDisappear {
                        // Check if authentication succeeded
                        if authManager.isAuthenticated {
                            isPresented = false
                        }
                    }
            } else {
                EmailLinkingView(isPresented: $showEmailAuth)
            }
        }
        .sheet(isPresented: $showPasskeyAuth) {
            // TODO: Implement passkey authentication
            Text("Passkey Authentication")
                .background(Color.black.opacity(0.001))
                .background(Material.ultraThinMaterial)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAppleSignIn) {
            // TODO: Implement Apple Sign In
            Text("Apple Sign In")
                .background(Color.black.opacity(0.001))
                .background(Material.ultraThinMaterial)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAddApp) {
            AddAppView(viewModel: AppsViewModel())
                .background(Color.black.opacity(0.001))
                .background(Material.ultraThinMaterial)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationTray(isPresented: $showProfileCreation) { profileName in
                Task {
                    await createProfile(name: profileName)
                }
            }
        }
        .onAppear {
            Task {
                if !isForAuthentication {
                    await profileViewModel.loadProfile()
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            // Close the tray when authentication succeeds
            if isForAuthentication && newValue {
                isPresented = false
            }
        }
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
                try await authManager.authenticateWithApple()
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
    
    private func createProfile(name: String) async {
        // Create the profile using the view model
        await profileViewModel.createProfile(name: name)
        
        // Reload profiles to reflect the change
        await profileViewModel.loadProfiles()
        
        // Dismiss the add tray after successful creation
        await MainActor.run {
            isPresented = false
        }
        
        // Show success feedback
        HapticManager.notification(.success)
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
                        // Asset icons (MetaMask, Coinbase)
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

// MARK: - Preview

struct UniversalAddTray_Previews: PreviewProvider {
    static var previews: some View {
        UniversalAddTray(isPresented: Binding.constant(true), initialSection: AddSection.none)
            .preferredColorScheme(.dark)
    }
}
