import SwiftUI

struct AccountDetailView: View {
    let account: LinkedAccount
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isEditingName = false
    @State private var customName: String = ""
    @State private var isAddressHidden = false
    @State private var showCopiedFeedback = false
    
    private var walletType: WalletType {
        WalletType(rawValue: account.walletType) ?? .unknown
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Spacer()
                
                Text("Account Details")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isEditingName {
                    Button(action: {
                        Task {
                            await viewModel.updateAccountName(account, name: customName.isEmpty ? nil : customName)
                            isEditingName = false
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 17))
                            .foregroundColor(DesignTokens.Colors.primary)
                    }
                } else {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 17))
                            .foregroundColor(DesignTokens.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            List {
                // Account Info Section
                Section {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(walletType.primaryColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: walletType.systemIconName)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(walletType.primaryColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(account.customName ?? account.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            HStack(spacing: 12) {
                                Text(isAddressHidden ? maskedAddress(account.address) : account.address)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack(spacing: 8) {
                                    // Copy button
                                    Button(action: {
                                        UIPasteboard.general.string = account.address
                                        HapticManager.notification(.success)
                                        withAnimation {
                                            showCopiedFeedback = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                showCopiedFeedback = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 14))
                                            .foregroundColor(showCopiedFeedback ? .green : DesignTokens.Colors.textSecondary)
                                    }
                                    
                                    // Hide/Show button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isAddressHidden.toggle()
                                        }
                                    }) {
                                        Image(systemName: isAddressHidden ? "eye.slash" : "eye")
                                            .font(.system(size: 14))
                                            .foregroundColor(DesignTokens.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // Account Settings
                Section {
                    // Custom Name
                    HStack {
                        Text("Name")
                        Spacer()
                        if isEditingName {
                            TextField("Account Name", text: $customName)
                                .textFieldStyle(LiquidGlassTextFieldStyle())
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(account.customName ?? "Default")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isEditingName {
                            customName = account.customName ?? ""
                            withAnimation {
                                isEditingName = true
                            }
                        }
                    }
                    
                    // Primary Account Toggle
                    HStack {
                        Text("Primary Account")
                        Spacer()
                        if account.isPrimary {
                            Image(systemName: "checkmark")
                                .foregroundColor(DesignTokens.Colors.primary)
                        } else {
                            Button("Set as Primary") {
                                Task {
                                    await viewModel.setPrimaryAccount(account)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.primary)
                        }
                    }
                }
                
                // Danger Zone
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Account")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Danger Zone")
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .alert("Remove Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.unlinkAccount(account)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to remove this account? This action cannot be undone.")
            }
        }
        .background(Color.black.opacity(0.001))
        .background(Material.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
    
    private func maskedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)•••\(suffix)"
    }
}