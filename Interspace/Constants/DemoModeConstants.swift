import Foundation

/// Global demo mode configuration accessible throughout the app
public enum DemoMode {
    public static let isEnabled: Bool = true
    public static let showIndicator: Bool = true
    public static let useMockData: Bool = true
    public static let skipAuthentication: Bool = true
    public static let demoUserEmail: String = "demo@interspace.app"
}