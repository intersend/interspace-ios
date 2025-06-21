import SwiftUI
import UIKit

// MARK: - Design Tokens for Liquid Glass Theme
struct DesignTokens {
    
    // MARK: - Colors
    struct Colors {
        
        // MARK: - Primary Colors
        static let primary = Color.accentColor
        static let primaryDark = Color(red: 0.0, green: 0.48, blue: 1.0)
        static let primaryVariant = Color(red: 0.0, green: 0.64, blue: 1.0)
        
        // MARK: - Background Colors (Space Theme)
        static let backgroundPrimary = Color.black
        static let backgroundSecondary = Color(red: 0.05, green: 0.05, blue: 0.08)
        static let backgroundTertiary = Color(red: 0.08, green: 0.08, blue: 0.12)
        
        // MARK: - Surface Colors (Liquid Glass)
        static let surfacePrimary = Color.clear // Uses .ultraThinMaterial
        static let surfaceSecondary = Color.clear // Uses .thinMaterial
        static let surfaceElevated = Color.clear // Uses .regularMaterial
        
        // MARK: - Text Colors
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.7)
        static let textTertiary = Color(white: 0.5)
        static let textPlaceholder = Color(white: 0.4)
        
        // MARK: - Interactive Colors
        static let buttonPrimary = Color.clear // Will use glass effect
        static let buttonSecondary = Color(white: 0.1)
        static let buttonDestructive = Color.red
        
        // MARK: - State Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // MARK: - Wallet Brand Colors
        static let metamask = Color(red: 1.0, green: 0.48, blue: 0.0)
        static let coinbase = Color(red: 0.0, green: 0.48, blue: 1.0)
        static let apple = Color.white
        static let google = Color(red: 0.26, green: 0.52, blue: 0.96)
        
        // MARK: - Border Colors
        static let borderPrimary = Color(white: 0.2)
        static let borderSecondary = Color(white: 0.1)
        static let borderFocus = Color.accentColor
        static let borderGlass = Color.white.opacity(0.1)
        
        // MARK: - Fill Colors
        static let fillTertiary = Color.white.opacity(0.05)
        
