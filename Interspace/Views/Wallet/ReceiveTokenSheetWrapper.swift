import SwiftUI
import CoreImage.CIFilterBuiltins

// Simple implementation of ReceiveTokenSheet
struct ReceiveTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @State private var copiedAddress = false
    @State private var qrCodeImage: UIImage?
    
    private var walletAddress: String {
        profileViewModel.activeProfile?.sessionWalletAddress ?? "0x0000000000000000000000000000000000000000"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // QR Code
                    if let qrCodeImage = qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .cornerRadius(20)
                            .padding()
                    }
                    
                    // Address
                    VStack(spacing: 16) {
                        Text("Wallet Address")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack {
                            Text(walletAddress)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button {
                                UIPasteboard.general.string = walletAddress
                                withAnimation {
                                    copiedAddress = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedAddress = false
                                }
                            } label: {
                                Image(systemName: copiedAddress ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top)
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
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(walletAddress.utf8)
        
        if let outputImage = filter.outputImage {
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
}
