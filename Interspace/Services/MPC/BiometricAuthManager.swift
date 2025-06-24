import Foundation
import LocalAuthentication
import Combine
import UIKit

// MARK: - BiometricAuthManager

@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    // Published properties
    @Published var isAuthenticating = false
    @Published var lastAuthenticationTime: Date?
    @Published var biometryType: LABiometryType = .none
    @Published var isAvailable = false
    
    // Configuration
    private let authenticationValidityDuration: TimeInterval = 30 // 30 seconds
    private let context = LAContext()
    
    private init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Authenticate user with biometrics
    func authenticate(reason: String) async throws {
        // Check if recently authenticated
        if let lastAuth = lastAuthenticationTime,
           Date().timeIntervalSince(lastAuth) < authenticationValidityDuration {
            return // Skip authentication if recently done
        }
        
        guard isAvailable else {
            throw MPCError.biometricNotAvailable
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Create new context for each authentication
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"
        
        // Set authentication options
        if #available(iOS 11.0, *) {
            authContext.localizedFallbackTitle = "" // Hide fallback button
        }
        
        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                lastAuthenticationTime = Date()
                
                // Haptic feedback
                await MainActor.run {
                    HapticManager.notification(.success)
                }
            } else {
                throw MPCError.biometricAuthFailed
            }
        } catch let error as LAError {
            throw mapLAError(error)
        } catch {
            throw MPCError.biometricAuthFailed
        }
    }
    
    /// Check if biometric authentication is available
    func checkBiometricAvailability() {
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        if isAvailable {
            biometryType = context.biometryType
        } else {
            biometryType = .none
            
            // Log the reason why biometrics aren't available
            if let error = error as? LAError {
                print("Biometrics unavailable: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get the current biometry type as a user-friendly string
    func getBiometryTypeString() -> String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        @unknown default:
            return "Biometric Authentication"
        }
    }
    
    /// Get the appropriate SF Symbol for the current biometry type
    func getBiometryIcon() -> String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.fill"
        @unknown default:
            return "lock.fill"
        }
    }
    
    /// Clear authentication cache
    func clearAuthenticationCache() {
        lastAuthenticationTime = nil
    }
    
    /// Set custom authentication validity duration
    func setAuthenticationValidityDuration(_ duration: TimeInterval) {
        // This would typically be stored in UserDefaults or similar
        // For now, we'll keep it as a constant
    }
    
    // MARK: - Private Methods
    
    private func mapLAError(_ error: LAError) -> MPCError {
        switch error.code {
        case .userCancel:
            return .userCancelled
            
        case .authenticationFailed:
            return .biometricAuthFailed
            
        case .systemCancel:
            return .systemCancelled
            
        case .passcodeNotSet:
            return .biometricNotConfigured("Device passcode not set")
            
        case .biometryNotAvailable:
            return .biometricNotAvailable
            
        case .biometryNotEnrolled:
            return .biometricNotConfigured("No biometric data enrolled")
            
        case .biometryLockout:
            return .biometricLockout
            
        case .userFallback:
            // We're hiding the fallback button, but handle it just in case
            return .biometricAuthFailed
            
        default:
            return .biometricAuthFailed
        }
    }
}

// MARK: - Biometric Authentication Helper

extension BiometricAuthManager {
    /// Request biometric authentication with additional options
    func authenticateWithOptions(
        reason: String,
        fallbackTitle: String? = nil,
        cancelTitle: String = "Cancel"
    ) async throws -> Bool {
        let authContext = LAContext()
        
        // Configure context
        authContext.localizedCancelTitle = cancelTitle
        if let fallbackTitle = fallbackTitle {
            authContext.localizedFallbackTitle = fallbackTitle
        }
        
        // Disable fallback to passcode for MPC operations
        if #available(iOS 11.0, *) {
            authContext.localizedFallbackTitle = ""
        }
        
        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                lastAuthenticationTime = Date()
            }
            
            return success
        } catch {
            throw mapLAError(error as? LAError ?? LAError(.authenticationFailed))
        }
    }
    
    /// Check if device has any form of authentication available
    func hasDeviceAuthentication() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check biometric authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return true
        }
        
        // Check device passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return true
        }
        
        return false
    }
}

// MARK: - MPCError Extensions

extension MPCError {
    static var biometricNotAvailable: MPCError {
        return .biometricAuthFailed
    }
    
    static var systemCancelled: MPCError {
        return .operationCancelled("System cancelled authentication")
    }
    
    static func biometricNotConfigured(_ reason: String) -> MPCError {
        return .configurationError(reason)
    }
    
    static var biometricLockout: MPCError {
        return .biometricAuthFailed
    }
}

// HapticManager is already defined in DesignTokens.swift