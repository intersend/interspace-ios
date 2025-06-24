import Foundation
import Combine

// MARK: - MPCSessionManager

@MainActor
final class MPCSessionManager: NSObject, ObservableObject {
    // Published properties
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: Error?
    
    // Private properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var messageHandlers: [String: (MPCMessage) -> Void] = [:]
    private var pendingRequests: [String: CheckedContinuation<MPCMessage, Error>] = [:]
    
    // Configuration
    private let maxReconnectAttempts = MPCConfiguration.shared.maxReconnectAttempts
    private let reconnectDelay: TimeInterval = 2.0
    
    override init() {
        super.init()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = MPCConfiguration.shared.websocketTimeout
        configuration.waitsForConnectivity = true
        
        self.urlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: OperationQueue.main
        )
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Public Methods
    
    func connect() async throws {
        guard connectionState != .connected else { return }
        
        connectionState = .connecting
        reconnectAttempts = 0
        
        do {
            try await establishConnection()
            startHeartbeat()
        } catch {
            connectionState = .disconnected
            lastError = error
            throw error
        }
    }
    
    func disconnect() {
        stopHeartbeat()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        connectionState = .disconnected
        isConnected = false
        
        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: MPCError.sessionExpired)
        }
        pendingRequests.removeAll()
    }
    
    func sendMessage(_ message: MPCMessage) async throws {
        guard isConnected else {
            throw MPCError.websocketNotConnected
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        
        try await webSocketTask?.send(wsMessage)
    }
    
    func sendRequest(_ request: MPCMessage) async throws -> MPCMessage {
        guard isConnected else {
            throw MPCError.websocketNotConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = continuation
            
            Task {
                do {
                    try await sendMessage(request)
                    
                    // Set timeout for response
                    Task {
                        try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                        if pendingRequests[request.id] != nil {
                            pendingRequests.removeValue(forKey: request.id)
                            continuation.resume(throwing: MPCError.requestTimeout)
                        }
                    }
                } catch {
                    pendingRequests.removeValue(forKey: request.id)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func registerHandler(for type: String, handler: @escaping (MPCMessage) -> Void) {
        messageHandlers[type] = handler
    }
    
    // MARK: - Private Methods
    
    private func establishConnection() async throws {
        let config = MPCConfiguration.shared
        let urlString = "\(config.duoNodeUrl)/ws/mpc"
        
        guard let url = URL(string: urlString) else {
            throw MPCError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication
        if let token = config.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add headers
        request.setValue("interspace-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Wait for connection
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Send initial auth message
                    let authMessage = MPCMessage(
                        id: UUID().uuidString,
                        type: "auth",
                        payload: ["token": config.authToken ?? ""]
                    )
                    
                    try await sendMessage(authMessage)
                    
                    // Start receiving messages
                    receiveMessage()
                    
                    // Wait for auth response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.connectionState == .connecting {
                            self.connectionState = .connected
                            self.isConnected = true
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // Continue receiving
                
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let decoder = JSONDecoder()
                let mpcMessage = try decoder.decode(MPCMessage.self, from: data)
                
                // Check if this is a response to a pending request
                if let continuation = pendingRequests.removeValue(forKey: mpcMessage.id) {
                    continuation.resume(returning: mpcMessage)
                }
                
                // Handle by type
                if let handler = messageHandlers[mpcMessage.type] {
                    handler(mpcMessage)
                }
                
                // Handle system messages
                switch mpcMessage.type {
                case "auth_success":
                    connectionState = .connected
                    isConnected = true
                    
                case "auth_error":
                    disconnect()
                    lastError = MPCError.authenticationFailed
                    
                case "pong":
                    // Heartbeat response
                    break
                    
                default:
                    break
                }
                
            } catch {
                print("Failed to decode MPC message: \(error)")
            }
            
        case .string(let string):
            if let data = string.data(using: .utf8) {
                handleMessage(.data(data))
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleError(_ error: Error) {
        lastError = error
        
        if isConnected {
            isConnected = false
            connectionState = .disconnected
            
            // Attempt reconnection
            attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed
            return
        }
        
        reconnectAttempts += 1
        connectionState = .reconnecting
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay * Double(reconnectAttempts), repeats: false) { _ in
            Task { @MainActor in
                do {
                    try await self.establishConnection()
                    self.startHeartbeat()
                } catch {
                    self.attemptReconnection()
                }
            }
        }
    }
    
    // MARK: - Heartbeat
    
    private var heartbeatTimer: Timer?
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                guard self.isConnected else { return }
                
                let heartbeat = MPCMessage(
                    id: UUID().uuidString,
                    type: "ping",
                    payload: [:]
                )
                
                try? await self.sendMessage(heartbeat)
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension MPCSessionManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            print("WebSocket connected with protocol: \(`protocol` ?? "none")")
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            print("WebSocket closed with code: \(closeCode.rawValue)")
            handleError(MPCError.websocketConnectionFailed)
        }
    }
}

// MARK: - Supporting Types

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
    
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .failed:
            return "Connection Failed"
        }
    }
}

struct MPCMessage: Codable {
    let id: String
    let type: String
    let payload: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, type, payload
    }
    
    init(id: String = UUID().uuidString, type: String, payload: [String: Any]) {
        self.id = id
        self.type = type
        self.payload = payload
    }
    
    // Custom encoding/decoding for [String: Any]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        
        if let payloadData = try? container.decode(Data.self, forKey: .payload),
           let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            payload = json
        } else {
            payload = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        
        if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
            try container.encode(payloadData, forKey: .payload)
        }
    }
}