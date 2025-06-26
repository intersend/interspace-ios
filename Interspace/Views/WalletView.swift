import SwiftUI

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var showTransactionHistory = false
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var selectedToken: UnifiedBalance.TokenBalance?
    @State private var showSettings = false
    @State private var showUniversalAddTray = false
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    
    var body: some View {
        ScrollView {
            if viewModel.unifiedBalance == nil && !viewModel.isLoading {
                // Empty State or Guest State
                VStack(spacing: 0) {
                    // Content at top
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        if AuthenticationManagerV2.shared.currentUser?.isGuest == true {
                            GuestWalletState()
                        } else {
                            EmptyWalletState()
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    .padding(.top, 80)
                    
                    Spacer(minLength: UIScreen.main.bounds.height - 400)
                }
                .frame(maxWidth: .infinity)
            } else {
                // Main wallet content - extract from mainContentView
                LazyVStack(spacing: DesignTokens.Spacing.lg) {
                    // Header with Profile Info
                    if let balance = viewModel.unifiedBalance {
                        ProfileHeaderView(balance: balance)
                            .padding(.top, DesignTokens.Spacing.md)
                    }
                    
                    // Total Balance Card
                    if let balance = viewModel.unifiedBalance {
                        TotalBalanceCard(balance: balance) {
                            showTransactionHistory = true
                        }
                    }
                    
                    // Quick Actions
                    QuickActionsRow(
                        onSend: { showSendSheet = true },
                        onReceive: { showReceiveSheet = true },
                        onScan: { /* QR Scanner */ },
                        onSwap: { /* Swap functionality */ }
                    )
                    
                    // Gas Analysis
                    if let gasAnalysis = viewModel.unifiedBalance?.gasAnalysis {
                        GasAnalysisCard(gasAnalysis: gasAnalysis)
                    }
                    
                    // Token List
                    if let tokens = viewModel.unifiedBalance?.unifiedBalance.tokens {
                        TokenListSection(
                            tokens: tokens,
                            onTokenTap: { token in
                                selectedToken = token
                            }
                        )
                    }
                    
                    Spacer(minLength: DesignTokens.Spacing.xxxl)
                }
            }
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .refreshable {
            await viewModel.refreshBalance()
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    LiquidGlassLoadingOverlay()
                }
            }
        )
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                StandardToolbarButtons(
                    showUniversalAddTray: $showUniversalAddTray,
                    showAbout: $showAbout,
                    showSecurity: $showSecurity,
                    showNotifications: $showNotifications,
                    initialSection: .wallet
                )
            }
        }
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(isPresented: $showUniversalAddTray, initialSection: .wallet)
        }
        .sheet(isPresented: $showAbout) {
            ProfileAboutView()
        }
        .sheet(isPresented: $showSecurity) {
            ProfileSecurityView(showDeleteConfirmation: .constant(false))
        }
        .sheet(isPresented: $showNotifications) {
            ProfileNotificationsView()
        }
        .sheet(isPresented: $showTransactionHistory) {
            Text("Transaction History - Coming Soon")
        }
        .sheet(isPresented: $showSendSheet) {
            Text("Send Tokens - Coming Soon")
        }
        .sheet(isPresented: $showReceiveSheet) {
            Text("Receive Tokens - Coming Soon")
        }
        .sheet(item: $selectedToken) { token in
            Text("Token Detail - Coming Soon")
        }
        .onAppear {
            Task {
                // Initialize wallet services lazily when wallet tab is accessed
                await ServiceInitializer.shared.wallet.initializeSDKsIfNeeded()
                await viewModel.loadBalance()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let balance: UnifiedBalance
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good morning")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Text(balance.profileName)
                        .font(DesignTokens.Typography.headlineLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Profile Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.Colors.primary, DesignTokens.Colors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(balance.profileName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: DesignTokens.Colors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
}

// MARK: - Total Balance Card

struct TotalBalanceCard: View {
    let balance: UnifiedBalance
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Total Balance")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Text("$\(formatCurrency(balance.unifiedBalance.totalUsdValue))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .animation(.spring(response: 0.6), value: balance.unifiedBalance.totalUsdValue)
                }
                
                HStack(spacing: DesignTokens.Spacing.md) {
                    BalanceChangeIndicator(change: "+$1,234.56", isPositive: true)
                    
                    Spacer()
                    
                    Text("\(balance.unifiedBalance.tokens.count) Assets")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.GlassEffect.thin)
            .cornerRadius(DesignTokens.CornerRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
    
    private func formatCurrency(_ value: String) -> String {
        if let doubleValue = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: doubleValue)) ?? value
        }
        return value
    }
}

// MARK: - Balance Change Indicator

