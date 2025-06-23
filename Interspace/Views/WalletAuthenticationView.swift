import SwiftUI

struct WalletAuthenticationView: View {
    let walletType: WalletType
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var authenticationStage: AuthStage = .connecting
    @State private var walletAddress: String?
    @State private var walletSignature: String?
    @State private var walletMessage: String?
    @State private var walletProfileInfo: WalletProfileInfo?
    @State private var selectedProfileId: String?
    @State private var newProfileName: String = ""
    @State private var hasAttemptedConnection = false
    
    @StateObject private var walletService = WalletService.shared
    
    enum AuthStage {
        case connecting
        case connected
        case checkingProfile
        case selectProfile
        case createProfile
        case completed
        case error
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Wallet Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(walletType.primaryColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: walletType.systemIconName)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(walletType.primaryColor)
                    }
                    .padding(.top, 40)
                    
                    // Dynamic content based on stage
                    switch authenticationStage {
                    case .connecting:
                        connectingView
                    case .connected:
                        connectedView
                    case .checkingProfile:
                        checkingProfileView
                    case .selectProfile:
                        selectProfileView
                    case .createProfile:
                        createProfileView
                    case .completed:
                        completedView
                    case .error:
                        errorView
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                    .disabled(isConnecting)
                }
            }
        }
        .onAppear {
            if authenticationStage == .connecting && !hasAttemptedConnection {
                hasAttemptedConnection = true
                connectWallet()
            }
        }
    }
    
    // MARK: - Stage Views
    
    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                .scaleEffect(1.2)
            
            Text("Connecting to \(walletType.displayName)...")
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            Text("Please approve the connection in your wallet")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
    
    private var connectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Wallet Connected!")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            if let address = walletAddress {
                Text(address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 40)
            }
            
            Text("Checking for existing profiles...")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.top, 8)
        }
    }
    
    private var checkingProfileView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                .scaleEffect(1.2)
            
            Text("Checking your profile...")
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    private var selectProfileView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("Profile Required")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("This wallet doesn't have a profile yet. Create one to continue.")
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                authenticationStage = .createProfile
            }) {
                Text("Create Profile")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignTokens.Colors.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var createProfileView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("Create Your Profile")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Choose a name for your smart profile")
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Profile Name", text: $newProfileName)
                    .textFieldStyle(LiquidGlassTextFieldStyle())
                
                Text("You can change this later")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 40)
            
            Button(action: createProfileAndAuthenticate) {
                Text("Create & Continue")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignTokens.Colors.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Welcome to Interspace!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            Text("Your wallet is now connected and ready to use")
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .onAppear {
            // Auto-dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Connection Failed")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
            if let error = connectionError {
                Text(error)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                connectionError = nil
                authenticationStage = .connecting
                hasAttemptedConnection = false
                // Small delay to allow state to reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasAttemptedConnection = true
                    connectWallet()
                }
            }) {
                Text("Try Again")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignTokens.Colors.primary, lineWidth: 2)
                    )
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Actions
    
    private func connectWallet() {
        // Prevent multiple simultaneous attempts
        guard !isConnecting else {
            print("🔐 WalletAuthenticationView: Connection already in progress, ignoring")
            return
        }
        
        isConnecting = true
        
        Task {
            do {
                // Step 1: Connect to wallet
                let result = try await walletService.connectWallet(walletType)
                
                await MainActor.run {
                    walletAddress = result.address
                    walletSignature = result.signature
                    walletMessage = result.message
                    authenticationStage = .connected
                    HapticManager.notification(.success)
                }
                
                // Wait a moment to show the connected state
                try await Task.sleep(nanoseconds: 1_500_000_000)
                
                // Step 2: Authenticate with backend
                await MainActor.run {
                    authenticationStage = .checkingProfile
                }
                
                let config = WalletConnectionConfig(
                    strategy: .wallet,
                    walletType: walletType.rawValue,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: result.address,
                    signature: result.signature,
                    message: result.message,
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                // Try to authenticate directly
                do {
                    try await viewModel.authManager.authenticate(with: config)
                    await MainActor.run {
                        authenticationStage = .completed
                    }
                    completeAuthentication(config: config)
                } catch {
                    // If authentication fails, assume new wallet needs profile
                    await MainActor.run {
                        authenticationStage = .selectProfile
                    }
                }
                
            } catch let error as WalletError {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    authenticationStage = .error
                    isConnecting = false
                    HapticManager.notification(.error)
                }
            } catch {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    authenticationStage = .error
                    isConnecting = false
                    HapticManager.notification(.error)
                }
            }
        }
    }
    
    private func createProfileAndAuthenticate() {
        guard !newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let address = walletAddress,
              let signature = walletSignature else { return }
        
        Task {
            do {
                // Create profile first
                let profile = try await viewModel.authManager.createProfileForWallet(
                    name: newProfileName,
                    walletAddress: address
                )
                
                selectedProfileId = profile.id
                
                // Now complete authentication with the stored signature
                let config = WalletConnectionConfig(
                    strategy: .wallet,
                    walletType: walletType.rawValue,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: address,
                    signature: signature,
                    message: walletMessage ?? "",
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                await completeAuthentication(config: config)
                
            } catch {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    authenticationStage = .error
                }
            }
        }
    }
    
    private func completeAuthentication(config: WalletConnectionConfig) {
        Task {
            do {
                try await viewModel.authManager.authenticate(with: config)
                
                await MainActor.run {
                    authenticationStage = .completed
                    HapticManager.notification(.success)
                }
            } catch {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    authenticationStage = .error
                }
            }
        }
    }
}

// MARK: - Preview
struct WalletAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        WalletAuthenticationView(
            walletType: .metamask,
            viewModel: AuthViewModel()
        )
        .preferredColorScheme(.dark)
    }
}