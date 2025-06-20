import SwiftUI

struct AddSocialAccountView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connect Social Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text("Link your social accounts to enhance your profile")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Available Social Accounts
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Accounts")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(SocialProvider.allCases.enumerated()), id: \.element) { index, provider in
                                    if index > 0 {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                    
                                    SocialProviderRow(
                                        provider: provider,
                                        onTap: {
                                            HapticManager.impact(.light)
                                            // Handle social login
                                        }
                                    )
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }
        }
    }
}

struct SocialProviderRow: View {
    let provider: SocialProvider
    let onTap: () -> Void
    
    private var providerIcon: String {
        switch provider {
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
        switch provider {
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
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(providerColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: providerIcon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(providerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Connect your \(provider.displayName) account")
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

