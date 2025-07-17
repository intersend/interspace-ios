import SwiftUI
import Combine

/// Streamlined Phantom wallet connection view
/// Provides Apple-like UX with minimal steps
struct PhantomConnectionView: View {
    @Binding var isPresented: Bool
    let onCompletion: (String, String, String, String?, String?) -> Void
    
    @StateObject private var walletService = WalletServiceV2.shared
    @State private var connectionState: ConnectionUIState = .ready
    @State private var errorMessage: String?
    @State private var hasOpenedWallet = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum ConnectionUIState {
        case ready
        case connecting
        case signingMessage
        case completed
        case error(String)
        
        var icon: String {
            switch self {
            case .ready, .connecting, .signingMessage:
                return "link.circle.fill"
            case .completed:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .ready, .connecting, .signingMessage:
                return .purple
            case .completed:
                return .green
            case .error:
                return .red
            }
        }
        
        var message: String {
            switch self {
            case .ready:
                return "Tap to connect with Phantom"
            case .connecting:
                return "Opening Phantom..."
            case .signingMessage:
                return "Sign the message in Phantom"
            case .completed:
                return "Successfully connected!"
            case .error(let message):
                return message
            }
        }
        
        var showProgress: Bool {
            switch self {
            case .connecting, .signingMessage:
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
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Wallet icon
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image("phantom")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .scaleEffect(connectionState.showProgress ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: connectionState.showProgress)
                    
                    // Status
                    VStack(spacing: 16) {
                        Text("Connect Phantom")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            if connectionState.showProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: connectionState.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(connectionState.iconColor)
                            }
                            
                            Text(connectionState.message)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .animation(.easeInOut, value: connectionState.showProgress)
                    }
                    
                    Spacer()
                    
                    // Action button
                    if case .ready = connectionState {
                        Button {
                            connectWallet()
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Connect Wallet")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                        }
                        .padding(.horizontal, 24)
                    } else if case .error = connectionState {
                        VStack(spacing: 12) {
                            Button {
                                connectionState = .ready
                                errorMessage = nil
                            } label: {
                                Text("Try Again")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                    )
                            }
                            
                            Button {
                                dismiss()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Help text
                    if !walletService.isWalletInstalled(.phantom) {
                        Button {
                            openAppStore()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Don't have Phantom?")
                                    .foregroundColor(.gray)
                                Text("Get it here")
                                    .foregroundColor(.purple)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)
                            }
                            .font(.system(size: 14))
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.bottom, 40)
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
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(connectionState.showProgress)
        .onAppear {
            checkWalletInstalled()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkWalletInstalled() {
        if !walletService.isWalletInstalled(.phantom) {
            connectionState = .ready
        }
    }
    
    private func connectWallet() {
        guard walletService.isWalletInstalled(.phantom) else {
            openAppStore()
            return
        }
        
        Task {
            await performConnection()
        }
    }
    
    @MainActor
    private func performConnection() async {
        // Update state
        connectionState = .connecting
        hasOpenedWallet = true
        
        do {
            // Authenticate with Phantom (connect + SIWE)
            let result = try await walletService.authenticateWithWallet(walletType: .phantom)
            
            // Update state
            connectionState = .completed
            
            // Brief delay to show success
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            // Call completion
            onCompletion(
                result.address,
                result.signature,
                result.message,
                result.walletName ?? "Phantom",
                result.walletIcon
            )
            
            // Dismiss
            dismiss()
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        HapticManager.notification(.error)
        
        if let walletError = error as? WalletError {
            switch walletError {
            case .walletNotInstalled:
                connectionState = .error("Phantom is not installed")
            case .userCancelled:
                connectionState = .error("Connection was cancelled")
            case .timeout:
                connectionState = .error("Connection timed out")
            default:
                connectionState = .error(walletError.localizedDescription)
            }
        } else {
            connectionState = .error(error.localizedDescription)
        }
    }
    
    private func openAppStore() {
        if let url = WalletType.phantom.appStoreURL {
            UIApplication.shared.open(url)
        }
    }
}