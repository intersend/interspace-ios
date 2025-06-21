import SwiftUI

// MARK: - Colors
public struct InterspaceColors {
    // Primary Colors
    static let background = Color(hex: "#000000")
    static let surface = Color(hex: "#1C1C1E")
    static let surfaceElevated = Color(hex: "#2C2C2E")
    static let primary = Color(hex: "#007AFF") // Apple Blue
    
    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#EBEBF5").opacity(0.6)
    static let textTertiary = Color(hex: "#EBEBF5").opacity(0.3)
    
    // Borders and Separators
    static let separator = Color(hex: "#38383A")
    static let separatorOpaque = Color(hex: "#545458").opacity(0.6)
    
    // System Colors
    static let success = Color(hex: "#34C759")
    static let warning = Color(hex: "#FF9500")
    static let error = Color(hex: "#FF3B30")
    
    // Overlay
    static let overlayBackground = Color.black.opacity(0.4)
}

// MARK: - Typography
public struct InterspaceTypography {
    // Large Title
    static func largeTitle(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .rounded))
    }
    
    // Title 1
    static func title1(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 28, weight: .bold, design: .rounded))
    }
    
    // Title 2
    static func title2(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
    }
    
    // Title 3
    static func title3(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
    }
    
    // Headline
    static func headline(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
    }
    
    // Body
    static func body(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 17, weight: .regular, design: .rounded))
    }
    
    // Subheadline
    static func subheadline(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 15, weight: .regular, design: .rounded))
    }
    
    // Footnote
    static func footnote(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
    }
    
    // Caption 1
    static func caption1(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .rounded))
    }
    
    // Caption 2
    static func caption2(_ text: String) -> Text {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .rounded))
    }
}

// MARK: - Spacing
public struct InterspaceSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius
public struct InterspaceRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 27
    static let full: CGFloat = 1000
}

// MARK: - Animations
public struct InterspaceAnimations {
    static let springResponse: Double = 0.4
    static let springDamping: Double = 0.8
    static let springBlendDuration: Double = 0
    
    static var spring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping, blendDuration: springBlendDuration)
    }
    
    static var easeOut: Animation {
        .easeOut(duration: 0.2)
    }
    
    static var easeInOut: Animation {
        .easeInOut(duration: 0.3)
    }
}

// MARK: - Shadow
public struct InterspaceElevation {
    static let low = Shadow(
        color: Color.black.opacity(0.1),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let medium = Shadow(
        color: Color.black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let high = Shadow(
        color: Color.black.opacity(0.2),
        radius: 16,
        x: 0,
        y: 8
    )
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Helpers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
extension View {
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(InterspaceColors.surface.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: InterspaceRadius.lg)
                    .stroke(InterspaceColors.separator, lineWidth: 0.5)
            )
    }
    
    func primaryButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(InterspaceColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: InterspaceRadius.md))
    }
    
    func secondaryButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(InterspaceColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(InterspaceColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: InterspaceRadius.md)
                    .stroke(InterspaceColors.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InterspaceRadius.md))
    }
    
    func tertiaryButton() -> some View {
        self
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(InterspaceColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
    }
}