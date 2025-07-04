import SwiftUI
import UIKit

struct UserProfileHeaderView: View {
    let user: User?
    let activeProfile: SmartProfile?
    let onIconTap: () -> Void
    
    @State private var profileIcon: ProfileIconType = .generated
    @State private var addressCopied = false
    @State private var addressHidden = false
    
    enum ProfileIconType {
        case generated
        case emoji(String)
        case custom(Image)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Compact Profile Icon with Edit
            Button(action: onIconTap) {
                ZStack(alignment: .bottomTrailing) {
                    profileIconView
                    
                    // Edit indicator
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.95))
            
            // Profile Info
            VStack(alignment: .leading, spacing: 4) {
                // Name with Dev Indicator
                HStack(spacing: 6) {
                    Text(activeProfile?.name ?? "My Profile")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    DevelopmentModeIndicator(size: .small)
                }
                
                // Full Wallet Address
                if let address = activeProfile?.sessionWalletAddress {
                    HStack(spacing: 8) {
                        Text(addressHidden ? hideAddress(address) : address)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .animation(.easeInOut(duration: 0.2), value: addressHidden)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            // Hide/Show Button
                            Button(action: toggleAddressVisibility) {
                                Image(systemName: addressHidden ? "eye.slash" : "eye")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            
                            // Copy Button
                            Button(action: copyAddress) {
                                Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(addressCopied ? .green : .secondary)
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var profileIconView: some View {
        switch profileIcon {
        case .generated:
            if let profileId = activeProfile?.id {
                ProfileIconGenerator.generateIcon(for: profileId, size: 60)
            } else {
                defaultIcon
            }
        case .emoji(let emoji):
            ProfileIconGenerator.emojiIcon(emoji, size: 60)
        case .custom(let image):
            ProfileIconGenerator.imageIcon(image, size: 60)
        }
    }
    
    private var defaultIcon: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.quaternarySystemFill))
                .frame(width: 60, height: 60)
            
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundColor(.tertiaryLabel)
        }
    }
    
    private func hideAddress(_ address: String) -> String {
        guard address.count > 10 else { return String(repeating: "•", count: address.count) }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        let middleCount = address.count - 10
        let dots = String(repeating: "•", count: middleCount)
        return "\(prefix)\(dots)\(suffix)"
    }
    
    private func toggleAddressVisibility() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            addressHidden.toggle()
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func copyAddress() {
        guard let address = activeProfile?.sessionWalletAddress else { return }
        
        UIPasteboard.general.string = address
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Show feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            addressCopied = true
        }
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                addressCopied = false
            }
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct UserProfileHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileHeaderView(
            user: User(
                id: "123",
                email: "user@example.com",
                walletAddress: nil,
                isGuest: false,
                authStrategies: ["google"],
                profilesCount: 3,
                linkedAccountsCount: 5,
                activeDevicesCount: 2,
                socialAccounts: [],
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            ),
            activeProfile: SmartProfile(
                id: "1",
                name: "Trading",
                isActive: true,
                sessionWalletAddress: "0x1234567890abcdef1234567890abcdef12345678",
                linkedAccountsCount: 2,
                appsCount: 5,
                foldersCount: 1,
                isDevelopmentWallet: true,
                needsMpcGeneration: false,
                clientShare: nil,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            ),
            onIconTap: {}
        )
        .background(Color.systemGroupedBackground)
    }
}
