import SwiftUI
import Combine

// WalletTransactionError is defined in WalletErrors.swift
// TokenBalance and ChainBalance type aliases are defined in WalletModels.swift

struct SwapTokenSheetBase: View {
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
    
    @FocusState private var amountFieldFocused: Bool
    @FocusState private var slippageFieldFocused: Bool
    
    // Real-time exchange rate timer
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
        priceImpact > 3.0 // 3% threshold
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if viewModel.isProcessing {
                    loadingOverlay
                }
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Header Icon
                        headerIcon
                        
                        // Swap Card
                        swapCard
                        
                        // Exchange Rate Info
                        if viewModel.exchangeRate != nil {
                            exchangeRateCard
                        }
                        
                        // Price Impact Warning
                        if isPriceImpactHigh {
                            priceImpactWarning
                        }
                        
                        // Route Preview
                        if let route = routePreview {
                            routeVisualizationCard(route)
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
                    }
                }
            }
        }
        .sheet(isPresented: $showFromTokenSelection) {
            TokenSelectionView(
                selectedToken: $fromToken,
                selectedChainId: $fromChainId,
                tokens: walletViewModel.unifiedBalance?.unifiedBalance.tokens ?? []
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
        .sheet(isPresented: $showToTokenSelection) {
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
        .sheet(isPresented: $showSlippageSettings) {
            SlippageSettingsView(slippageTolerance: $slippageTolerance)
        }
        .sheet(isPresented: $showReview) {
            SwapReviewSheet(
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
        .sheet(isPresented: $showMPCApproval) {
            if let transaction = pendingTransaction {
                MPCTransactionApprovalView(
                    transaction: transaction,
                    onApprove: {
                        try await viewModel.executeTransaction(transaction: transaction)
                        HapticManager.shared.notification(type: .success)
                        dismiss()
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
                
                // Auto-select most held token
                if let tokens = walletViewModel.unifiedBalance?.unifiedBalance.tokens,
                   let mostHeldToken = tokens.max(by: { $0.totalBalanceUSD < $1.totalBalanceUSD }) {
                    fromToken = mostHeldToken
                    if let chainBalance = mostHeldToken.chainBalances.max(by: { $0.balanceUSD < $1.balanceUSD }) {
                        fromChainId = chainBalance.chainId
                    }
                }
                
                // Show token selection if no token selected
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
        .onChange(of: fromAmount) { newValue in
            if let rate = viewModel.exchangeRate,
               let amount = Double(newValue),
               amount > 0 {
                toAmount = String(format: "%.6f", amount * rate)
            } else {
                toAmount = ""
            }
        }
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Finding best route...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThinMaterial)
                )
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
    }
    
    private var swapCard: some View {
        VStack {
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
                            .rotationEffect(.degrees(isFlipped ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFlipped)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                
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
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
                    } else {
                        Text(amount.wrappedValue.isEmpty ? "0.0" : amount.wrappedValue)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // USD Value
                    if let token = token, let amountDouble = Double(amount.wrappedValue), amountDouble > 0 {
                        let usdValue = amountDouble * (token.totalBalanceUSD / token.totalBalance)
                        Text("≈ \(WalletDesignSystem.formatCurrency(usdValue))")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Max Button
                if isInput, let token = token, let chainId = chainId,
                   let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                    Button {
                        amount.wrappedValue = String(chainBalance.balance)
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
        VStack {
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Exchange Rate")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if viewModel.isUpdatingRate {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    if let fromToken = fromToken, let toToken = toToken, let rate = viewModel.exchangeRate {
                        Text("1 \(fromToken.symbol) = \(String(format: "%.6f", rate)) \(toToken.symbol)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Update countdown
                    Text("Updates in \(10 - Int(Date().timeIntervalSince(viewModel.lastUpdateTime)))s")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                if let priceImpact = viewModel.priceImpact {
                    HStack {
                        Text("Price Impact")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text("\(String(format: "%.2f", priceImpact))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(priceImpact > 3 ? .red : priceImpact > 1 ? .orange : .green)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
    }
    
    private func routeVisualizationCard(_ route: RouteVisualization) -> some View {
        VStack {
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
                
                // Route visualization
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
                            
                            if index < route.steps.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
                
                Text("via \(route.`protocol`)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
    }
    
    // MARK: - Helper Methods
    
    private func swapTokens() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
            HapticManager.shared.impact(style: .medium)
        }
    }
    
    private func getRecommendedTokens() -> [TokenBalance] {
        guard let tokens = walletViewModel.unifiedBalance?.unifiedBalance.tokens else { return [] }
        
        // Filter out the from token and sort by portfolio value
        return tokens
            .filter { $0.id != fromToken?.id }
            .sorted { $0.totalBalanceUSD > $1.totalBalanceUSD }
    }
}

// MARK: - Swap View Model

@MainActor
class SwapTokenViewModel: ObservableObject {
    @Published var exchangeRate: Double?
    @Published var priceImpact: Double?
    @Published var isUpdatingRate = false
    @Published var isBuilding = false
    @Published var isProcessing = false
    @Published var error: String?
    @Published var lastUpdateTime = Date()
    @Published var bestRoute: RouteInfo?
    
    private let walletAPI = WalletAPI.shared
    // TODO: Replace with actual MPCWalletService when available
    private var profileId: String?
    private var currentIntent: IntentResponse?
    
    func initialize(walletViewModel: WalletViewModel) async {
        if let activeProfile = ProfileViewModel.shared.activeProfile {
            self.profileId = activeProfile.id
        }
    }
    
    func updateExchangeRate(from: TokenBalance?, to: TokenBalance?, amount: String) async {
        guard let from = from, let to = to, !amount.isEmpty else { return }
        
        isUpdatingRate = true
        defer { 
            isUpdatingRate = false
            lastUpdateTime = Date()
        }
        
        // Simulated exchange rate calculation
        // In production, this would call an API to get real rates
        let mockRate = 1.0 + (Double.random(in: -0.05...0.05))
        exchangeRate = mockRate
        
        // Calculate price impact based on amount
        if let amountDouble = Double(amount) {
            let marketDepth = 100000.0 // Mock market depth
            priceImpact = (amountDouble / marketDepth) * 100
        }
        
        // Simulate best route finding
        bestRoute = RouteInfo(
            protocol: "Uniswap V3",
            estimatedGas: "$2.50",
            steps: [from.symbol, to.symbol]
        )
    }
    
    func buildSwapTransaction(
        fromToken: TokenBalance,
        fromChainId: Int,
        toToken: TokenBalance,
        toChainId: Int,
        fromAmount: String,
        toAmount: String,
        slippage: Double
    ) async throws -> MPCTransaction {
        guard let profileId = profileId else {
            throw WalletTransactionError.profileNotFound
        }
        
        isBuilding = true
        defer { isBuilding = false }
        
        // Convert amounts to smallest unit
        let fromAmountWei = convertToSmallestUnit(amount: fromAmount, decimals: fromToken.decimals)
        let toAmountWei = convertToSmallestUnit(amount: toAmount, decimals: toToken.decimals)
        
        // Calculate minimum amount with slippage
        let minAmountOut = calculateMinAmountWithSlippage(amount: toAmountWei, slippage: slippage)
        
        // Build swap intent
        let intentRequest = CreateIntentRequest(
            type: "SWAP",
            from: CreateIntentRequest.TokenEndpoint(
                token: fromToken.symbol,
                chainId: fromChainId,
                amount: fromAmountWei,
                address: nil
            ),
            to: CreateIntentRequest.TokenEndpoint(
                token: toToken.symbol,
                chainId: toChainId,
                amount: minAmountOut,
                address: nil
            ),
            gasToken: nil // Auto-select gas token
        )
        
        // Create intent with Orby
        let intentResponse = try await walletAPI.createIntent(
            profileId: profileId,
            request: intentRequest
        )
        
        self.currentIntent = intentResponse
        
        // Get the first unsigned operation
        guard let operation = intentResponse.data.unsignedOperations.intents.first else {
            throw WalletTransactionError.noOperationsFound
        }
        
        // Create MPCTransaction for approval
        let transaction = MPCTransaction(
            id: intentResponse.data.intentId,
            type: .swap,
            status: .pending,
            from: ProfileViewModel.shared.activeProfile?.sessionWalletAddress ?? "",
            to: operation.to,
            value: operation.value,
            tokenSymbol: fromToken.symbol,
            chainId: fromChainId,
            unsignedData: operation.data
        )
        
        return transaction
    }
    
    func executeTransaction(transaction: MPCTransaction) async throws {
        guard let profileId = profileId,
              let intent = currentIntent else {
            throw WalletTransactionError.missingTransactionData
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Sign operations with MPC
        var signedOperations: [SignedOperation] = []
        
        for (index, operation) in intent.data.unsignedOperations.intents.enumerated() {
            let txRequest = TransactionRequest(
                hash: Data(hex: operation.data) ?? Data(),
                chainPath: "m/44'/60'/0'/0/0",
                value: operation.value,
                to: operation.to,
                data: operation.data
            )
            
            // TODO: Replace with actual MPC signing when MPCWalletService is available
            let signature = "mock_signature_\(index)"
            
            signedOperations.append(SignedOperation(
                index: index,
                signature: signature,
                signedData: operation.data
            ))
        }
        
        // Submit signed operations
        _ = try await walletAPI.submitSignedOperations(
            operationSetId: intent.data.operationSetId,
            signedOperations: signedOperations
        )
    }
    
    // MARK: - Helper Methods
    
    private func convertToSmallestUnit(amount: String, decimals: Int) -> String {
        guard let amountDouble = Double(amount) else { return "0" }
        let multiplier = pow(10.0, Double(decimals))
        let result = amountDouble * multiplier
        return String(format: "%.0f", result)
    }
    
    private func calculateMinAmountWithSlippage(amount: String, slippage: Double) -> String {
        guard let amountDouble = Double(amount) else { return "0" }
        let minAmount = amountDouble * (1 - slippage / 100)
        return String(format: "%.0f", minAmount)
    }
    
    private func getNetworkName(chainId: Int) -> String {
        switch chainId {
        case 1: return "Ethereum"
        case 137: return "Polygon"
        case 10: return "Optimism"
        case 42161: return "Arbitrum"
        case 8453: return "Base"
        default: return "Chain \(chainId)"
        }
    }
}

// MARK: - Supporting Views

struct SlippageSettingsView: View {
    @Binding var slippageTolerance: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
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
                    
                    // Preset Options
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Slippage Tolerance")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(presetValues, id: \.self) { value in
                                Button {
                                    slippageTolerance = value
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
                        
                        Text("%")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Warning for high slippage
                    if let slippage = Double(slippageTolerance), slippage > 5 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("High slippage tolerance")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
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
        }
    }
}

struct SwapReviewSheet: View {
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
    }
    
    private var swapSummary: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // From
            HStack(spacing: DesignTokens.Spacing.sm) {
                TokenIcon(symbol: fromToken.symbol)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(fromAmount)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(fromToken.symbol)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            Image(systemName: "arrow.down")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.5))
            
            // To
            HStack(spacing: DesignTokens.Spacing.sm) {
                TokenIcon(symbol: toToken.symbol)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toAmount)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
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
    }
    
    private var transactionDetails: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            SwapDetailRow(label: "Exchange Rate", value: "1 \(fromToken.symbol) = \(String(format: "%.6f", exchangeRate)) \(toToken.symbol)", isAddress: false)
            SwapDetailRow(label: "Price Impact", value: "\(String(format: "%.2f", priceImpact))%", isAddress: false)
            SwapDetailRow(label: "Slippage Tolerance", value: "\(String(format: "%.1f", slippage))%", isAddress: false)
            SwapDetailRow(label: "Route", value: viewModel.bestRoute?.protocol ?? "Best Route", isAddress: false)
            SwapDetailRow(label: "Network Fee", value: viewModel.bestRoute?.estimatedGas ?? "≈ $2.50", isAddress: false)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(Material.ultraThinMaterial)
        )
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
    }
}

// MARK: - Models

struct RouteVisualization {
    let steps: [RouteStep]
    let `protocol`: String
    
    struct RouteStep {
        let symbol: String
        let chainId: Int
    }
}

struct RouteInfo {
    let `protocol`: String
    let estimatedGas: String
    let steps: [String]
}

struct SwapDetailRow: View {
    let label: String
    let value: String
    let isAddress: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            if isAddress {
                Text(value.prefix(6) + "..." + value.suffix(4))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SwapTokenSheetBase()
        .environmentObject(WalletViewModel())
}