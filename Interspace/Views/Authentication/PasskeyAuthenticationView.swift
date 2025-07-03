import SwiftUI
import AuthenticationServices

struct PasskeyAuthenticationView: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    
    @EnvironmentObject var authManager: AuthenticationManagerV2
    @State private var email = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isRegistering = false
    
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        // Passkey Icon
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 40)
                        
                        Text("Sign in with Passkey")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Use Face ID or Touch ID to sign in securely")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Email field (optional for passkey)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email (optional)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(LiquidGlassTextFieldStyle())
                                .focused($isEmailFocused)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .submitLabel(.continue)
                                .onSubmit {
                                    authenticateWithPasskey()
                                }
                        }
                        
                        // Sign In Button
                        Button(action: authenticateWithPasskey) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 20, weight: .medium))
                                    Text("Sign In with Passkey")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                        
                        // Alternative: Register new passkey
                        if !email.isEmpty {
                            Button(action: { isRegistering = true }) {
                                Text("Register new passkey for this email")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Info text
                        Text("Your passkey is securely stored on this device")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            // Check if passkeys are available
            if !PasskeyService.isPasskeyAvailable() {
                errorMessage = "Passkeys require iOS 16 or later"
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $isRegistering) {
            PasskeyRegistrationView(
                email: email,
                isPresented: $isRegistering,
                onSuccess: {
                    isRegistering = false
                    onSuccess()
                }
            )
        }
    }
    
    private func authenticateWithPasskey() {
        isLoading = true
        
        Task {
            do {
                // Use email if provided, otherwise nil for system to choose
                let username = email.isEmpty ? nil : email
                try await authManager.authenticateWithPasskey(email: username)
                
                await MainActor.run {
                    isLoading = false
                    HapticManager.notification(.success)
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    HapticManager.notification(.error)
                    
                    // Handle specific error cases
                    if let authError = error as? AuthenticationError {
                        switch authError {
                        case .passkeyNotFound:
                            errorMessage = "No passkey found for this account. Please register a passkey first."
                            if !email.isEmpty {
                                isRegistering = true
                            }
                        case .passkeyAuthenticationFailed(let message):
                            errorMessage = message
                            showError = true
                        default:
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Passkey Registration View

struct PasskeyRegistrationView: View {
    let email: String
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Icon
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 60)
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("Register Passkey")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Create a passkey for \(email)")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Register Button
                    Button(action: registerPasskey) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Create Passkey")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                    
                    // Info
                    Text("This passkey will be saved to your iCloud Keychain")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func registerPasskey() {
        // This would need to be implemented with proper registration flow
        // For now, show error message
        errorMessage = "Passkey registration requires you to be signed in first. Please sign in with email or wallet, then add a passkey from your profile settings."
        showError = true
    }
}

// MARK: - Preview

struct PasskeyAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        PasskeyAuthenticationView(isPresented: .constant(true)) { }
            .environmentObject(AuthenticationManagerV2.shared)
            .preferredColorScheme(.dark)
    }
}