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
        case .google, .apple:
            // Social authentication not handled here
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
                    oauthCode: nil
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
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - QR Code Scanner View (Native iOS)

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showManualInput = false
    @State private var manualURI = ""
    @State private var hasDetectedQR = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Native iOS QR Scanner
                QRScannerRepresentable { result in
                    if !hasDetectedQR {
                        hasDetectedQR = true
                        onCodeScanned(result)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            hasDetectedQR = false
                        }
                    }
                }
                .ignoresSafeArea(.all)
                
                // Viewfinder overlay
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)
                    
                    Spacer()
                    
                    // Instructions overlay
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Scan QR Code")
                            .font(DesignTokens.Typography.headlineSmall)
                            .foregroundColor(.white)
                        
                        Text("Position the QR code within the frame to connect")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button("Enter URI Manually") {
                            showManualInput = true
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.GlassEffect.regular)
                        .foregroundColor(.white)
                        .cornerRadius(DesignTokens.CornerRadius.button)
                    }
                    .padding(DesignTokens.Spacing.xl)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Enter WalletConnect URI", isPresented: $showManualInput) {
            TextField("wc:a281567bb3e4...", text: $manualURI)
            Button("Cancel", role: .cancel) {
                manualURI = ""
            }
            Button("Connect") {
                onCodeScanned(manualURI)
                manualURI = ""
            }
            .disabled(manualURI.isEmpty)
        } message: {
            Text("Paste your WalletConnect URI here")
        }
    }
}

// MARK: - Native QR Scanner UIViewRepresentable

struct QRScannerRepresentable: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> QRScannerUIView {
        let view = QRScannerUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: QRScannerUIView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerRepresentable
        
        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }
        
        func didScanQRCode(_ code: String) {
            parent.onCodeScanned(code)
        }
    }
}

// MARK: - QR Scanner UIView

protocol QRScannerDelegate: AnyObject {
    func didScanQRCode(_ code: String)
}

class QRScannerUIView: UIView {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            setupCamera()
        } else {
            stopCamera()
        }
    }
    
    private func setupCamera() {
        guard captureSession == nil else { return }
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get video capture device")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Failed to create video input: \(error)")
            return
        }
        
        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
        } else {
            print("Failed to add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession?.canAddOutput(metadataOutput) == true {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Failed to add metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = bounds
        previewLayer?.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerUIView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        delegate?.didScanQRCode(stringValue)
    }
}

// MARK: - Preview

struct WalletConnectTray_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectTray(viewModel: AuthViewModel())
            .preferredColorScheme(.dark)
    }
}