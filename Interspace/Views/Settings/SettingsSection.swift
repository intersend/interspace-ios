import SwiftUI

struct SettingsSection<Content: View>: View {
    let header: String?
    let footer: String?
    let content: Content
    
    init(
        header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if let header = header {
                Text(header)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondaryLabel)
                    .textCase(.uppercase)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            
            // Content Container with Liquid Glass effect
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.separator.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            
            // Footer
            if let footer = footer {
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryLabel)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
}

// Helper view for dividers within sections
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.separator.opacity(0.3))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }
}

// Convenience modifier for common section styling
extension View {
    func settingsSectionStyle() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// Preview
struct SettingsSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSection(header: "Account") {
                    SettingsRow(
                        icon: "person.circle.fill",
                        iconColor: .blue,
                        title: "Personal Information",
                        action: {}
                    )
                    
                    SettingsDivider()
                    
                    SettingsRow(
                        icon: "shield.fill",
                        iconColor: .green,
                        title: "Sign-In & Security",
                        action: {}
                    )
                    
                    SettingsDivider()
                    
                    SettingsRow(
                        icon: "creditcard.fill",
                        iconColor: .orange,
                        title: "Payment & Shipping",
                        value: "Visa",
                        action: {}
                    )
                }
                
                SettingsSection(
                    header: "Services",
                    footer: "Manage your iCloud storage and see what's taking up space"
                ) {
                    SettingsRow(
                        icon: "icloud.fill",
                        iconColor: .blue,
                        title: "iCloud",
                        value: "2 TB",
                        action: {}
                    )
                    
                    SettingsDivider()
                    
                    SettingsRow(
                        icon: "square.stack.3d.up.fill",
                        iconColor: .indigo,
                        title: "Media & Purchases",
                        action: {}
                    )
                }
                
                SettingsSection {
                    SettingsRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "Delete Account",
                        showDisclosure: false,
                        action: {}
                    )
                }
            }
        }
        .background(Color.systemGroupedBackground)
    }
}