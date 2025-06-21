import SwiftUI

struct EmailAuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Custom navigation bar
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isEmailCodeSent {
                            Button(action: {
                                withAnimation(DesignTokens.Animation.easeInOut) {
                                    viewModel.isEmailCodeSent = false
                                    viewModel.verificationCode = ""
                                    isEmailFocused = true
                                }
                            }) {
                                Text("Back")
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.xl) {
                            // Header
                            VStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: "envelope.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(DesignTokens.Colors.primary)
                                    .animation(DesignTokens.Animation.spring.delay(0.1), value: true)
                                
                                Text("Email Authentication")
                                    .font(DesignTokens.Typography.headlineLarge)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                    .animation(DesignTokens.Animation.spring.delay(0.2), value: true)
                                
                                Text(viewModel.isEmailCodeSent ? 
                                     "Enter the 6-digit code sent to your email" :
                                     "Enter your email address to get started"
                                )
                                    .font(DesignTokens.Typography.bodyMedium)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .animation(DesignTokens.Animation.spring.delay(0.3), value: viewModel.isEmailCodeSent)
                            }
                            .padding(.top, DesignTokens.Spacing.xl)
                            
                            // Content
                            VStack(spacing: DesignTokens.Spacing.lg) {
                                if !viewModel.isEmailCodeSent {
                                    // Email Input Phase
                                    emailInputSection
                                } else {
                                    // Verification Code Input Phase
                                    verificationCodeSection
                                }
                            }
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            
                            
                            
                            Spacer(minLength: DesignTokens.Spacing.xl)
                        }
                        
                        Spacer(minLength: DesignTokens.Spacing.xl)
                    }
                }
            }
            
            // Loading Overlay
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            if !viewModel.isEmailCodeSent {
                isEmailFocused = true
            }
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private var emailInputSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Email Input
            VStack(spacing: DesignTokens.Spacing.sm) {
                TextField("Enter your email address", text: $viewModel.email)
                    .textFieldStyle(LiquidGlassTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .onSubmit {
                        if viewModel.isEmailValid {
                            sendEmailCode()
                        }
                    }
                
                if !viewModel.email.isEmpty && !viewModel.isEmailValid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignTokens.Colors.error)
                        Text("Please enter a valid email address")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.error)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            
            // Continue Button
            Button(action: sendEmailCode) {
                HStack {
                    Text("Send Verification Code")
                        .font(DesignTokens.Typography.buttonMedium)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.textPrimary))
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.buttonPaddingVertical)
                .background(
                    viewModel.isEmailValid ? 
                    Color.clear : 
                    DesignTokens.Colors.buttonSecondary
                )
                .background(DesignTokens.GlassEffect.regular)
                .foregroundColor(
                    viewModel.isEmailValid ?
                    DesignTokens.Colors.textPrimary :
                    DesignTokens.Colors.textTertiary
                )
                .cornerRadius(DesignTokens.CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button)
                        .stroke(
                            viewModel.isEmailValid ?
                            DesignTokens.Colors.borderFocus :
                            DesignTokens.Colors.borderSecondary,
                            lineWidth: 1
                        )
                )
            }
            .disabled(!viewModel.isEmailValid || viewModel.isLoading)
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var verificationCodeSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Email Display
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Code sent to:")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                Text(viewModel.email)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.GlassEffect.thin)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            
            // Verification Code Input
            VStack(spacing: DesignTokens.Spacing.sm) {
                NativeCodeInput(
                    code: $viewModel.verificationCode,
                    onComplete: {
                        viewModel.verifyEmailCode()
                    }
                )
                
                // Helper text
                Text("Check your email for the code")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                
                if !viewModel.verificationCode.isEmpty && !viewModel.isVerificationCodeValid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignTokens.Colors.error)
                        Text("Please enter a valid 6-digit code")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.error)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            
            // Verify Button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                viewModel.verifyEmailCode()
            }) {
                HStack {
                    Text("Verify Code")
                        .font(DesignTokens.Typography.buttonMedium)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.textPrimary))
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.buttonPaddingVertical)
                .background(
                    viewModel.isVerificationCodeValid ? 
                    Color.clear : 
                    DesignTokens.Colors.buttonSecondary
                )
                .background(DesignTokens.GlassEffect.regular)
                .foregroundColor(
                    viewModel.isVerificationCodeValid ?
                    DesignTokens.Colors.textPrimary :
                    DesignTokens.Colors.textTertiary
                )
                .cornerRadius(DesignTokens.CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button)
                        .stroke(
                            viewModel.isVerificationCodeValid ?
                            DesignTokens.Colors.borderFocus :
                            DesignTokens.Colors.borderSecondary,
                            lineWidth: 1
                        )
                )
            }
            .disabled(!viewModel.isVerificationCodeValid || viewModel.isLoading)
            .buttonStyle(PlainButtonStyle())
            
            // Resend Code Button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                viewModel.resendEmailCode()
            }) {
                Text(viewModel.emailResendText)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(
                        viewModel.canResendEmail ?
                        DesignTokens.Colors.primary :
                        DesignTokens.Colors.textTertiary
                    )
                    .underline(viewModel.canResendEmail)
            }
            .disabled(!viewModel.canResendEmail)
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func sendEmailCode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        viewModel.sendEmailCode()
    }
}


// MARK: - Preview

struct EmailAuthView_Previews: PreviewProvider {
    static var previews: some View {
        EmailAuthView(viewModel: AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
