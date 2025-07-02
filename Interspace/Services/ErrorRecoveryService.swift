import Foundation
import SwiftUI

// MARK: - Error Recovery Service
@MainActor
final class ErrorRecoveryService: ObservableObject {
    static let shared = ErrorRecoveryService()
    
    @Published var currentError: RecoverableError?
    @Published var isShowingError = false
    
    private init() {}
    
    /// Handle an error with appropriate recovery options
    func handleError(_ error: Error, context: ErrorContext) {
        // Convert to recoverable error
        let recoverableError = createRecoverableError(from: error, context: context)
        
        // Show error UI
        currentError = recoverableError
        isShowingError = true
        
        // Log for debugging
        print("🚨 ErrorRecovery: \(recoverableError.title) - \(recoverableError.message)")
        
        // Haptic feedback
        HapticManager.notification(.error)
    }
    
    /// Create a recoverable error with appropriate actions
    private func createRecoverableError(from error: Error, context: ErrorContext) -> RecoverableError {
        // Handle specific error types
        if let apiError = error as? APIError {
            return handleAPIError(apiError, context: context)
        } else if let authError = error as? AuthenticationError {
            return handleAuthError(authError, context: context)
        } else {
            // Generic error handling
            return RecoverableError(
                title: "Something went wrong",
                message: error.localizedDescription,
                actions: [
                    .init(title: "OK", style: .default) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
        }
    }
    
    /// Handle API errors
    private func handleAPIError(_ error: APIError, context: ErrorContext) -> RecoverableError {
        switch error {
        case .unauthorized:
            return RecoverableError(
                title: "Session Expired",
                message: "Your session has expired. Please sign in again.",
                actions: [
                    .init(title: "Sign In", style: .default) { [weak self] in
                        self?.dismissError()
                        // Trigger re-authentication
                        SessionCoordinator.shared.handleReauthentication()
                    },
                    .init(title: "Cancel", style: .cancel) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
            
        case .apiError(let message):
            // Check for specific error messages
            if message.lowercased().contains("token") && message.lowercased().contains("not provided") {
                return RecoverableError(
                    title: "Authentication Required",
                    message: "Please sign in to continue.",
                    actions: [
                        .init(title: "Sign In", style: .default) { [weak self] in
                            self?.dismissError()
                            SessionCoordinator.shared.handleReauthentication()
                        },
                        .init(title: "Cancel", style: .cancel) { [weak self] in
                            self?.dismissError()
                        }
                    ]
                )
            } else if message.lowercased().contains("already linked") {
                return RecoverableError(
                    title: "Account Already Linked",
                    message: message,
                    actions: [
                        .init(title: "OK", style: .default) { [weak self] in
                            self?.dismissError()
                        }
                    ]
                )
            } else {
                return RecoverableError(
                    title: "Error",
                    message: message,
                    actions: [
                        .init(title: "Retry", style: .default) { [weak self] in
                            self?.dismissError()
                            context.retryAction?()
                        },
                        .init(title: "Cancel", style: .cancel) { [weak self] in
                            self?.dismissError()
                        }
                    ]
                )
            }
            
        case .invalidResponse(let statusCode):
            let message = "The server returned an unexpected response (code: \(statusCode))."
            return RecoverableError(
                title: "Connection Error",
                message: message,
                actions: [
                    .init(title: "Retry", style: .default) { [weak self] in
                        self?.dismissError()
                        context.retryAction?()
                    },
                    .init(title: "Cancel", style: .cancel) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
            
        default:
            return RecoverableError(
                title: "Network Error",
                message: "Please check your connection and try again.",
                actions: [
                    .init(title: "Retry", style: .default) { [weak self] in
                        self?.dismissError()
                        context.retryAction?()
                    },
                    .init(title: "Cancel", style: .cancel) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
        }
    }
    
    /// Handle authentication errors
    private func handleAuthError(_ error: AuthenticationError, context: ErrorContext) -> RecoverableError {
        switch error {
        case .tokenExpired:
            return RecoverableError(
                title: "Session Expired",
                message: "Your session has expired. Please sign in again.",
                actions: [
                    .init(title: "Sign In", style: .default) { [weak self] in
                        self?.dismissError()
                        SessionCoordinator.shared.handleReauthentication()
                    }
                ]
            )
            
        case .invalidCredentials:
            return RecoverableError(
                title: "Invalid Credentials",
                message: "The provided credentials are invalid. Please try again.",
                actions: [
                    .init(title: "OK", style: .default) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
            
        case .emailNotVerified:
            return RecoverableError(
                title: "Email Not Verified",
                message: "Please verify your email before linking accounts.",
                actions: [
                    .init(title: "OK", style: .default) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
            
        case .lastAccountCannotBeUnlinked:
            return RecoverableError(
                title: "Cannot Unlink",
                message: "You must keep at least one account linked to your profile.",
                actions: [
                    .init(title: "OK", style: .default) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
            
        default:
            return RecoverableError(
                title: "Authentication Error",
                message: error.localizedDescription,
                actions: [
                    .init(title: "OK", style: .default) { [weak self] in
                        self?.dismissError()
                    }
                ]
            )
        }
    }
    
    /// Dismiss current error
    func dismissError() {
        withAnimation {
            isShowingError = false
        }
        
        // Clear error after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentError = nil
        }
    }
}

// MARK: - Supporting Types

struct RecoverableError {
    let title: String
    let message: String
    let actions: [RecoverableAction]
}

struct RecoverableAction {
    let title: String
    let style: ActionStyle
    let handler: () -> Void
    
    enum ActionStyle {
        case `default`
        case cancel
        case destructive
    }
}

struct ErrorContext {
    let source: ErrorSource
    let retryAction: (() -> Void)?
    
    enum ErrorSource {
        case authentication
        case accountLinking
        case profileOperation
        case networkRequest
        case unknown
    }
}

// MARK: - Error Recovery View Modifier

struct ErrorRecoveryModifier: ViewModifier {
    @ObservedObject private var errorService = ErrorRecoveryService.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorService.currentError?.title ?? "Error",
                isPresented: $errorService.isShowingError,
                presenting: errorService.currentError
            ) { error in
                ForEach(error.actions.indices, id: \.self) { index in
                    let action = error.actions[index]
                    Button(action.title, role: buttonRole(for: action.style)) {
                        action.handler()
                    }
                }
            } message: { error in
                Text(error.message)
            }
    }
    
    private func buttonRole(for style: RecoverableAction.ActionStyle) -> ButtonRole? {
        switch style {
        case .cancel:
            return .cancel
        case .destructive:
            return .destructive
        case .default:
            return nil
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add error recovery handling to any view
    func withErrorRecovery() -> some View {
        self.modifier(ErrorRecoveryModifier())
    }
}