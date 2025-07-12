import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveTokenSheetBase: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var selectedChainId: Int = 1 // Default to Ethereum mainnet
    @State private var showChainSelector = false
    @State private var showAmountRequest = false
    @State private var requestedAmount = ""
    @State private var copiedAddress = false
    @State private var qrCodeImage: UIImage?
    
    @FocusState private var amountFieldFocused: Bool
    
    // Get current wallet address based on selected chain
    private var currentAddress: String {
        // In a real implementation, this would get the actual address for the selected chain
        // For now, returning a placeholder that would come from the profile's wallet data
        return profileViewModel.activeProfile?.sessionWalletAddress ?? "0x0000000000000000000000000000000000000000"
    }
    
    // Get available chains from wallet balance
    private var availableChains: [(chainId: Int, chainName: String)] {
        guard let unifiedBalance = walletViewModel.unifiedBalance else {
            return [(1, "Ethereum"), (137, "Polygon"), (10, "Optimism")] // Default chains
        }
        
        // Extract unique chains from all token balances
        struct ChainInfo: Hashable {
            let chainId: Int
            let chainName: String
        }
        
        var chains = Set<ChainInfo>()
        for token in unifiedBalance.unifiedBalance.tokens {
            for chainBalance in token.balancesPerChain {
                chains.insert(ChainInfo(chainId: chainBalance.chainId, chainName: chainBalance.chainName))
            }
        }
        
        return chains.map { ($0.chainId, $0.chainName) }.sorted { $0.0 < $1.0 }
    }
    
    private var selectedChainName: String {
        availableChains.first(where: { $0.chainId == selectedChainId })?.chainName ?? "Ethereum"
    }
    
    // Generate QR code content
    private var qrCodeContent: String {
        if !requestedAmount.isEmpty, let amount = Double(requestedAmount), amount > 0 {
            // EIP-681 format for payment requests
            return "ethereum:\(currentAddress)?value=\(amount)"
        } else {
            return currentAddress
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                        // QR Code Display
                        qrCodeSection
                        
                        // Wallet Address
                        addressSection
                        
                        // Chain Selector
                        chainSelectorSection
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        // Amount Request (Optional)
                        if showAmountRequest {
                            amountRequestSection
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    .padding(.vertical, DesignTokens.Spacing.sectionSpacing)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showChainSelector) {
            ChainSelectorSheet(
                selectedChainId: $selectedChainId,
                availableChains: availableChains
            )
        }
        .onAppear {
            generateQRCode()
        }
        .onChange(of: qrCodeContent) { _ in
            generateQRCode()
        }
        .onChange(of: selectedChainId) { _ in
            generateQRCode()
        }
    }
    
    // MARK: - Sections
    
    private var qrCodeSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // QR Code Container
            VStack(spacing: DesignTokens.Spacing.md) {
                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .background(Color.white)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(
                            color: DesignTokens.Colors.primary.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                } else {
                    // Loading state
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(Material.ultraThinMaterial)
                        .frame(width: 260, height: 260)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                
                if !requestedAmount.isEmpty {
                    Text("Requesting \(requestedAmount) ETH")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Instructions
            Text("Scan to send tokens to this address")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Wallet Address")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(formatAddress(currentAddress))
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    copyAddress()
                } label: {
                    Image(systemName: copiedAddress ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(copiedAddress ? DesignTokens.Colors.success : DesignTokens.Colors.primary)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: copiedAddress)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
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
    
    private var chainSelectorSection: some View {
        Button {
            showChainSelector = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(selectedChainName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
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
    
    private var actionButtonsSection: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Share Button
            Button {
                shareAddress()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(LiquidGlassButtonStyle(variant: .secondary, size: .medium))
            
            // Request Amount Toggle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAmountRequest.toggle()
                    if showAmountRequest {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            amountFieldFocused = true
                        }
                    } else {
                        requestedAmount = ""
                        amountFieldFocused = false
                    }
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Label(showAmountRequest ? "Cancel" : "Request Amount", 
                      systemImage: showAmountRequest ? "xmark" : "plus.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(LiquidGlassButtonStyle(variant: .secondary, size: .medium))
        }
    }
    
    private var amountRequestSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Request Amount")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("0.0", text: $requestedAmount)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(.decimalPad)
                    .focused($amountFieldFocused)
                
                Text("ETH")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Helper Methods
    
    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = currentAddress
        HapticManager.shared.impact(style: .medium)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copiedAddress = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedAddress = false
            }
        }
    }
    
    private func shareAddress() {
        let activityVC = UIActivityViewController(
            activityItems: [currentAddress],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            rootVC.present(activityVC, animated: true)
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(qrCodeContent.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

// MARK: - Chain Selector Sheet

struct ChainSelectorSheet: View {
    @Binding var selectedChainId: Int
    let availableChains: [(chainId: Int, chainName: String)]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(availableChains, id: \.chainId) { chain in
                            ChainRow(
                                chainId: chain.chainId,
                                chainName: chain.chainName,
                                isSelected: selectedChainId == chain.chainId,
                                onSelect: {
                                    selectedChainId = chain.chainId
                                    HapticManager.shared.impact(style: .light)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(DesignTokens.Spacing.screenPadding)
                }
            }
            .navigationTitle("Select Network")
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

struct ChainRow: View {
    let chainId: Int
    let chainName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    // Chain icons/colors mapping
    private var chainColor: Color {
        switch chainId {
        case 1: return Color(red: 0.38, green: 0.49, blue: 0.72) // Ethereum
        case 137: return Color(red: 0.51, green: 0.29, blue: 0.87) // Polygon
        case 10: return Color(red: 0.93, green: 0.11, blue: 0.14) // Optimism
        case 42161: return Color(red: 0.13, green: 0.59, blue: 0.85) // Arbitrum
        case 56: return Color(red: 0.95, green: 0.73, blue: 0.18) // BSC
        default: return DesignTokens.Colors.primary
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Chain Icon
                Circle()
                    .fill(chainColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(chainName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chainName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Chain ID: \(chainId)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
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
                                isSelected ? chainColor.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
        }
    }
}

// MARK: - Previews

#Preview("Receive Token Sheet") {
    ReceiveTokenSheetBase()
        .environmentObject(WalletViewModel())
        .environmentObject(ProfileViewModel.shared)
}

#Preview("Chain Selector") {
    ChainSelectorSheet(
        selectedChainId: .constant(1),
        availableChains: [
            (1, "Ethereum"),
            (137, "Polygon"),
            (10, "Optimism"),
            (42161, "Arbitrum"),
            (56, "BSC")
        ]
    )
}