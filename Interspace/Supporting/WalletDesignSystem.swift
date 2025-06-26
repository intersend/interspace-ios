import SwiftUI

// MARK: - Apple-Inspired Wallet Design System
public struct WalletDesign {
    
    // MARK: - Typography
    struct Typography {
        static let balanceDisplay = Font.system(size: 56, weight: .bold, design: .rounded)
            .monospacedDigit()
        
        static let balanceChange = Font.system(size: 17, weight: .medium, design: .rounded)
        
        static let sectionHeader = Font.system(size: 22, weight: .semibold, design: .rounded)
        
        static let tokenName = Font.system(size: 17, weight: .semibold, design: .rounded)
        
        static let tokenBalance = Font.system(size: 17, weight: .regular, design: .rounded)
            .monospacedDigit()
        
        static let tokenValue = Font.system(size: 15, weight: .regular, design: .rounded)
        
        static let chainLabel = Font.system(size: 13, weight: .regular, design: .rounded)
        
        static let transactionAmount = Font.system(size: 17, weight: .semibold, design: .rounded)
            .monospacedDigit()
        
        static let caption = Font.system(size: 11, weight: .regular, design: .rounded)
    }
    
    // MARK: - Colors
    struct Colors {
        static let positiveChange = Color.systemGreen
        static let negativeChange = Color.systemRed
        static let neutralValue = Color(UIColor.secondaryLabel)
        
        static let tokenIcon = Color(UIColor.systemGray5)
        static let nftBorder = Color(UIColor.systemGray3)
        
        static let actionPrimary = Color.systemBlue
        static let actionSecondary = Color(UIColor.systemGray)
        
        static let shimmer = LinearGradient(
            colors: [
                Color(UIColor.systemGray5),
                Color(UIColor.systemGray4),
                Color(UIColor.systemGray5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let micro: CGFloat = 4
        static let tight: CGFloat = 8
        static let regular: CGFloat = 16
        static let loose: CGFloat = 24
        static let section: CGFloat = 32
        static let hero: CGFloat = 48
    }
    
    // MARK: - Sizing
    struct Sizing {
        static let tokenIcon: CGFloat = 40
        static let nftThumbnail: CGFloat = 120
        static let nftAspectRatio: CGFloat = 0.75 // 3:4
        static let searchBarHeight: CGFloat = 36
        static let actionButtonHeight: CGFloat = 48
        static let transactionIcon: CGFloat = 32
    }
    
    // MARK: - Animation
    struct Animation {
        static let spring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        
        static let springBouncy = SwiftUI.Animation.spring(
            response: 0.5,
            dampingFraction: 0.7,
            blendDuration: 0
        )
        
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
        
        static let numberTransition = SwiftUI.Animation.easeInOut(duration: 0.3)
        
        static let refreshControl = SwiftUI.Animation.spring(
            response: 0.6,
            dampingFraction: 0.65,
            blendDuration: 0
        )
    }
    
    // MARK: - Effects
    struct Effects {
        static func cardShadow(colorScheme: ColorScheme) -> some View {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .shadow(
                    color: colorScheme == .dark 
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        }
        
        static let glassMaterial = Material.ultraThinMaterial
        
        static let tokenCellTap = AnyTransition.scale(scale: 0.98).combined(with: .opacity)
    }
}

// MARK: - Wallet-Specific View Modifiers
extension View {
    func walletCard() -> some View {
        self
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
    }
    
    func tokenCellStyle() -> some View {
        self
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.vertical, WalletDesign.Spacing.tight)
            .contentShape(Rectangle())
    }
    
    func sectionHeaderStyle() -> some View {
        self
            .font(WalletDesign.Typography.sectionHeader)
            .foregroundColor(.primary)
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.top, WalletDesign.Spacing.loose)
            .padding(.bottom, WalletDesign.Spacing.tight)
    }
    
    func shimmerEffect(isLoading: Bool) -> some View {
        self
            .overlay(
                WalletDesign.Colors.shimmer
                    .opacity(isLoading ? 1 : 0)
                    .animation(
                        isLoading
                            ? .linear(duration: 1.5).repeatForever(autoreverses: false)
                            : .default,
                        value: isLoading
                    )
            )
            .mask(self)
    }
    
}

// Note: Using HapticManager from DesignTokens.swift

// MARK: - Number Formatting
extension Double {
    func formatAsBalance() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        
        if self >= 1_000_000 {
            formatter.maximumFractionDigits = 1
            let millions = self / 1_000_000
            return "$\(formatter.string(from: NSNumber(value: millions)) ?? "0")M"
        } else if self >= 10_000 {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "$0"
        }
        
        return formatter.string(from: NSNumber(value: self)) ?? "$0"
    }
    
    func formatAsChange() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let sign = self >= 0 ? "+" : ""
        let percentage = abs(self)
        
        return "\(sign)\(formatter.string(from: NSNumber(value: percentage)) ?? "0")%"
    }
}

// MARK: - SF Symbols
struct WalletSymbols {
    static let send = "arrow.up.circle.fill"
    static let receive = "arrow.down.circle.fill"
    static let swap = "arrow.2.circlepath"
    static let history = "clock.arrow.circlepath"
    static let search = "magnifyingglass"
    static let filter = "line.3.horizontal.decrease.circle"
    static let qrCode = "qrcode"
    static let copy = "doc.on.doc"
    static let share = "square.and.arrow.up"
    static let checkmark = "checkmark.circle.fill"
    static let error = "exclamationmark.circle.fill"
    static let pending = "clock.fill"
    static let chainLink = "link.circle.fill"
    static let gas = "flame.fill"
    static let nft = "photo.fill"
    static let expand = "chevron.down"
    static let collapse = "chevron.up"
}