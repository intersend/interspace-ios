import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveTokenSheetEnhanced: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @State private var selectedChainId: Int = 1
    @State private var showChainSelector = false
    @State private var showAmountRequest = false
    @State private var requestedAmount = ""
    @State private var copiedAddress = false
    @State private var qrCodeImage: UIImage?
    @State private var qrCodeScale: CGFloat = 0.8
    @State private var qrCodeOpacity: Double = 0
    @State private var showAmountCard = false
    
    @FocusState private var amountFieldFocused: Bool
    
    private var currentAddress: String {
        return profileViewModel.activeProfile?.sessionWalletAddress ?? "0x0000000000000000000000000000000000000000"
    }
    
    private var availableChains: [(chainId: Int, chainName: String)] {
        guard let unifiedBalance = walletViewModel.unifiedBalance else {
            return [(1, "Ethereum"), (137, "Polygon"), (10, "Optimism")]
        }
        
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
    
    private var qrCodeContent: String {
        if !requestedAmount.isEmpty, let amount = Double(requestedAmount), amount > 0 {
            return "ethereum:\(currentAddress)?value=\(amount)"
        } else {
            return currentAddress
        }
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
                
                RubberBandScrollView {
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
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .push(from: .top).combined(with: .opacity)
                                ))
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
        .customSheet(isPresented: $showChainSelector, detents: [.medium]) {
            ChainSelectorSheetEnhanced(
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
            VStack {
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
                            .scaleEffect(qrCodeScale)
                            .opacity(qrCodeOpacity)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    qrCodeScale = 1.0
                                    qrCodeOpacity = 1.0
                                }
                            }
                    } else {
                        // Loading state with shimmer
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .fill(Material.ultraThinMaterial)
                            .frame(width: 260, height: 260)
                            .shimmer()
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    
                    if !requestedAmount.isEmpty {
                        HStack(spacing: 4) {
                            Text("Requesting")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            NumberTickerView(
                                value: Double(requestedAmount) ?? 0,
                                format: "%.4f",
                                font: .system(size: 14, weight: .bold),
                                color: DesignTokens.Colors.primary
                            )
                            
                            Text("ETH")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .transition(.push(from: .bottom).combined(with: .opacity))
                    }
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
            .animatedListItem(index: 0)
            
            // Instructions
            Text("Scan to send tokens to this address")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .animatedListItem(index: 1)
        }
    }
    
    private var addressSection: some View {
        VStack {
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
                            .rotationEffect(.degrees(copiedAddress ? 360 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: copiedAddress)
                    }
                    .animatedButton()
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .animatedListItem(index: 2)
    }
    
    private var chainSelectorSection: some View {
        VStack {
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
                            .contentTransition(.opacity)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedChainName)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(DesignTokens.Spacing.md)
            }
            .animatedButton()
        }
        .animatedListItem(index: 3)
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
            .buttonStyle(SimpleLiquidGlassButtonStyle(isProminent: false, tint: .white))
            .animatedListItem(index: 4)
            
            // Request Amount Toggle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAmountRequest.toggle()
                    if showAmountRequest {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            amountFieldFocused = true
                            showAmountCard = true
                        }
                    } else {
                        requestedAmount = ""
                        amountFieldFocused = false
                        showAmountCard = false
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
                    .contentTransition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAmountRequest)
            }
            .buttonStyle(SimpleLiquidGlassButtonStyle(isProminent: false, tint: .white))
            .animatedListItem(index: 5)
        }
    }
    
    private var amountRequestSection: some View {
        VStack {
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
                        .focusTransition { focused in
                            // Focus transition handled
                        }
                    
                    Text("ETH")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // USD equivalent
                if let amount = Double(requestedAmount), amount > 0 {
                    NumberTickerView(
                        value: amount * 3500, // Mock ETH price
                        format: "≈ $%.2f",
                        font: .system(size: 14),
                        color: .white.opacity(0.5)
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .scaleEffect(showAmountCard ? 1 : 0.95)
        .opacity(showAmountCard ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showAmountCard)
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    qrCodeImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}

// MARK: - Enhanced Chain Selector Sheet

struct ChainSelectorSheetEnhanced: View {
    @Binding var selectedChainId: Int
    let availableChains: [(chainId: Int, chainName: String)]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(Array(availableChains.enumerated()), id: \.element.chainId) { index, chain in
                            ChainRowEnhanced(
                                chainId: chain.chainId,
                                chainName: chain.chainName,
                                isSelected: selectedChainId == chain.chainId,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedChainId = chain.chainId
                                    }
                                    HapticManager.shared.impact(style: .light)
                                    dismiss()
                                }
                            )
                            .animatedListItem(index: index)
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

struct ChainRowEnhanced: View {
    let chainId: Int
    let chainName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var chainColor: Color {
        switch chainId {
        case 1: return Color(red: 0.38, green: 0.49, blue: 0.72)
        case 137: return Color(red: 0.51, green: 0.29, blue: 0.87)
        case 10: return Color(red: 0.93, green: 0.11, blue: 0.14)
        case 42161: return Color(red: 0.13, green: 0.59, blue: 0.85)
        case 56: return Color(red: 0.95, green: 0.73, blue: 0.18)
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
                    .scaleEffect(isSelected ? 1.2 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
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
        .animatedButton()
    }
}