import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @EnvironmentObject var authManager: AuthenticationManagerV2
    
    // Sheet states
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    @State private var showUniversalAddTray = false
    @State private var showProfileSwitcher = false
    @State private var showProfileDetail = false
    @State private var selectedAccount: LinkedAccount?
    @State private var selectedSocialAccount: SocialAccount?
    @State private var selectedEmailAccount: AccountV2?
    
    // UI states
    @State private var isAddressHidden = false
    
    @Namespace private var profileNamespace
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            // Profile Header Section
            profileHeaderSection
            
            // Show loading indicator during profile operations
            if viewModel.isLoading && viewModel.linkedAccounts.isEmpty && viewModel.socialAccounts.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.vertical, 40)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            } else if viewModel.linkedAccounts.isEmpty && viewModel.socialAccounts.isEmpty {
                // Only show empty state if not loading
                emptyStateView
            } else {
                // Linked Wallets Section
                if !viewModel.linkedAccounts.isEmpty {
                    linkedWalletsSection
                }
                
                // Social Accounts Section
                if !viewModel.socialAccounts.isEmpty {
                    socialAccountsSection
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .refreshable {
            await viewModel.refreshProfile()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                StandardToolbarButtons(
                    showUniversalAddTray: $showUniversalAddTray,
                    showAbout: $showAbout,
                    showSecurity: $showSecurity,
                    showNotifications: $showNotifications,
                    initialSection: .none
                )
            }
        }
        .preferredColorScheme(.dark) // iOS 26 Liquid Glass is optimized for dark mode
        .sheet(isPresented: $showAbout) {
            ProfileAboutView()
        }
        .sheet(isPresented: $showSecurity) {
            ProfileSecurityView()
        }
        .sheet(isPresented: $showNotifications) {
            ProfileNotificationsView()
        }
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(isPresented: $showUniversalAddTray, initialSection: .none)
        }
        .sheet(isPresented: $showProfileDetail) {
            ProfileDetailView(isAddressHidden: $isAddressHidden)
        }
        .sheet(isPresented: $showProfileSwitcher) {
            NavigationStack {
                ProfileSwitcherView(viewModel: viewModel)
            }
        }
        .sheet(item: $selectedAccount) { account in
            AccountDetailView(account: account, viewModel: viewModel)
        }
        .sheet(item: $selectedSocialAccount) { account in
            SocialAccountDetailView(account: account, viewModel: viewModel)
        }
        .sheet(item: $selectedEmailAccount) { account in
            AccountDetailViewV2(account: account, viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        .onAppear {
            Task {
                print("🔵 ProfileView appeared - loading profile data")
                await viewModel.loadProfile()
                
                // Debug social accounts
                print("🔵 ProfileView - Social accounts count: \(viewModel.socialAccounts.count)")
                for account in viewModel.socialAccounts {
                    print("  - \(account.provider.rawValue): \(account.displayName ?? "N/A")")
                }
            }
        }
        .onChange(of: sessionCoordinator.activeProfile?.id) { _ in
            // Reload profile when active profile changes
            Task {
                print("🔵 ProfileView - Active profile changed, reloading...")
                await viewModel.loadProfile()
            }
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        Section {
            // Profile Row
            Button(action: {
                HapticManager.impact(.light)
                showProfileDetail = true
            }) {
                HStack(spacing: 16) {
                    // Profile Icon - Use viewModel's activeProfile as fallback
                    if let profile = sessionCoordinator.activeProfile ?? viewModel.activeProfile {
                        ProfileIconGenerator.generateIcon(for: profile.id, size: 60)
                    } else {
                        // Default icon when no profile is available
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Profile Name - Use viewModel's activeProfile as fallback
                        Text(sessionCoordinator.activeProfile?.name ?? viewModel.activeProfile?.name ?? "Profile")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // Wallet Address (one line)
                        if let address = sessionCoordinator.activeProfile?.sessionWalletAddress ?? viewModel.activeProfile?.sessionWalletAddress {
                            Text(isAddressHidden ? maskedAddress(address) : address)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Sign in on Other Profiles
            Button(action: {
                HapticManager.impact(.light)
                showProfileSwitcher = true
            }) {
                HStack {
                    Label("My Profiles", systemImage: "person.2")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Linked Accounts Section
    
    private var linkedWalletsSection: some View {
        Section(header: Text("LINKED ACCOUNTS")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gray)) {
            ForEach(viewModel.linkedAccounts) { account in
                Button(action: {
                    selectedAccount = account
                }) {
                    LinkedAccountRow(account: account, isAddressHidden: isAddressHidden)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Email Accounts Section
    
    private var emailAccountsSection: some View {
        Section(header: Text("EMAIL ACCOUNTS")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gray)) {
            ForEach(viewModel.emailAccounts) { account in
                Button(action: {
                    selectedEmailAccount = account
                }) {
                    HStack(spacing: 16) {
                        // Email Icon with background circle
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                            )
                        
                        // Email address
                        Text(account.identifier)
                            .font(.body)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Social Accounts Section
    
    private var socialAccountsSection: some View {
        Section(header: Text("SOCIAL ACCOUNTS")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gray)) {
            ForEach(viewModel.socialAccounts) { account in
                Button(action: {
                    selectedSocialAccount = account
                }) {
                    SocialAccountRow(account: account)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                
                Text("No accounts connected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                
                Text("Add wallets and social accounts to get started")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    // MARK: - Helper Methods
    
    private func maskedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)•••••\(suffix)"
    }
}

// MARK: - Wallet Account Row

struct LinkedAccountRow: View {
    let account: LinkedAccount
    let isAddressHidden: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Account Icon
            Group {
                switch account.authStrategy {
                case "wallet":
                    Image(walletIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                case "email":
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                        )
                case "social":
                    Image(systemName: socialIcon)
                        .font(.system(size: 20))
                        .foregroundColor(socialColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(socialColor.opacity(0.15))
                        )
                default:
                    Image(systemName: "link")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.displayName)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    if account.isPrimary {
                        Text("PRIMARY")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.2))
                            )
                    }
                }
                
                Text(isAddressHidden && account.authStrategy == "wallet" ? maskedAddress(account.address) : account.displayIdentifier)
                    .font(.system(size: 13, design: account.authStrategy == "wallet" ? .monospaced : .default))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
    
    private var walletIcon: String {
        switch WalletType(rawValue: account.walletType ?? "") {
        case .metamask:
            return "metamask"
        case .coinbase:
            return "coinbase"
        default:
            return "wallet.pass"
        }
    }
    
    private var socialIcon: String {
        switch account.walletType?.lowercased() {
        case "apple":
            return "applelogo"
        case "google":
            return "g.circle"
        case "facebook":
            return "f.circle"
        case "twitter", "x":
            return "x.circle"
        default:
            return "person.circle"
        }
    }
    
    private var socialColor: Color {
        switch account.walletType?.lowercased() {
        case "apple":
            return .white
        case "google":
            return .red
        case "facebook":
            return .blue
        case "twitter", "x":
            return .white
        default:
            return .gray
        }
    }
    
    private func maskedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)••••••\(suffix)"
    }
}

// MARK: - Social Account Row

struct SocialAccountRow: View {
    let account: SocialAccount
    
    var body: some View {
        HStack(spacing: 16) {
            // Social Icon
            Image(systemName: socialIcon)
                .font(.system(size: 20))
                .foregroundColor(socialColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(socialColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName ?? account.provider.rawValue.capitalized)
                    .font(.body)
                    .foregroundColor(.white)
                
                if let username = account.username {
                    Text("@\(username)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
    
    private var socialIcon: String {
        switch account.provider {
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
    
    private var socialColor: Color {
        switch account.provider {
        case .google:
            return .red
        case .apple:
            return .white
        case .telegram:
            return .blue
        case .farcaster:
            return .purple
        case .twitter:
            return .blue
        case .github:
            return .gray
        }
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SessionCoordinator.shared)
            .environmentObject(AuthenticationManagerV2.shared)
            .preferredColorScheme(.dark)
    }
}
