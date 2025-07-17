import SwiftUI

struct LinkedAccountsView: View {
    let profile: SmartProfile
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var accountToDelete: LinkedAccount?
    @State private var accountToEdit: LinkedAccount?
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showAddAccount = false
    @State private var isPerformingAction = false
    
    // Filter out MPC session wallets
    var filteredAccounts: [LinkedAccount] {
        viewModel.linkedAccounts.filter { account in
            account.walletType?.lowercased() != "mpc"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                if filteredAccounts.isEmpty && !viewModel.isLoadingAccounts {
                    // Empty State
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .padding(.bottom, DesignTokens.Spacing.md)
                        
                        Text("No Linked Accounts")
                            .font(DesignTokens.Typography.headlineMedium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Connect wallets and accounts to access them from this profile")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                        
                        Button(action: {
                            HapticManager.impact(.light)
                            addAccount()
                        }) {
                            Label("Add Account", systemImage: "plus.circle.fill")
                                .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(DesignTokens.Colors.primary)
                        .padding(.top, DesignTokens.Spacing.md)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(filteredAccounts) { account in
                                ManageLinkedAccountRow(
                                    account: account,
                                    onSetPrimary: { setPrimaryAccount(account) },
                                    onEdit: { 
                                        accountToEdit = account
                                        showEditSheet = true
                                    },
                                    onDelete: {
                                        accountToDelete = account
                                        showDeleteConfirmation = true
                                    }
                                )
                                .disabled(isPerformingAction)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    }
                }
                
                // Loading Overlay
                if viewModel.isLoadingAccounts || isPerformingAction {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Linked Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
                
                if !filteredAccounts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticManager.impact(.light)
                            addAccount()
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(DesignTokens.Colors.primary)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Remove Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let account = accountToDelete {
                Text("Remove \(account.displayName) (\(account.displayIdentifier))? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let account = accountToEdit {
                EditAccountSheet(
                    account: account,
                    onSave: { newName in
                        Task {
                            await updateAccountName(account, name: newName)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView(viewModel: viewModel)
        }
    }
    
    // MARK: - Actions
    
    private func addAccount() {
        showAddAccount = true
    }
    
    private func setPrimaryAccount(_ account: LinkedAccount) {
        guard !account.isPrimary else { return }
        
        Task {
            isPerformingAction = true
            await viewModel.setPrimaryAccount(account)
            isPerformingAction = false
        }
    }
    
    private func updateAccountName(_ account: LinkedAccount, name: String?) {
        Task {
            isPerformingAction = true
            await viewModel.updateAccountName(account, name: name)
            isPerformingAction = false
        }
    }
    
    private func deleteAccount(_ account: LinkedAccount) {
        Task {
            isPerformingAction = true
            await viewModel.unlinkAccount(account)
            isPerformingAction = false
            accountToDelete = nil
        }
    }
}

// MARK: - Account Row

struct ManageLinkedAccountRow: View {
    let account: LinkedAccount
    let onSetPrimary: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Wallet Icon
            if account.authStrategy == "wallet",
               let iconUrl = account.walletIconUrl,
               let url = URL(string: iconUrl) {
                // Use AsyncImage for remote wallet icons
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(walletIconBackground)
                        
                        Image(systemName: walletIconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(walletIconColor)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                // Fallback to system icon
                ZStack {
                    Circle()
                        .fill(walletIconBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: walletIconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(walletIconColor)
                }
            }
            
            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(account.customName ?? account.displayName)
                        .font(DesignTokens.Typography.bodyLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if account.isPrimary {
                        Text("PRIMARY")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.primary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(account.displayIdentifier)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            // Menu Button
            Menu {
                if !account.isPrimary {
                    Button(action: {
                        HapticManager.impact(.light)
                        onSetPrimary()
                    }) {
                        Label("Set as Primary", systemImage: "star")
                    }
                }
                
                Button(action: {
                    HapticManager.impact(.light)
                    onEdit()
                }) {
                    Label("Edit Name", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    HapticManager.impact(.medium)
                    onDelete()
                }) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
        .contextMenu {
            if !account.isPrimary {
                Button(action: {
                    HapticManager.impact(.light)
                    onSetPrimary()
                }) {
                    Label("Set as Primary", systemImage: "star")
                }
            }
            
            Button(action: {
                HapticManager.impact(.light)
                onEdit()
            }) {
                Label("Edit Name", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                HapticManager.impact(.medium)
                onDelete()
            }) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
    
    // Computed properties for wallet styling
    private var walletIconName: String {
        switch account.authStrategy {
        case "wallet":
            return getWalletIcon(for: account.walletType)
        case "email":
            return "envelope.fill"
        case "social":
            return "person.crop.circle.fill"
        default:
            return "link"
        }
    }
    
    private var walletIconBackground: Color {
        switch account.authStrategy {
        case "wallet":
            return getWalletColor(for: account.walletType).opacity(0.1)
        case "email":
            return DesignTokens.Colors.primary.opacity(0.1)
        case "social":
            return Color.blue.opacity(0.1)
        default:
            return DesignTokens.Colors.textTertiary.opacity(0.1)
        }
    }
    
    private var walletIconColor: Color {
        switch account.authStrategy {
        case "wallet":
            return getWalletColor(for: account.walletType)
        case "email":
            return DesignTokens.Colors.primary
        case "social":
            return Color.blue
        default:
            return DesignTokens.Colors.textTertiary
        }
    }
    
    private func getWalletIcon(for walletType: String?) -> String {
        switch walletType?.lowercased() {
        case "metamask":
            return "wallet.pass.fill"
        case "coinbase":
            return "c.circle.fill"
        case "walletconnect":
            return "link.circle.fill"
        case "rainbow":
            return "cloud.sun.fill"
        case "argent":
            return "shield.fill"
        case "trust":
            return "checkmark.shield.fill"
        case "phantom":
            return "moon.fill"
        case "zerion":
            return "square.stack.3d.up.fill"
        case "family":
            return "person.2.fill"
        default:
            return "wallet.pass.fill"
        }
    }
    
    private func getWalletColor(for walletType: String?) -> Color {
        switch walletType?.lowercased() {
        case "metamask":
            return Color.orange
        case "coinbase":
            return Color.blue
        case "walletconnect":
            return Color.cyan
        case "rainbow":
            return Color.purple
        case "argent":
            return Color.indigo
        case "trust":
            return Color.green
        default:
            return DesignTokens.Colors.primary
        }
    }
}

// MARK: - Edit Account Sheet

struct EditAccountSheet: View {
    let account: LinkedAccount
    let onSave: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var customName: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(account: LinkedAccount, onSave: @escaping (String?) -> Void) {
        self.account = account
        self.onSave = onSave
        self._customName = State(initialValue: account.customName ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Account Name")
                            .font(DesignTokens.Typography.labelMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Spacer()
                    }
                    
                    TextField("Enter custom name", text: $customName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Material.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .onSubmit {
                            saveChanges()
                        }
                    
                    Text("Leave empty to use default name (\(account.displayName))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.screenPadding)
            .background(DesignTokens.Colors.backgroundSecondary)
            .navigationTitle("Edit Account")
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
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func saveChanges() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmed.isEmpty ? nil : trimmed)
        dismiss()
    }
}

// MARK: - Preview

struct LinkedAccountsView_Previews: PreviewProvider {
    static var previews: some View {
        LinkedAccountsView(
            profile: SmartProfile(
                id: "1",
                name: "Trading Profile",
                isActive: true,
                sessionWalletAddress: "0x1234567890123456789012345678901234567890",
                linkedAccountsCount: 3,
                appsCount: 8,
                foldersCount: 2,
                needsMpcGeneration: false,
                clientShare: nil,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            ),
            viewModel: ProfileViewModel.shared
        )
        .preferredColorScheme(.dark)
    }
}
