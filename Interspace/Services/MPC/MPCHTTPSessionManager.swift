import Foundation
import Combine

// MARK: - MPC HTTP Session Manager
// Manages MPC sessions via HTTP instead of WebSocket

@MainActor
final class MPCHTTPSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var currentSession: MPCSession?
    @Published var connectionError: Error?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 1.0
    private let maxPollingDuration: TimeInterval = 120.0 // 2 minutes
    
    // Session tracking
    private var activeSessions = [String: MPCSession]()
    private let sessionQueue = DispatchQueue(label: "com.interspace.mpc.http.session", qos: .userInitiated)
    
    // MARK: - Singleton
    static let shared = MPCHTTPSessionManager()
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Session Management
    
    /// Start a new MPC session
    func startSession(
        profileId: String,
        type: MPCSessionType,
        initialData: [String: Any]? = nil
    ) async throws -> MPCSession {
        
        let sessionId = UUID().uuidString
        let session = MPCSession(
            id: sessionId,
            profileId: profileId,
            type: type,
            status: MPCSessionStatus.pending,
            createdAt: Date()
        )
        
        // Store session
        await MainActor.run {
            self.currentSession = session
            self.activeSessions[sessionId] = session
        }
        
        // Initialize session based on type
        switch type {
        case .keyGeneration:
            try await startKeyGeneration(session: session, initialData: initialData)
        case .signing:
            try await startSigning(session: session, initialData: initialData)
        case .keyRotation:
            try await startKeyRotation(session: session, initialData: initialData)
        }
        
        return session
    }
    
    /// Poll session status
    func pollSessionStatus(_ sessionId: String) async throws -> MPCSession {
        let response = try await ProfileAPI.shared.getSessionStatus(sessionId: sessionId)
        
        guard response.success else {
            throw MPCError.profileNotFound
        }
        
        let updatedSession = MPCSession(
            id: response.data.sessionId,
            profileId: response.data.profileId,
            type: mapSessionType(response.data.type),
            status: mapStatus(response.data.status),
            result: mapSessionResult(response.data.result),
            error: response.data.error,
            createdAt: ISO8601DateFormatter().date(from: response.data.createdAt) ?? Date()
        )
        
        // Update local session
        await MainActor.run {
            self.activeSessions[sessionId] = updatedSession
            if self.currentSession?.id == sessionId {
                self.currentSession = updatedSession
            }
        }
        
        return updatedSession
    }
    
    /// Send P1 message and get P2 response
    func sendP1Message(
        sessionId: String,
        messageType: MPCMessageType,
        message: [String: Any]
    ) async throws -> P2MessageResponse {
        
        let response = try await ProfileAPI.shared.forwardP1Message(
            sessionId: sessionId,
            messageType: messageType,
            message: message
        )
        
        guard response.success else {
            throw MPCError.signingFailed("Failed to forward P1 message: \(response.message)")
        }
        
        // Parse P2 messages from response
        return P2MessageResponse(
            sessionId: sessionId,
            messages: parseP2Messages(response.message),
            requiresMoreRounds: response.message.contains("more_rounds")
        )
    }
    
    // MARK: - Private Methods
    
    private func startKeyGeneration(session: MPCSession, initialData: [String: Any]?) async throws {
        guard let profileId = session.profileId else {
            throw MPCError.sessionExpired
        }
        
        // Extract P1 messages from initial data
        let p1Messages = initialData?["p1Messages"] as? [[String: Any]] ?? []
        
        let response = try await ProfileAPI.shared.startKeyGeneration(
            profileId: profileId,
            p1Messages: p1Messages
        )
        
        guard response.success else {
            throw MPCError.keyGenerationFailed(response.data.profileId)
        }
        
        // Start polling for completion
        startPolling(sessionId: response.data.sessionId)
    }
    
    private func startSigning(session: MPCSession, initialData: [String: Any]?) async throws {
        guard let profileId = session.profileId,
              let message = initialData?["message"] as? String else {
            throw MPCError.sessionExpired
        }
        
        let p1Messages = initialData?["p1Messages"] as? [[String: Any]] ?? []
        
        let response = try await ProfileAPI.shared.startSigning(
            profileId: profileId,
            message: message,
            p1Messages: p1Messages
        )
        
        guard response.success else {
            throw MPCError.signingFailed("Failed to start signing session")
        }
        
        // Start polling for completion
        startPolling(sessionId: response.data.sessionId)
    }
    
    private func startKeyRotation(session: MPCSession, initialData: [String: Any]?) async throws {
        // Similar to key generation but with rotation endpoint
        // Implementation depends on backend support
        throw MPCError.keyRotationFailed("Key rotation via HTTP not yet implemented")
    }
    
    private func startPolling(sessionId: String) {
        stopPolling()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                do {
                    let session = try await self?.pollSessionStatus(sessionId)
                    
                    if session?.status == .completed || session?.status == .failed {
                        self?.stopPolling()
                        self?.handleSessionCompletion(session!)
                    }
                } catch {
                    print("Polling error: \(error)")
                    // Continue polling unless it's a critical error
                    if error is MPCError {
                        self?.stopPolling()
                        self?.connectionError = error
                    }
                }
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func handleSessionCompletion(_ session: MPCSession) {
        if session.status == .completed {
            NotificationCenter.default.post(
                name: .mpcSessionCompleted,
                object: nil,
                userInfo: ["session": session]
            )
        } else if session.status == .failed {
            NotificationCenter.default.post(
                name: .mpcSessionFailed,
                object: nil,
                userInfo: ["session": session, "error": session.error ?? "Unknown error"]
            )
        }
    }
    
    private func mapStatus(_ status: String) -> MPCSessionStatus {
        switch status {
        case "pending": return .pending
        case "in_progress": return .inProgress
        case "completed": return .completed
        case "failed": return .failed
        default: return .pending
        }
    }
    
    private func mapSessionType(_ type: String) -> MPCSessionType {
        switch type {
        case "keyGeneration": return .keyGeneration
        case "signing": return .signing
        case "keyRotation": return .keyRotation
        default: return .keyGeneration
        }
    }
    
    private func mapSessionResult(_ result: SessionResult?) -> MPCSessionResult? {
        guard let result = result else { return nil }
        return MPCSessionResult(
            keyId: result.keyId,
            publicKey: result.publicKey,
            address: result.address,
            signature: result.signature
        )
    }
    
    private func parseP2Messages(_ messageString: String) -> [[String: Any]] {
        // Parse P2 messages from response
        // This depends on the actual response format
        guard let data = messageString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["p2Messages"] as? [[String: Any]] else {
            return []
        }
        return messages
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity
        NotificationCenter.default.publisher(for: .connectivityStatusChanged)
            .sink { [weak self] notification in
                if let isConnected = notification.userInfo?["isConnected"] as? Bool {
                    self?.isConnected = isConnected
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopPolling()
        activeSessions.removeAll()
        currentSession = nil
        cancellables.removeAll()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - Supporting Types

struct P2MessageResponse {
    let sessionId: String
    let messages: [[String: Any]]
    let requiresMoreRounds: Bool
}

struct MPCSession {
    let id: String
    let profileId: String?
    let type: MPCSessionType
    var status: MPCSessionStatus
    var result: MPCSessionResult?
    var error: String?
    let createdAt: Date
    var expiresAt: Date {
        createdAt.addingTimeInterval(120) // 2 minutes
    }
}

struct MPCSessionResult {
    let keyId: String?
    let publicKey: String?
    let address: String?
    let signature: String?
}

enum MPCSessionType {
    case keyGeneration
    case signing
    case keyRotation
}

enum MPCSessionStatus {
    case pending
    case inProgress
    case completed
    case failed
}

enum MPCMessageType: String {
    case keyGen = "keyGen"
    case sign = "sign"
}

// MARK: - Notifications

extension Notification.Name {
    static let mpcSessionCompleted = Notification.Name("mpcSessionCompleted")
    static let mpcSessionFailed = Notification.Name("mpcSessionFailed")
    static let connectivityStatusChanged = Notification.Name("connectivityStatusChanged")
}