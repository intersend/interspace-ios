import SwiftUI

struct PINSetupView: View {
    @StateObject private var pinManager = PINCodeManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: SetupStep = .enterPIN
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    enum SetupStep {
        case enterPIN
        case confirmPIN
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
                        Text(currentStep == .enterPIN ? "Create PIN" : "Confirm PIN")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(currentStep == .enterPIN ? 
                             "Create a 6-digit PIN for backup access" : 
                             "Enter your PIN again to confirm")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // PIN Input
                    VStack(spacing: 24) {
                        if currentStep == .enterPIN {
                            PINInputField(
                                pin: $firstPIN,
                                isSecure: true,
                                onComplete: handlePINComplete
                            )
                            .id("first-pin")
                        } else {
                            PINInputField(
                                pin: $confirmPIN,
                                isSecure: true,
                                onComplete: handlePINComplete
                            )
                            .id("confirm-pin")
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    
                    Spacer()
                    
                    // Cancel button
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 30)
                
                if isProcessing {
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
    
    private func handlePINComplete() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showError = false
        }
        
        switch currentStep {
        case .enterPIN:
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Move to confirmation step with a small delay to ensure keyboard resets
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentStep = .confirmPIN
                }
            }
            
        case .confirmPIN:
            if firstPIN == confirmPIN {
                savePIN()
            } else {
                // PINs don't match
                errorMessage = "PINs don't match. Please try again."
                showError = true
                confirmPIN = ""
                
                // Error haptic
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func savePIN() {
        isProcessing = true
        
        Task {
            do {
                try await pinManager.setPIN(firstPIN)
                
                await MainActor.run {
                    // Success haptic
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    isProcessing = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                    confirmPIN = ""
                    
                    // Error haptic
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - PIN Input Field

struct PINInputField: View {
    @Binding var pin: String
    let isSecure: Bool
    let onComplete: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<6) { index in
                    Circle()
                        .fill(index < pin.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(index < pin.count ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: pin.count)
                }
            }
            
            // Hidden text field
            TextField("", text: Binding(
                get: { pin },
                set: { newValue in
                    // Ensure only digits and limit to 6
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                    pin = filtered
                    
                    // Auto-complete when 6 digits entered
                    if filtered.count == 6 {
                        // Delay slightly to ensure the binding updates
                        DispatchQueue.main.async {
                            onComplete()
                        }
                    }
                }
            ))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 1, height: 1)
        }
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

#Preview {
    PINSetupView(
        onSuccess: {},
        onCancel: {}
    )
}