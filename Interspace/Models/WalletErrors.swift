import Foundation

// MARK: - Wallet Connection Errors

/// Errors related to wallet connection and authentication
enum WalletConnectionError: LocalizedError, Identifiable, Equatable {
    case sdkNotInitialized
    case connectionFailed(String)
    case signatureFailed(String)
    case noAccountsFound
    case userCancelled
    case unsupportedWallet(String)
    case networkError(String)
    case qrCodeScanRequired
    case showQRCode(String)
    case timeout(String)
    
    var id: String {
        switch self {
        case .sdkNotInitialized:
            return "sdkNotInitialized"
        case .connectionFailed(let message):
            return "connectionFailed_\(message)"
        case .signatureFailed(let message):
            return "signatureFailed_\(message)"
        case .noAccountsFound:
            return "noAccountsFound"
        case .userCancelled:
            return "userCancelled"
        case .unsupportedWallet(let wallet):
            return "unsupportedWallet_\(wallet)"
        case .networkError(let message):
            return "networkError_\(message)"
        case .qrCodeScanRequired:
            return "qrCodeScanRequired"
        case .showQRCode(let uri):
            return "showQRCode_\(uri)"
        case .timeout(let message):
            return "timeout_\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "Wallet SDK not initialized"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .signatureFailed(let message):
            return "Signature failed: \(message)"
        case .noAccountsFound:
            return "No wallet accounts found"
        case .userCancelled:
            return "User cancelled the operation"
        case .unsupportedWallet(let wallet):
            return "Unsupported wallet: \(wallet)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .qrCodeScanRequired:
            return "QR code scan required"
        case .showQRCode:
            return "Please scan the QR code with your wallet"
        case .timeout(let message):
            return message
        }
    }
}

// MARK: - Transaction Errors

/// Errors related to token transactions and operations
enum WalletTransactionError: LocalizedError, Identifiable {
    case profileNotFound
    case noOperationsFound
    case missingTransactionData
    case invalidAmount
    case insufficientBalance
    case invalidAddress
    case networkMismatch
    case gasEstimationFailed
    case transactionFailed(String)
    
    var id: String {
        switch self {
        case .profileNotFound:
            return "profileNotFound"
        case .noOperationsFound:
            return "noOperationsFound"
        case .missingTransactionData:
            return "missingTransactionData"
        case .invalidAmount:
            return "invalidAmount"
        case .insufficientBalance:
            return "insufficientBalance"
        case .invalidAddress:
            return "invalidAddress"
        case .networkMismatch:
            return "networkMismatch"
        case .gasEstimationFailed:
            return "gasEstimationFailed"
        case .transactionFailed(let message):
            return "transactionFailed_\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .noOperationsFound:
            return "No wallet operations found for this profile"
        case .missingTransactionData:
            return "Missing transaction data"
        case .invalidAmount:
            return "Invalid amount"
        case .insufficientBalance:
            return "Insufficient balance"
        case .invalidAddress:
            return "Invalid wallet address"
        case .networkMismatch:
            return "Network mismatch"
        case .gasEstimationFailed:
            return "Failed to estimate gas fees"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

/// Legacy type alias - use WalletConnectionError for new code
typealias WalletError = WalletConnectionError

// MARK: - Notes

/// This file contains the canonical implementation of WalletTransactionError.
/// Please remove any duplicate implementations of WalletTransactionError present in other files.
