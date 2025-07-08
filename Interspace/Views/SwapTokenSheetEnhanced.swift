import SwiftUI
import Combine

struct SwapTokenSheetEnhanced: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @StateObject private var viewModel = SwapTokenViewModel()
    
    @State private var fromToken: TokenBalance?
    @State private var toToken: TokenBalance?
    @State private var fromChainId: Int?
    @State private var toChainId: Int?
    @State private var fromAmount = ""
    @State private var toAmount = ""
    @State private var showFromTokenSelection = false
    @State private var showToTokenSelection = false
    @State private var isFlipped = false
    @State private var showSlippageSettings = false
    @State private var slippageTolerance = "0.5"
    @State private var showReview = false
    @State private var showMPCApproval = false
    @State private var pendingTransaction: MPCTransaction?
    @State private var routePreview: RouteVisualization?
    @State private var showSuccessAnimation = false
    @State private var headerScale: CGFloat = 0.8
    @State private var headerOpacity: Double = 0
    @State private var swapButtonRotation: Double = 0
    
    @FocusState private var amountFieldFocused: Bool
    @FocusState private var slippageFieldFocused: Bool
    
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var isFormValid: Bool {
        fromToken != nil &&
        toToken != nil &&
        !fromAmount.isEmpty &&
        (Double(fromAmount) ?? 0) > 0 &&
        viewModel.exchangeRate != nil
    }
    
    private var priceImpact: Double {
        viewModel.priceImpact ?? 0
    }
    
    private var isPriceImpactHigh: Bool {
        priceImpact > 3.0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with blur
                Color.black.ignoresSafeArea()
                    .overlay(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                            .ignoresSafeArea()
                    )
                
                if viewModel.isProcessing {
                    loadingOverlay
                }
                
                if showSuccessAnimation {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    SuccessAnimationView {
                        dismiss()
                    }
                }
                
                RubberBandScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Header Icon
                        headerIcon
                        
                        // Swap Card
                        swapCard
                        
                        // Exchange Rate Info
                        if viewModel.exchangeRate != nil {
                            exchangeRateCard
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .push(from: .top).combined(with: .opacity)
                                ))
                        }
                        
                        // Price Impact Warning
                        if isPriceImpactHigh {
                            priceImpactWarning
                                .transition(.push(from: .trailing).combined(with: .opacity))
                        }
                        
                        // Route Preview
                        if let route = routePreview {
                            routeVisualizationCard(route)
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .push(from: .top).combined(with: .opacity)
                                ))
                        }
                        
                        // Swap Button
                        swapButton
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    .padding(.vertical, DesignTokens.Spacing.sectionSpacing)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSlippageSettings.toggle()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .rotationEffect(.degrees(showSlippageSettings ? 90 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSlippageSettings)
                    }
                }
            }
        }
        .customSheet(isPresented: $showFromTokenSelection, detents: [.medium, .large]) {
            TokenSelectionView(
                selectedToken: $fromToken,
                selectedChainId: $fromChainId,
                tokens: walletViewModel.unifiedBalance?.tokens ?? []
            )
            .onDisappear {
                if fromToken != nil && fromAmount.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        amountFieldFocused = true
                    }
                }
                Task {
                    await viewModel.updateExchangeRate(
                        from: fromToken,
                        to: toToken,
                        amount: fromAmount
                    )
                }
            }
        }
        .customSheet(isPresented: $showToTokenSelection, detents: [.medium, .large]) {
            TokenSelectionView(
                selectedToken: $toToken,
                selectedChainId: $toChainId,
                tokens: getRecommendedTokens()
            )
            .onDisappear {
                Task {
                    await viewModel.updateExchangeRate(
                        from: fromToken,
                        to: toToken,
                        amount: fromAmount
                    )
                }
            }
        }
        .customSheet(isPresented: $showSlippageSettings, detents: [.medium]) {
            SlippageSettingsViewEnhanced(slippageTolerance: $slippageTolerance)
        }
        .customSheet(isPresented: $showReview, detents: [.large]) {
            SwapReviewSheetEnhanced(
                fromToken: fromToken!,
                toToken: toToken!,
                fromAmount: fromAmount,
                toAmount: toAmount,
                exchangeRate: viewModel.exchangeRate!,
                priceImpact: priceImpact,
                slippage: Double(slippageTolerance) ?? 0.5,
                viewModel: viewModel,
                onConfirm: { transaction in
                    pendingTransaction = transaction
                    showReview = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showMPCApproval = true
                    }
                }
            )
        }
        .customSheet(isPresented: $showMPCApproval, detents: [.medium]) {
            if let transaction = pendingTransaction {
                MPCTransactionApprovalView(
                    transaction: transaction,
                    onApprove: {
                        try await viewModel.executeTransaction(transaction: transaction)
                        HapticManager.shared.notification(type: .success)
                        showSuccessAnimation = true
                    },
                    onReject: {
                        pendingTransaction = nil
                        HapticManager.shared.notification(type: .warning)
                    }
                )
            }
        }
        .onAppear {
            Task {
                await viewModel.initialize(walletViewModel: walletViewModel)
                
                if let tokens = walletViewModel.unifiedBalance?.tokens,
                   let mostHeldToken = tokens.max(by: { $0.totalBalanceUSD < $1.totalBalanceUSD }) {
                    fromToken = mostHeldToken
                    if let chainBalance = mostHeldToken.chainBalances.max(by: { $0.balanceUSD < $1.balanceUSD }) {
                        fromChainId = chainBalance.chainId
                    }
                }
                
                if fromToken == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFromTokenSelection = true
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            Task {
                await viewModel.updateExchangeRate(
                    from: fromToken,
                    to: toToken,
                    amount: fromAmount
                )
            }
        }
        .onChange(of: fromAmount) { _, newValue in
            if let rate = viewModel.exchangeRate,
               let amount = Double(newValue),
               amount > 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    toAmount = String(format: "%.6f", amount * rate)
                }
            } else {
                toAmount = ""
            }
        }
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .transition(.opacity)
            .overlay {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Finding best route...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .shimmer()
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThinMaterial)
                )
                .scaleEffect(viewModel.isProcessing ? 1 : 0.8)
                .opacity(viewModel.isProcessing ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isProcessing)
            }
    }
    
    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 80, height: 80)
            
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 36))
                .foregroundColor(DesignTokens.Colors.primary)
                .rotationEffect(.degrees(isFlipped ? 180 : 0))
        }
        .scaleEffect(headerScale)
        .opacity(headerOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                headerScale = 1.0
                headerOpacity = 1.0
            }
        }
    }
    
    private var swapCard: some View {
        LiquidGlassCard {
            VStack(spacing: 0) {
                // From Token
                tokenInputSection(
                    label: "From",
                    token: fromToken,
                    chainId: fromChainId,
                    amount: $fromAmount,
                    isInput: true,
                    onTokenTap: {
                        showFromTokenSelection = true
                        HapticManager.shared.impact(style: .light)
                    }
                )
                .animatedListItem(index: 0)
                
                // Swap Direction Button
                Button {
                    swapTokens()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Material.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.primary)
                            .rotationEffect(.degrees(swapButtonRotation))
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .animatedButton()
                
                // To Token
                tokenInputSection(
                    label: "To",
                    token: toToken,
                    chainId: toChainId,
                    amount: $toAmount,
                    isInput: false,
                    onTokenTap: {
                        showToTokenSelection = true
                        HapticManager.shared.impact(style: .light)
                    }
                )
                .animatedListItem(index: 1)
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
    
    private func tokenInputSection(
        label: String,
        token: TokenBalance?,
        chainId: Int?,
        amount: Binding<String>,
        isInput: Bool,
        onTokenTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if let token = token, let chainId = chainId,
                   let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                    Text("Balance: \(WalletDesignSystem.formatTokenAmount(chainBalance.balance, decimals: token.decimals))")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: chainBalance.balance)
                }
            }
            
            HStack(spacing: DesignTokens.Spacing.md) {
                // Token Selection
                Button(action: onTokenTap) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if let token = token {
                            TokenIcon(symbol: token.symbol)
                                .frame(width: 36, height: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(token.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if let chainId = chainId,
                                   let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                                    Text(chainBalance.chainName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("Select")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .animatedButton()
                
                Spacer()
                
                // Amount Input
                VStack(alignment: .trailing, spacing: 4) {
                    if isInput {
                        TextField("0.0", text: amount)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($amountFieldFocused)
                            .disabled(!isInput)
                            .focusTransition { focused in
                                // Focus transition handled
                            }
                    } else {
                        if amount.wrappedValue.isEmpty {
                            Text("0.0")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        } else {
                            NumberTickerView(
                                value: Double(amount.wrappedValue) ?? 0,
                                format: "%.6f",
                                font: .system(size: 24, weight: .medium, design: .rounded),
                                color: .white.opacity(0.8)
                            )
                        }
                    }
                    
                    // USD Value
                    if let token = token, let amountDouble = Double(amount.wrappedValue), amountDouble > 0 {
                        let usdValue = amountDouble * (token.totalBalanceUSD / token.totalBalance)
                        NumberTickerView(
                            value: usdValue,
                            format: "≈ $%.2f",
                            font: .system(size: 12),
                            color: .white.opacity(0.5)
                        )
                    }
                }
                
                // Max Button
                if isInput, let token = token, let chainId = chainId,
                   let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            amount.wrappedValue = String(chainBalance.balance)
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text("MAX")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.Colors.primary.opacity(0.2))
                            )
                    }
                    .animatedButton()
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var exchangeRateCard: some View {
        LiquidGlassCard {
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Exchange Rate")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if viewModel.isUpdatingRate {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .transition(.opacity)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                HStack {
                    if let fromToken = fromToken, let toToken = toToken, let rate = viewModel.exchangeRate {
                        HStack(spacing: 4) {
                            Text("1 \(fromToken.symbol) =")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            NumberTickerView(
                                value: rate,
                                format: "%.6f",
                                font: .system(size: 16, weight: .medium),
                                color: DesignTokens.Colors.primary
                            )
                            
                            Text(toToken.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Update countdown
                    CountdownTimerView(
                        totalTime: 10,
                        startTime: viewModel.lastUpdateTime
                    )
                }
                
                if let priceImpact = viewModel.priceImpact {
                    HStack {
                        Text("Price Impact")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        NumberTickerView(
                            value: priceImpact,
                            format: "%.2f%%",
                            font: .system(size: 13, weight: .medium),
                            color: priceImpact > 3 ? .red : priceImpact > 1 ? .orange : .green
                        )
                    }
                    .transition(.push(from: .bottom).combined(with: .opacity))
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .animatedListItem(index: 2)
    }
    
    private var priceImpactWarning: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text("High price impact! Consider reducing the amount.")
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(Color.orange.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                        .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                )
        )
        .animatedListItem(index: 3)
    }
    
    private func routeVisualizationCard(_ route: RouteVisualization) -> some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Route")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Label("Best Route", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
                
                // Route visualization with animation
                HStack(spacing: 8) {
                    ForEach(route.steps.indices, id: \.self) { index in
                        let step = route.steps[index]
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(step.symbol)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .scaleEffect(1.2)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.1), value: true)
                            
                            if index < route.steps.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                    .transition(.push(from: .leading).combined(with: .opacity))
                            }
                        }
                    }
                }
                
                Text("via \(route.protocol)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(DesignTokens.Spacing.md)
        }
        .animatedListItem(index: 4)
    }
    
    private var swapButton: some View {
        Button {
            showReview = true
            HapticManager.shared.impact(style: .medium)
        } label: {
            HStack {
                if viewModel.isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Review Swap")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                    .fill(DesignTokens.Colors.primary.opacity(isFormValid && !viewModel.isBuilding ? 1 : 0.5))
            )
        }
        .disabled(!isFormValid || viewModel.isBuilding)
        .scaleEffect(isFormValid ? 1 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFormValid)
        .animatedListItem(index: 5)
    }
    
    private func swapTokens() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            let tempToken = fromToken
            let tempChainId = fromChainId
            let tempAmount = fromAmount
            
            fromToken = toToken
            fromChainId = toChainId
            fromAmount = toAmount
            
            toToken = tempToken
            toChainId = tempChainId
            toAmount = tempAmount
            
            isFlipped.toggle()
            swapButtonRotation += 180
            HapticManager.shared.impact(style: .medium)
        }
    }
    
    private func getRecommendedTokens() -> [TokenBalance] {
        guard let tokens = walletViewModel.unifiedBalance?.tokens else { return [] }
        
        return tokens
            .filter { $0.id != fromToken?.id }
            .sorted { $0.totalBalanceUSD > $1.totalBalanceUSD }
    }
}

