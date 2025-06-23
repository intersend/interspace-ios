import Foundation
import SwiftUI

/// Manages the initialization and lifecycle of all services in the app
@MainActor
class ServiceInitializer: ObservableObject {
    static let shared = ServiceInitializer()
    
    @Published var isInitialized = false
    @Published var initializationProgress: Double = 0.0
    
    private var initializationTimes: [String: TimeInterval] = [:]
    private var servicesQueue = DispatchQueue(label: "com.interspace.services", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - Service Registry
    
    private var _keychainManager: KeychainManager?
    private var _authenticationManagerV2: AuthenticationManagerV2?
    private var _sessionCoordinator: SessionCoordinator?
    private var _walletService: WalletService?
    private var _profileIconGenerator: ProfileIconGenerator?
    private var _googleSignInService: GoogleSignInService?
//    private var _appleSignInService: AppleSignInService?
    private var _passkeyService: PasskeyService?
    
    // MARK: - Critical Services (Required at launch)
    
    /// Initialize services that are critical for app launch
    func initializeCriticalServices() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize in parallel where possible
        await withTaskGroup(of: Void.self) { group in
            // KeychainManager must be first
            group.addTask { @MainActor in
                self.initializeKeychainManager()
            }
            
            // Wait for KeychainManager before others
            await group.next()
            
            // Initialize remaining critical services
            group.addTask { @MainActor in
                self.initializeAuthenticationManagerV2()
            }
            
            group.addTask { @MainActor in
                self.initializeSessionCoordinator()
            }
            
            group.addTask { @MainActor in
                self.initializeWalletService()
            }
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("⚡️ Critical services initialized in \(String(format: "%.2f", totalTime))s")
        
        initializationProgress = 0.5
        isInitialized = true
    }
    
    // MARK: - Deferred Services (Can be initialized later)
    
    /// Initialize non-critical services in the background
    func initializeDeferredServices() {
        Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    self.initializeProfileIconGenerator()
                }
                
                group.addTask { @MainActor in
                    self.initializeGoogleSignInService()
                }
//                
//                group.addTask { @MainActor in
//                    self.initializeAppleSignInService()
//                }
                
                group.addTask { @MainActor in
                    self.initializePasskeyService()
                }
            }
            
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡️ Deferred services initialized in \(String(format: "%.2f", totalTime))s")
            
            initializationProgress = 1.0
        }
    }
    
    // MARK: - Individual Service Initializers
    
    private func initializeKeychainManager() {
        let start = CFAbsoluteTimeGetCurrent()
        _keychainManager = KeychainManager.shared
        recordInitTime("KeychainManager", start: start)
    }
    
    private func initializeAuthenticationManagerV2() {
        let start = CFAbsoluteTimeGetCurrent()
        _authenticationManagerV2 = AuthenticationManagerV2.shared
        recordInitTime("AuthenticationManagerV2", start: start)
    }
    
    private func initializeSessionCoordinator() {
        let start = CFAbsoluteTimeGetCurrent()
        _sessionCoordinator = SessionCoordinator.shared
        recordInitTime("SessionCoordinator", start: start)
    }
    
    private func initializeWalletService() {
        let start = CFAbsoluteTimeGetCurrent()
        _walletService = WalletService.shared
        // Note: WalletService SDKs are initialized lazily when needed
        recordInitTime("WalletService", start: start)
    }
    
    private func initializeProfileIconGenerator() {
        let start = CFAbsoluteTimeGetCurrent()
        _profileIconGenerator = ProfileIconGenerator()
        recordInitTime("ProfileIconGenerator", start: start)
    }
    
    private func initializeGoogleSignInService() {
        let start = CFAbsoluteTimeGetCurrent()
        _googleSignInService = GoogleSignInService.shared
        // Note: Google Sign-In configuration is deferred until needed
        recordInitTime("GoogleSignInService", start: start)
    }
    
