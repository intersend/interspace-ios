import SwiftUI
import AVFoundation

// MARK: - QR Code Scanner View

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

// MARK: - QR Scanner UIViewRepresentable

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