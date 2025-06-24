import SwiftUI

struct ProfileSettingsView: View {
    let profile: SmartProfile
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedName: String
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var showWalletSecurity = false
    @State private var isUpdating = false
    
    init(profile: SmartProfile, viewModel: ProfileViewModel) {
        self.profile = profile
        self.viewModel = viewModel
        self._editedName = State(initialValue: profile.name)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.lg) {
                        // Header
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignTokens.Colors.primary, DesignTokens.Colors.primary.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(profile.name.prefix(1).uppercased())
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .animation(DesignTokens.Animation.spring.delay(0.1), value: true)
                            
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Text(profile.name)
                                    .font(DesignTokens.Typography.headlineLarge)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                if profile.isActive {
                                    HStack {
                                        Circle()
                                            .fill(DesignTokens.Colors.success)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("Active Profile")
                                            .font(DesignTokens.Typography.labelMedium)
                                            .foregroundColor(DesignTokens.Colors.success)
                                    }
                                }
                            }
                        }
                        .padding(.top, DesignTokens.Spacing.xl)
                        
                        // Profile Information
                        VStack(spacing: DesignTokens.Spacing.md) {
                            // Session Wallet
                            InfoCard(
                                title: "Session Wallet",
                                subtitle: "ERC-7702 Proxy Address",
                                value: profile.sessionWalletAddress,
                                copyable: true
                            )
                            
                            // Statistics
                            StatsCard(profile: profile)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        
                        // Actions Section
                        VStack(spacing: 0) {
                            if !profile.isActive {
                                ActionRow(
                                    title: "Activate Profile",
                                    subtitle: "Set as your active profile",
                                    icon: "checkmark.circle",
                                    iconColor: DesignTokens.Colors.success,
                                    isFirst: true,
                                    isLast: false
                                ) {
                                    activateProfile()
                                }
                            }
                            
                            ActionRow(
                                title: "Rename Profile",
                                subtitle: "Change the profile name",
                                icon: "pencil",
                                iconColor: DesignTokens.Colors.textSecondary,
                                isFirst: profile.isActive,
                                isLast: false
                            ) {
                                showRenameSheet = true
                            }
                            
                            ActionRow(
                                title: "Linked Accounts",
                                subtitle: "\(profile.linkedAccountsCount) connected",
                                icon: "link",
                                iconColor: DesignTokens.Colors.textSecondary,
                                showChevron: true,
                                isFirst: false,
                                isLast: false
                            ) {
                                // Navigate to linked accounts
                            }
                            
                            ActionRow(
                                title: "Apps & Folders",
                                subtitle: "\(profile.appsCount) apps, \(profile.foldersCount) folders",
                                icon: "square.grid.3x3",
                                iconColor: DesignTokens.Colors.textSecondary,
                                showChevron: true,
                                isFirst: false,
                                isLast: false
                            ) {
                                // Navigate to apps management
                            }
                        }
                        .background(DesignTokens.GlassEffect.thin)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        
                        // Advanced Section
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("ADVANCED")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                                .padding(.bottom, DesignTokens.Spacing.xs)
                            
                            VStack(spacing: 0) {
                                // Wallet Security
                                ActionRow(
                                    title: "Wallet Security",
                                    subtitle: "Manage MPC wallet security settings",
                                    icon: "lock.shield",
                                    iconColor: DesignTokens.Colors.primary,
                                    showChevron: true,
                                    isFirst: true,
                                    isLast: !profile.isDevelopmentWallet && profile.isActive
                                ) {
                                    showWalletSecurity = true
                                }
                                
                                // Export Key Share
                                if !profile.isDevelopmentWallet {
                                    ActionRow(
                                        title: "Export Key Share",
                                        subtitle: "Backup your MPC key share",
                                        icon: "square.and.arrow.up",
                                        iconColor: DesignTokens.Colors.textSecondary,
                                        showChevron: true,
                                        isFirst: false,
                                        isLast: profile.isActive
                                    ) {
                                        // Handle key share export
                                    }
                                }
                                
                                if !profile.isActive {
                                    ActionRow(
                                        title: "Delete Profile",
                                        subtitle: "Permanently remove this profile",
                                        icon: "trash",
                                        iconColor: DesignTokens.Colors.error,
                                        isFirst: false,
                                        isLast: true
                                    ) {
                                        showDeleteConfirmation = true
                                    }
                                }
                            }
                            .background(DesignTokens.GlassEffect.thin)
                            .cornerRadius(DesignTokens.CornerRadius.lg)
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        }
                        .padding(.top, DesignTokens.Spacing.md)
                        
                        Spacer(minLength: DesignTokens.Spacing.xl)
                    }
                }
                
                // Loading Overlay
                if isUpdating {
                    LoadingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
        .confirmationDialog(
            "Delete Profile",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteProfile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. All apps, folders, and linked accounts will be removed.")
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameProfileSheet(
                currentName: profile.name,
                onRename: { newName in
                    Task {
                        await renameProfile(newName)
                    }
                }
            )
        }
        .sheet(isPresented: $showWalletSecurity) {
            WalletSecurityView(profile: profile)
        }
    }
    
    // MARK: - Actions
    
    private func activateProfile() {
        isUpdating = true
        viewModel.activateProfile(profile)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isUpdating = false
            dismiss()
        }
    }
    
    private func renameProfile(_ newName: String) async {
        isUpdating = true
        await viewModel.updateProfile(profile, name: newName)
        isUpdating = false
    }
    
    private func deleteProfile() {
        Task {
            isUpdating = true
            await viewModel.deleteProfile(profile)
            isUpdating = false
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct InfoCard: View {
    let title: String
    let subtitle: String
    let value: String
    let copyable: Bool
    
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            HStack {
                Text(value.prefix(20) + "..." + value.suffix(8))
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                if copyable {
                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(showCopied ? DesignTokens.Colors.success : DesignTokens.Colors.textTertiary)
                    }
                    .animation(.easeInOut(duration: 0.2), value: showCopied)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = value
        showCopied = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopied = false
        }
    }
}

struct StatsCard: View {
    let profile: SmartProfile
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            ProfileStatItem(
                title: "Linked Accounts",
                value: "\(profile.linkedAccountsCount)",
                icon: "link"
            )
            
            Divider()
                .frame(height: 40)
                .background(DesignTokens.Colors.borderSecondary)
            
            ProfileStatItem(
                title: "Apps",
                value: "\(profile.appsCount)",
                icon: "square.grid.3x3"
            )
            
            Divider()
                .frame(height: 40)
                .background(DesignTokens.Colors.borderSecondary)
            
            ProfileStatItem(
                title: "Folders",
                value: "\(profile.foldersCount)",
                icon: "folder"
            )
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }
}

