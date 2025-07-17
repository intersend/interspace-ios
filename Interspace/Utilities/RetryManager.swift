import Foundation
import UIKit

/// Manages retry logic with exponential backoff for network operations
actor RetryManager {
    
    // MARK: - Configuration
    
    struct RetryConfiguration {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let jitterRange: Double // Random jitter to prevent thundering herd
        
        static let `default` = RetryConfiguration(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 16.0,
            multiplier: 2.0,
            jitterRange: 0.2
        )
        
        static let aggressive = RetryConfiguration(
            maxRetries: 5,
            initialDelay: 0.5,
            maxDelay: 8.0,
            multiplier: 1.5,
            jitterRange: 0.3
        )
        
        static let gentle = RetryConfiguration(
            maxRetries: 2,
            initialDelay: 2.0,
            maxDelay: 10.0,
            multiplier: 2.5,
            jitterRange: 0.1
        )
    }
    
    // MARK: - Retry State
    
    struct RetryState {
        let attempt: Int
        let totalAttempts: Int
        let nextDelay: TimeInterval?
        let error: Error?
        
        var isLastAttempt: Bool {
            attempt >= totalAttempts
        }
        
        var shouldRetry: Bool {
            !isLastAttempt && isRetryableError
        }
        
        private var isRetryableError: Bool {
            guard let error = error else { return true }
            
            // Check for specific non-retryable errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cancelled, .userCancelledAuthentication, .userAuthenticationRequired,
                     .appTransportSecurityRequiresSecureConnection, .fileDoesNotExist,
                     .zeroByteResource, .cannotDecodeRawData, .cannotDecodeContentData,
                     .cannotParseResponse, .dataNotAllowed:
                    return false
                default:
                    return true
                }
            }
            
            // Check for HTTP status codes
            if let apiError = error as? APIError {
                switch apiError {
                case .invalidResponse(let statusCode):
                    // Don't retry client errors (4xx) except for specific cases
                    if statusCode >= 400 && statusCode < 500 {
                        return statusCode == 408 || statusCode == 429 // Timeout or rate limit
                    }
                    // Retry server errors (5xx)
                    return statusCode >= 500
                case .unauthorized:
                    // Don't retry authentication errors
                    return false
                case .invalidURL, .invalidRequest:
                    // Don't retry these errors
                    return false
                default:
                    return true
                }
            }
            
            return true
        }
    }
    
    // MARK: - Properties
    
    private let configuration: RetryConfiguration
    private var retryTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Execute an operation with retry logic
    func execute<T>(
        operation: @escaping () async throws -> T,
        onRetry: ((RetryState) async -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxRetries {
            do {
                // Cancel any previous retry task
                let taskId = UUID().uuidString
                retryTasks[taskId]?.cancel()
                
                // Execute the operation
                let result = try await operation()
                
                // Success - clean up and return
                retryTasks.removeValue(forKey: taskId)
                return result
                
            } catch {
                lastError = error
                
                let state = RetryState(
                    attempt: attempt + 1,
                    totalAttempts: configuration.maxRetries,
                    nextDelay: calculateDelay(for: attempt),
                    error: error
                )
                
                // Notify about retry attempt
                await onRetry?(state)
                
                // Check if we should retry
                if state.shouldRetry {
                    let delay = state.nextDelay ?? configuration.initialDelay
                    
                    // Create retry task
                    let taskId = UUID().uuidString
                    retryTasks[taskId] = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    
                    // Wait for delay
                    await retryTasks[taskId]?.value
                    retryTasks.removeValue(forKey: taskId)
                    
                    // Log retry attempt
                    print("🔄 RetryManager: Retrying after \(String(format: "%.1f", delay))s delay (attempt \(attempt + 1)/\(configuration.maxRetries))")
                } else {
                    // Don't retry - throw the error
                    throw error
                }
            }
        }
        
        // All retries exhausted
        throw lastError ?? APIError.requestFailed(NSError(domain: "RetryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]))
    }
    
    /// Cancel all pending retry operations
    func cancelAll() {
        retryTasks.values.forEach { $0.cancel() }
        retryTasks.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        // Calculate base delay with exponential backoff
        let baseDelay = min(
            configuration.initialDelay * pow(configuration.multiplier, Double(attempt)),
            configuration.maxDelay
        )
        
        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: -configuration.jitterRange...configuration.jitterRange)
        let jitteredDelay = baseDelay * (1 + jitter)
        
        return max(0, jitteredDelay)
    }
}

// MARK: - Convenience Extensions

extension RetryManager {
    /// Execute with a specific configuration
    static func execute<T>(
        with configuration: RetryConfiguration = .default,
        operation: @escaping () async throws -> T,
        onRetry: ((RetryState) async -> Void)? = nil
    ) async throws -> T {
        let manager = RetryManager(configuration: configuration)
        return try await manager.execute(operation: operation, onRetry: onRetry)
    }
}

