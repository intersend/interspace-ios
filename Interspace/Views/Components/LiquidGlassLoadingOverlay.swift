import SwiftUI

struct LiquidGlassLoadingOverlay: View {
    @State private var isAnimating = false
    var allowsInteraction: Bool = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all)
                .allowsHitTesting(!allowsInteraction)
            
            // Loading content
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Animated loading indicator
                ZStack {
                    Circle()
                        .stroke(DesignTokens.Colors.primary.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(DesignTokens.Colors.primary, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(
                            isAnimating ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                            value: isAnimating
                        )
                }
                
                Text("Loading...")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.xl)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.CornerRadius.lg))
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - Preview

struct LiquidGlassLoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea(.all)
            
            LiquidGlassLoadingOverlay()
        }
        .preferredColorScheme(.dark)
    }
}