        // MARK: - Interactive Colors
        static let interactive = Color.accentColor
    }
    
    // MARK: - Typography
    struct Typography {
        
        // MARK: - Font Weights
        static let thin = Font.Weight.thin
        static let light = Font.Weight.light
        static let regular = Font.Weight.regular
        static let medium = Font.Weight.medium
        static let semibold = Font.Weight.semibold
        static let bold = Font.Weight.bold
        static let heavy = Font.Weight.heavy
        
        // MARK: - Display Text
        static let displayLarge = Font.system(size: 48, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 36, weight: .bold, design: .default)
        static let displaySmall = Font.system(size: 28, weight: .bold, design: .default)
        
        // MARK: - Headline Text
        static let headlineLarge = Font.system(size: 24, weight: .semibold, design: .default)
        static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)
        
        // MARK: - Body Text
        static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
        
        // MARK: - Label Text
        static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
        
        // MARK: - Button Text
        static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .default)
        static let buttonMedium = Font.system(size: 16, weight: .semibold, design: .default)
        static let buttonSmall = Font.system(size: 14, weight: .semibold, design: .default)
        
        // MARK: - Caption Text
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionEmphasis = Font.system(size: 12, weight: .medium, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        
        // MARK: - Title Text
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // MARK: - Body Text (additional)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing (iOS 18 Standards)
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        
        // MARK: - iOS 18 Component Specific
        static let buttonPaddingVertical: CGFloat = 16   // Increased for better touch targets
        static let buttonPaddingHorizontal: CGFloat = 24 // Wider buttons in iOS 18
        static let inputPaddingVertical: CGFloat = 12    // Larger input fields
        static let inputPaddingHorizontal: CGFloat = 16
        static let cardPadding: CGFloat = 20             // Increased for Liquid Glass cards
        static let screenPadding: CGFloat = 20           // Standard iOS 18 screen margins
        static let sectionSpacing: CGFloat = 24          // Increased section spacing
        static let listItemSpacing: CGFloat = 12         // More spacing between list items
        
        // MARK: - iOS 18 Native Layout Spacing
        static let iOSScreenMargin: CGFloat = 20         // Standard iOS screen edge margin
        static let iOSNavigationSpacing: CGFloat = 16    // Navigation content spacing
        static let iOSAuthHeaderSpacing: CGFloat = 32    // Auth screens header spacing
        static let iOSAuthSectionSpacing: CGFloat = 24   // Between auth sections
        static let iOSAuthContentSpacing: CGFloat = 40   // Auth content vertical spacing
        static let iOSListSectionSpacing: CGFloat = 32   // Between list sections
        static let iOSHeaderBottomSpacing: CGFloat = 24  // Space below headers
        
        // MARK: - iOS 18 Row Heights
        static let iOSMinRowHeight: CGFloat = 48         // Minimum row height in iOS 18
        static let iOSProfileRowHeight: CGFloat = 72     // For profile header cards
        static let iOSAccountRowHeight: CGFloat = 60     // For account rows
    }
    
    // MARK: - Corner Radius (iOS 18 Standards)
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let round: CGFloat = 1000 // For fully rounded elements
        
        // MARK: - iOS 18 Component Specific
        static let button: CGFloat = 16              // Increased from 12 in iOS 18
        static let input: CGFloat = 12               // Increased from 10 in iOS 18
        static let card: CGFloat = 20                // Increased from 16 for Liquid Glass
        static let sheet: CGFloat = 20               // Standard for iOS 18 sheets
        static let profileCard: CGFloat = 20         // Large profile cards
        static let accountRow: CGFloat = 16          // Account row containers
        static let iconContainer: CGFloat = 12       // For icon backgrounds
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let extraLarge = Shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        
        static let level1 = Shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let level2 = Shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let level3 = Shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let level4 = Shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Animation Durations
    struct Animation {
        static let fast: Double = 0.2
        static let medium: Double = 0.3
        static let slow: Double = 0.5
        static let extraSlow: Double = 0.8
        
        // MARK: - Easing Curves
        static let easeInOut = SwiftUI.Animation.easeInOut
        static let easeIn = SwiftUI.Animation.easeIn
        static let easeOut = SwiftUI.Animation.easeOut
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.1)
        static let springSnappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Glass Effects
    struct GlassEffect {
        static let ultraThin = Material.ultraThinMaterial
        static let thin = Material.thinMaterial
        static let regular = Material.regularMaterial
        static let thick = Material.thickMaterial
        static let ultraThick = Material.ultraThickMaterial
    }
    
    // MARK: - Liquid Glass Materials
    struct LiquidGlass {
        static let ultraThin = Material.ultraThinMaterial
        static let thin = Material.thinMaterial
        static let regular = Material.regularMaterial
        static let thick = Material.thickMaterial
        static let ultraThick = Material.ultraThickMaterial
    }
}

// MARK: - Component Styles
struct LiquidGlassButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: LiquidGlassButtonSize
    
    enum ButtonVariant {
        case primary
        case secondary
        case ghost
        case wallet(WalletType)
        case destructive
    }
    
    init(variant: ButtonVariant, size: LiquidGlassButtonSize = .medium) {
        self.variant = variant
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundView)
            .cornerRadius(DesignTokens.CornerRadius.button)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: DesignTokens.Animation.fast), value: configuration.isPressed)
    }
    
    private var buttonFont: Font {
        switch size {
        case .small:
            return DesignTokens.Typography.buttonSmall
        case .medium:
            return DesignTokens.Typography.buttonMedium
        case .large:
            return DesignTokens.Typography.buttonLarge
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small:
            return 8
        case .medium:
            return DesignTokens.Spacing.buttonPaddingVertical
        case .large:
            return 20
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small:
            return 16
        case .medium:
            return DesignTokens.Spacing.buttonPaddingHorizontal
        case .large:
            return 32
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return DesignTokens.Colors.textPrimary
        case .secondary:
            return DesignTokens.Colors.textSecondary
        case .ghost:
            return DesignTokens.Colors.textTertiary
        case .wallet:
            return DesignTokens.Colors.textPrimary
        case .destructive:
            return Color.white
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            Rectangle()
                .fill(DesignTokens.GlassEffect.ultraThin)
        case .secondary:
            Rectangle()
                .fill(DesignTokens.GlassEffect.thin)
        case .ghost:
            Rectangle()
                .fill(Color.clear)
        case .wallet:
            Rectangle()
                .fill(DesignTokens.GlassEffect.ultraThin)
        case .destructive:
            Rectangle()
                .fill(DesignTokens.Colors.buttonDestructive)
        }
    }
}

