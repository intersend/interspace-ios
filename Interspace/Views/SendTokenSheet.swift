import SwiftUI

struct SendTokenSheet: View {
    let selectedToken: UnifiedBalance.TokenBalance?
    @Environment(\.dismiss) private var dismiss
    
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var selectedChain: UnifiedBalance.ChainBalance?
    @State private var showQRScanner = false
    @State private var isSending = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case address, amount
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // Header
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(DesignTokens.Colors.primary)
                            
                            Text("Send Tokens")
                                .font(DesignTokens.Typography.headlineLarge)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        .padding(.top, DesignTokens.Spacing.lg)
                        
                        // Token Selection
                        if let token = selectedToken {
                            TokenSelectionCard(token: token)
                        }
                        
                        // Recipient Address
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("Recipient Address")
                                    .font(DesignTokens.Typography.labelMedium)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showQRScanner = true
                                }) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundColor(DesignTokens.Colors.primary)
                                }
                            }
                            
                            TextField("0x...", text: $recipientAddress)
                                .textFieldStyle(LiquidGlassTextFieldStyle())
                                .focused($focusedField, equals: .address)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        // Amount Input
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("Amount")
                                    .font(DesignTokens.Typography.labelMedium)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                
                                Spacer()
                                
                                if let token = selectedToken {
                                    Button("Max") {
                                        amount = formatMaxAmount(token)
                                    }
                                    .font(DesignTokens.Typography.labelMedium)
                                    .foregroundColor(DesignTokens.Colors.primary)
                                }
                            }
                            
                            TextField("0.0", text: $amount)
                                .textFieldStyle(LiquidGlassTextFieldStyle())
                                .focused($focusedField, equals: .amount)
                                .keyboardType(.decimalPad)
                        }
                        
                        // Chain Selection
                        if let token = selectedToken, token.balancesPerChain.count > 1 {
                            ChainSelectionSection(
                                chains: token.balancesPerChain,
                                selectedChain: $selectedChain
                            )
                        }
                        
                        // Send Button
                        Button(action: sendToken) {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isSending ? "Sending..." : "Send")
                                    .font(DesignTokens.Typography.buttonMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.buttonPaddingVertical)
                            .background(
                                isFormValid ?
                                DesignTokens.Colors.primary :
                                DesignTokens.Colors.buttonSecondary
                            )
                            .foregroundColor(
                                isFormValid ?
                                .white :
                                DesignTokens.Colors.textTertiary
                            )
                            .cornerRadius(DesignTokens.CornerRadius.button)
                            .scaleEffect(isSending ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isSending)
                        }
                        .disabled(!isFormValid || isSending)
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer(minLength: DesignTokens.Spacing.xl)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet { address in
                recipientAddress = address
            }
        }
        .onAppear {
            if let token = selectedToken, let firstChain = token.balancesPerChain.first {
                selectedChain = firstChain
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        recipientAddress.hasPrefix("0x") &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    // MARK: - Methods
    
    private func formatMaxAmount(_ token: UnifiedBalance.TokenBalance) -> String {
        if let doubleValue = Double(token.totalAmount) {
            let adjustedValue = doubleValue / pow(10, Double(token.decimals))
            return String(adjustedValue)
        }
        return token.totalAmount
    }
    
    private func sendToken() {
        guard isFormValid else { return }
        
        isSending = true
        
        // Implement send logic here
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSending = false
            dismiss()
        }
    }
}

// MARK: - Token Selection Card

struct TokenSelectionCard: View {
    let token: UnifiedBalance.TokenBalance
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(token.symbol.prefix(1))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(token.name)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text("$\(formatCurrency(token.totalUsdValue))")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(token.totalAmount, decimals: token.decimals))
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(token.symbol)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }
    
    private func formatCurrency(_ value: String) -> String {
        if let doubleValue = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: doubleValue)) ?? value
        }
        return value
    }
    
    private func formatAmount(_ amount: String, decimals: Int) -> String {
        if let doubleValue = Double(amount) {
            let adjustedValue = doubleValue / pow(10, Double(decimals))
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            return formatter.string(from: NSNumber(value: adjustedValue)) ?? amount
        }
        return amount
    }
}

// MARK: - Chain Selection

struct ChainSelectionSection: View {
    let chains: [UnifiedBalance.ChainBalance]
    @Binding var selectedChain: UnifiedBalance.ChainBalance?
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Select Chain")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }
            
            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(chains, id: \.chainId) { chain in
                    ChainRow(
                        chain: chain,
                        isSelected: selectedChain?.chainId == chain.chainId
                    ) {
                        selectedChain = chain
                    }
                }
            }
        }
    }
}

struct ChainRow: View {
    let chain: UnifiedBalance.ChainBalance
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.chainName)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Chain ID: \(chain.chainId)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                Text(formatAmount(chain.amount))
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.primary)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                isSelected ? 
                DesignTokens.Colors.primary.opacity(0.1) : 
                Color.clear
            )
            .background(DesignTokens.GlassEffect.ultraThin)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(
                        isSelected ?
                        DesignTokens.Colors.primary :
                        DesignTokens.Colors.borderSecondary,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatAmount(_ amount: String) -> String {
        if let doubleValue = Double(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            return formatter.string(from: NSNumber(value: doubleValue)) ?? amount
        }
        return amount
    }
}

// MARK: - QR Scanner Sheet

struct QRScannerSheet: View {
    let onAddressScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("QR Scanner")
                    .font(DesignTokens.Typography.headlineLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .padding()
                
                Text("Position the QR code within the frame")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct SendTokenSheet_Previews: PreviewProvider {
    static var previews: some View {
        SendTokenSheet(selectedToken: nil)
            .preferredColorScheme(.dark)
    }
}