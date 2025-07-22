import Foundation
import Network

// MARK: - Local IP Detection Extension
extension MPCConfiguration {
    
    /// Automatically detect the host machine's local IP address
    /// This is useful for iOS Simulator to connect to services running on the host
    static func detectLocalIPAddress() -> String? {
        var address: String?
        
        // Get list of all interfaces on the local machine
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // Loop through interfaces
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // Check if interface is up and running
                let flags = Int32(interface.ifa_flags)
                guard (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0 else { continue }
                
                // Skip loopback interface
                let name = String(cString: interface.ifa_name)
                if name == "lo0" { continue }
                
                // Convert interface address to a human readable string
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                
                let addressString = String(cString: hostname)
                
                // Prefer en0 (Ethernet) or en1 (Wi-Fi) interfaces
                if name.hasPrefix("en") && !addressString.isEmpty {
                    address = addressString
                    // If we found en0, prefer it and break
                    if name == "en0" { break }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    /// Get the appropriate WebSocket host for current environment
    var dynamicWebsocketHost: String {
        // First, check Info.plist for custom configuration
        if let customHost = Bundle.main.object(forInfoDictionaryKey: "MPC_WEBSOCKET_HOST") as? String,
           !customHost.isEmpty {
            return customHost
        }
        
        #if targetEnvironment(simulator)
        // For simulator, try to auto-detect the host IP
        if let detectedIP = Self.detectLocalIPAddress() {
            print("🔵 Auto-detected host IP: \(detectedIP)")
            return detectedIP
        }
        
        // Fallback to hardcoded IP if detection fails
        print("⚠️ Could not auto-detect host IP, using fallback")
        return "192.168.2.79"
        #else
        // For device, use the existing logic
        return websocketHost
        #endif
    }
}

// MARK: - Environment Variable Support
extension MPCConfiguration {
    
    /// Check if we should use host.docker.internal for Docker Desktop
    var shouldUseDockerHost: Bool {
        #if targetEnvironment(simulator)
        // Check if MPC_USE_DOCKER_HOST environment variable is set
        return ProcessInfo.processInfo.environment["MPC_USE_DOCKER_HOST"] == "1"
        #else
        return false
        #endif
    }
    
    /// Get WebSocket host with Docker Desktop support
    var dockerAwareWebsocketHost: String {
        if shouldUseDockerHost {
            return "host.docker.internal"
        }
        return dynamicWebsocketHost
    }
}