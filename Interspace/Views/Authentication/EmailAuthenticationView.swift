import SwiftUI

struct EmailAuthenticationView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = EmailAuthViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    
    enum Field {
        case email
        case code
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Icon and Title
                            VStack(spacing: 16) {
                                Image(systemName: "envelope.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text(viewModel.currentStep == .email ? "Sign in with Email" : "Verify Your Email")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(viewModel.currentStep == .email ? 
                                     "Enter your email to continue" : 
                                     "We sent a code to \(viewModel.email)")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            
                            // Input Section
                            VStack(spacing: 20) {
                                if viewModel.currentStep == .email {
                                    // Email Input
                                    VStack(alignment: .leading, spacing: 8) {
                                        TextField("Email", text: $viewModel.email)
                                            .textFieldStyle(AppleTextFieldStyle())
                                            .keyboardType(.emailAddress)
                                            .textContentType(.emailAddress)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .focused($focusedField, equals: .email)
                                            .submitLabel(.continue)
                                            .onSubmit {
                                                if viewModel.isEmailValid {
                                                    viewModel.sendVerificationCode()
                                                }
                                            }
                                        
                                        if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                                            Text("Please enter a valid email")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    Button(action: {
                                        viewModel.sendVerificationCode()
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.isEmailValid ? Color.blue : Color.gray.opacity(0.3))
                                            
                                            if viewModel.isLoading {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Text("Continue")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .frame(height: 50)
                                    }
                                    .disabled(!viewModel.isEmailValid || viewModel.isLoading)
                                    
                                } else {
                                    // Verification Code Input
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Verification Code")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if viewModel.canResendCode {
                                                Button("Resend") {
                                                    viewModel.resendVerificationCode()
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                            } else {
                                                Text("Resend in \(viewModel.resendCountdown)s")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        TextField("000000", text: $viewModel.verificationCode)
                                            .textFieldStyle(AppleTextFieldStyle())
                                            .keyboardType(.numberPad)
                                            .textContentType(.oneTimeCode)
                                            .focused($focusedField, equals: .code)
                                            .onChange(of: viewModel.verificationCode) { newValue in
                                                // Auto-submit when 6 digits entered
                                                if newValue.count == 6 {
                                                    viewModel.verifyCode()
                                                }
                                            }
                                            .onReceive(viewModel.verificationCode.publisher.collect()) {
                                                // Limit to 6 digits
                                                let filtered = String($0.prefix(6))
                                                if filtered != viewModel.verificationCode {
                                                    viewModel.verificationCode = filtered
                                                }
                                            }
                                        
                                        if !viewModel.verificationCode.isEmpty && viewModel.verificationCode.count < 6 {
                                            Text("Enter all 6 digits")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Button(action: {
                                        viewModel.verifyCode()
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.isCodeValid ? Color.blue : Color.gray.opacity(0.3))
                                            
                                            if viewModel.isLoading {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Text("Verify")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .frame(height: 50)
                                    }
                                    .disabled(!viewModel.isCodeValid || viewModel.isLoading)
                                    
                                    Button("Change Email") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            viewModel.goBackToEmail()
                                            focusedField = .email
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 32)
                            
                            Spacer(minLength: 100)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            focusedField = .email
        }
        .onChange(of: viewModel.currentStep) { newStep in
            withAnimation(.easeInOut(duration: 0.3)) {
                if newStep == .code {
                    focusedField = .code
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class EmailAuthViewModel: ObservableObject {
    @Published var currentStep: AuthStep = .email
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var canResendCode = true
    @Published var resendCountdown = 0
    @Published var animationTrigger = 0
    @Published var isAuthenticated = false
    
    private var resendTimer: Timer?
    private let authManager = AuthenticationManagerV2.shared
    
    enum AuthStep {
        case email
        case code
    }
    
    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isCodeValid: Bool {
        verificationCode.count == 6 && verificationCode.allSatisfy { $0.isNumber }
    }
    
    deinit {
        resendTimer?.invalidate()
    }
    
    func sendVerificationCode() {
        guard isEmailValid else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await authManager.sendEmailCode(email)
                
                if response.success {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .code
                        animationTrigger += 1
                    }
                    startResendTimer()
                } else {
                    errorMessage = response.message ?? "Failed to send code"
                    showError = true
                }
                
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    func verifyCode() {
        guard isCodeValid else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let config = WalletConnectionConfig(
                    strategy: .email,
                    walletType: nil,
                    email: email,
                    verificationCode: verificationCode,
                    walletAddress: nil,
                    signature: nil,
                    message: nil,
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                try await authManager.authenticate(with: config)
                isAuthenticated = true
                
            } catch {
                isLoading = false
                errorMessage = "Invalid code. Please try again."
                showError = true
                
                // Clear the code for retry
                verificationCode = ""
            }
        }
    }
    
    func resendVerificationCode() {
        guard canResendCode else { return }
        
        Task {
            do {
                let response = try await authManager.resendEmailCode(email)
                
                if response.success {
                    startResendTimer()
                    animationTrigger += 1
                } else {
                    errorMessage = response.message ?? "Failed to resend code"
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    func goBackToEmail() {
        currentStep = .email
        verificationCode = ""
        resendTimer?.invalidate()
        canResendCode = true
        resendCountdown = 0
    }
    
    private func startResendTimer() {
        canResendCode = false
        resendCountdown = 60
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                if self.resendCountdown > 0 {
                    self.resendCountdown -= 1
                } else {
                    self.canResendCode = true
                    self.resendTimer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct AppleTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
            .font(.body)
    }
}

// MARK: - Preview

struct EmailAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailAuthenticationView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}