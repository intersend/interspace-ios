import Foundation

// MARK: - MPC Local Development Configuration
// This file contains configuration for local MPC development with Docker

struct MPCLocalConfig {
    /// The host machine's IP address for iOS simulator to connect to Docker containers
    /// Update this with your machine's IP address when developing locally
    /// To find your IP: ifconfig | grep "inet " | grep -v 127.0.0.1
    static let hostIP = "192.168.2.79"
    
    /// Alternative: Use this method to get the host IP dynamically
    /// Note: This requires the backend to be accessible via ngrok or similar
    static var dynamicHostIP: String {
        // In a real implementation, you could:
        // 1. Read from a config file
        // 2. Use mDNS/Bonjour to discover the host
        // 3. Use environment variables passed during build
        // For now, return the static IP
        return hostIP
    }
    
    /// Get the appropriate host for the current environment
    static var sigpairHost: String {
        #if DEBUG
        // For local development with Docker
        return hostIP
        #else
        // For production, this would be handled by MPCConfiguration
        return "interspace-duo-node-prod.a.run.app"
        #endif
    }
}