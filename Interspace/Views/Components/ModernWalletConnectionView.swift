import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine

/// Modern wallet connection view with QR code and wallet list
/// Uses custom wallet implementations for better UX
struct ModernWalletConnectionView: View {
    @Binding var isPresented: Bool
    let onCompletion: (String, String, String, String?, String?) -> Void
    
    @StateObject private var walletService = WalletServiceV2.shared
    @State private var selectedWallet: WalletType?
    @State private var connectionState: ConnectionState = .idle
    @State private var availableWallets: [(WalletType, Bool)] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var walletConnectURI: String?
    
    @Environment(\.dismiss) private var dismiss
    
    enum ConnectionState: Equatable {
        case idle
        case connecting(WalletType)
        case waitingForApproval(WalletType)
        case signingMessage(WalletType)
        case completed
        case error(String)
        
        var statusMessage: String {
            switch self {
            case .idle:
                return "Select a wallet or scan with WalletConnect"
            case .connecting(let wallet):
                return "Connecting to \(wallet.displayName)..."
            case .waitingForApproval(let wallet):
                return "Approve in \(wallet.displayName)"
            case .signingMessage(let wallet):
                return "Sign message in \(wallet.displayName)"
            case .completed:
                return "Successfully connected!"
            case .error(let message):
                return message
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connecting, .waitingForApproval, .signingMessage:
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with QR code
                    VStack(spacing: 24) {
                        Text("Connect Wallet")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        // QR Code section
                        qrCodeSection
                            .padding(.horizontal, 40)
                        
                        // Status message
                        HStack(spacing: 8) {
                            if connectionState.isActive {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(connectionState.statusMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: 30)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                    
                    // Available wallets
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Available Wallets")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(availableWallets, id: \.0.id) { wallet, isInstalled in
                                    walletRow(wallet: wallet, isInstalled: isInstalled)
                                    
                                    if wallet != availableWallets.last?.0 {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelConnection()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Connection Error", isPresented: $showError) {
            Button("Try Again") {
                connectionState = .idle
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            checkAvailableWallets()
            generateWalletConnectURI()
        }
        .onDisappear {
            cleanupConnection()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var qrCodeSection: some View {
        ZStack {
            if connectionState == .completed {
                // Success state
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text("Connected!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(width: 240, height: 240)
            } else if let uri = walletConnectURI {
                VStack(spacing: 16) {
                    // QR Code
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .frame(width: 240, height: 240)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        if let qrImage = generateQRCode(from: uri) {
                            qrImage
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .padding(20)
                                .frame(width: 200, height: 200)
                        }
                        
                        // Loading overlay when connecting
                        if connectionState.isActive {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 240, height: 240)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                        }
                    }
                    
                    // Copy button
                    Button {
                        copyURI()
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // Loading state
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(width: 240, height: 240)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: connectionState)
    }
    
    @ViewBuilder
    private func walletRow(wallet: WalletType, isInstalled: Bool) -> some View {
        Button {
            connectWallet(wallet)
        } label: {
            HStack(spacing: 16) {
                // Wallet icon
                Image(wallet.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if isInstalled {
                        if walletService.factory.isSupported(wallet) {
                            Text("Tap to connect")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else {
                            Text("Coming soon")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("Tap to install")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                if case .connecting(let activeWallet) = connectionState,
                   activeWallet == wallet {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(connectionState.isActive)
    }
    
    // MARK: - Private Methods
    
    private func checkAvailableWallets() {
        // Get wallets to check
        let walletsToCheck: [WalletType] = [
            .phantom, .trust, .rainbow, .argent, .family,
            .oneInch, .zerion, .imToken, .tokenPocket,
            .spot, .omni, .gnosisSafe, .binance, .clave,
            .farcaster, .kraken, .cryptocom, .metamask, .coinbase
        ]
        
        // Check which are installed and supported
        availableWallets = walletsToCheck.compactMap { wallet in
            let isInstalled = walletService.isWalletInstalled(wallet)
            return (wallet, isInstalled)
        }.sorted { lhs, rhs in
            // Sort by: supported & installed first, then supported, then others
            let lhsSupported = walletService.factory.isSupported(lhs.0)
            let rhsSupported = walletService.factory.isSupported(rhs.0)
            
            if lhsSupported != rhsSupported {
                return lhsSupported
            }
            if lhs.1 != rhs.1 {
                return lhs.1
            }
            return lhs.0.displayName < rhs.0.displayName
        }
    }
    
    private func generateWalletConnectURI() {
        // For now, generate a placeholder URI
        // In the future, this would create a real WalletConnect URI for backwards compatibility
        walletConnectURI = "wc:example-\(UUID().uuidString)@2?relay-protocol=irn&symKey=example"
    }
    
    private func connectWallet(_ wallet: WalletType) {
        guard connectionState != .completed else { return }
        
        // Check if wallet is installed
        guard walletService.isWalletInstalled(wallet) else {
            // Open App Store
            if let url = wallet.appStoreURL {
                UIApplication.shared.open(url)
            }
            return
        }
        
        // Check if wallet is supported
        guard walletService.factory.isSupported(wallet) else {
            showError = true
            errorMessage = "\(wallet.displayName) support is coming soon!"
            return
        }
        
        // Connect to wallet
        selectedWallet = wallet
        connectionState = .connecting(wallet)
        
        Task {
            await performConnection(wallet: wallet)
        }
    }
    
    @MainActor
    private func performConnection(wallet: WalletType) async {
        do {
            // Update state
            connectionState = .waitingForApproval(wallet)
            
            // Authenticate with wallet
            let result = try await walletService.authenticateWithWallet(walletType: wallet)
            
            // Update state
            connectionState = .signingMessage(wallet)
            
            // Brief delay for UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Success
            connectionState = .completed
            HapticManager.notification(.success)
            
            // Brief delay to show success
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // Call completion
            onCompletion(
                result.address,
                result.signature,
                result.message,
                result.walletName ?? wallet.displayName,
                result.walletIcon
            )
            
            // Dismiss
            dismiss()
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        connectionState = .idle
        HapticManager.notification(.error)
        
        if let walletError = error as? WalletError {
            errorMessage = walletError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        showError = true
    }
    
    private func copyURI() {
        guard let uri = walletConnectURI else { return }
        UIPasteboard.general.string = uri
        HapticManager.notification(.success)
    }
    
    private func generateQRCode(from string: String) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return Image(uiImage: UIImage(cgImage: cgImage))
        }
        
        return nil
    }
    
    private func cancelConnection() {
        Task {
            try? await walletService.disconnect()
        }
        dismiss()
    }
    
    private func cleanupConnection() {
        if connectionState.isActive {
            Task {
                try? await walletService.disconnect()
            }
        }
    }
}

// MARK: - WalletFactory Extension

extension WalletFactory {
    /// Convenience property for SwiftUI
    var factory: WalletFactory {
        self
    }
}