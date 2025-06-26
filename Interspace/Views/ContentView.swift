import SwiftUI

struct ContentView: View {
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    @State private var hasTrackedLaunch = false
    @State private var showAuthExpiry = false
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch sessionCoordinator.sessionState {
                case .loading:
                    LoadingView()
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    
                case .unauthenticated:
                    AuthView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.05)),
                            removal: .opacity
                        ))
                    
                case .needsProfile:
                    OnboardingView()
                        .transition(.opacity)
                    
                case .authenticated:
                    ZStack {
                        Color.clear // Invisible background to force full size
                        MainTabView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Force full size
                            .background(Color.cyan.opacity(0.2)) // DEBUG: Cyan for MainTabView
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    
                case .error:
                    ErrorView()
                        .transition(.opacity)
                        
                case .locked:
                    LockedView()
                        .transition(.opacity)
                }
            }
            
            // Auth expiry overlay - smooth fade effect
            if showAuthExpiry {
                AuthExpiryOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionCoordinator.sessionState)
        .animation(.easeInOut(duration: 0.3), value: showAuthExpiry)
        .onAppear {
            if !hasTrackedLaunch {
                hasTrackedLaunch = true
                AppLaunchPerformance.shared.markFirstContentView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationExpired)) { _ in
            // Show auth expiry overlay briefly before transitioning
            withAnimation(.easeIn(duration: 0.2)) {
                showAuthExpiry = true
            }
            
            // Hide overlay after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showAuthExpiry = false
                }
            }
        }
        .alert("Session Error", isPresented: $sessionCoordinator.showError) {
            Button("OK") {
                sessionCoordinator.dismissError()
            }
        } message: {
            if let error = sessionCoordinator.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(DesignTokens.Colors.error)
                
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Something went wrong")
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if let error = sessionCoordinator.error {
                        Text(error.localizedDescription)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button("Sign Out") {
                        Task {
                            await sessionCoordinator.logout()
                        }
                    }
                    .secondaryButton()
                    
                    Button("Try Again") {
                        Task {
                            await sessionCoordinator.loadUserSession()
                        }
                    }
                    .primaryButton()
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

// MARK: - Locked View

struct LockedView: View {
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    
    var body: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(DesignTokens.Colors.primary)
                
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Session Locked")
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Your session has been locked for security")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Unlock with Face ID") {
                    Task {
                        await sessionCoordinator.verifyBiometricAccess()
                    }
                }
                .primaryButton()
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

// MARK: - Auth Expiry Overlay

struct AuthExpiryOverlay: View {
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .blur(radius: 10)
            
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("Session Expired")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(.white)
                
                Text("Please sign in again")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(DesignTokens.Spacing.xl)
            .background(
              RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(opacity)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                opacity = 1
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject private var sessionCoordinator = SessionCoordinator.shared
    @State private var profileName = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header section - flows from top
                    VStack(spacing: DesignTokens.Spacing.iOSAuthHeaderSpacing) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(DesignTokens.Colors.primary)
                        
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Text("Create Your First Profile")
                                .font(DesignTokens.Typography.headlineLarge)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Profiles help you organize your crypto accounts into smart contexts like Trading, Gaming, or DeFi")
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.iOSAuthContentSpacing)
                    .padding(.horizontal, DesignTokens.Spacing.iOSScreenMargin)
                    
                    Spacer()
                    
                    // Bottom form section
                    VStack(spacing: DesignTokens.Spacing.md) {
                        TextField("Profile name", text: $profileName)
                            .textFieldStyle(LiquidGlassTextFieldStyle())
                        
                        Button(action: createProfile) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isCreating ? "Creating..." : "Create Profile")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .primaryButton()
                        .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.iOSScreenMargin)
                    .padding(.bottom, DesignTokens.Spacing.iOSAuthContentSpacing)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(sessionCoordinator.$error) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func createProfile() {
        guard !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        Task {
            await sessionCoordinator.createInitialProfile(name: profileName.trimmingCharacters(in: .whitespacesAndNewlines))
            isCreating = false
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .apps {
        didSet {
            if oldValue != selectedTab {
                HapticManager.impact(.light)
            }
        }
    }
    
    enum Tab: String, CaseIterable {
        case apps = "Apps"
        case profile = "Profile"
        case wallet = "Wallet"
        
        var icon: String {
            switch self {
            case .apps:
                return "square.grid.3x3"
            case .profile:
                return "person.circle"
            case .wallet:
                return "creditcard.circle"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .apps:
                return "square.grid.3x3.fill"
            case .profile:
                return "person.circle.fill"
            case .wallet:
                return "creditcard.circle.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Apps Tab
            NavigationStack {
                AppsView()
            }
            .tabItem {
                Label("Apps", systemImage: selectedTab == .apps ? Tab.apps.selectedIcon : Tab.apps.icon)
            }
            .tag(Tab.apps)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: selectedTab == .profile ? Tab.profile.selectedIcon : Tab.profile.icon)
            }
            .tag(Tab.profile)
            
            // Wallet Tab
            NavigationStack {
                WalletViewRedesigned()
            }
            .tabItem {
                Label("Wallet", systemImage: selectedTab == .wallet ? Tab.wallet.selectedIcon : Tab.wallet.icon)
            }
            .tag(Tab.wallet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Force TabView to fill
        .accentColor(DesignTokens.Colors.primary)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
        .preferredColorScheme(.dark) // Consistent dark mode
        .onAppear {
            // Configure tab bar for native iOS appearance
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithDefaultBackground()
            tabAppearance.backgroundColor = UIColor(DesignTokens.Colors.backgroundPrimary)
            
            // Configure tab bar item appearance
            tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(DesignTokens.Colors.textSecondary)
            tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(DesignTokens.Colors.textSecondary),
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(DesignTokens.Colors.primary)
            tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(DesignTokens.Colors.primary),
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
            
            // Configure navigation bar for native Apple dark mode look
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithDefaultBackground()
            navAppearance.backgroundColor = UIColor.black
            navAppearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 34, weight: .bold)
            ]
            
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
            UINavigationBar.appearance().tintColor = UIColor.white
            UINavigationBar.appearance().prefersLargeTitles = true
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
