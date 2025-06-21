import SwiftUI

struct SocialAccountDetailView: View {
    let account: SocialAccount
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    
    private var providerIcon: String {
        switch account.provider {
        case .google:
            return "globe"
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
    
    private var providerColor: Color {
        switch account.provider {
        case .google:
            return DesignTokens.Colors.google
        case .apple:
            return DesignTokens.Colors.apple
        case .telegram:
            return .blue
        case .farcaster:
            return .purple
        case .twitter:
            return .blue
        case .github:
            return .white
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Account Info Section
                Section {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(providerColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: providerIcon)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(providerColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName ?? account.username ?? account.provider.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            if let username = account.username {
                                Text(username)
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // Account Details
                Section {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(account.provider.displayName)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    
                    HStack {
                        Text("Connected")
                        Spacer()
                        Text(account.createdAt, style: .date)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                
                // Actions
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Disconnect Account")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Social Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
            .alert("Disconnect Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    Task {
                        await viewModel.unlinkSocialAccount(account)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect this social account?")
            }
        }
    }
}