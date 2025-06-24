import SwiftUI
import LocalAuthentication

// MARK: - MPCWalletSetupView

struct MPCWalletSetupView: View {
    @StateObject private var viewModel = MPCWalletSetupViewModel()
    @ObservedObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = SetupStep.welcome
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case biometricSetup = 1
        case keyGeneration = 2
        case backup = 3
        case confirmation = 4
        
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .biometricSetup: return "Security Setup"
            case .keyGeneration: return "Creating Wallet"
            case .backup: return "Backup Options"
            case .confirmation: return "Complete Setup"
            }
        }
        
        var icon: String {
            switch self {
            case .welcome: return "sparkles"
            case .biometricSetup: return "faceid"
            case .keyGeneration: return "key.fill"
            case .backup: return "lock.shield.fill"
            case .confirmation: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Progress Indicator
                progressView
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding()
                }
                
                // Action Buttons
                actionButtons
                    .padding()
            }
        }
        .alert("Setup Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            viewModel.profileViewModel = profileViewModel
        }
    }
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(currentStep.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding()
        .background(
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        )
    }
    
    private var progressView: some View {
        HStack(spacing: 8) {
            ForEach(SetupStep.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step.rawValue <= currentStep.rawValue ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeView
            
        case .biometricSetup:
            biometricSetupView
            
        case .keyGeneration:
            keyGenerationView
            
        case .backup:
            backupView
            
        case .confirmation:
            confirmationView
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.primary)
                .padding()
                .background(
                    Circle()
                        .fill(DesignTokens.Colors.primary.opacity(0.1))
                )
            
            VStack(spacing: 16) {
                Text("Secure MPC Wallet")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your wallet will be protected by multi-party computation, ensuring maximum security for your digital assets.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Features
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "lock.shield",
                    title: "Military-grade Security",
                    description: "2-of-2 threshold signatures protect your assets"
                )
                
                FeatureRow(
                    icon: "faceid",
                    title: "Biometric Protection",
                    description: "Face ID or Touch ID required for transactions"
                )
                
                FeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Key Rotation",
                    description: "Automatic security updates every 30 days"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var biometricSetupView: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: BiometricAuthManager.shared.getBiometryIcon())
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.primary)
            
            VStack(spacing: 16) {
                Text("Enable \(BiometricAuthManager.shared.getBiometryTypeString())")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Protect your wallet with biometric authentication for all transactions.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            if viewModel.biometricEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(BiometricAuthManager.shared.getBiometryTypeString()) is enabled")
                            .foregroundColor(.white)
                    }
                    
                    Text("You'll be asked to authenticate when performing sensitive operations")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            Button {
                Task {
                    await viewModel.enableBiometrics()
                }
            } label: {
                Label(
                    viewModel.biometricEnabled ? "Re-enable Biometrics" : "Enable Biometrics",
                    systemImage: BiometricAuthManager.shared.getBiometryIcon()
                )
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignTokens.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var keyGenerationView: some View {
        VStack(spacing: 32) {
            if viewModel.isGeneratingWallet {
                // Loading state
                VStack(spacing: 24) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Generating your secure wallet...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("This may take a few moments")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxHeight: .infinity)
            } else if let walletInfo = viewModel.generatedWallet {
                // Success state
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Wallet Created Successfully!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Wallet info card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Address")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                        
                        Text(walletInfo.address)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Button {
                            UIPasteboard.general.string = walletInfo.address
                            HapticManager.notification(.success)
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignTokens.Colors.primary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            } else {
                // Initial state
                VStack(spacing: 24) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Text("Ready to create your wallet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Tap below to generate your secure MPC wallet")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var backupView: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.primary)
            
            VStack(spacing: 16) {
                Text("Backup & Recovery")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose how you want to backup your wallet for recovery purposes.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                BackupOption(
                    icon: "icloud",
                    title: "iCloud Backup",
                    description: "Encrypted backup stored in your iCloud",
                    isSelected: viewModel.selectedBackupMethod == .icloud,
                    action: { viewModel.selectedBackupMethod = .icloud }
                )
                
                BackupOption(
                    icon: "square.and.arrow.down",
                    title: "Manual Backup",
                    description: "Export encrypted backup to save elsewhere",
                    isSelected: viewModel.selectedBackupMethod == .manual,
                    action: { viewModel.selectedBackupMethod = .manual }
                )
                
                BackupOption(
                    icon: "xmark.circle",
                    title: "Skip for Now",
                    description: "You can set up backup later in settings",
                    isSelected: viewModel.selectedBackupMethod == .skip,
                    action: { viewModel.selectedBackupMethod = .skip }
                )
            }
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Setup Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your MPC wallet is now ready to use. You can manage security settings anytime from your profile.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Summary card
            VStack(spacing: 16) {
                SummaryRow(title: "Wallet Type", value: "MPC Secured")
                SummaryRow(title: "Biometric Protection", value: viewModel.biometricEnabled ? "Enabled" : "Disabled")
                SummaryRow(title: "Backup Method", value: viewModel.selectedBackupMethod.displayName)
                SummaryRow(title: "Key Rotation", value: "Every 30 days")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .welcome {
                Button {
                    withAnimation {
                        currentStep = SetupStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                Task {
                    await handleNext()
                }
            } label: {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(nextButtonTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(nextButtonEnabled ? DesignTokens.Colors.primary : Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!nextButtonEnabled || viewModel.isProcessing)
        }
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Get Started"
        case .biometricSetup:
            return viewModel.biometricEnabled ? "Continue" : "Skip"
        case .keyGeneration:
            return viewModel.generatedWallet != nil ? "Continue" : "Generate Wallet"
        case .backup:
            return "Continue"
        case .confirmation:
            return "Finish"
        }
    }
    
    private var nextButtonEnabled: Bool {
        switch currentStep {
        case .keyGeneration:
            return !viewModel.isGeneratingWallet
        default:
            return true
        }
    }
    
    private func handleNext() async {
        switch currentStep {
        case .welcome:
            withAnimation {
                currentStep = .biometricSetup
            }
            
        case .biometricSetup:
            withAnimation {
                currentStep = .keyGeneration
            }
            
        case .keyGeneration:
            if viewModel.generatedWallet == nil {
                do {
                    try await viewModel.generateWallet()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }
            }
            withAnimation {
                currentStep = .backup
            }
            
        case .backup:
            if viewModel.selectedBackupMethod != .skip {
                do {
                    try await viewModel.performBackup()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }
            }
            withAnimation {
                currentStep = .confirmation
            }
            
        case .confirmation:
            await viewModel.completeSetup()
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Colors.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(DesignTokens.Colors.primary.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

struct BackupOption: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? DesignTokens.Colors.primary : .white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? DesignTokens.Colors.primary.opacity(0.1) : Color.white.opacity(0.05))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignTokens.Colors.primary : .white.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? DesignTokens.Colors.primary.opacity(0.05) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? DesignTokens.Colors.primary.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - View Model

@MainActor
final class MPCWalletSetupViewModel: ObservableObject {
    @Published var biometricEnabled = false
    @Published var isGeneratingWallet = false
    @Published var generatedWallet: WalletInfo?
    @Published var selectedBackupMethod: BackupMethod = .icloud
    @Published var isProcessing = false
    
    weak var profileViewModel: ProfileViewModel?
    
    enum BackupMethod {
        case icloud
        case manual
        case skip
        
        var displayName: String {
            switch self {
            case .icloud: return "iCloud Backup"
            case .manual: return "Manual Backup"
            case .skip: return "Not Set"
            }
        }
    }
    
    func enableBiometrics() async {
        do {
            try await BiometricAuthManager.shared.authenticate(reason: "Enable biometric protection for your wallet")
            biometricEnabled = true
            HapticManager.notification(.success)
        } catch {
            print("Biometric setup failed: \(error)")
        }
    }
    
    func generateWallet() async throws {
        guard let profileId = profileViewModel?.activeProfile?.id else { return }
        
        isGeneratingWallet = true
        defer { isGeneratingWallet = false }
        
        do {
            let walletInfo = try await MPCWalletService.shared.generateWallet(for: profileId)
            generatedWallet = walletInfo
            HapticManager.notification(.success)
        } catch {
            HapticManager.notification(.error)
            throw error
        }
    }
    
    func performBackup() async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        switch selectedBackupMethod {
        case .icloud:
            // TODO: Implement iCloud backup
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate backup
            
        case .manual:
            // TODO: Implement manual backup export
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate export
            
        case .skip:
            break
        }
        
        HapticManager.notification(.success)
    }
    
    func completeSetup() async {
        guard let profileId = profileViewModel?.activeProfile?.id,
              let walletInfo = generatedWallet else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Store MPC wallet info in view model
        profileViewModel?.mpcWalletInfo = walletInfo
        
        // Link the wallet address to the profile
        await profileViewModel?.linkAccount(
            address: walletInfo.address,
            walletType: .mpc,
            customName: "MPC Wallet"
        )
        
        // Save preferences
        UserDefaults.standard.set(biometricEnabled, forKey: "mpc_biometric_enabled_\(profileId)")
        UserDefaults.standard.set(selectedBackupMethod == .icloud, forKey: "mpc_icloud_backup_\(profileId)")
        
        HapticManager.notification(.success)
    }
}