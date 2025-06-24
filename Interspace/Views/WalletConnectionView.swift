import SwiftUI

// Protocol for wallet connection handling
protocol WalletConnectionHandler: ObservableObject {
    func handleWalletConnection(walletType: WalletType, address: String, signature: String, message: String) async throws
}

// Make ProfileViewModel conform to the protocol
extension ProfileViewModel: WalletConnectionHandler {
    func handleWalletConnection(walletType: WalletType, address: String, signature: String, message: String) async throws {
        // Profile linking logic
        let config = WalletConnectionConfig(
            strategy: .wallet,
            walletType: walletType.rawValue,
            email: nil,
            verificationCode: nil,
            walletAddress: address,
            signature: signature,
            message: message,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        try await linkWallet(config: config)
    }
}

// Make AuthViewModel conform to the protocol
extension AuthViewModel: WalletConnectionHandler {
    func handleWalletConnection(walletType: WalletType, address: String, signature: String, message: String) async throws {
        // Authentication logic
        let config = WalletConnectionConfig(
            strategy: .wallet,
            walletType: walletType.rawValue,
            email: nil,
            verificationCode: nil,
            walletAddress: address,
            signature: signature,
            message: message,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil
        )
        try await authManager.authenticate(with: config)
    }
}

struct WalletConnectionView<ViewModel: WalletConnectionHandler>: View {
    let walletType: WalletType
    @ObservedObject var viewModel: ViewModel
    let onComplete: () -> Void
    var isForAuthentication: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var connectedAddress: String?
    @State private var customName: String = ""
    @State private var walletSignature: String?
    @State private var walletMessage: String?
    @State private var showProfileCreation = false
    @State private var needsProfileCreation = false
    @State private var connectionState: ConnectionState = .idle
    @State private var hasStartedConnection = false
    @State private var connectionStartTime: Date?
    @State private var showRetryButton = false
    @State private var timeoutTimer: Timer?
    
    @StateObject private var walletService = WalletService.shared
    @StateObject private var authManager = AuthenticationManagerV2.shared
    @StateObject private var sessionCoordinator = SessionCoordinator.shared
    
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case waitingForUser  // New state for when waiting for user action in wallet
        case signing
        case linking
        case success
        case error(String)
        case timeout  // New state for timeout
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
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Connect \(walletType.displayName)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Text("Authorize Interspace to connect to your wallet")
                            .font(.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Dynamic content based on state
                    switch connectionState {
                    case .idle:
                        // Connect Button
                        Button(action: connectWallet) {
                            HStack {
                                Image(systemName: walletType.systemIconName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Connect \(walletType.displayName)")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(walletType.primaryColor)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        
                    case .connecting:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: walletType.primaryColor))
                                .scaleEffect(1.2)
                            
                            Text("Opening \(walletType.displayName)...")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            
                            Text("This will open the \(walletType.displayName) app")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                        
                    case .waitingForUser:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: walletType.primaryColor))
                                .scaleEffect(1.2)
                            
                            Text("Waiting for confirmation...")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            
                            Text("Please confirm in \(walletType.displayName)")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                            
                            if showRetryButton {
                                VStack(spacing: 12) {
                                    Text("Taking longer than usual...")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Button(action: retryConnection) {
                                        Text("Try Again")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(DesignTokens.Colors.primary)
                                    }
                                }
                                .padding(.top, 8)
                                .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 40)
                        
                    case .signing:
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: walletType.primaryColor))
                                .scaleEffect(1.2)
                            
