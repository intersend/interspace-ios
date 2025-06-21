import SwiftUI
import AVFoundation

// MARK: - Liquid Glass WalletConnect Scanner
struct LiquidGlassWalletConnectScanner: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingManualInput = false
    @State private var manualInput = ""
    
    let onCodeScanned: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Deep space background
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                // Camera Scanner
                CameraView { code in
                    handleScannedCode(code)
                }
                
                // Overlay with instructions
                VStack {
                    Spacer()
                    
                    // Instructions card
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            Text("Scan QR Code")
                                .font(DesignTokens.Typography.title2)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text("Point your camera at the WalletConnect QR code")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        HStack(spacing: DesignTokens.Spacing.md) {
                            // Manual input button
                            Button(action: {
                                HapticManager.impact(.light)
                                showingManualInput = true
                            }) {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    Image(systemName: "keyboard")
                                    Text("Manual")
                                }
                                .font(DesignTokens.Typography.footnote)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(variant: .secondary, size: .small))
                            
                            // Auto-paste button if clipboard has WC URI
                            if let clipboardString = UIPasteboard.general.string,
                               clipboardString.hasPrefix("wc:") {
                                Button(action: {
                                    HapticManager.impact(.light)
                                    handleScannedCode(clipboardString)
                                }) {
                                    HStack(spacing: DesignTokens.Spacing.xs) {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                    .font(DesignTokens.Typography.footnote)
                                }
                                .buttonStyle(LiquidGlassButtonStyle(variant: .primary, size: .small))
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.xl)
                    .background(DesignTokens.LiquidGlass.regular)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl)
                            .stroke(DesignTokens.Colors.borderGlass, lineWidth: 0.5)
                    )
                    .cornerRadius(DesignTokens.CornerRadius.xl)
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    
                    Spacer(minLength: DesignTokens.Spacing.xxxl)
                }
            }
            .navigationTitle("Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.interactive)
                }
            }
        }
        .sheet(isPresented: $showingManualInput) {
            LiquidGlassManualInputView(
                input: $manualInput,
                onSubmit: { code in
                    handleScannedCode(code)
                },
                onCancel: {
                    showingManualInput = false
                }
            )
        }
    }
    
    private func handleScannedCode(_ code: String) {
        if code.hasPrefix("wc:") {
            HapticManager.notification(.success)
            onCodeScanned(code)
            dismiss()
        } else {
            HapticManager.notification(.error)
        }
    }
}

// MARK: - Liquid Glass Manual Input View
struct LiquidGlassManualInputView: View {
    @Binding var input: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private var isValidInput: Bool {
        input.hasPrefix("wc:")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Header
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Enter Connection Code")
                            .font(DesignTokens.Typography.title1)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Paste or type the WalletConnect URI from your wallet app")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignTokens.Spacing.xl)
                    
                    // Input section
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("WalletConnect URI")
                            .font(DesignTokens.Typography.footnote)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        TextField("wc:...", text: $input)
                            .liquidGlassTextField(size: .large)
                            .focused($isTextFieldFocused)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                if isValidInput {
                                    HapticManager.impact(.medium)
                                    onSubmit(input)
                                    dismiss()
                                }
                            }
                        
                        if !input.isEmpty && !isValidInput {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text("URI must start with 'wc:'")
                                    .font(DesignTokens.Typography.caption1)
                            }
                            .foregroundColor(DesignTokens.Colors.error)
                        }
                    }
                    
                    // Quick paste button
                    if let clipboardString = UIPasteboard.general.string,
                       clipboardString.hasPrefix("wc:") && input != clipboardString {
                        Button(action: {
                            HapticManager.impact(.light)
                            input = clipboardString
                        }) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste from clipboard")
                            }
                            .font(DesignTokens.Typography.body)
                        }
                        .buttonStyle(LiquidGlassButtonStyle(variant: .secondary, size: .medium))
                    }
                    
                    // Connect button
                    Button(action: {
                        if isValidInput {
                            HapticManager.impact(.medium)
                            onSubmit(input)
                            dismiss()
                        }
                    }) {
                        Text("Connect Wallet")
                            .font(DesignTokens.Typography.body)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(
                        variant: isValidInput ? .primary : .secondary,
                        size: .large
                    ))
                    .disabled(!isValidInput)
                    .animation(DesignTokens.Animation.springSnappy, value: isValidInput)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
            }
            .background(DesignTokens.Colors.backgroundPrimary)
            .navigationTitle("Manual Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.impact(.light)
                        onCancel()
                        dismiss()
                    }
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.interactive)
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
            
            // Auto-fill from clipboard if available
            if let clipboardString = UIPasteboard.general.string,
               clipboardString.hasPrefix("wc:") {
                input = clipboardString
            }
        }
    }
}

// MARK: - Native Camera Implementation

struct CameraView: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraUIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        
        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                DispatchQueue.main.async {
                    self.onCodeScanned(stringValue)
                }
            }
        }
    }
}

class CameraUIView: UIView {
    var delegate: AVCaptureMetadataOutputObjectsDelegate?
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
        
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
}