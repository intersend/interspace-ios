import SwiftUI
import Combine

/// Mini wallet authorization tray matching the provided UI design
struct MiniWalletAuthorizationTray: View {
    @Binding var isPresented: Bool
    let walletType: WalletType
    var isForAuthentication: Bool = false
    let onAuthorize: () async -> Void
    
    // State management
    @State private var isLoading = false
    @State private var hasInitiatedConnection = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Wallet Icon
            Group {
                if walletType == .metamask {
                    Image("metamask")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    // For other wallets, use system icon with background
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(walletType.primaryColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: walletType.systemIconName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(walletType.primaryColor)
                    }
                }
            }
            .padding(.top, 32)
            
            // Title
            Text("Authorize \(walletType.displayName)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            
            // Authorize Button
            Button(action: {
                guard !hasInitiatedConnection else { return }
                hasInitiatedConnection = true
                isLoading = true
                
                HapticManager.impact(.medium)
                
                Task {
                    await onAuthorize()
                    
                    // Reset state after a delay if still on screen
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await MainActor.run {
                        isLoading = false
                        hasInitiatedConnection = false
                    }
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(walletType.primaryColor)
                        )
                } else {
                    Text("Authorize")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(walletType.primaryColor)
                        )
                }
            }
            .disabled(isLoading || hasInitiatedConnection)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(320)])
        .background(Color.black.opacity(0.001))
        .background(Material.regularMaterial)
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .onDisappear {
            // Cancel any pending wallet connections when tray is dismissed
            if hasInitiatedConnection && isLoading {
                print("🚫 MiniWalletAuthorizationTray: Cancelling pending connection for \(walletType.displayName)")
                
                // Reset state
                isLoading = false
                hasInitiatedConnection = false
                
            }
        }
    }
}
