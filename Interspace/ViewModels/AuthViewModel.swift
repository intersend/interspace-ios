import Foundation
import Combine
import SwiftUI
import UIKit
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedAuthStrategy: AuthStrategy?
    @Published var isLoading = false
    @Published var error: AuthenticationError?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showWalletTray = false
    
    // Email Authentication
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var isEmailCodeSent = false
    @Published var emailResendTimer = 0
    @Published var canResendEmail = true
    
    // Wallet Connection
    @Published var selectedWalletType: WalletType?
    
    // Services
    let authManager = AuthenticationManagerV2.shared
    private let walletService = WalletService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var emailTimer: Timer?
    
    init() {
        setupBindings()
    }
    
    deinit {
        emailTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind authentication manager
        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        authManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
                self?.showError = error != nil
            }
            .store(in: &cancellables)
        
        // Bind wallet service
        walletService.$error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] walletError in
                self?.error = AuthenticationError.walletConnectionFailed(walletError.localizedDescription)
                self?.showError = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Actions
    
    func selectAuthStrategy(_ strategy: AuthStrategy) {
        selectedAuthStrategy = strategy
        error = nil
        showError = false
        
        switch strategy {
        case .wallet:
            showWalletTray = true
        case .email:
            break // Show email input
        case .guest:
            authenticateAsGuest()
        case .passkey:
            if #available(iOS 16.0, *) {
                authenticateWithPasskey()
            } else {
                error = AuthenticationError.passkeyNotSupported
                showError = true
            }
        default:
            break
        }
    }
    
    func authenticateAsGuest() {
        Task {
            do {
                let config = WalletConnectionConfig(
                    strategy: .guest,
                    walletType: nil,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: nil,
                    signature: nil,
                    message: nil,
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                try await authManager.authenticate(with: config)
            } catch {
                print("Guest authentication error: \(error)")
            }
        }
    }
    
    // MARK: - Email Authentication
    
    func sendEmailCode() {
        guard !email.isEmpty, isValidEmail(email) else {
            error = AuthenticationError.emailVerificationFailed
            showError = true
            return
        }
        
        Task {
            do {
                try await authManager.sendEmailCode(email)
                isEmailCodeSent = true
                startEmailResendTimer()
            } catch {
                print("Failed to send email code: \(error)")
            }
        }
    }
    
    
    func verifyEmailCode() {
        guard !verificationCode.isEmpty, verificationCode.count == 6 else {
            error = AuthenticationError.emailVerificationFailed
            showError = true
            return
        }
        
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
            } catch {
                print("Email verification error: \(error)")
            }
        }
    }
    
    func resendEmailCode() {
        guard canResendEmail else { return }
        
        Task {
            do {
                try await authManager.resendEmailCode(email)
                isEmailCodeSent = true
                startEmailResendTimer()
            } catch {
                print("Failed to resend email code: \(error)")
            }
        }
    }
    
    private func startEmailResendTimer() {
        canResendEmail = false
        emailResendTimer = 60
        
        emailTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if self.emailResendTimer > 0 {
                    self.emailResendTimer -= 1
                } else {
                    self.canResendEmail = true
                    self.emailTimer?.invalidate()
                    self.emailTimer = nil
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Passkey Authentication
    
    @available(iOS 16.0, *)
    func authenticateWithPasskey() {
        Task {
            do {
                isLoading = true
                error = nil
                
                let tokens = try await PasskeyService.shared.authenticateWithPasskey()
                
                // Store tokens in keychain
                if !tokens.accessToken.isEmpty {
                    try KeychainManager.shared.save(tokens.accessToken, for: .accessToken)
                    try KeychainManager.shared.save(tokens.refreshToken, for: .refreshToken)
                    
                    // Update authentication state
                    await MainActor.run {
                        authManager.isAuthenticated = true
                    }
                }
                
                isLoading = false
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = AuthenticationError.passkeyAuthenticationFailed(error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }
    
    @available(iOS 16.0, *)
    func registerPasskey() {
        guard authManager.isAuthenticated else {
            error = AuthenticationError.notAuthenticated
            showError = true
            return
        }
        
        Task {
            do {
                isLoading = true
                error = nil
                
                // Get current user email
                let userEmail = authManager.currentUser?.email ?? email
                guard !userEmail.isEmpty else {
                    throw AuthenticationError.emailRequired
                }
                
                let _ = try await PasskeyService.shared.registerPasskey(for: userEmail)
                
                await MainActor.run {
                    self.isLoading = false
                    // Show success message
                    self.errorMessage = "Passkey registered successfully!"
                    self.showError = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = AuthenticationError.passkeyRegistrationFailed(error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }
    
    // MARK: - Wallet Authentication
    
    func selectWallet(_ walletType: WalletType) {
        selectedWalletType = walletType
        showWalletTray = false
        connectWallet(walletType)
    }
    
    private func connectWallet(_ walletType: WalletType) {
        Task {
            do {
                // Let WalletService handle connection state management
                // Don't force disconnect here as it causes ping-pong with MetaMask
                print("🔗 AuthViewModel: Initiating wallet connection for \(walletType.rawValue)")
                
                let result = try await walletService.connectWallet(walletType)
                
                // For wallet connections during auth flow, we pass the message along with signature
                let config = WalletConnectionConfig(
                    strategy: .wallet,
                    walletType: walletType.rawValue,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: result.address,
                    signature: result.signature,
                    message: result.message, // Include the message for verification
                    socialProvider: nil,
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                try await authManager.authenticate(with: config)
            } catch {
                print("Wallet connection error: \(error)")
                
                // Handle specific wallet errors with better user feedback
                await MainActor.run {
                    if let walletError = error as? WalletError {
                        switch walletError {
                        case .connectionFailed(let message):
                            if message.lowercased().contains("account") && message.lowercased().contains("changed") {
                                self.errorMessage = "Account changed detected. Please try connecting again."
                            } else {
                                self.errorMessage = message
                            }
                        case .userCancelled:
                            self.errorMessage = "Connection cancelled"
                        case .signatureFailed(let message):
                            self.errorMessage = "Signature failed: \(message)"
                        default:
                            self.errorMessage = walletError.localizedDescription
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    self.showError = true
                }
                
                // If connection failed, ensure we're in a clean state
                if let walletError = error as? WalletError {
                    if walletError.localizedDescription.contains("account has changed") {
                        // Clear wallet state for retry
                        await walletService.disconnect()
                    }
                }
            }
        }
    }
    
    // MARK: - Wallet Availability
    
    func isWalletAvailable(_ walletType: WalletType) -> Bool {
        walletService.isWalletAvailable(walletType)
    }
    
    func getAvailableWallets() -> [WalletType] {
        WalletType.allCases.filter { isWalletAvailable($0) }
    }
    
    // MARK: - UI Actions
    
    func dismissError() {
        error = nil
        showError = false
    }
    
    func dismissWalletTray() {
        showWalletTray = false
        selectedWalletType = nil
    }
    
    func resetAuthFlow() {
        selectedAuthStrategy = nil
        email = ""
        verificationCode = ""
        isEmailCodeSent = false
        selectedWalletType = nil
        error = nil
        showError = false
        errorMessage = ""
        showWalletTray = false
        emailTimer?.invalidate()
        emailTimer = nil
        canResendEmail = true
        emailResendTimer = 0
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var isEmailValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }
    
    var isVerificationCodeValid: Bool {
        verificationCode.count == 6 && verificationCode.allSatisfy { $0.isNumber }
    }
    
    var emailResendText: String {
        if canResendEmail {
            return "Resend Code"
        } else {
            return "Resend in \(emailResendTimer)s"
        }
    }
    
    // MARK: - Wallet Connection Methods
    
    func connectWithMetaMask() {
        selectedWalletType = .metamask
        connectWallet(.metamask)
    }
    
    func connectWithCoinbase() {
        selectedWalletType = .coinbase
        connectWallet(.coinbase)
    }
    
    // MARK: - Social Authentication Methods
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        throw AuthenticationError.invalidCredentials
                    }
                    
                    let socialProfile = SocialProfile(
                        id: appleIDCredential.user,
                        email: appleIDCredential.email,
                        name: appleIDCredential.fullName?.formatted(),
                        picture: nil
                    )
                    
                    let config = WalletConnectionConfig(
                        strategy: .apple,
                        walletType: nil,
                        email: appleIDCredential.email,
                        verificationCode: nil,
                        walletAddress: nil,
                        signature: nil,
                        message: nil,
                        socialProvider: "apple",
                        socialProfile: socialProfile,
                        oauthCode: nil
                    )
                    
                    try await authManager.authenticate(with: config)
                    
                case .failure(let error):
                    throw AuthenticationError.unknown(error.localizedDescription)
                }
            } catch {
                print("Apple Sign In error: \(error)")
            }
        }
    }
    
    func signInWithApple() {
        // For now, we'll use the native SignInWithAppleButton's completion handler
        // The actual implementation will be in the handleAppleSignIn method above
        print("Apple Sign In initiated - use the native SignInWithAppleButton")
    }
    
    func signInWithGoogle() {
        Task {
            do {
                // TODO: Implement Google Sign-In using GoogleSignInService
                // This will be implemented when we create the GoogleSignInService
                let config = WalletConnectionConfig(
                    strategy: .google,
                    walletType: nil,
                    email: nil,
                    verificationCode: nil,
                    walletAddress: nil,
                    signature: nil,
                    message: nil,
                    socialProvider: "google",
                    socialProfile: nil,
                    oauthCode: nil
                )
                
                try await authManager.authenticate(with: config)
            } catch {
                print("Google Sign In error: \(error)")
            }
        }
    }
}