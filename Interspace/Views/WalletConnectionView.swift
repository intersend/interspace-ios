import SwiftUI
import Combine

/// Enhanced wallet connection view with Apple-like smoothness
struct WalletConnectionView: View {
    @StateObject private var walletService = WalletService.shared
    @StateObject private var connectionManager = WalletConnectionManager.shared
    @State private var selectedWallet: WalletType?
    @State private var showingProgress = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var retryCount = 0
    @Environment(\.dismiss) var dismiss
    
    let onSuccess: (WalletConnectionResult) -> Void
    let isLinking: Bool
    
    init(isLinking: Bool = false, onSuccess: @escaping (WalletConnectionResult) -> Void) {
        self.isLinking = isLinking
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                // Main content
                if showingProgress, let wallet = selectedWallet {
                    ConnectionProgressView(
                        walletType: wallet,
                        onCancel: cancelConnection,
                        onRetry: retryConnection
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                } else {
                    walletSelectionView
                        .transition(.opacity)
                }
            }
            .navigationTitle(isLinking ? "Link Wallet" : "Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("Try Again", action: retryConnection)
            Button("Cancel", role: .cancel) {
                cancelConnection()
            }
        } message: {
            Text(errorMessage)
        }
        .onReceive(connectionManager.$connectionState) { state in
            handleConnectionStateChange(state)
        }
    }
    
    // MARK: - Wallet Selection View
    
    @ViewBuilder
    private var walletSelectionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 48))
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Text(isLinking ? "Choose a wallet to link" : "Choose a wallet to connect")
                        .font(.title3)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Popular wallets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("POPULAR")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(popularWallets, id: \.self) { wallet in
                            WalletRowView(
                                wallet: wallet,
                                isInstalled: walletService.isWalletAvailable(wallet),
                                onTap: { selectWallet(wallet) }
                            )
                            
                            if wallet != popularWallets.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // All wallets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("ALL WALLETS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(otherWallets, id: \.self) { wallet in
                            WalletRowView(
                                wallet: wallet,
                                isInstalled: walletService.isWalletAvailable(wallet),
                                onTap: { selectWallet(wallet) }
                            )
                            
                            if wallet != otherWallets.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Footer hint
                Text("Tap any wallet to connect")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var popularWallets: [WalletType] {
        [.metamask, .coinbase, .rainbow, .trust]
    }
    
    private var otherWallets: [WalletType] {
        [.argent, .phantom, .zerion, .oneInch, .imToken, .walletConnect]
            .filter { walletService.isWalletAvailable($0) || WalletConfiguration.configuration(for: $0).universalLinkDomain != nil }
    }
    
    // MARK: - Actions
    
    private func selectWallet(_ wallet: WalletType) {
        // Haptic feedback
        HapticManager.selection()
        
        selectedWallet = wallet
        withAnimation(.spring()) {
            showingProgress = true
        }
        
        // Start connection
        Task {
            do {
                let result = try await walletService.connectWallet(wallet)
                await MainActor.run {
                    onSuccess(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    handleConnectionError(error)
                }
            }
        }
    }
    
    private func cancelConnection() {
        HapticManager.impact(.light)
        
        connectionManager.cancelConnection()
        
        withAnimation(.spring()) {
            showingProgress = false
            selectedWallet = nil
        }
    }
    
    private func retryConnection() {
        guard let wallet = selectedWallet else { return }
        
        retryCount += 1
        HapticManager.impact(.light)
        
        // Reset error state
        showingError = false
        errorMessage = ""
        
        // Retry with exponential backoff
        let delay = min(Double(retryCount) * 0.5, 3.0)
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                let result = try await walletService.connectWallet(wallet)
                await MainActor.run {
                    onSuccess(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleConnectionStateChange(_ state: WalletConnectionManager.ConnectionState) {
        switch state {
        case .connected(_, _):
            // Success handled in selectWallet
            break
            
        case .failed(let error):
            handleConnectionError(error)
            
        case .timeout:
            errorMessage = "Connection timed out. Make sure the wallet app is open and try again."
            showingError = true
            
        default:
            break
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        let walletError = error as? WalletError ?? WalletError.connectionFailed(error.localizedDescription)
        
        switch walletError {
        case .userCancelled:
            // User cancelled, just go back to selection
            withAnimation(.spring()) {
                showingProgress = false
            }
            
        case .qrCodeScanRequired:
            // This is handled by the WalletConnect flow
            break
            
        default:
            errorMessage = walletError.localizedDescription
            showingError = true
            
            if retryCount >= 3 {
                // After 3 retries, go back to selection
                withAnimation(.spring()) {
                    showingProgress = false
                    selectedWallet = nil
                    retryCount = 0
                }
            }
        }
    }
}

// MARK: - Wallet Row View

struct WalletRowView: View {
    let wallet: WalletType
    let isInstalled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Wallet icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(wallet.primaryColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    if let icon = UIImage(named: wallet.icon) {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: wallet.systemIconName)
                            .font(.system(size: 24))
                            .foregroundColor(wallet.primaryColor)
                    }
                }
                
                // Wallet info
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.displayName)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if !isInstalled {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                            Text("Tap to install")
                                .font(.caption)
                        }
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct WalletConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectionView { result in
            print("Connected: \(result.address)")
        }
    }
}