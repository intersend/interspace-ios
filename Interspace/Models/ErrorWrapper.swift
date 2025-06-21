import Foundation

// MARK: - Error Wrapper

struct ErrorWrapper: Error, LocalizedError {
    let message: String
    let underlyingError: Error?
    
    init(_ message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        return message
    }
    
    var localizedDescription: String {
        return message
    }
}

// Note: WalletViewError is defined in ViewModels/WalletViewModel.swift

// Note: APIError is defined in Services/APIService.swift