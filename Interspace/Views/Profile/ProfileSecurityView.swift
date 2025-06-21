import SwiftUI
import LocalAuthentication

struct ProfileSecurityView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showDeleteConfirmation: Bool
    
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Text("Security")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color(white: 0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            List {
                    // Biometric Lock Section
                    Section(header: Text("AUTHENTICATION")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)) {
                        
                        Toggle(isOn: $biometricLockEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: biometricIcon)
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                    .frame(width: 36, height: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(biometricTitle)
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Text("Require authentication to access your profile")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .listRowBackground(Color(white: 0.1))
                        .onChange(of: biometricLockEnabled) { oldValue, newValue in
                            if newValue {
                                authenticateWithBiometrics()
                            }
                        }
                    }
                    
                    // Account Management Section
                    Section(header: Text("DANGER ZONE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)) {
                        
                        // Delete Account Button
                        Button(action: {
                            HapticManager.notification(.warning)
                            dismiss()
                            // Small delay to allow sheet dismissal
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showDeleteConfirmation = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                    .frame(width: 36, height: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete Account")
                                        .font(.body)
                                        .foregroundColor(.red)
                                    
                                    Text("Permanently delete your account and all data")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    
                    // Security Tips Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Security Tips", systemImage: "shield.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                SecurityTipRow(text: "Never share your private keys or recovery phrases")
                                SecurityTipRow(text: "Enable biometric authentication for added security")
                                SecurityTipRow(text: "Regularly review your connected accounts")
                                SecurityTipRow(text: "Keep your device software up to date")
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color(white: 0.05))
                    }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            checkBiometricType()
        }
    }
    
    // MARK: - Biometric Helpers
    
    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }
    
    private var biometricTitle: String {
        switch biometricType {
        case .faceID:
            return "Face ID Lock"
        case .touchID:
            return "Touch ID Lock"
        default:
            return "Biometric Lock"
        }
    }
    
    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Enable biometric authentication to secure your profile"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        HapticManager.notification(.success)
                    } else {
                        // Authentication failed, revert toggle
                        biometricLockEnabled = false
                        HapticManager.notification(.error)
                    }
                }
            }
        } else {
            // Biometrics not available, revert toggle
            biometricLockEnabled = false
        }
    }
}

// MARK: - Security Tip Row

struct SecurityTipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 6, height: 6)
                .offset(y: 6)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

struct ProfileSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSecurityView(showDeleteConfirmation: .constant(false))
            .preferredColorScheme(.dark)
    }
}