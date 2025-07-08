import SwiftUI

struct PINEntryView: View {
    @StateObject private var pinManager = PINCodeManager.shared
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isValidating = false
    @State private var shakeOffset: CGFloat = 0
    
    let onSuccess: () -> Void
    let onCancel: (() -> Void)?
    
    init(onSuccess: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Enter PIN")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if pinManager.isLocked {
                            Text("Too many failed attempts")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        } else if pinManager.failedAttempts > 0 {
                            Text("\(5 - pinManager.failedAttempts) attempts remaining")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        } else {
                            Text("Enter your 6-digit PIN")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // PIN Input
                    VStack(spacing: 24) {
                        PINInputField(
                            pin: $pin,
                            isSecure: true,
                            onComplete: validatePIN
                        )
                        .offset(x: shakeOffset)
                        .disabled(pinManager.isLocked)
                        
                        if showError {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    
                    Spacer()
                    
                    // Bottom buttons
                    VStack(spacing: 16) {
                        if let onCancel = onCancel {
                            Button {
                                onCancel()
                            } label: {
                                HStack {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 18))
                                    Text("Try Face ID Again")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.white.opacity(0.15))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 30)
                
                if isValidating {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
    
    @Environment(\.dismiss) private var dismiss
    
    private func validatePIN() {
        guard !pinManager.isLocked else {
            showLockedError()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showError = false
        }
        
        isValidating = true
        
        Task {
            do {
                let isValid = try await pinManager.validatePIN(pin)
                
                await MainActor.run {
                    isValidating = false
                    
                    if isValid {
                        // Success haptic
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        
                        onSuccess()
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    errorMessage = error.localizedDescription
                    showError = true
                    pin = ""
                    
                    // Shake animation
                    withAnimation(.default) {
                        shakeOffset = 10
                    }
                    withAnimation(.default.delay(0.1)) {
                        shakeOffset = -10
                    }
                    withAnimation(.default.delay(0.2)) {
                        shakeOffset = 10
                    }
                    withAnimation(.default.delay(0.3)) {
                        shakeOffset = 0
                    }
                    
                    // Error haptic
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                    
                    // Check if we should show locked message
                    if pinManager.isLocked {
                        showLockedError()
                    }
                }
            }
        }
    }
    
    private func showLockedError() {
        errorMessage = "Too many failed attempts. Please try again later."
        showError = true
        
        // Heavy haptic for lockout
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}