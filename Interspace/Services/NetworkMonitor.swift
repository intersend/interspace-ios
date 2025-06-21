import Foundation
import Network
import Combine

// MARK: - Network Monitor

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.interspace.networkmonitor")
    
    // MARK: - Connection Type
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
                
                // Post notification for network status change
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: path.status == .satisfied
                )
                
                print("📡 Network Status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
                print("📡 Connection Type: \(self?.connectionType ?? .unknown)")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - Utility Methods
    
    /// Check if we should sync based on connection type and constraints
    func shouldPerformBackgroundSync() -> Bool {
        return isConnected && !isConstrained && (connectionType == .wifi || !isExpensive)
    }
    
    /// Check if we should download large data
    func shouldDownloadLargeData() -> Bool {
        return isConnected && connectionType == .wifi && !isConstrained
    }
}