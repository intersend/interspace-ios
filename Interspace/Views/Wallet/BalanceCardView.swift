import SwiftUI

struct BalanceCardView: View {
    let balance: UnifiedBalance
    let namespace: Namespace.ID
    let scrollOffset: CGFloat
    let onTransactionsTap: () -> Void
    
    @State private var isExpanded = false
    @State private var isPressed = false
    @State private var displayedBalance: Double = 0
    @State private var balanceChange: Double = 0
    @State private var changePercentage: Double = 0
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var numberScale: CGFloat = 1.0
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                HapticManager.impact(.medium)
                isExpanded.toggle()
            }
        }) {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedView
                } else {
                    collapsedView
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            animateBalance()
            startShimmerAnimation()
        }
    }
    
    // MARK: - Collapsed View
    
    private var collapsedView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Total Balance")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    // Animated balance
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text(formatBalance(displayedBalance))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .scaleEffect(numberScale)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: numberScale)
                    }
                }
                
                Spacer()
                
                // Change indicator
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: changePercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(changePercentage >= 0 ? 0 : 0))
                        
                        Text("\(abs(changePercentage), specifier: "%.2f")%")
                            .font(DesignTokens.Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(changePercentage >= 0 ? DesignTokens.Colors.success : DesignTokens.Colors.error)
                    
                    Text("24h")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            
            // Stats row
            HStack(spacing: DesignTokens.Spacing.md) {
                StatChip(
                    icon: "banknote",
                    value: "\(balance.unifiedBalance.tokens.count)",
                    label: "Assets"
                )
                
                StatChip(
                    icon: "link.circle.fill",
                    value: "\(countChains())",
                    label: "Chains"
                )
                
                Spacer()
                
                // View transactions button
                Button(action: onTransactionsTap) {
                    HStack(spacing: 4) {
                        Text("History")
                            .font(DesignTokens.Typography.labelMedium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(height: 180)
        .background(cardBackground)
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .overlay(shimmerOverlay)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header with balance
            collapsedView
            
            // Portfolio breakdown
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text("Portfolio Breakdown")
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Spacer()
                }
                
                // Token allocation chart placeholder
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.GlassEffect.ultraThin)
                    .frame(height: 200)
                    .overlay(
                        Text("Chart Coming Soon")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    )
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .background(cardBackground)
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl)
                .fill(DesignTokens.GlassEffect.regular)
            
            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: DesignTokens.Colors.primary.opacity(0.1), location: 0),
                    .init(color: DesignTokens.Colors.primary.opacity(0.05), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(DesignTokens.CornerRadius.xl)
            
            // Border
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    // MARK: - Shimmer Overlay
    
    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.3)
            .offset(x: geometry.size.width * shimmerPhase)
            .animation(
                Animation.linear(duration: 2.5)
                    .repeatForever(autoreverses: false),
                value: shimmerPhase
            )
        }
        .cornerRadius(DesignTokens.CornerRadius.xl)
        .allowsHitTesting(false)
    }
    
    // MARK: - Helper Methods
    
    private func formatBalance(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    private func countChains() -> Int {
        var uniqueChains = Set<Int>()
        for token in balance.unifiedBalance.tokens {
            for chainBalance in token.balancesPerChain {
                uniqueChains.insert(chainBalance.chainId)
            }
        }
        return uniqueChains.count
    }
    
    private func animateBalance() {
        guard let totalValue = Double(balance.unifiedBalance.totalUsdValue) else { return }
        
        // Animate from 0 to actual value
        withAnimation(.easeOut(duration: 1.0)) {
            displayedBalance = totalValue
        }
        
        // Simulate balance change (in production, this would come from API)
        balanceChange = totalValue * 0.0234 // +2.34%
        changePercentage = 2.34
        
        // Pulse animation on value change
        numberScale = 1.05
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            numberScale = 1.0
        }
    }
    
    private func startShimmerAnimation() {
        shimmerPhase = -1.0
        withAnimation {
            shimmerPhase = 2.0
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.primary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignTokens.Colors.fillTertiary)
        )
    }
}

// MARK: - Preview

struct BalanceCardView_Previews: PreviewProvider {
    @Namespace static var namespace
    
    static var previews: some View {
        ZStack {
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            BalanceCardView(
                balance: UnifiedBalance(
                    profileId: "123",
                    profileName: "Main Wallet",
                    unifiedBalance: UnifiedBalance.BalanceData(
                        totalUsdValue: "25431.67",
                        tokens: []
                    ),
                    gasAnalysis: UnifiedBalance.GasAnalysis(
                        suggestedGasToken: nil,
                        nativeGasAvailable: [],
                        availableGasTokens: []
                    )
                ),
                namespace: namespace,
                scrollOffset: 0,
                onTransactionsTap: {}
            )
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}