// MARK: - Helper Extensions
extension View {
    func liquidGlassBackground() -> some View {
        self.background(DesignTokens.GlassEffect.ultraThin)
    }
    
    func liquidGlassCard() -> some View {
        self
            .background(DesignTokens.GlassEffect.thin)
            .cornerRadius(DesignTokens.CornerRadius.card)
            .shadow(
                color: DesignTokens.Shadows.medium.color,
                radius: DesignTokens.Shadows.medium.radius,
                x: DesignTokens.Shadows.medium.x,
                y: DesignTokens.Shadows.medium.y
            )
    }
    
    func liquidGlassSheet() -> some View {
        self
            .background(DesignTokens.GlassEffect.regular)
            .cornerRadius(DesignTokens.CornerRadius.sheet, corners: [.topLeft, .topRight])
    }
}

// MARK: - Custom Corner Radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}


// MARK: - Haptic Feedback Helper
struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
    
    static func selection() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Liquid Glass Extensions
extension View {
    func liquidGlassButton(variant: LiquidGlassButtonVariant, size: LiquidGlassButtonSize) -> some View {
        self.modifier(LiquidGlassButtonModifier(variant: variant, size: size))
    }
    
    func liquidGlassTextField(size: LiquidGlassTextFieldSize) -> some View {
        self.modifier(LiquidGlassTextFieldModifier(size: size))
    }
    
    func properSafeAreaLayout() -> some View {
        self.safeAreaInset(edge: .top, spacing: 0) {
            EmptyView()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EmptyView()
        }
    }
    
    // MARK: - iOS Native Layout Helpers
    func iOSNativeScreenMargins() -> some View {
        self.padding(.horizontal, DesignTokens.Spacing.iOSScreenMargin)
    }
    
    func iOSNativeAuthLayout() -> some View {
        self
            .padding(.top, DesignTokens.Spacing.iOSAuthContentSpacing)
            .padding(.horizontal, DesignTokens.Spacing.iOSScreenMargin)
    }
    
    func iOSNativeListLayout() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
    }
}

// MARK: - Liquid Glass Button Modifier
enum LiquidGlassButtonVariant {
    case primary
    case secondary
    case ghost
    case destructive
    case wallet(WalletType)
}

enum LiquidGlassButtonSize {
    case small
    case medium
    case large
}

struct LiquidGlassButtonModifier: ViewModifier {
    let variant: LiquidGlassButtonVariant
    let size: LiquidGlassButtonSize
    
    func body(content: Content) -> some View {
        Button(action: {}) {
            content
        }
        .buttonStyle(LiquidGlassButtonStyle(variant: buttonVariant, size: size))
    }
    
    private var buttonVariant: LiquidGlassButtonStyle.ButtonVariant {
        switch variant {
        case .primary:
            return .primary
        case .secondary:
            return .secondary
        case .ghost:
            return .ghost
        case .destructive:
            return .destructive
        case .wallet(let walletType):
            return .wallet(walletType)
        }
    }
}

// MARK: - Liquid Glass TextField Modifier
enum LiquidGlassTextFieldSize {
    case small
    case medium
    case large
}

struct LiquidGlassTextFieldModifier: ViewModifier {
    let size: LiquidGlassTextFieldSize
    
    func body(content: Content) -> some View {
        content
            .textFieldStyle(LiquidGlassTextFieldStyle())
            .frame(height: height)
    }
    
    private var height: CGFloat {
        switch size {
        case .small:
            return 36
        case .medium:
            return 44
        case .large:
            return 52
        }
    }
}