// MARK: - Countdown Timer View
struct CountdownTimerView: View {
    let totalTime: TimeInterval
    let startTime: Date
    @State private var timeRemaining: TimeInterval = 0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text("Updates in \(Int(timeRemaining))s")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.5))
            .onReceive(timer) { _ in
                let elapsed = Date().timeIntervalSince(startTime)
                timeRemaining = max(0, totalTime - elapsed)
            }
    }
}

// MARK: - Enhanced Slippage Settings
struct SlippageSettingsViewEnhanced: View {
    @Binding var slippageTolerance: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var selectedPreset: String?
    
    let presetValues = ["0.1", "0.5", "1.0", "3.0"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Description
                    Text("Your transaction will revert if the price changes unfavorably by more than this percentage.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .animatedListItem(index: 0)
                    
                    // Preset Options
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Slippage Tolerance")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .animatedListItem(index: 1)
                        
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(Array(presetValues.enumerated()), id: \.element) { index, value in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        slippageTolerance = value
                                        selectedPreset = value
                                    }
                                    HapticManager.shared.impact(style: .light)
                                } label: {
                                    Text("\(value)%")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(slippageTolerance == value ? .white : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(slippageTolerance == value ? DesignTokens.Colors.primary : Color.white.opacity(0.1))
                                        )
                                }
                                .scaleEffect(slippageTolerance == value ? 1.1 : 1)
                                .animatedButton()
                                .animatedListItem(index: index + 2)
                            }
                        }
                    }
                    
                    // Custom Input
                    HStack {
                        TextField("0.0", text: $slippageTolerance)
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                            .multilineTextAlignment(.center)
                            .focusTransition { focused in
                                if focused {
                                    selectedPreset = nil
                                }
                            }
                        
                        Text("%")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                            .fill(Color.white.opacity(0.1))
                    )
                    .animatedListItem(index: 6)
                    
                    // Warning for high slippage
                    if let slippage = Double(slippageTolerance), slippage > 5 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("High slippage tolerance")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .transition(.push(from: .bottom).combined(with: .opacity))
                        .animatedListItem(index: 7)
                    }
                    
                    Spacer()
                }
                .padding(DesignTokens.Spacing.screenPadding)
            }
            .navigationTitle("Slippage Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            isInputFocused = true
            selectedPreset = presetValues.first { $0 == slippageTolerance }
        }
    }
}

