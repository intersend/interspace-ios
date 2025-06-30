import SwiftUI
import AVFoundation

struct WalletConnectTray: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showQRScanner = false
    @State private var manualURI = ""
    @State private var showManualInput = false
    
    private let wallets: [WalletType] = [.metamask, .coinbase, .walletConnect]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with proper iOS styling
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.lg) {
                        // Header Section
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            // Drag Handle
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 36, height: 5)
                                .padding(.top, DesignTokens.Spacing.sm)
                            
                            Text("Connect Wallet")
                                .font(DesignTokens.Typography.headlineLarge)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .padding(.top, DesignTokens.Spacing.md)
                            
                            Text("Choose how you'd like to connect your wallet")
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        
                        // Wallet Options - Using native iOS grouped style
                        VStack(spacing: 0) {
                            ForEach(Array(wallets.enumerated()), id: \.offset) { index, wallet in
                                WalletRow(
                                    wallet: wallet,
                                    isFirst: index == 0,
                                    isLast: index == wallets.count - 1,
                                    isAvailable: viewModel.isWalletAvailable(wallet)
                                ) {
                                    handleWalletSelection(wallet)
                                }
                            }
                        }
                        .background(DesignTokens.GlassEffect.thin)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        
                        // WalletConnect Section
                        if showManualInput {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                // Manual URI Input
                                VStack(spacing: DesignTokens.Spacing.sm) {
                                    HStack {
                                        Text("WalletConnect URI")
                                            .font(DesignTokens.Typography.labelMedium)
                                            .foregroundColor(DesignTokens.Colors.textSecondary)
                                        Spacer()
                                    }
                                    
                                    TextField("wc:a281567bb3e4...", text: $manualURI)
                                        .textFieldStyle(.roundedBorder)
                                        .font(DesignTokens.Typography.bodyMedium)
                                    
                                    HStack(spacing: DesignTokens.Spacing.sm) {
                                        Button("Cancel") {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showManualInput = false
                                                manualURI = ""
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(DesignTokens.Colors.backgroundTertiary)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                        .cornerRadius(DesignTokens.CornerRadius.button)
                                        
                                        Button("Connect") {
                                            connectWithURI(manualURI)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(DesignTokens.Colors.primary)
                                        .foregroundColor(.white)
                                        .cornerRadius(DesignTokens.CornerRadius.button)
                                        .disabled(manualURI.isEmpty)
                                    }
                                }
                                .padding(DesignTokens.Spacing.md)
                                .background(DesignTokens.GlassEffect.thin)
                                .cornerRadius(DesignTokens.CornerRadius.lg)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Footer Text
                        Text("Your wallet will be used to sign transactions and prove ownership of your digital assets.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            .padding(.bottom, DesignTokens.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView { result in
                connectWithURI(result)
                showQRScanner = false
            }
        }
        .onAppear {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func handleWalletSelection(_ wallet: WalletType) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        switch wallet {
        case .walletConnect:
            showQRScanner = true
        case .metamask:
            viewModel.selectWallet(wallet)
            dismiss()
        case .coinbase:
            viewModel.selectWallet(wallet)
            dismiss()
        case .rainbow, .trust, .argent, .gnosisSafe, .family, .phantom, .oneInch, .zerion, .imToken, .tokenPocket, .spot, .omni:
            // WalletConnect-compatible wallets
            viewModel.selectWallet(wallet)
            dismiss()
        case .google, .apple:
            // Social authentication not handled here
            break
        case .mpc:
            // MPC wallets handled separately
            break
        case .safe, .ledger, .trezor, .unknown:
            // These wallet types not yet supported
            break
        }
    }
    
    private func connectWithURI(_ uri: String) {
        // Handle WalletConnect URI connection
        Task {
            do {
                let result = try await WalletService.shared.connectWithWalletConnectURI(uri)
                
                let config = WalletConnectionConfig(
                    strategy: .wallet,
                    walletType: WalletType.walletConnect.rawValue,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: result.address,
                    signature: result.signature,
                    message: result.message,
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil,
                    idToken: nil,
                    accessToken: nil,
                    shopDomain: nil
                )
                
                try await viewModel.authManager.authenticate(with: config)
                dismiss()
            } catch {
                viewModel.error = AuthenticationError.walletConnectionFailed(error.localizedDescription)
                viewModel.showError = true
            }
        }
    }
}

// MARK: - Wallet Row Component (Native iOS Style)

struct WalletRow: View {
    let wallet: WalletType
    let isFirst: Bool
    let isLast: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Wallet Icon
                ZStack {
                    if wallet == .walletConnect {
                        // Special styling for WalletConnect
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.24, green: 0.51, blue: 0.96))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "qrcode")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        // Regular wallet icons
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white)
                            .frame(width: 40, height: 40)
                        
                        Image(wallet.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    }
                }
                
                // Wallet Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(walletDisplayName)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if wallet == .walletConnect {
                        Text("Scan QR code to connect")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    } else if !isAvailable {
                        Text("Not installed • Tap to install")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    } else {
                        Text("Available")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.success)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(DesignTokens.Colors.backgroundTertiary.opacity(0.3))
                .opacity(0)
        )
        // Add separators between rows (native iOS style)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSecondary)
                    .frame(height: 0.5)
                    .padding(.leading, 64) // Indent to align with text
            }
        }
    }
    
    private var walletDisplayName: String {
        switch wallet {
        case .metamask:
            return "MetaMask"
        case .coinbase:
            return "Coinbase Wallet"
        case .walletConnect:
            return "WalletConnect"
        case .rainbow:
            return "Rainbow"
        case .trust:
            return "Trust Wallet"
        case .argent:
            return "Argent"
        case .gnosisSafe:
            return "Gnosis Safe"
        case .family:
            return "Family"
        case .phantom:
            return "Phantom"
        case .oneInch:
            return "1inch Wallet"
        case .zerion:
            return "Zerion"
        case .imToken:
            return "imToken"
        case .tokenPocket:
            return "TokenPocket"
        case .spot:
            return "Spot"
        case .omni:
            return "Omni"
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        case .safe:
            return "Safe"
        case .ledger:
            return "Ledger"
        case .trezor:
            return "Trezor"
        case .mpc:
            return "MPC Wallet"
        case .unknown:
            return "Unknown"
        }
    }
}


// MARK: - Preview

struct WalletConnectTray_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectTray(viewModel: AuthViewModel())
            .preferredColorScheme(.dark)
    }
}