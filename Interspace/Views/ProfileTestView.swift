import SwiftUI

// Test view to verify Profile components compile correctly
struct ProfileTestView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Test UserProfileHeaderView
                UserProfileHeaderView(
                    user: User(
                        id: "test",
                        email: "test@example.com",
                        walletAddress: nil,
                        isGuest: false,
                        authStrategies: ["google"],
                        profilesCount: 2,
                        linkedAccountsCount: 3,
                        activeDevicesCount: 1,
                        socialAccounts: [],
                        createdAt: "2024-01-01T00:00:00Z",
                        updatedAt: "2024-01-01T00:00:00Z"
                    ),
                    activeProfile: SmartProfile(
                        id: "1",
                        name: "Trading",
                        isActive: true,
                        sessionWalletAddress: "0x1234567890abcdef",
                        linkedAccountsCount: 2,
                        appsCount: 5,
                        foldersCount: 1,
                        isDevelopmentWallet: false,
                        clientShare: nil,
                        createdAt: "2024-01-01T00:00:00Z",
                        updatedAt: "2024-01-01T00:00:00Z"
                    ),
                    onIconTap: {}
                )
                
                // Test SettingsSection with SettingsRow
                SettingsSection(header: "TEST SECTION") {
                    SettingsRow(
                        icon: "person.circle.fill",
                        iconColor: .blue,
                        title: "Test Row",
                        subtitle: "This is a subtitle",
                        value: "Value",
                        action: {}
                    )
                    
                    SettingsRow(
                        icon: "bell.fill",
                        iconColor: .red,
                        title: "Notifications",
                        value: "On",
                        action: {}
                    )
                }
            }
        }
        .background(Color.systemGroupedBackground)
    }
}

#Preview {
    ProfileTestView()
}