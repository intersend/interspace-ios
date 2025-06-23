import Foundation

enum AppEnvironment: String, CaseIterable {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
    
    var apiBaseURL: String {
        switch self {
        case .development:
            // Read from Info.plist which gets value from build configuration
            if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
               !url.isEmpty && url != "$(API_BASE_URL)" {
                return url
            }
            // Fallback for development
            return "https://7d4b-184-147-176-114.ngrok-free.app/api/v1"
        case .staging:
            return "https://staging-api.interspace.fi/api/v1"
        case .production:
            return "https://api.interspace.fi/api/v1"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var isDebugEnabled: Bool {
        switch self {
        case .development:
            return true
        case .staging, .production:
            return false
        }
    }
}

class EnvironmentConfiguration: ObservableObject {
    static let shared = EnvironmentConfiguration()
    
    @Published private(set) var currentEnvironment: AppEnvironment
    @Published var isDevelopmentModeEnabled: Bool = false
    @Published var showDebugOverlay: Bool = false
    @Published var enableMockData: Bool = false
    @Published var enableDetailedLogging: Bool = false
    
    private let environmentKey = "com.interspace.environment"
    private let devModeKey = "com.interspace.devModeEnabled"
    
    private init() {
        // Initialize currentEnvironment first
        if let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey),
           let environment = AppEnvironment(rawValue: savedEnvironment) {
            self.currentEnvironment = environment
        } else {
            #if DEBUG
            self.currentEnvironment = .development
            #else
            self.currentEnvironment = .production
            #endif
        }
        
        // Then initialize other properties
        #if DEBUG
        let savedDevMode = UserDefaults.standard.bool(forKey: devModeKey)
        if !UserDefaults.standard.contains(key: devModeKey) {
            // First time in debug, enable dev mode
            self.isDevelopmentModeEnabled = true
            UserDefaults.standard.set(true, forKey: devModeKey)
        } else {
            self.isDevelopmentModeEnabled = savedDevMode
        }
        #else
        self.isDevelopmentModeEnabled = false
        #endif
        
        // Load other settings
        self.showDebugOverlay = UserDefaults.standard.bool(forKey: "com.interspace.showDebugOverlay")
        self.enableMockData = UserDefaults.standard.bool(forKey: "com.interspace.enableMockData")
        self.enableDetailedLogging = UserDefaults.standard.bool(forKey: "com.interspace.enableDetailedLogging")
    }
    
    func setEnvironment(_ environment: AppEnvironment) {
        self.currentEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: environmentKey)
        
        // Update APIService with new base URL
        NotificationCenter.default.post(name: .environmentChanged, object: nil)
    }
    
    func toggleDevelopmentMode() {
        #if DEBUG
        isDevelopmentModeEnabled.toggle()
        UserDefaults.standard.set(isDevelopmentModeEnabled, forKey: devModeKey)
        #endif
    }
    
    func toggleDebugOverlay() {
        showDebugOverlay.toggle()
        UserDefaults.standard.set(showDebugOverlay, forKey: "com.interspace.showDebugOverlay")
    }
    
    func toggleMockData() {
        enableMockData.toggle()
        UserDefaults.standard.set(enableMockData, forKey: "com.interspace.enableMockData")
    }
    
    func toggleDetailedLogging() {
        enableDetailedLogging.toggle()
        UserDefaults.standard.set(enableDetailedLogging, forKey: "com.interspace.enableDetailedLogging")
    }
}

extension Notification.Name {
    static let environmentChanged = Notification.Name("com.interspace.environmentChanged")
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
