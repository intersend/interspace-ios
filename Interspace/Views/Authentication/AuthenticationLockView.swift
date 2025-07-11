import SwiftUI
import LocalAuthentication

struct AuthenticationLockView: View {
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @StateObject private var pinManager = PINCodeManager.shared
    
    @State private var showPINEntry = false {
        didSet {
            print("DEBUG: showPINEntry changed to: \(showPINEntry)")
        }
    }
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            if showPINEntry {
                PINEntryView(
                    onSuccess: {
                        // With 100-year tokens, we don't need to validate
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sessionCoordinator.sessionState = .authenticated
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPINEntry = false
                        }
                        // Small delay before retrying Face ID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            attemptBiometricAuthentication()
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), 
                                       removal: .move(edge: .bottom).combined(with: .opacity)))
            }
            
            if !showPINEntry {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo
                    Image("SplashScreenLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    // Spinner
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPINEntry)
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showPINEntry = true
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Small delay to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                attemptBiometricAuthentication()
            }
        }
    }
    
    private func attemptBiometricAuthentication() {
        print("DEBUG: attemptBiometricAuthentication called")
        guard biometricManager.isAvailable else {
            print("DEBUG: Biometric not available, showing PIN")
            showPINEntry = true
            return
        }
        
        isAuthenticating = true
        
        Task { @MainActor in
            do {
                print("DEBUG: Calling authenticateWithOptions")
                let success = try await biometricManager.authenticateWithOptions(
                    reason: "Unlock Interspace",
                    fallbackTitle: nil  // Don't show fallback button
                )
                print("DEBUG: authenticateWithOptions returned: \(success)")
                
                if success {
                    // With 100-year tokens, we don't need to validate
                    // Haptic feedback for success
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sessionCoordinator.sessionState = .authenticated
                    }
                } else {
                    print("DEBUG: Face ID returned false - showing PIN")
                    // Authentication failed or was cancelled - show PIN
                    showPINEntry = true
                }
            } catch {
                print("DEBUG: authenticateWithOptions threw error: \(error)")
                // Any error (including cancel) - show PIN
                
                // Check if it's a cancel error
                if let laError = error as? LAError,
                   (laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel) {
                    print("DEBUG: User cancelled Face ID - showing PIN")
                }
                
                // Always show PIN on any error
                showPINEntry = true
            }
            
            isAuthenticating = false
        }
    }
}

#Preview {
    AuthenticationLockView()
        .environmentObject(SessionCoordinator.shared)
}