//    private func initializeAppleSignInService() {
//        let start = CFAbsoluteTimeGetCurrent()
//        _appleSignInService = AppleSignInService.shared
//        recordInitTime("AppleSignInService", start: start)
//    }
    
    private func initializePasskeyService() {
        let start = CFAbsoluteTimeGetCurrent()
        _passkeyService = PasskeyService.shared
        recordInitTime("PasskeyService", start: start)
    }
    
    // MARK: - Service Accessors
    
    var keychain: KeychainManager {
        if _keychainManager == nil {
            initializeKeychainManager()
        }
        return _keychainManager!
    }
    
    var auth: AuthenticationManagerV2 {
        if _authenticationManagerV2 == nil {
            initializeAuthenticationManagerV2()
        }
        return _authenticationManagerV2!
    }
    
    var session: SessionCoordinator {
        if _sessionCoordinator == nil {
            initializeSessionCoordinator()
        }
        return _sessionCoordinator!
    }
    
    var wallet: WalletService {
        if _walletService == nil {
            initializeWalletService()
        }
        return _walletService!
    }
    
    // MARK: - Lazy Service Getters
    
    func getProfileIconGenerator() -> ProfileIconGenerator {
        servicesQueue.sync(flags: .barrier) {
            if _profileIconGenerator == nil {
                _profileIconGenerator = ProfileIconGenerator()
            }
            return _profileIconGenerator!
        }
    }
    
    func getGoogleSignInService() -> GoogleSignInService {
        servicesQueue.sync(flags: .barrier) {
            if _googleSignInService == nil {
                _googleSignInService = GoogleSignInService.shared
            }
            return _googleSignInService!
        }
    }
    
//    func getAppleSignInService() -> AppleSignInService {
//        servicesQueue.sync(flags: .barrier) {
//            if _appleSignInService == nil {
//                _appleSignInService = AppleSignInService.shared
//            }
//            return _appleSignInService!
//        }
//    }
    
    func getPasskeyService() -> PasskeyService {
        servicesQueue.sync(flags: .barrier) {
            if _passkeyService == nil {
                _passkeyService = PasskeyService.shared
            }
            return _passkeyService!
        }
    }
    
    // MARK: - Performance Tracking
    
    private func recordInitTime(_ service: String, start: CFAbsoluteTime) {
        let duration = CFAbsoluteTimeGetCurrent() - start
        initializationTimes[service] = duration
        print("⏱️ \(service) initialized in \(String(format: "%.3f", duration))s")
    }
    
    func getInitializationReport() -> String {
        var report = "Service Initialization Report:\n"
        let sortedTimes = initializationTimes.sorted { $0.value > $1.value }
        
        for (service, time) in sortedTimes {
            report += "  • \(service): \(String(format: "%.3f", time))s\n"
        }
        
        let totalTime = initializationTimes.values.reduce(0, +)
        report += "Total: \(String(format: "%.3f", totalTime))s"
        
        return report
    }
    
    // MARK: - Service Context Preloading
    
    enum ServiceContext {
        case authentication
        case wallet
        case profile
    }
    
    /// Preload services that will be needed for a specific context
    func preloadServicesForContext(_ context: ServiceContext) {
        Task {
            switch context {
            case .authentication:
                _ = getGoogleSignInService()
//                _ = getAppleSignInService()
                _ = getPasskeyService()
            case .wallet:
                await wallet.initializeSDKsIfNeeded()
            case .profile:
                _ = getProfileIconGenerator()
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// Reset all services (for logout)
    func resetAllServices() {
        servicesQueue.sync(flags: .barrier) {
            _keychainManager = nil
            _authenticationManagerV2 = nil
            _sessionCoordinator = nil
            _walletService = nil
            _profileIconGenerator = nil
            _googleSignInService = nil
//            _appleSignInService = nil
            _passkeyService = nil
            
            isInitialized = false
            initializationProgress = 0.0
            initializationTimes.removeAll()
        }
    }
    
    /// Clean up services that haven't been used recently
    func cleanupUnusedServices() {
        // This could be expanded to track service usage and clean up unused ones
        // For now, just a placeholder for future optimization
    }
}