// MARK: - Enhanced Swap Review Sheet
struct SwapReviewSheetEnhanced: View {
    let fromToken: TokenBalance
    let toToken: TokenBalance
    let fromAmount: String
    let toAmount: String
    let exchangeRate: Double
    let priceImpact: Double
    let slippage: Double
    @ObservedObject var viewModel: SwapTokenViewModel
    let onConfirm: (MPCTransaction) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                        // Transaction Icon
                        transactionIcon
                        
                        // Swap Summary
                        swapSummary
                        
                        // Transaction Details
                        transactionDetails
                        
                        // Confirm Button
                        confirmButton
                    }
                    .padding(DesignTokens.Spacing.screenPadding)
                    .padding(.bottom, DesignTokens.Spacing.sectionSpacing)
                }
            }
            .navigationTitle("Review Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isProcessing)
                }
            }
            .alert("Transaction Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var transactionIcon: some View {
        ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 100, height: 100)
            
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(DesignTokens.Colors.primary)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
    
    private var swapSummary: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // From
            HStack(spacing: DesignTokens.Spacing.sm) {
                TokenIcon(symbol: fromToken.symbol)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    NumberTickerView(
                        value: Double(fromAmount) ?? 0,
                        format: "%.6f",
                        font: .system(size: 24, weight: .bold, design: .rounded),
                        color: .white
                    )
                    
                    Text(fromToken.symbol)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            Image(systemName: "arrow.down")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.5))
                .rotationEffect(.degrees(0))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: true)
            
            // To
            HStack(spacing: DesignTokens.Spacing.sm) {
                TokenIcon(symbol: toToken.symbol)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    NumberTickerView(
                        value: Double(toAmount) ?? 0,
                        format: "%.6f",
                        font: .system(size: 24, weight: .bold, design: .rounded),
                        color: .white
                    )
                    
                    Text(toToken.symbol)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(Material.ultraThinMaterial)
        )
        .animatedListItem(index: 0)
    }
    
    private var transactionDetails: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            DetailRow(label: "Exchange Rate", value: "1 \(fromToken.symbol) = \(String(format: "%.6f", exchangeRate)) \(toToken.symbol)", isAddress: false)
            DetailRow(label: "Price Impact", value: "\(String(format: "%.2f", priceImpact))%", isAddress: false)
            DetailRow(label: "Slippage Tolerance", value: "\(String(format: "%.1f", slippage))%", isAddress: false)
            DetailRow(label: "Route", value: viewModel.bestRoute?.protocol ?? "Best Route", isAddress: false)
            DetailRow(label: "Network Fee", value: viewModel.bestRoute?.estimatedGas ?? "≈ $2.50", isAddress: false)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(Material.ultraThinMaterial)
        )
        .animatedListItem(index: 1)
    }
    
    private var confirmButton: some View {
        Button {
            Task {
                isProcessing = true
                defer { isProcessing = false }
                
                do {
                    let transaction = try await viewModel.buildSwapTransaction(
                        fromToken: fromToken,
                        fromChainId: fromToken.chainBalances.first?.chainId ?? 1,
                        toToken: toToken,
                        toChainId: toToken.chainBalances.first?.chainId ?? 1,
                        fromAmount: fromAmount,
                        toAmount: toAmount,
                        slippage: slippage
                    )
                    
                    await onConfirm(transaction)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.shared.notification(type: .error)
                }
            }
        } label: {
            HStack {
                if isProcessing || viewModel.isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("Building transaction...")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.leading, 8)
                        .shimmer()
                } else {
                    Text("Confirm Swap")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                    .fill(DesignTokens.Colors.primary.opacity(isProcessing || viewModel.isBuilding ? 0.6 : 1))
            )
        }
        .disabled(isProcessing || viewModel.isBuilding)
        .scaleEffect(isProcessing || viewModel.isBuilding ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isProcessing || viewModel.isBuilding)
        .animatedListItem(index: 2)
    }
}