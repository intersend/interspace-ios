import Foundation

// MARK: - MPCError

enum MPCError: LocalizedError, Equatable {
    // SDK Errors
    case sdkNotInitialized
    case sdkInitializationFailed(String)
    
    // Key Management Errors
    case keyShareNotFound
    case keyGenerationFailed(String)
    case keyRotationFailed(String)
    case derivationFailed(String)
    
    // Authentication Errors
    case biometricAuthFailed
    case authenticationFailed
    case sessionExpired
    
    // Network Errors
    case websocketConnectionFailed
    case websocketNotConnected
    case networkTimeout
    case requestTimeout
    
    // Operation Errors
    case signingFailed(String)
    case backupFailed(String)
    case exportFailed(String)
    case operationInProgress
    case operationCancelled(String)
    case profileNotFound
    case userCancelled
    
    // Storage Errors
    case storageError(String)
    case encryptionFailed
    case decryptionFailed
    
    // Configuration Errors
    case invalidConfiguration
    case configurationError(String)
    
    // Data Errors
    case invalidData
    case serializationError(String)
    
    // Generic
    case unknown(Error)
    
<<<<<<< HEAD
    static func == (lhs: MPCError, rhs: MPCError) -> Bool {
        switch (lhs, rhs) {
        case (.sdkNotInitialized, .sdkNotInitialized),
             (.keyShareNotFound, .keyShareNotFound),
             (.biometricAuthFailed, .biometricAuthFailed),
             (.authenticationFailed, .authenticationFailed),
             (.sessionExpired, .sessionExpired),
             (.websocketConnectionFailed, .websocketConnectionFailed),
             (.websocketNotConnected, .websocketNotConnected),
             (.networkTimeout, .networkTimeout),
             (.requestTimeout, .requestTimeout),
             (.operationInProgress, .operationInProgress),
             (.profileNotFound, .profileNotFound),
             (.userCancelled, .userCancelled),
             (.encryptionFailed, .encryptionFailed),
             (.decryptionFailed, .decryptionFailed),
             (.invalidConfiguration, .invalidConfiguration),
             (.invalidData, .invalidData):
            return true
            
        case (.sdkInitializationFailed(let a), .sdkInitializationFailed(let b)),
             (.keyGenerationFailed(let a), .keyGenerationFailed(let b)),
             (.keyRotationFailed(let a), .keyRotationFailed(let b)),
             (.derivationFailed(let a), .derivationFailed(let b)),
             (.signingFailed(let a), .signingFailed(let b)),
             (.backupFailed(let a), .backupFailed(let b)),
             (.exportFailed(let a), .exportFailed(let b)),
             (.operationCancelled(let a), .operationCancelled(let b)),
             (.storageError(let a), .storageError(let b)),
             (.configurationError(let a), .configurationError(let b)),
             (.serializationError(let a), .serializationError(let b)):
            return a == b
            
        case (.unknown(let a), .unknown(let b)):
            return (a as NSError) == (b as NSError)
            
        default:
            return false
        }
    }
    
=======
>>>>>>> origin/main
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "MPC SDK is not initialized. Please try again."
            
        case .sdkInitializationFailed(let reason):
            return "Failed to initialize MPC SDK: \(reason)"
            
        case .keyShareNotFound:
            return "Wallet key not found. Please create a wallet first."
            
        case .keyGenerationFailed(let reason):
            return "Failed to generate wallet: \(reason)"
            
        case .keyRotationFailed(let reason):
            return "Failed to rotate keys: \(reason)"
            
        case .derivationFailed(let reason):
            return "Failed to derive key: \(reason)"
            
        case .biometricAuthFailed:
            return "Biometric authentication failed. Please try again."
            
        case .authenticationFailed:
            return "Authentication failed. Please sign in again."
            
        case .sessionExpired:
            return "Your session has expired. Please reconnect."
            
        case .websocketConnectionFailed:
            return "Failed to connect to wallet service. Please check your connection."
            
        case .websocketNotConnected:
            return "Not connected to wallet service. Please try again."
            
        case .networkTimeout:
            return "Network request timed out. Please try again."
            
        case .requestTimeout:
            return "Request timed out. Please try again."
            
        case .signingFailed(let reason):
            return "Failed to sign transaction: \(reason)"
            
        case .backupFailed(let reason):
            return "Failed to create backup: \(reason)"
            
        case .exportFailed(let reason):
            return "Failed to export key: \(reason)"
            
        case .operationInProgress:
            return "Another operation is in progress. Please wait."
            
        case .operationCancelled(let reason):
            return "Operation cancelled: \(reason)"
            
        case .profileNotFound:
            return "No active profile found. Please select a profile first."
            
        case .userCancelled:
            return "Operation cancelled by user."
            
        case .storageError(let reason):
            return "Storage error: \(reason)"
            
        case .encryptionFailed:
            return "Failed to encrypt data securely."
            
        case .decryptionFailed:
            return "Failed to decrypt data. Please try again."
            
        case .invalidConfiguration:
            return "Invalid configuration. Please contact support."
            
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
            
        case .invalidData:
            return "Invalid data format."
            
        case .serializationError(let reason):
            return "Data error: \(reason)"
            
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sdkNotInitialized, .sdkInitializationFailed:
            return "Try closing and reopening the app."
            
        case .keyShareNotFound:
            return "Create a new wallet from your profile settings."
            
        case .keyGenerationFailed, .keyRotationFailed:
            return "Ensure you have a stable internet connection and try again."
            
        case .biometricAuthFailed:
            return "Make sure your biometric data is properly configured in Settings."
            
        case .authenticationFailed, .sessionExpired:
            return "Sign out and sign back in to refresh your session."
            
        case .websocketConnectionFailed, .websocketNotConnected, .networkTimeout:
            return "Check your internet connection and try again."
            
        case .signingFailed:
            return "Verify the transaction details and try again."
            
        case .backupFailed:
            return "Ensure you have copied the RSA public key correctly."
            
        case .exportFailed:
            return "This is a sensitive operation. Make sure you're in a secure environment."
            
        case .operationInProgress:
            return "Wait for the current operation to complete."
            
        case .storageError, .encryptionFailed, .decryptionFailed:
            return "Try restarting the app. If the problem persists, contact support."
            
        case .invalidConfiguration, .configurationError:
            return "Update the app to the latest version."
            
        default:
            return nil
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkTimeout, .requestTimeout, .websocketConnectionFailed:
            return true
        case .signingFailed, .backupFailed, .exportFailed:
            return true
        case .operationInProgress, .biometricAuthFailed:
            return false
        default:
            return false
        }
    }
    
    var requiresReauthentication: Bool {
        switch self {
        case .authenticationFailed, .sessionExpired:
            return true
        default:
            return false
        }
    }
}