import SwiftUI
import Combine
import Foundation

// TokenBalance and ChainBalance are defined in WalletModels.swift

struct SendTokenSheetBase: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @StateObject private var viewModel = SendTokenViewModel()
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    
    @State private var selectedToken: TokenBalance?
    @State private var selectedChainId: Int?
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var showTokenSelection = false
    @State private var showQRScanner = false
    @State private var showGasTokenSelection = false
    @State private var isValidatingAddress = false
    @State private var addressValidationError: String?
    @State private var showTransactionReview = false
    @State private var showMPCApproval = false
    @State private var pendingTransaction: MPCTransaction?
    @State private var pendingTransactionToSign: TransactionToSign?
    @State private var showTransactionComplete = false
    
    @FocusState private var amountFieldFocused: Bool
    @FocusState private var addressFieldFocused: Bool
    
    private var isFormValid: Bool {
        !recipientAddress.isEmpty &&
        !amount.isEmpty &&
        selectedToken != nil &&
        addressValidationError == nil &&
        (Double(amount) ?? 0) > 0
    }
    
    private var maxSendableAmount: Double {
        guard let token = selectedToken,
              let chainId = selectedChainId,
              let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) else {
            return 0
        }
        // Reserve some for gas
        let gasReserve = token.symbol.lowercased() == "eth" ? 0.005 : 0
        return max(0, chainBalance.balance - gasReserve)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Send")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
        }
        .sheet(isPresented: $showTokenSelection) {
            tokenSelectionSheet
        }
        .sheet(isPresented: $showQRScanner) {
            qrScannerSheet
        }
        .sheet(isPresented: $showGasTokenSelection) {
            gasTokenSelectionSheet
        }
        .sheet(isPresented: $showTransactionReview) {
            transactionReviewSheet
        }
        .sheet(isPresented: $showMPCApproval) {
            mpcApprovalSheet
        }
        .sheet(isPresented: $showTransactionComplete) {
            transactionCompleteSheet
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .overlay {
            loadingOverlay
        }
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: showTokenSelection) { _ in
            handleTokenSelectionChange()
        }
        .onChange(of: viewModel.transactionCompleted) { completed in
            if completed {
                showTransactionComplete = true
                viewModel.transactionCompleted = false // Reset for next time
            }
        }
        .onChange(of: selectedToken?.id) { _ in
            handleSelectedTokenChange()
        }
        .onChange(of: showQRScanner) { _ in
            handleQRScannerChange()
        }
        .onChange(of: recipientAddress) { _ in
            if !recipientAddress.isEmpty && amount.isEmpty {
                // Auto-focus amount field when address is entered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    amountFieldFocused = true
                }
            }
        }
    } // End of body
    
    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 80, height: 80)
            
            Image(systemName: "paperplane.fill")
                .font(.system(size: 36))
                .foregroundColor(DesignTokens.Colors.primary)
                .rotationEffect(.degrees(-45))
        }
    }
    
    private var tokenSelectionCard: some View {
        Button {
            showTokenSelection = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                if let token = selectedToken {
                    TokenIcon(symbol: token.symbol)
                        .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(token.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let chainId = selectedChainId,
                           let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                            Text(chainBalance.chainName)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(WalletDesignSystem.formatCurrency(selectedToken?.totalBalanceUSD ?? 0))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Balance")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Select Token")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .liquidGlassCard()
    }
    
    private var recipientAddressCard: some View {
        Group {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Recipient")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if isValidatingAddress {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let error = addressValidationError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: DesignTokens.Spacing.sm) {
                    TextField("0x...", text: $recipientAddress)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.white)
                        .focused($addressFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: recipientAddress) { _ in
                            validateAddress()
                        }
                    
                    Button {
                        showQRScanner = true
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Colors.primary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .liquidGlassCard()
    }
    
    private var amountInputCard: some View {
        Group {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text("Amount")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if let token = selectedToken, let chainId = selectedChainId,
                       let chainBalance = token.chainBalances.first(where: { $0.chainId == chainId }) {
                        Text("Available: \(WalletDesignSystem.formatTokenAmount(chainBalance.balance, decimals: token.decimals)) \(token.symbol)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                HStack(spacing: DesignTokens.Spacing.sm) {
                    TextField("0.0", text: $amount)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .focused($amountFieldFocused)
                    
                    Spacer()
                    
                    if let token = selectedToken {
                        Text(token.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button {
                        amount = String(maxSendableAmount)
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text("MAX")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.Colors.primary.opacity(0.2))
                            )
                    }
                    .disabled(selectedToken == nil)
                }
                
                // USD Value
                if let token = selectedToken, let amountDouble = Double(amount), amountDouble > 0 {
                    let usdValue = amountDouble * (token.totalBalanceUSD / token.totalBalance)
                    Text("≈ \(WalletDesignSystem.formatCurrency(usdValue))")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .liquidGlassCard()
    }
    
    private var gasTokenCard: some View {
        Button {
            showGasTokenSelection = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gas Token")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let gasToken = viewModel.selectedGasToken {
                        HStack(spacing: 4) {
                            Text(gasToken.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            if gasToken.isAISelected {
                                Text("AI Selected")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DesignTokens.Colors.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(DesignTokens.Colors.primary.opacity(0.2))
                                    )
                            }
                        }
                    } else {
                        Text("Auto (Recommended)")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                if viewModel.estimatedGasFee > 0 {
                    Text("≈ \(WalletDesignSystem.formatCurrency(viewModel.estimatedGasFee))")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(DesignTokens.Spacing.md)
        }
        .liquidGlassCard()
    }
    
    private var transactionSummary: some View {
        Group {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text("Transaction Summary")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                
                VStack(spacing: DesignTokens.Spacing.sm) {
                    summaryRow(label: "Network Fee", value: "≈ \(WalletDesignSystem.formatCurrency(viewModel.estimatedGasFee))")
                    summaryRow(label: "Total", value: "≈ \(WalletDesignSystem.formatCurrency(getTotalUSDValue()))")
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .liquidGlassCard()
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private func validateAddress() {
        guard !recipientAddress.isEmpty else {
            addressValidationError = nil
            return
        }
        
        isValidatingAddress = true
        addressValidationError = nil
        
        // Basic Ethereum address validation
        let isValid = recipientAddress.hasPrefix("0x") && 
                     recipientAddress.count == 42 &&
                     recipientAddress.range(of: "^0x[a-fA-F0-9]{40}$", options: .regularExpression) != nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isValidatingAddress = false
            if !isValid && !recipientAddress.isEmpty {
                addressValidationError = "Invalid address"
            }
        }
    }
    
    private func getTotalUSDValue() -> Double {
        guard let token = selectedToken,
              let amountDouble = Double(amount) else { return 0 }
        
        let tokenUSDValue = amountDouble * (token.totalBalanceUSD / token.totalBalance)
        return tokenUSDValue + viewModel.estimatedGasFee
    }
    
    // MARK: - Extracted View Components
    
    private var mainContent: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header Icon
                    headerIcon
                    
                    // Token Selection
                    tokenSelectionCard
                    
                    // Recipient Address
                    recipientAddressCard
                    
                    // Amount Input
                    amountInputCard
                    
                    // Gas Token Selection
                    gasTokenCard
                    
                    // Summary
                    if isFormValid {
                        transactionSummary
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xl)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Review") {
                showTransactionReview = true
            }
            .foregroundColor(isFormValid ? DesignTokens.Colors.primary : .white.opacity(0.3))
            .disabled(!isFormValid)
        }
    }
    
    // MARK: - Sheet Views
    
    private var tokenSelectionSheet: some View {
        TokenSelectionView(
            selectedToken: $selectedToken,
            selectedChainId: $selectedChainId,
            tokens: walletViewModel.unifiedBalance?.unifiedBalance.tokens ?? []
        )
    }
    
    private var qrScannerSheet: some View {
        QRCodeScannerView { scannedCode in
            recipientAddress = scannedCode
            validateAddress()
        }
    }
    
    private var gasTokenSelectionSheet: some View {
        GasTokenSelectionView(
            selectedGasToken: $viewModel.selectedGasToken,
            availableGasTokens: viewModel.availableGasTokens
        )
    }
    
    @ViewBuilder
    private var transactionReviewSheet: some View {
        if let token = selectedToken, let chainId = selectedChainId {
            TransactionReviewSheet(
                token: token,
                chainId: chainId,
                recipientAddress: recipientAddress,
                amount: amount,
                gasToken: viewModel.selectedGasToken,
                fromAddress: profileViewModel.activeProfile?.sessionWalletAddress ?? "",
                viewModel: viewModel,
                onConfirm: { transaction, transactionToSign in
                    pendingTransaction = transaction
                    pendingTransactionToSign = transactionToSign
                    
                    // Check if user has external wallet
                    if profileViewModel.linkedAccounts.first(where: { $0.authStrategy == "wallet" }) != nil {
                        // External wallet flow - directly execute
                        Task {
                            await viewModel.executeTransaction(transaction, transactionToSign: transactionToSign)
                            if viewModel.error == nil {
                                showTransactionReview = false
                                showTransactionComplete = true
                            }
                        }
                    } else {
                        // MPC wallet flow
                        showMPCApproval = true
                        showTransactionReview = false
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var mpcApprovalSheet: some View {
        if let transaction = pendingTransaction {
            MPCTransactionApprovalView(
                isPresented: $showMPCApproval,
                transaction: transaction,
                onApprove: {
                    Task {
                        await viewModel.executeTransaction(transaction, transactionToSign: pendingTransactionToSign)
                        if viewModel.error == nil {
                            HapticManager.notification(.success)
                            showTransactionComplete = true
                        }
                    }
                }
            )
        }
    }
    
    private var transactionCompleteSheet: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()
                
                // Success animation
                SuccessAnimationView(onComplete: {})
                    .frame(width: 120, height: 120)
                
                Text("Transaction Sent!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your transaction has been submitted successfully")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DesignTokens.Colors.primary)
                    .cornerRadius(16)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isProcessing {
            LoadingOverlay(message: "Processing transaction...")
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        Task {
            await viewModel.loadGasTokens()
        }
        
        // Auto-focus token selection if no token selected
        if selectedToken == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTokenSelection = true
            }
        }
    }
    
    private func handleTokenSelectionChange() {
        if !showTokenSelection && selectedToken != nil && recipientAddress.isEmpty {
            // Auto-focus address field after token selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                addressFieldFocused = true
            }
        }
    }
    
    private func handleSelectedTokenChange() {
        if selectedToken != nil && recipientAddress.isEmpty {
            // Auto-focus address field when token is selected
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                addressFieldFocused = true
            }
        }
    }
    
    private func handleQRScannerChange() {
        if !showQRScanner && !recipientAddress.isEmpty && amount.isEmpty {
            // Auto-focus amount field after QR scan
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                amountFieldFocused = true
            }
        }
    }
} // End of SendTokenSheetBase struct

// MARK: - View Models

@MainActor
class SendTokenViewModel: ObservableObject {
    @Published var selectedGasToken: GasToken?
    @Published var availableGasTokens: [GasToken] = []
    @Published var estimatedGasFee: Double = 0.0
    @Published var isBuilding = false
    @Published var isProcessing = false
    @Published var error: String?
    @Published var transactionCompleted = false
    
    private let walletAPI = WalletAPI.shared
    
    func loadGasTokens() async {
        // Load available gas tokens from Orby
        // For now, use mock data
        availableGasTokens = [
            GasToken(id: "eth", symbol: "ETH", balance: 0.1, decimals: 18, priceUSD: 3000, isAISelected: true),
            GasToken(id: "usdc", symbol: "USDC", balance: 100, decimals: 6, priceUSD: 1),
            GasToken(id: "matic", symbol: "MATIC", balance: 50, decimals: 18, priceUSD: 0.8)
        ]
        
        // Auto-select AI recommended token
        if let aiRecommended = availableGasTokens.first(where: { $0.isAISelected }) {
            selectedGasToken = aiRecommended
        }
        
        estimatedGasFee = 0.50 // Placeholder
    }
    
    func buildTransaction(
        token: TokenBalance,
        chainId: Int,
        recipientAddress: String,
        amount: String,
        fromAddress: String
    ) async throws -> (MPCTransaction, TransactionToSign?) {
        isBuilding = true
        defer { isBuilding = false }
        
        // Convert amount to smallest unit
        let amountInSmallestUnit = convertToSmallestUnit(amount: amount, decimals: token.decimals)
        
        // Create intent with Orby
        let request = CreateIntentRequest(
            type: "TRANSFER",
            from: CreateIntentRequest.TokenEndpoint(
                token: token.symbol.lowercased(),
                chainId: chainId,
                amount: amountInSmallestUnit,
                address: nil // Let Orby decide based on cluster
            ),
            to: CreateIntentRequest.TokenEndpoint(
                token: nil,
                chainId: nil,
                amount: nil,
                address: recipientAddress
            ),
            gasToken: selectedGasToken?.symbol.lowercased()
        )
        
        guard let activeProfile = AuthenticationManagerV2.shared.activeProfile else {
            throw WalletTransactionError.profileNotFound
        }
        
        let response = try await walletAPI.createIntent(profileId: activeProfile.id, request: request)
        
        // Create MPC transaction from the response
        let transaction = MPCTransaction(
            id: response.data.operationSetId,
            type: .send,
            status: .pending,
            from: response.data.transactionToSign?.from ?? fromAddress,
            to: recipientAddress,
            value: amount,
            tokenSymbol: token.symbol,
            chainId: response.data.transactionToSign?.chainId ?? chainId,
            unsignedData: response.data.transactionToSign?.data ?? "",
            timestamp: Date()
        )
        
        return (transaction, response.data.transactionToSign)
    }
    
    func executeTransaction(_ transaction: MPCTransaction, transactionToSign: TransactionToSign?) async {
        isProcessing = true
        error = nil
        defer { isProcessing = false }
        
        do {
            // Get active profile
            guard let activeProfile = AuthenticationManagerV2.shared.activeProfile else {
                throw WalletTransactionError.profileNotFound
            }
            
            // Get linked accounts from the active profile
            let profileAPI = ProfileAPI.shared
            let linkedAccounts = try await profileAPI.getLinkedAccounts(profileId: activeProfile.id)
            
            // Check if we have a linked external wallet (MetaMask)
            if let primaryLinkedAccount = linkedAccounts.first(where: { $0.authStrategy == "wallet" }),
               let transactionToSign = transactionToSign {
                
                // External wallet flow (MetaMask)
                await handleExternalWalletTransaction(
                    transaction: transaction,
                    transactionToSign: transactionToSign,
                    linkedAccount: primaryLinkedAccount
                )
                
            } else {
                // MPC wallet flow
                let txRequest = TransactionRequest(
                    hash: Data(hex: transaction.unsignedData) ?? Data(),
                    chainPath: "m/44'/60'/0'/0/0",
                    value: transaction.value,
                    to: transaction.to,
                    data: transaction.unsignedData
                )
                
                let signedData = try await MPCWalletService.shared.signTransaction(
                    profileId: activeProfile.id,
                    transaction: txRequest
                )
                
                // Submit signed operation
                let signedOp = SignedOperation(
                    index: 0,
                    signature: signedData
                )
                
                _ = try await walletAPI.submitSignedOperations(
                    operationSetId: transaction.id,
                    signedOperations: [signedOp]
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func handleExternalWalletTransaction(
        transaction: MPCTransaction,
        transactionToSign: TransactionToSign,
        linkedAccount: LinkedAccount
    ) async {
        do {
            // Determine wallet type from linked account metadata
            let walletType = detectWalletType(from: linkedAccount)
            
            // Create wallet transaction that matches what Orby expects
            let walletTx = WalletTransaction(
                from: transactionToSign.from,
                to: transactionToSign.to,
                value: transactionToSign.value,
                data: transactionToSign.data,
                gasLimit: transactionToSign.gasLimit,
                gasPrice: nil,
                maxFeePerGas: transactionToSign.maxFeePerGas,
                maxPriorityFeePerGas: transactionToSign.maxPriorityFeePerGas,
                nonce: transactionToSign.nonce,
                chainId: transactionToSign.chainId
            )
            
            // Sign transaction through external wallet (don't send it)
            let walletService = WalletServiceV2.shared
            
            // Connect to the wallet if not already connected
            if walletService.activeWallet?.walletType != walletType {
                _ = try await walletService.connect(walletType: walletType)
            }
            
            // Sign the transaction (MetaMask will not broadcast it)
            let signature = try await walletService.signTransaction(walletTx, walletType: walletType)
            
            // Submit the signature to Orby for execution
            // Orby will handle broadcasting the transaction with proper gas management
            let signedOp = SignedOperation(
                index: 0,
                signature: signature,
                signedData: nil  // Only signature is needed for EOA wallets
            )
            
            _ = try await walletAPI.submitSignedOperations(
                operationSetId: transaction.id,
                signedOperations: [signedOp]
            )
            
            // Show success
            transactionCompleted = true
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func detectWalletType(from linkedAccount: LinkedAccount) -> WalletType {
        // Use the walletType property from LinkedAccount
        if let walletType = linkedAccount.walletType {
            switch walletType.lowercased() {
            case "metamask": return .metamask
            case "phantom": return .phantom
            case "rainbow": return .rainbow
            case "trust": return .trust
            case "coinbase": return .coinbase
            default: break
            }
        }
        
        // If walletType is not set, try to parse from metadata JSON string
        if let metadataString = linkedAccount.metadata,
           let data = metadataString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let walletProvider = json["walletProvider"] as? String {
            switch walletProvider.lowercased() {
            case "metamask": return .metamask
            case "phantom": return .phantom
            case "rainbow": return .rainbow
            case "trust": return .trust
            case "coinbase": return .coinbase
            default: break
            }
        }
        
        // Default to MetaMask if we can't determine
        return .metamask
    }
}

// MARK: - Supporting Views

struct GasTokenSelectionView: View {
    @Binding var selectedGasToken: GasToken?
    let availableGasTokens: [GasToken]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        // Auto option
                        GasTokenRow(
                            gasToken: nil,
                            isSelected: selectedGasToken == nil,
                            isRecommended: true,
                            onSelect: {
                                selectedGasToken = nil
                                dismiss()
                            }
                        )
                        
                        // Available gas tokens
                        ForEach(availableGasTokens) { gasToken in
                            GasTokenRow(
                                gasToken: gasToken,
                                isSelected: selectedGasToken?.id == gasToken.id,
                                isRecommended: false,
                                onSelect: {
                                    selectedGasToken = gasToken
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                }
            }
            .navigationTitle("Select Gas Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct GasTokenRow: View {
    let gasToken: GasToken?
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(role: nil, action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                if let gasToken = gasToken {
                    TokenIcon(symbol: gasToken.symbol)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(gasToken.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            if gasToken.isAISelected {
                                Text("AI")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(DesignTokens.Colors.primary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(DesignTokens.Colors.primary.opacity(0.2))
                                    )
                            }
                        }
                        
                        Text("Balance: \(WalletDesignSystem.formatTokenAmount(gasToken.balance, decimals: gasToken.decimals))")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.Colors.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(DesignTokens.Colors.primary.opacity(0.2))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Select")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("AI will choose the best token")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if isRecommended {
                    Text("Recommended")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Colors.primary.opacity(0.2))
                        )
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignTokens.Colors.primary : .white.opacity(0.2))
                    .font(.system(size: 20))
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .fill(Material.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? DesignTokens.Colors.primary.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
        }
    }
}

struct TransactionReviewSheet: View {
    let token: TokenBalance
    let chainId: Int
    let recipientAddress: String
    let amount: String
    let gasToken: GasToken?
    let fromAddress: String
    @ObservedObject var viewModel: SendTokenViewModel
    let onConfirm: (MPCTransaction, TransactionToSign?) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // Transaction Icon
                        transactionIcon
                        
                        // Amount Display
                        amountDisplay
                        
                        // Transaction Details
                        transactionDetails
                        
                        // Confirm Button
                        confirmButton
                    }
                    .padding(DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
            }
            .navigationTitle("Review Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isProcessing || viewModel.isBuilding)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private var transactionIcon: some View {
        ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: 100, height: 100)
            
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(DesignTokens.Colors.primary)
        }
    }
    
    private var amountDisplay: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("\(amount) \(token.symbol)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if let amountDouble = Double(amount) {
                let usdValue = amountDouble * (token.totalBalanceUSD / token.totalBalance)
                Text("≈ \(WalletDesignSystem.formatCurrency(usdValue))")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var transactionDetails: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            SendDetailRow(label: "From", value: "My Wallet", isAddress: false)
            SendDetailRow(label: "To", value: recipientAddress, isAddress: true)
            
            if let chain = token.chainBalances.first(where: { $0.chainId == chainId }) {
                SendDetailRow(label: "Network", value: chain.chainName, isAddress: false)
            }
            
            SendDetailRow(label: "Gas Token", value: gasToken?.symbol ?? "Auto", isAddress: false)
            SendDetailRow(label: "Network Fee", value: "≈ \(WalletDesignSystem.formatCurrency(viewModel.estimatedGasFee))", isAddress: false)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                .fill(Material.ultraThinMaterial)
        )
    }
    
    private var confirmButton: some View {
        Button {
            Task {
                isProcessing = true
                defer { isProcessing = false }
                
                do {
                    // Build transaction with Orby
                    let (transaction, transactionToSign) = try await viewModel.buildTransaction(
                        token: token,
                        chainId: chainId,
                        recipientAddress: recipientAddress,
                        amount: amount,
                        fromAddress: fromAddress
                    )
                    
                    // Pass both transaction and transactionToSign
                    await onConfirm(transaction, transactionToSign)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.notification(.error)
                }
            }
        } label: {
            HStack {
                if isProcessing || viewModel.isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Confirm & Send")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
                    .fill(DesignTokens.Colors.primary)
            )
        }
        .disabled(isProcessing || viewModel.isBuilding)
    }
}

struct SendDetailRow: View {
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

// MARK: - Models

struct GasToken: Identifiable {
    let id: String
    let symbol: String
    let balance: Double
    let decimals: Int
    let priceUSD: Double
    var isAISelected: Bool = false
}

// MARK: - Utility Functions

func convertToSmallestUnit(amount: String, decimals: Int) -> String {
    guard let amountDouble = Double(amount) else { return "0" }
    let multiplier = pow(10.0, Double(decimals))
    let smallestUnit = amountDouble * multiplier
    return String(format: "%.0f", smallestUnit)
}

#Preview {
    SendTokenSheetBase()
        .environmentObject(WalletViewModel())
}
