import SwiftUI
import LocalAuthentication

struct WalletSecurityView: View {
    let profile: SmartProfile
    @StateObject private var mpcService = MPCWalletService.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var requireBiometricForTransactions = true
    @State private var autoLockTimeout = 5 // minutes
    @State private var showKeyShareExport = false
    @State private var showRecoveryOptions = false
    @State private var isPerformingAction = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.lg) {
                        // Security Status Card
                        SecurityStatusCard(
                            profile: profile,
                            biometryType: biometricAuth.biometryType
                        )
                        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        .padding(.top, DesignTokens.Spacing.lg)
                        
                        // Biometric Settings
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("BIOMETRIC SECURITY")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            
                            VStack(spacing: 0) {
                                BiometricToggleRow(
                                    title: "Require for Transactions",
                                    subtitle: "Use biometrics to approve all transactions",
                                    isEnabled: $requireBiometricForTransactions,
                                    biometryType: biometricAuth.biometryType,
                                    isFirst: true,
                                    isLast: false
                                )
                                
                                AutoLockRow(
                                    title: "Auto-Lock",
                                    subtitle: "Require authentication after inactivity",
                                    selectedTimeout: $autoLockTimeout,
                                    isFirst: false,
                                    isLast: true
                                )
                            }
                            .background(DesignTokens.GlassEffect.thin)
                            .cornerRadius(DesignTokens.CornerRadius.lg)
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        }
                        
                        // Key Management
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("KEY MANAGEMENT")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            
                            VStack(spacing: 0) {
                                ActionRow(
                                    title: "Export Key Share",
                                    subtitle: "Create encrypted backup of your key share",
                                    icon: "square.and.arrow.up",
                                    iconColor: DesignTokens.Colors.primary,
                                    showChevron: true,
                                    isFirst: true,
                                    isLast: false
                                ) {
                                    handleKeyShareExport()
                                }
                                
                                ActionRow(
                                    title: "Recovery Options",
                                    subtitle: "Configure social recovery guardians",
                                    icon: "person.3",
                                    iconColor: DesignTokens.Colors.textSecondary,
                                    showChevron: true,
                                    isFirst: false,
                                    isLast: true
                                ) {
                                    showRecoveryOptions = true
                                }
                            }
                            .background(DesignTokens.GlassEffect.thin)
                            .cornerRadius(DesignTokens.CornerRadius.lg)
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                        }
                        
                        // Emergency Actions
                        if !(profile.isDevelopmentWallet ?? false) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("EMERGENCY")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                                
                                VStack(spacing: 0) {
                                    ActionRow(
                                        title: "Rotate Key Share",
                                        subtitle: "Generate new key share and invalidate current",
                                        icon: "arrow.triangle.2.circlepath",
                                        iconColor: DesignTokens.Colors.warning,
                                        isFirst: true,
                                        isLast: false
                                    ) {
                                        handleKeyRotation()
                                    }
                                    
                                    ActionRow(
                                        title: "Revoke Access",
                                        subtitle: "Immediately disable wallet access",
                                        icon: "xmark.shield",
                                        iconColor: DesignTokens.Colors.error,
                                        isFirst: false,
                                        isLast: true
                                    ) {
                                        handleRevokeAccess()
                                    }
                                }
                                .background(DesignTokens.GlassEffect.thin)
                                .cornerRadius(DesignTokens.CornerRadius.lg)
                                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            }
                        }
                        
                        Spacer(minLength: DesignTokens.Spacing.xl)
                    }
                }
                
                // Loading Overlay
                if isPerformingAction {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Wallet Security")
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
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showKeyShareExport) {
            KeyShareExportView(profile: profile)
        }
        .sheet(isPresented: $showRecoveryOptions) {
            RecoveryOptionsView(profile: profile)
        }
    }
    
    // MARK: - Actions
    
    private func handleKeyShareExport() {
        showKeyShareExport = true
    }
    
    private func handleKeyRotation() {
        alertTitle = "Rotate Key Share"
        alertMessage = "This will generate a new key share and invalidate the current one. You'll need to update all your connected devices. Continue?"
        showAlert = true
    }
    
    private func handleRevokeAccess() {
        alertTitle = "Revoke Access"
        alertMessage = "This will immediately disable all wallet access. You'll need to go through recovery to regain access. This action cannot be undone. Continue?"
        showAlert = true
    }
}

