import SwiftUI

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let value: String?
    let showDisclosure: Bool
    let action: (() -> Void)?
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        showDisclosure: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.showDisclosure = showDisclosure
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 12) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.label)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryLabel)
                    }
                }
                
                Spacer()
                
                // Value Text
                if let value = value {
                    Text(value)
                        .font(.system(size: 17))
                        .foregroundColor(.secondaryLabel)
                }
                
                // Disclosure Indicator
                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tertiaryLabel)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, subtitle != nil ? 10 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
        .disabled(action == nil)
    }
}

// Custom button style for proper interaction feedback
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.systemGray5 : Color.clear
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Toggle variant of SettingsRow
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.label)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryLabel)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, subtitle != nil ? 10 : 6)
    }
}

// Preview
struct SettingsRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "person.circle.fill",
                iconColor: .blue,
                title: "Personal Information",
                action: {}
            )
            
            Divider()
                .padding(.leading, 58)
            
            SettingsRow(
                icon: "shield.fill",
                iconColor: .green,
                title: "Sign-In & Security",
                subtitle: "Password, Face ID & more",
                action: {}
            )
            
            Divider()
                .padding(.leading, 58)
            
            SettingsRow(
                icon: "creditcard.fill",
                iconColor: .orange,
                title: "Payment & Shipping",
                value: "Visa",
                action: {}
            )
            
            Divider()
                .padding(.leading, 58)
            
            SettingsToggleRow(
                icon: "wifi",
                iconColor: .blue,
                title: "Wi-Fi",
                subtitle: "Connected to MyNetwork",
                isOn: .constant(true)
            )
        }
        .background(Color.systemBackground)
        .previewLayout(.sizeThatFits)
    }
}