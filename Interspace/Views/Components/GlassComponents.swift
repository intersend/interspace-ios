import SwiftUI

// MARK: - Glass Components Import
// This file serves as a central import point for all Glass components

// Re-export all Glass components for easy access
@_exported import struct LiquidWebView
@_exported import struct LiquidGlassEffect
@_exported import struct GlassProgressBar

// Re-export fluid transitions
@_exported import struct FluidWebTransition
@_exported import struct EnhancedAppIconTransition
@_exported import struct PullToDismissModifier

// MARK: - Glass Design Tokens
extension DesignTokens {
    struct Glass {
        static let ultraThin = GlassStyle.ultraThin
        static let thin = GlassStyle.thin
        static let regular = GlassStyle.regular
        static let thick = GlassStyle.thick
        static let prominent = GlassStyle.prominent
        
        static let defaultCornerRadius: CGFloat = 20
        static let compactBarHeight: CGFloat = 36
        static let expandedBarHeight: CGFloat = 44
        static let animationResponse: Double = 0.35
        static let animationDamping: Double = 0.85
    }
}

// MARK: - Convenience Extensions
extension View {
    /// Apply glass background with default settings
    func glassBackground(style: GlassStyle = .regular) -> some View {
        self.adaptiveLiquidGlass(style: style, cornerRadius: DesignTokens.Glass.defaultCornerRadius)
    }
    
    /// Apply glass navigation chrome
    func glassNavigation() -> some View {
        self.background(
            Color.clear
                .adaptiveLiquidGlass(style: .thin, cornerRadius: 0)
                .ignoresSafeArea()
        )
    }
}