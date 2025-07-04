import SwiftUI

struct ProfileSelectorCard: View {
    let activeProfile: SmartProfile?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Compact text
                Text(activeProfile?.name ?? "Select Profile")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.thinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(FloatingPillButtonStyle())
    }
}

// Floating pill button style with liquid glass effect
struct FloatingPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct ProfileSelectorCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ProfileSelectorCard(
                activeProfile: SmartProfile(
                    id: "1",
                    name: "Trading",
                    isActive: true,
                    sessionWalletAddress: "0x1234567890abcdef1234567890abcdef12345678",
                    linkedAccountsCount: 3,
                    appsCount: 12,
                    foldersCount: 2,
                    isDevelopmentWallet: false,
                    needsMpcGeneration: false,
                    clientShare: nil,
                    createdAt: "2024-01-01T00:00:00Z",
                    updatedAt: "2024-01-01T00:00:00Z"
                ),
                onTap: {}
            )
            
            ProfileSelectorCard(
                activeProfile: nil,
                onTap: {}
            )
        }
        .padding()
        .background(Color.systemGroupedBackground)
    }
}