                            Text("Please sign the message in \(walletType.displayName)")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 40)
                        
                    case .linking:
                        VStack(spacing: 20) {
                            // Linking animation
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(walletType.primaryColor)
                                .scaleEffect(connectionState == .linking ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: connectionState == .linking)
                            
                            Text(isForAuthentication ? "Setting up your account..." : "Adding to your profile...")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            
                            if let address = connectedAddress {
                                Text(address)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .padding(.vertical, 40)
                        
                    case .success:
                        VStack(spacing: 20) {
                            // Success Icon
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                            
                            Text("Success!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text(isForAuthentication ? "Your wallet is connected" : "Wallet added to profile")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .padding(.vertical, 40)
                        .onAppear {
                            // Auto-dismiss after showing success
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                onComplete()
                            }
                        }
                        
                    case .error(let error):
                        VStack(spacing: 20) {
                            // Error Icon
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            
                            // Error Message
                            VStack(spacing: 8) {
                                Text("Connection Failed")
                                    .font(.headline)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button(action: { dismiss() }) {
                                    Text("Cancel")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
                                        )
                                }
                                
                                Button(action: retryConnection) {
                                    Text("Try Again")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(walletType.primaryColor)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        
                    case .timeout:
                        VStack(spacing: 20) {
                            // Timeout Icon
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            // Timeout Message
                            VStack(spacing: 8) {
                                Text("Connection Timed Out")
                                    .font(.headline)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text("The connection is taking too long. Please try again.")
                                    .font(.subheadline)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            
                            // Retry Button
                            Button(action: retryConnection) {
                                Text("Try Again")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(walletType.primaryColor)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        }
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
                }
            }
        }
        .sheet(isPresented: $showProfileCreation) {
            CreateProfileView { profileName in
                Task {
                    // After profile creation, complete the authentication
                    await handlePostProfileCreation(profileName: profileName)
                }
            }
        }
        .onDisappear {
            // Clean up timer
            timeoutTimer?.invalidate()
        }
    }
    
    private func connectWallet() {
        // Prevent multiple connection attempts
        guard !hasStartedConnection && !isConnecting else {
            print("💳 WalletConnectionView: Connection already in progress, ignoring")
            return
        }
        
        hasStartedConnection = true
        isConnecting = true
        connectionError = nil
        connectionState = .connecting
        connectionStartTime = Date()
        showRetryButton = false
        
        // Start timeout monitoring
        startTimeoutMonitoring()
        
        // Debug MetaMask state before connecting
        if walletType == .metamask {
            WalletService.shared.debugMetaMaskState()
        }
        
        Task {
            do {
                // Small delay to show the "Opening wallet" state
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Step 1: Connect and get signature
                await MainActor.run {
                    connectionState = .waitingForUser
                }
                
                let result = try await walletService.connectWallet(walletType)
                
                await MainActor.run {
                    connectedAddress = result.address
                    walletSignature = result.signature
                    walletMessage = result.message
                    HapticManager.notification(.success)
                }
                
                // Step 2: Automatically proceed with linking/auth
                await MainActor.run {
                    connectionState = .linking
                }
                
                if isForAuthentication {
                    // Authentication flow
                    try await performAuthentication()
                } else {
                    // Profile linking flow - directly link without additional UI
                    try await performLinking()
                }
                
                // Success!
                await MainActor.run {
                    connectionState = .success
                    isConnecting = false
                }
                
            } catch let error as WalletError {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    connectionState = .error(error.localizedDescription)
                    isConnecting = false
                    hasStartedConnection = false // Reset for retry
                    HapticManager.notification(.error)
                }
            } catch {
                // Stop timeout monitoring
                timeoutTimer?.invalidate()
                
                await MainActor.run {
                    // Check if it's a user cancellation
                    if let walletError = error as? WalletError, case .userCancelled = walletError {
                        connectionError = "Connection cancelled"
                        connectionState = .error("Connection cancelled. Please try again when ready.")
                    } else if error.localizedDescription.contains("timed out") {
                        connectionState = .timeout
                    } else {
                        connectionError = error.localizedDescription
                        connectionState = .error(error.localizedDescription)
                    }
                    
                    isConnecting = false
                    hasStartedConnection = false // Reset for retry
                    HapticManager.notification(.error)
                }
            }
        }
    }
    
    private func retryConnection() {
        // Force reset wallet service state if needed
        if walletService.isConnectionInProgress {
            walletService.forceResetConnection()
        }
        
        // Reset UI state
        hasStartedConnection = false
        isConnecting = false
        connectionError = nil
        connectionState = .idle
        showRetryButton = false
        
        // Add small delay then retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connectWallet()
        }
    }
    
    private func startTimeoutMonitoring() {
        // Cancel any existing timer
        timeoutTimer?.invalidate()
        
        // Show retry button after 15 seconds
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            if connectionState == .waitingForUser {
                withAnimation {
                    showRetryButton = true
                }
            }
        }
    }
    
    private func performLinking() async throws {
        guard let signature = walletSignature,
              let message = walletMessage,
              let address = connectedAddress else {
            throw WalletError.signatureFailed("Missing signature or message")
        }
        
        // Use the protocol method for wallet connection
        try await viewModel.handleWalletConnection(
            walletType: walletType,
            address: address,
            signature: signature,
            message: message
        )
    }
    
    private func performAuthentication() async throws {
        guard let address = connectedAddress,
              let signature = walletSignature,
              let message = walletMessage else {
            throw WalletError.signatureFailed("Missing signature or message")
        }
        
        do {
            // Use the protocol method for wallet connection
            try await viewModel.handleWalletConnection(
                walletType: walletType,
                address: address,
                signature: signature,
                message: message
            )
            
        } catch let error as AuthenticationError {
            // If authentication fails, it might be a new wallet
            if error.localizedDescription.contains("not found") || 
               error.localizedDescription.contains("no account") ||
               error.localizedDescription.contains("no profile") {
                print("🔐 New wallet detected, needs profile creation")
                await MainActor.run {
                    needsProfileCreation = true
                    showProfileCreation = true
                    connectionState = .idle // Reset state for profile creation
                }
                throw error // Re-throw to stop the success state
            } else {
                // Other authentication errors
                throw error
            }
        }
    }
    
    private func handlePostProfileCreation(profileName: String) async {
        guard let address = connectedAddress,
              let signature = walletSignature,
              let message = walletMessage else { return }
        
        await MainActor.run {
            connectionState = .linking
        }
        
        do {
            // Create the authentication config
            let config = WalletConnectionConfig(
                strategy: .wallet,
                walletType: walletType.rawValue,
                email: nil,
                verificationCode: nil,
                walletAddress: address,
                signature: signature,
                message: message,
                socialProvider: nil,
                socialProfile: nil,
                oauthCode: nil
            )
            
            // Authenticate with the wallet
            try await authManager.authenticate(with: config)
            
            // Create the profile
            await sessionCoordinator.createInitialProfile(name: profileName)
            
            await MainActor.run {
                connectionState = .success
                dismiss()
                // Navigation to Apps view will be handled by ContentView
            }
        } catch {
            print("Error during post-profile creation: \(error)")
            await MainActor.run {
                connectionError = "Failed to complete setup: \(error.localizedDescription)"
                connectionState = .error(error.localizedDescription)
            }
        }
    }
}


// MARK: - Preview

struct WalletConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectionView(
            walletType: .metamask,
            viewModel: ProfileViewModel.shared,
            onComplete: {}
        )
        .preferredColorScheme(.dark)
    }
}