struct BalanceChangeIndicator: View {
    let change: String
    let isPositive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
            
            Text(change)
                .font(DesignTokens.Typography.labelMedium)
        }
        .foregroundColor(isPositive ? DesignTokens.Colors.success : DesignTokens.Colors.error)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            (isPositive ? DesignTokens.Colors.success : DesignTokens.Colors.error)
                .opacity(0.1)
        )
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

// MARK: - Quick Actions

struct QuickActionsRow: View {
    let onSend: () -> Void
    let onReceive: () -> Void
    let onScan: () -> Void
    let onSwap: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            QuickActionButton(
                title: "Send",
                icon: "arrow.up.circle.fill",
                color: DesignTokens.Colors.primary,
                action: onSend
            )
            
            QuickActionButton(
                title: "Receive",
                icon: "arrow.down.circle.fill",
                color: DesignTokens.Colors.success,
                action: onReceive
            )
            
            QuickActionButton(
                title: "Scan",
                icon: "qrcode.viewfinder",
                color: DesignTokens.Colors.textSecondary,
                action: onScan
            )
            
            QuickActionButton(
                title: "Swap",
                icon: "arrow.left.arrow.right.circle.fill",
                color: Color.orange,
                action: onSwap
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Gas Analysis Card

struct GasAnalysisCard: View {
    let gasAnalysis: UnifiedBalance.GasAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(DesignTokens.Colors.primary)
                
                Text("Gas Analysis")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Spacer()
            }
            
            if let suggestedToken = gasAnalysis.suggestedGasToken {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested Gas Token")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        Text(suggestedToken.symbol)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("Score: \(suggestedToken.score)")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.success)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.success.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                }
            }
            
            if !gasAnalysis.nativeGasAvailable.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Available Gas")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    ForEach(gasAnalysis.nativeGasAvailable.prefix(3), id: \.chainId) { gas in
                        HStack {
                            Text(gas.symbol)
                                .font(DesignTokens.Typography.labelMedium)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text(formatAmount(gas.amount))
                                .font(DesignTokens.Typography.labelMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
    
    private func formatAmount(_ amount: String) -> String {
        if let doubleValue = Double(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 4
            return formatter.string(from: NSNumber(value: doubleValue)) ?? amount
        }
        return amount
    }
}

// MARK: - Token List Section

struct TokenListSection: View {
    let tokens: [UnifiedBalance.TokenBalance]
    let onTokenTap: (UnifiedBalance.TokenBalance) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Assets")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Spacer()
                
                Text("\(tokens.count) tokens")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
            
            LazyVStack(spacing: 0) {
                ForEach(Array(tokens.enumerated()), id: \.element.standardizedTokenId) { index, token in
                    TokenRow(
                        token: token,
                        isLast: index == tokens.count - 1
                    ) {
                        onTokenTap(token)
                    }
                }
            }
            .background(DesignTokens.GlassEffect.ultraThin)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
            )
            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
        }
    }
}

// MARK: - Token Row

struct TokenRow: View {
    let token: UnifiedBalance.TokenBalance
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Token Icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text(token.symbol.prefix(1))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
                
                // Token Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.name)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(token.balancesPerChain.count) networks")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                // Balance Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(formatCurrency(token.totalUsdValue))")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(formatTokenAmount(token.totalAmount, decimals: token.decimals))
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSecondary)
                    .frame(height: 0.5)
                    .padding(.leading, 68)
            }
        }
    }
    
    private func formatCurrency(_ value: String) -> String {
        if let doubleValue = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: doubleValue)) ?? value
        }
        return value
    }
    
    private func formatTokenAmount(_ amount: String, decimals: Int) -> String {
        if let doubleValue = Double(amount) {
            let adjustedValue = doubleValue / pow(10, Double(decimals))
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = min(6, decimals)
            return formatter.string(from: NSNumber(value: adjustedValue)) ?? amount
        }
        return amount
    }
}

// MARK: - Empty State

struct EmptyWalletState: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Your Wallet is Empty")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text("Connect your accounts to see your crypto balance")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Connect Accounts") {
                // Navigate to account linking
            }
            .font(DesignTokens.Typography.buttonMedium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.primary)
            .cornerRadius(DesignTokens.CornerRadius.button)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
}

// MARK: - Guest Wallet State

struct GuestWalletState: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Guest Mode")
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text("Sign in with your wallet to see your crypto balance and transaction history")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Connect Wallet") {
                // Navigate to wallet connection
            }
            .font(DesignTokens.Typography.buttonMedium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.primary)
            .cornerRadius(DesignTokens.CornerRadius.button)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
}

// MARK: - Preview

struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView()
            .preferredColorScheme(.dark)
    }
}