struct ProfileStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text(value)
                .font(DesignTokens.Typography.headlineSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let showChevron: Bool
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color = DesignTokens.Colors.textSecondary,
        showChevron: Bool = false,
        isFirst: Bool,
        isLast: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showChevron = showChevron
        self.isFirst = isFirst
        self.isLast = isLast
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSecondary)
                    .frame(height: 0.5)
                    .padding(.leading, 60)
            }
        }
    }
}

// MARK: - Rename Sheet

struct RenameProfileSheet: View {
    let currentName: String
    let onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var newName: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(currentName: String, onRename: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onRename = onRename
        self._newName = State(initialValue: currentName)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Profile Name")
                            .font(DesignTokens.Typography.labelMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Spacer()
                    }
                    
                    TextField("Enter profile name", text: $newName)
                        .textFieldStyle(LiquidGlassTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .autocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit {
                            if isValidName {
                                saveChanges()
                            }
                        }
                }
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.screenPadding)
            .background(DesignTokens.Colors.backgroundSecondary)
            .navigationTitle("Rename Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValidName)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var isValidName: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed != currentName
    }
    
    private func saveChanges() {
        onRename(newName.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}

// MARK: - Preview

struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSettingsView(
            profile: SmartProfile(
                id: "1",
                name: "Trading Profile",
                isActive: true,
                sessionWalletAddress: "0x1234567890123456789012345678901234567890",
                linkedAccountsCount: 3,
                appsCount: 8,
                foldersCount: 2,
                isDevelopmentWallet: false,
                clientShare: nil,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            ),
            viewModel: ProfileViewModel.shared
        )
        .preferredColorScheme(.dark)
    }
}
