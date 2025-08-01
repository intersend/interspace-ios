import Foundation
import Network
import UIKit

/// Manages pre-connection checks to ensure smooth wallet connections
class PreflightCheckManager {
    static let shared = PreflightCheckManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.interspace.preflight")
    private var isNetworkAvailable = true
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Types
    
    struct PreflightResult {
        let passed: Bool
        let issues: [PreflightIssue]
        
        var hasBlockingIssues: Bool {
            issues.contains { $0.severity == .blocking }
        }
    }
    
    struct PreflightIssue {
        let type: IssueType
        let severity: Severity
        let message: String
        let resolution: String?
        
        enum IssueType {
            case noNetwork
            case walletNotInstalled
            case walletNotConfigured
            case permissionsDenied
            case insufficientStorage
            case appNotActive
        }
        
        enum Severity {
            case blocking
            case warning
            case info
        }
    }
    
    // MARK: - Public Methods
    
    /// Perform all pre-flight checks for wallet connection
    func performChecks(for walletType: WalletType) async -> PreflightResult {
        var issues: [PreflightIssue] = []
        
        // Run all checks in parallel for speed
        await withTaskGroup(of: PreflightIssue?.self) { group in
            // Network check
            group.addTask {
                return self.checkNetworkConnectivity()
            }
            
            // Wallet availability check
            group.addTask {
                return await self.checkWalletAvailability(walletType)
            }
            
            // App state check
            group.addTask {
                return await self.checkAppState()
            }
            
            // Storage check (for caching)
            group.addTask {
                return self.checkStorage()
            }
            
            // Collect results
            for await issue in group {
                if let issue = issue {
                    issues.append(issue)
                }
            }
        }
        
        // Sort by severity
        issues.sort { $0.severity.rawValue < $1.severity.rawValue }
        
        let passed = !issues.contains { $0.severity == .blocking }
        
        return PreflightResult(passed: passed, issues: issues)
    }
    
    /// Quick check if we can attempt connection
    func canAttemptConnection() -> Bool {
        return isNetworkAvailable && UIApplication.shared.applicationState == .active
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    private func checkNetworkConnectivity() -> PreflightIssue? {
        guard isNetworkAvailable else {
            return PreflightIssue(
                type: .noNetwork,
                severity: .blocking,
                message: "No internet connection",
                resolution: "Please check your internet connection and try again"
            )
        }
        return nil
    }
    
    @MainActor
    private func checkWalletAvailability(_ walletType: WalletType) async -> PreflightIssue? {
        // Skip checks for always-available wallets
        if [.google, .apple, .mpc].contains(walletType) {
            return nil
        }
        
        // Check if wallet app is installed
        let isInstalled = WalletService.shared.isWalletAvailable(walletType)
        
        if !isInstalled {
            // Check if we can use universal links as fallback
            let config = WalletConfiguration.configuration(for: walletType)
            if config.universalLinkDomain != nil {
                // Universal link available, just a warning
                return PreflightIssue(
                    type: .walletNotInstalled,
                    severity: .warning,
                    message: "\(walletType.displayName) app not installed",
                    resolution: "You'll be redirected to install the app if needed"
                )
            } else {
                // No fallback, blocking issue
                return PreflightIssue(
                    type: .walletNotInstalled,
                    severity: .blocking,
                    message: "\(walletType.displayName) app is required",
                    resolution: "Please install \(walletType.displayName) from the App Store"
                )
            }
        }
        
        return nil
    }
    
    @MainActor
    private func checkAppState() async -> PreflightIssue? {
        let state = UIApplication.shared.applicationState
        
        if state != .active {
            return PreflightIssue(
                type: .appNotActive,
                severity: .warning,
                message: "App is in background",
                resolution: "Connection may fail if app remains in background"
            )
        }
        
        return nil
    }
    
    private func checkStorage() -> PreflightIssue? {
        // Check available storage for caching
        if let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) {
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                let freeSpaceInMB = freeSpace.int64Value / (1024 * 1024)
                
                if freeSpaceInMB < 10 { // Less than 10MB
                    return PreflightIssue(
                        type: .insufficientStorage,
                        severity: .warning,
                        message: "Low storage space",
                        resolution: "Free up some space for optimal performance"
                    )
                }
            }
        }
        
        return nil
    }
}

// MARK: - Extensions

extension PreflightCheckManager.PreflightIssue.Severity: Comparable {
    var rawValue: Int {
        switch self {
        case .blocking: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - UI Helper

extension PreflightCheckManager {
    /// Get user-friendly message for preflight results
    func getUserMessage(for result: PreflightResult) -> (title: String, message: String, canProceed: Bool) {
        if result.passed {
            return (
                "Ready to Connect",
                "All checks passed. Tap to continue.",
                true
            )
        }
        
        if let blockingIssue = result.issues.first(where: { $0.severity == .blocking }) {
            return (
                "Cannot Connect",
                blockingIssue.resolution ?? blockingIssue.message,
                false
            )
        }
        
        if let warning = result.issues.first(where: { $0.severity == .warning }) {
            return (
                "Connection Warning",
                warning.message,
                true
            )
        }
        
        return (
            "Ready to Connect",
            "Tap to continue",
            true
        )
    }
    
    /// Show alert for preflight issues
    @MainActor
    func showIssueAlert(for issue: PreflightIssue, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: getAlertTitle(for: issue.type),
            message: issue.resolution ?? issue.message,
            preferredStyle: .alert
        )
        
        // Add appropriate actions based on issue type
        switch issue.type {
        case .walletNotInstalled:
            if let walletType = getWalletType(from: issue) {
                alert.addAction(UIAlertAction(title: "Install App", style: .default) { _ in
                    self.openAppStore(for: walletType)
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
        case .noNetwork:
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
        default:
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        
        viewController.present(alert, animated: true)
    }
    
    private func getAlertTitle(for issueType: PreflightIssue.IssueType) -> String {
        switch issueType {
        case .noNetwork:
            return "No Internet Connection"
        case .walletNotInstalled:
            return "Wallet App Required"
        case .walletNotConfigured:
            return "Wallet Not Set Up"
        case .permissionsDenied:
            return "Permissions Required"
        case .insufficientStorage:
            return "Low Storage"
        case .appNotActive:
            return "App in Background"
        }
    }
    
    private func getWalletType(from issue: PreflightIssue) -> WalletType? {
        // Extract wallet type from issue message
        // This is a simple implementation - could be improved
        for walletType in WalletType.allCases {
            if issue.message.contains(walletType.displayName) {
                return walletType
            }
        }
        return nil
    }
    
    private func openAppStore(for walletType: WalletType) {
        let generator = WalletDeepLinkGenerator.shared
        let result = generator.generateDeepLinks(for: walletType, uri: "")
        
        if let appStoreURL = result.fallbackURL {
            UIApplication.shared.open(appStoreURL)
        }
    }
}