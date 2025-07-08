import Foundation
import Combine

/// Manages wallet connection state and retry logic
class WalletConnectionManager: ObservableObject {
    static let shared = WalletConnectionManager()
    
    @Published var connectionState: ConnectionState = .idle
    @Published var connectionError: WalletConnectionError?
    @Published var connectionProgress: ConnectionProgress?
    
    private var connectionTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0
    
    private init() {}
    
    // MARK: - Types
    
    enum ConnectionState: Equatable {
        case idle
        case connecting(WalletType)
        case connected(WalletType, String) // wallet type and address
        case failed(WalletConnectionError)
        case timeout
    }
    
    struct ConnectionProgress {
        let stage: ConnectionStage
        let message: String
        let progress: Double // 0.0 to 1.0
    }
    
    enum ConnectionStage {
        case initializing
        case creatingSession
        case waitingForApproval
        case signingMessage
        case verifying
        case completing
    }
    
    // MARK: - Connection Management
    
    /// Start a wallet connection with retry logic
    func startConnection(walletType: WalletType, completion: @escaping (Result<WalletConnectionResult, WalletConnectionError>) -> Void) {
        // Cancel any existing connection
        connectionTask?.cancel()
        
        // Reset state
        retryCount = 0
        connectionError = nil
        connectionState = .connecting(walletType)
        
        // Start connection task
        connectionTask = Task {
            await connectWithRetry(walletType: walletType, completion: completion)
        }
    }
    
    /// Cancel current connection
    func cancelConnection() {
        connectionTask?.cancel()
        connectionTask = nil
        connectionState = .idle
        connectionProgress = nil
    }
    
    // MARK: - Private Methods
    
    private func connectWithRetry(walletType: WalletType, completion: @escaping (Result<WalletConnectionResult, WalletConnectionError>) -> Void) async {
        while retryCount < maxRetries {
            do {
                // Update progress
                await updateProgress(.initializing, message: "Initializing connection...", progress: 0.1)
                
                // Get wallet configuration
                let configuration = WalletConfiguration.configuration(for: walletType)
                
                // Check if wallet supports WalletConnect
                guard configuration.supportsWalletConnect else {
                    throw WalletConnectionError.unsupportedWallet(walletType.displayName)
                }
                
                // Attempt connection based on wallet type
                let result = try await attemptConnection(walletType: walletType, configuration: configuration)
                
                // Success!
                await MainActor.run {
                    self.connectionState = .connected(walletType, result.address)
                    self.connectionProgress = nil
                }
                
                completion(.success(result))
                return
                
            } catch {
                // Handle error
                let walletError = error as? WalletConnectionError ?? WalletConnectionError.connectionFailed(error.localizedDescription)
                
                // Check if we should retry
                if shouldRetry(error: walletError) && retryCount < maxRetries - 1 {
                    retryCount += 1
                    let delay = calculateRetryDelay()
                    
                    await MainActor.run {
                        self.connectionProgress = ConnectionProgress(
                            stage: .initializing,
                            message: "Connection failed. Retrying in \(Int(delay)) seconds...",
                            progress: 0.0
                        )
                    }
                    
                    // Wait before retry
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // Check if task was cancelled
                    if Task.isCancelled { return }
                    
                } else {
                    // Final failure
                    await MainActor.run {
                        self.connectionState = .failed(walletError)
                        self.connectionError = walletError
                        self.connectionProgress = nil
                    }
                    
                    completion(.failure(walletError))
                    return
                }
            }
        }
    }
    
    private func attemptConnection(walletType: WalletType, configuration: WalletConfiguration) async throws -> WalletConnectionResult {
        // This would integrate with WalletService/WalletConnectService
        // For now, throw an error to indicate this needs implementation
        throw WalletConnectionError.connectionFailed("Connection implementation needed")
    }
    
    private func shouldRetry(error: WalletConnectionError) -> Bool {
        switch error {
        case .userCancelled:
            return false // Don't retry user cancellations
        case .unsupportedWallet:
            return false // Don't retry unsupported wallets
        case .connectionFailed, .networkError:
            return true // Retry these errors
        default:
            return true
        }
    }
    
    private func calculateRetryDelay() -> TimeInterval {
        // Exponential backoff: 2s, 4s, 8s
        return baseRetryDelay * pow(2, Double(retryCount))
    }
    
    @MainActor
    private func updateProgress(_ stage: ConnectionStage, message: String, progress: Double) {
        connectionProgress = ConnectionProgress(
            stage: stage,
            message: message,
            progress: progress
        )
    }
    
    // MARK: - Connection Helpers
    
    /// Monitor connection timeout
    func startConnectionTimeout(duration: TimeInterval = 30.0) async {
        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            // If we're still connecting after timeout, mark as timed out
            if case .connecting = connectionState {
                await MainActor.run {
                    self.connectionState = .timeout
                    self.connectionError = WalletConnectionError.connectionFailed("Connection timed out")
                }
            }
        } catch {
            // Task was cancelled, which is fine
        }
    }
    
    /// Update connection progress based on WalletConnect events
    func handleWalletConnectEvent(_ event: WalletConnectEvent) {
        Task { @MainActor in
            switch event {
            case .sessionProposed:
                updateProgress(.creatingSession, message: "Session created. Waiting for wallet approval...", progress: 0.3)
                
            case .sessionSettled:
                updateProgress(.waitingForApproval, message: "Session approved. Preparing to sign message...", progress: 0.5)
                
            case .sessionRejected:
                connectionState = .failed(WalletConnectionError.userCancelled)
                connectionProgress = nil
                
            case .signingMessage:
                updateProgress(.signingMessage, message: "Signing authentication message...", progress: 0.7)
                
            case .verifyingSignature:
                updateProgress(.verifying, message: "Verifying signature...", progress: 0.9)
                
            case .connectionComplete:
                updateProgress(.completing, message: "Completing connection...", progress: 1.0)
            }
        }
    }
}

// MARK: - WalletConnect Event Types

enum WalletConnectEvent {
    case sessionProposed
    case sessionSettled
    case sessionRejected
    case signingMessage
    case verifyingSignature
    case connectionComplete
}

// MARK: - Extensions

extension WalletConnectionManager {
    /// Get user-friendly message for connection state
    var stateMessage: String {
        switch connectionState {
        case .idle:
            return "Ready to connect"
        case .connecting(let walletType):
            return "Connecting to \(walletType.displayName)..."
        case .connected(let walletType, _):
            return "Connected to \(walletType.displayName)"
        case .failed(let error):
            return error.localizedDescription
        case .timeout:
            return "Connection timed out"
        }
    }
    
    /// Check if connection is in progress
    var isConnecting: Bool {
        if case .connecting = connectionState {
            return true
        }
        return false
    }
}