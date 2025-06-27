import Foundation

/// Configuration for demo mode
struct DemoModeConfiguration {
    /// Enable demo mode - set to true for the demo app
    static let isDemoMode = true
    
    /// Reset data on app launch
    static let resetDataOnLaunch = true
    
    /// Show demo mode indicator in UI
    static let showDemoIndicator = true
    
    /// Disable all network requests
    static let disableNetworkRequests = true
    
    /// Skip authentication flows
    static let skipAuthentication = true
    
    /// Use mock data providers
    static let useMockDataProviders = true
}

/// Protocol for services that support demo mode
protocol DemoModeSupporting {
    /// Initialize the service in demo mode
    func initializeForDemoMode()
}