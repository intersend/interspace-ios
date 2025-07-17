import Foundation

struct MPCConfiguration {
    static let shared = MPCConfiguration()
    
    private init() {}
    
    /// Get the WebSocket host for MPC operations
    var websocketHost: String {
        // First, check Info.plist for custom configuration
        if let customHost = Bundle.main.object(forInfoDictionaryKey: "MPC_WEBSOCKET_HOST") as? String,
           !customHost.isEmpty {
            return customHost
        }
        
        // Check if we're in simulator
        #if targetEnvironment(simulator)
        return "localhost"
        #else
        // For device, check environment
        if EnvironmentConfiguration.shared.currentEnvironment.apiBaseURL.contains("ngrok") {
            // Extract ngrok host if available
            if let ngrokHost = URL(string: EnvironmentConfiguration.shared.currentEnvironment.apiBaseURL)?.host {
                return ngrokHost
            }
        }
        
        // Fallback to default local network IP
        // Update this to your machine's IP when running locally
        return "192.168.2.79"
        #endif
    }
    
    /// Get the WebSocket port for MPC operations
    var websocketPort: String {
        // Check Info.plist for custom configuration
        if let customPort = Bundle.main.object(forInfoDictionaryKey: "MPC_WEBSOCKET_PORT") as? String,
           !customPort.isEmpty {
            return customPort
        }
        
        // Default sigpair port
        return "8080"
    }
    
    /// Check if WebSocket connection should be secure (wss vs ws)
    var isWebSocketSecure: Bool {
        // Check Info.plist for custom configuration
        if let customSecure = Bundle.main.object(forInfoDictionaryKey: "MPC_WEBSOCKET_SECURE") as? Bool {
            return customSecure
        }
        
        // Use secure connection for ngrok
        return EnvironmentConfiguration.shared.currentEnvironment.apiBaseURL.contains("ngrok")
    }
    
    /// Get the complete WebSocket URL
    var websocketURL: String {
        let protocol = isWebSocketSecure ? "wss" : "ws"
        return "\(protocol)://\(websocketHost):\(websocketPort)"
    }
    
    /// Log current configuration
    func logConfiguration() {
        print("🔵 MPC Configuration:")
        print("   - Host: \(websocketHost)")
        print("   - Port: \(websocketPort)")
        print("   - Secure: \(isWebSocketSecure)")
        print("   - Full URL: \(websocketURL)")
    }
}