// MARK: - Supporting Views

struct SecurityStatusCard: View {
    let profile: SmartProfile
    let biometryType: LABiometryType
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Security Score
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Security Level")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(securityColor)
                        
                        Text(securityLevel)
                            .font(DesignTokens.Typography.headlineSmall)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                }
                
                Spacer()
                
                // Security Score Visual
                ZStack {
                    Circle()
                        .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: securityScore)
                        .stroke(securityColor, lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: securityScore)
                    
                    Text("\(Int(securityScore * 100))%")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
            }
            
            Divider()
                .background(DesignTokens.Colors.borderSecondary)
            
            // Security Features
            VStack(spacing: DesignTokens.Spacing.sm) {
                SecurityFeatureRow(
                    icon: biometryIcon,
                    title: biometryTitle,
                    isEnabled: biometryType != .none
                )
                
                SecurityFeatureRow(
                    icon: "key.horizontal",
                    title: "MPC Key Protection",
                    isEnabled: !(profile.isDevelopmentWallet ?? false)
                )
                
                SecurityFeatureRow(
                    icon: "lock.rotation",
                    title: "Key Rotation Available",
                    isEnabled: !(profile.isDevelopmentWallet ?? false)
                )
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }
    
    private var securityScore: CGFloat {
        var score: CGFloat = 0.3 // Base score
        
        if biometryType != .none {
            score += 0.3
        }
        
        if !(profile.isDevelopmentWallet ?? false) {
            score += 0.2
        }
        
        // Add more factors as needed
        
        return min(score, 1.0)
    }
    
    private var securityLevel: String {
        switch securityScore {
        case 0.8...1.0:
            return "High"
        case 0.5..<0.8:
            return "Medium"
        default:
            return "Low"
        }
    }
    
    private var securityColor: Color {
        switch securityScore {
        case 0.8...1.0:
            return DesignTokens.Colors.success
        case 0.5..<0.8:
            return DesignTokens.Colors.warning
        default:
            return DesignTokens.Colors.error
        }
    }
    
    private var biometryIcon: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock"
        }
    }
    
    private var biometryTitle: String {
        switch biometryType {
        case .faceID:
            return "Face ID Enabled"
        case .touchID:
            return "Touch ID Enabled"
        default:
            return "Biometric Authentication"
        }
    }
}

struct SecurityFeatureRow: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isEnabled ? DesignTokens.Colors.success : DesignTokens.Colors.textTertiary)
                .frame(width: 24)
            
            Text(title)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 16))
                .foregroundColor(isEnabled ? DesignTokens.Colors.success : DesignTokens.Colors.textTertiary)
        }
    }
}

struct BiometricToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    let biometryType: LABiometryType
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .disabled(biometryType == .none)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSecondary)
                    .frame(height: 0.5)
                    .padding(.leading, DesignTokens.Spacing.md)
            }
        }
    }
}

struct AutoLockRow: View {
    let title: String
    let subtitle: String
    @Binding var selectedTimeout: Int
    let isFirst: Bool
    let isLast: Bool
    
    let timeoutOptions = [1, 5, 15, 30, 60] // minutes
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(timeoutOptions, id: \.self) { timeout in
                    Button(action: {
                        selectedTimeout = timeout
                    }) {
                        HStack {
                            Text(timeoutText(for: timeout))
                            if selectedTimeout == timeout {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(timeoutText(for: selectedTimeout))
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 12)
    }
    
    private func timeoutText(for minutes: Int) -> String {
        if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            return "1 hour"
        }
    }
}

// MARK: - Placeholder Views

struct KeyShareExportView: View {
    let profile: SmartProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Key Share Export")
                    .font(.largeTitle)
                Text("Export functionality coming soon")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Export Key Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecoveryOptionsView: View {
    let profile: SmartProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Recovery Options")
                    .font(.largeTitle)
                Text("Social recovery configuration coming soon")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Recovery Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct WalletSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        WalletSecurityView(
            profile: SmartProfile(
                id: "1",
                name: "Trading Profile",
                isActive: true,
                sessionWalletAddress: "0x1234567890123456789012345678901234567890",
                linkedAccountsCount: 3,
                appsCount: 8,
                foldersCount: 2,
                isDevelopmentWallet: false,
                needsMpcGeneration: false,
                clientShare: nil,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            )
        )
        .preferredColorScheme(.dark)
    }
}
