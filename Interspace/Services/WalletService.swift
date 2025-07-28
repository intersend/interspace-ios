import Foundation
import Combine
import UIKit

final class WalletService: ObservableObject {
    static let shared = WalletService()
    
    @Published var connectionStatus: WalletConnectionStatus = .disconnected
    @Published var connectedWallet: WalletType?
    @Published var walletAddress: String?
    @Published var error: WalletError?
    
    
    // Connection state management
    private(set) var isConnectionInProgress = false
    private var isAuthenticationFlow = false
    private var lastConnectionAttempt: Date?
    private let connectionCooldown: TimeInterval = 2.0 // 2 seconds cooldown between attempts
    
    // Enhanced connection tracking
    private var currentConnectionId: String?
    private var connectionStartTime: Date?
    private let connectionTimeout: TimeInterval = 30.0 // 30 seconds timeout
    private let connectionWarningTime: TimeInterval = 15.0 // Show warning after 15 seconds
    private var connectionTimeoutTask: Task<Void, Never>?
    
    // Lazy initialization flags
    private var isInitialized = false
    private var initializationTask: Task<Void, Never>?
    
    private init() {
        // Defer all initialization until needed
        print("💼 WalletService: Created (deferred initialization)")
    }
    
    /// Initialize SDKs only when wallet features are needed
    @MainActor
    func initializeSDKsIfNeeded() async {
        guard !isInitialized else { return }
        
        // Prevent multiple initializations
        if let existingTask = initializationTask {
            await existingTask.value
            return
        }
        
        initializationTask = Task {
            print("💼 WalletService: Starting SDK initialization")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Set up observers first
            setupNotificationObservers()
            
            
            isInitialized = true
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("💼 WalletService: SDK initialization completed in \(String(format: "%.2f", duration))s")
        }
        
        await initializationTask?.value
    }
    
    
    
    private func setupNotificationObservers() {
        // Add notification observer for debugging
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification(_:)),
            name: nil,
            object: nil
        )
        
        // Add observers for session management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearWalletConnections),
            name: .clearWalletConnections,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionDidEnd),
            name: .sessionDidEnd,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileDidChange),
            name: .profileDidChange,
            object: nil
        )
    }
    
    @objc private func handleNotification(_ notification: Notification) {
        if notification.name.rawValue.contains("MetaMask") || notification.name.rawValue.contains("metamask") {
            print("🔔 WalletService: Received MetaMask notification: \(notification.name.rawValue)")
            if let userInfo = notification.userInfo {
                print("🔔 WalletService: UserInfo: \(userInfo)")
            }
        }
    }
    
    @objc private func handleClearWalletConnections() {
        print("🔔 WalletService: Received clearWalletConnections notification")
        Task {
            await disconnect()
        }
    }
    
    @objc private func handleSessionDidEnd() {
        print("🔔 WalletService: Received sessionDidEnd notification")
        Task {
            await disconnect()
        }
    }
    
    @objc private func handleProfileDidChange(_ notification: Notification) {
        print("🔔 WalletService: Received profileDidChange notification")
        // Clear wallet state when profile changes
        Task {
            await disconnect()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        connectionTimeoutTask?.cancel()
    }
    
    // MARK: - App Lifecycle
    
    /// Call this when app enters background to ensure clean state
    func handleAppBackground() {
        print("💰 WalletService: App entering background, clearing temporary state")
        // Only clear if we're not in an active connected state
        if connectionStatus != .connected {
            Task {
                await MainActor.run {
                    self.connectionStatus = .disconnected
                    self.error = nil
                }
            }
        }
    }
    
    /// Call this when app becomes active to check wallet state
    func handleAppForeground() {
        print("💰 WalletService: App becoming active, checking wallet state")
        print("💰 WalletService: isAuthenticationFlow: \(isAuthenticationFlow), isConnectionInProgress: \(isConnectionInProgress)")
        
        // Check for stuck connections
        if isConnectionInProgress, let startTime = connectionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            print("💰 WalletService: Connection in progress for \(elapsed) seconds")
            
            // If connection has been in progress too long, it's likely stuck
            if elapsed > connectionTimeout {
                print("💰 WalletService: Connection timeout detected, resetting state")
                resetConnectionState(error: WalletError.connectionFailed("Connection timed out. Please try again."))
                return
            }
            
            // MetaMask state handling moved to WalletServiceV2
        }
    }
    
    
    
    
    // MARK: - Debug Methods
    
    
    // MARK: - Wallet Connection
    
    func connectWallet(_ walletType: WalletType) async throws -> WalletConnectionResult {
        // Initialize SDKs if needed (this is fast if already initialized)
        await initializeSDKsIfNeeded()
        
        // Haptic feedback for connection start
        await MainActor.run {
            HapticManager.impact(.light)
        }
        
        // Perform preflight checks
        let preflightResult = await PreflightCheckManager.shared.performChecks(for: walletType)
        
        if !preflightResult.passed {
            print("❌ WalletService: Preflight checks failed")
            await MainActor.run {
                HapticManager.notification(.error)
            }
            
            if let blockingIssue = preflightResult.issues.first(where: { $0.severity == .blocking }) {
                let walletError = WalletError.connectionFailed(blockingIssue.resolution ?? blockingIssue.message)
                await MainActor.run {
                    self.error = walletError
                }
                throw walletError
            }
        }
        
        // Show warnings if any
        if let warning = preflightResult.issues.first(where: { $0.severity == .warning }) {
            print("⚠️ WalletService: Preflight warning: \(warning.message)")
        }
        
        // Check if a connection is already in progress
        if isConnectionInProgress {
            // Check if it's a stuck connection
            if let startTime = connectionStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 10 { // If stuck for more than 10 seconds, allow retry
                    print("💰 WalletService: Previous connection appears stuck (\(elapsed)s), allowing retry")
                    resetConnectionState(error: nil as WalletError?)
                } else {
                    print("💰 WalletService: Connection already in progress, please wait")
                    throw WalletError.connectionFailed("Connection in progress. Please wait...")
                }
            }
        }
        
        // Check cooldown period (but not for stuck connections)
        if let lastAttempt = lastConnectionAttempt, !isConnectionInProgress {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < connectionCooldown {
                let remainingCooldown = connectionCooldown - timeSinceLastAttempt
                print("💰 WalletService: Connection cooldown active, \(remainingCooldown) seconds remaining")
                throw WalletError.connectionFailed("Please wait a moment before trying again")
            }
        }
        
        // Mark connection as in progress
        let connectionId = UUID().uuidString
        currentConnectionId = connectionId
        isConnectionInProgress = true
        isAuthenticationFlow = true
        lastConnectionAttempt = Date()
        connectionStartTime = Date()
        
        await MainActor.run {
            connectionStatus = .connecting
            error = nil
            // Haptic feedback for state change
            HapticManager.impact(.medium)
        }
        
        // Start connection timeout
        startConnectionTimeout(connectionId: connectionId)
        
        do {
            let result: WalletConnectionResult
            
            switch walletType {
            case .metamask:
                // Redirect to WalletServiceV2 for native MetaMask SDK integration
                print("💰 WalletService: Redirecting MetaMask to WalletServiceV2")
                result = try await WalletServiceV2.shared.connectWallet(.metamask)
            case .coinbase:
                // Coinbase now uses AppKit modal
                throw WalletError.connectionFailed("Please use the Connect Wallet option for Coinbase Wallet")
            case .rainbow, .trust, .argent, .gnosisSafe, .family, .phantom, .oneInch, .zerion, .imToken, .tokenPocket, .spot, .omni:
                // These wallets are no longer supported without WalletConnect
                throw WalletError.connectionFailed("This wallet type requires WalletConnect which has been removed")
            case .google, .apple:
                throw WalletError.unsupportedWallet("Social authentication should use AuthenticationManagerV2")
            case .mpc:
                throw WalletError.unsupportedWallet("MPC wallets should use MPCWalletService")
            case .safe, .ledger, .trezor, .unknown:
                throw WalletError.unsupportedWallet("Wallet type \(walletType.rawValue) not yet supported")
            }
            
            await MainActor.run {
                connectionStatus = .connected
                connectedWallet = walletType
                walletAddress = result.address
                // Success haptic
                HapticManager.notification(.success)
            }
            
            // Clear connection state on success
            resetConnectionState(error: nil as WalletError?)
            
            return result
        } catch let walletError as WalletError {
            // Clear connection state on error
            resetConnectionState(error: walletError)
            
            await MainActor.run {
                connectionStatus = .disconnected
                connectedWallet = nil
                walletAddress = nil
                error = walletError
                // Error haptic
                HapticManager.notification(.error)
            }
            throw walletError
        } catch {
            // Clear connection flags on error
            isConnectionInProgress = false
            isAuthenticationFlow = false
            
            let walletError = WalletError.connectionFailed(error.localizedDescription)
            await MainActor.run {
                connectionStatus = .disconnected
                connectedWallet = nil
                walletAddress = nil
                self.error = walletError
                // Error haptic
                HapticManager.notification(.error)
            }
            throw walletError
        }
    }
    
    
    // MARK: - SIWE Helper Methods
    
    private func getSIWENonce() async throws -> String {
        // Call backend to get SIWE nonce
        let url = URL(string: "\(APIService.shared.getBaseURL())/siwe/nonce")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add ngrok headers if using ngrok URL
        if url.absoluteString.contains("ngrok") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WalletError.networkError("Failed to get nonce: HTTP \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(NonceResponse.self, from: data)
        
        guard result.success, let nonce = result.data?.nonce else {
            throw WalletError.networkError(result.error ?? "Failed to get nonce")
        }
        
        return nonce
    }
    
    private func createSIWEMessage(address: String, nonce: String, chainId: Int) -> String {
        let domain = "interspace.fi"
        let uri = "https://interspace.fi"
        let version = "1"
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let statement = "Sign in with Ethereum to Interspace"
        
        // Format according to EIP-4361
        var message = "\(domain) wants you to sign in with your Ethereum account:\n"
        message += "\(address)\n\n"
        message += "\(statement)\n\n"
        message += "URI: \(uri)\n"
        message += "Version: \(version)\n"
        message += "Chain ID: \(chainId)\n"
        message += "Nonce: \(nonce)\n"
        message += "Issued At: \(issuedAt)"
        
        return message
    }
    
    // MARK: - Disconnect
    
    func disconnect() async {
        print("💰 WalletService: Starting disconnect process")
        
        // Clear connection flags
        isConnectionInProgress = false
        isAuthenticationFlow = false
        
        // Update UI state immediately
        await MainActor.run {
            connectionStatus = .disconnected
            connectedWallet = nil
            walletAddress = nil
            error = nil
        }
        
        // Reset SDKs
        // MetaMask SDK is now handled via WalletServiceV2
        
        // Coinbase SDK reset temporarily disabled
        // print("💰 WalletService: Resetting Coinbase session")
        // coinbaseSDK.resetSession()
        
        print("💰 WalletService: Disconnect completed")
    }
    
    // MARK: - Wallet Availability
    
    func isWalletAvailable(_ walletType: WalletType) -> Bool {
        switch walletType {
        case .metamask:
            return canOpenMetaMask()
        case .coinbase:
            // Coinbase now uses AppKit modal
            return false
        case .google, .apple:
            return true // Social authentication is always available
        case .mpc:
            return true // MPC wallets are always available
        case .safe, .ledger, .trezor, .unknown:
            return false // Not yet supported
        default:
            // Use the new WalletDeepLinkGenerator for all WalletConnect-based wallets
            return WalletDeepLinkGenerator.shared.isWalletInstalled(walletType)
        }
    }
    
    private func canOpenMetaMask() -> Bool {
        // Check multiple URL schemes that MetaMask might use
        let schemes = ["metamask://", "metamask-app://", "https://metamask.app.link"]
        
        for scheme in schemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                print("💰 WalletService: MetaMask found with scheme: \(scheme)")
                return true
            }
        }
        
        print("💰 WalletService: MetaMask not found with any known schemes")
        return false
    }
    
    
    private func canOpenWallet(scheme: String) -> Bool {
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            print("💰 WalletService: Wallet with scheme \(scheme) is installed")
            return true
        }
        print("💰 WalletService: Wallet with scheme \(scheme) is not installed")
        return false
    }
    
    // MARK: - Connection State Management
    
    private func resetConnectionState(error: WalletError?) {
        print("💰 WalletService: Resetting connection state")
        
        // Cancel timeout task
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        
        // Reset flags
        isConnectionInProgress = false
        isAuthenticationFlow = false
        currentConnectionId = nil
        connectionStartTime = nil
        
        // Update UI state if there's an error
        if let error = error {
            Task { @MainActor in
                self.connectionStatus = .disconnected
                self.connectedWallet = nil
                self.walletAddress = nil
                self.error = error
            }
        }
    }
    
    private func startConnectionTimeout(connectionId: String) {
        // Cancel any existing timeout
        connectionTimeoutTask?.cancel()
        
        // Start new timeout
        connectionTimeoutTask = Task {
            // Warning after 15 seconds
            try? await Task.sleep(nanoseconds: UInt64(connectionWarningTime * 1_000_000_000))
            
            // Check if this connection is still active
            guard currentConnectionId == connectionId, isConnectionInProgress else { return }
            
            print("⚠️ WalletService: Connection taking longer than usual...")
            
            // Final timeout after 30 seconds total
            try? await Task.sleep(nanoseconds: UInt64((connectionTimeout - connectionWarningTime) * 1_000_000_000))
            
            // Check again if this connection is still active
            guard currentConnectionId == connectionId, isConnectionInProgress else { return }
            
            print("❌ WalletService: Connection timeout reached")
            await MainActor.run {
                self.resetConnectionState(error: WalletError.connectionFailed("Connection timed out. Please try again."))
            }
        }
    }
    
    func forceResetConnection() {
        print("💰 WalletService: Force resetting connection")
        resetConnectionState(error: nil as WalletError?)
        
        // Also clear any MetaMask state
        // MetaMask SDK is now handled via WalletServiceV2
    }
    
    // MARK: - Deep Linking
    
    /// Open wallet app with deep link
    @MainActor
    func openWalletWithDeepLink(walletType: WalletType, uri: String) {
        print("📱 WalletService: Opening wallet app with deep link for \(walletType.displayName)")
        print("📱 WalletService: URI: \(uri)")
        
        // Use the new WalletDeepLinkGenerator
        let deepLinkGenerator = WalletDeepLinkGenerator.shared
        let deepLinkResult = deepLinkGenerator.generateDeepLinks(for: walletType, uri: uri)
        
        
        
        // Open wallet using the deep link generator
        deepLinkGenerator.openWallet(with: deepLinkResult) { success in
            if success {
                print("📱 WalletService: Successfully opened \(walletType.displayName)")
            } else {
                print("❌ WalletService: Failed to open \(walletType.displayName)")
                // The generator already handles fallback to App Store
            }
        }
    }
    
    // Note: tryPhantomUniversalLink is now handled by WalletDeepLinkGenerator
    
    /// Show alert when wallet app is not installed
    @MainActor
    private func showWalletNotInstalledAlert(walletType: WalletType) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "\(walletType.displayName) Not Found",
            message: "The \(walletType.displayName) app doesn't appear to be installed. Would you like to view it on the App Store?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View on App Store", style: .default) { _ in
            if let appStoreUrl = self.getAppStoreUrl(for: walletType),
               let url = URL(string: appStoreUrl) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Show alert when no wallet apps are installed
    @MainActor
    private func showNoWalletInstalledAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "No Wallet Apps Found",
            message: "You need a crypto wallet app to continue. Would you like to browse wallet apps on the App Store?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Browse Wallets", style: .default) { _ in
            // Open App Store search for crypto wallets
            if let url = URL(string: "https://apps.apple.com/search?term=crypto+wallet") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Show alert when wallet connection fails
    @MainActor
    private func showWalletOpenFailedAlert(walletType: WalletType) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Connection Failed",
            message: "Unable to open \(walletType.displayName). Please make sure the app is installed and try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        rootViewController.present(alert, animated: true)
    }
    
    /// Get App Store URL for wallet apps
    private func getAppStoreUrl(for walletType: WalletType) -> String? {
        switch walletType {
        case .trust:
            return "https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409"
        case .rainbow:
            return "https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021"
        case .metamask:
            return "https://apps.apple.com/app/metamask-blockchain-wallet/id1438144202"
        case .argent:
            return "https://apps.apple.com/app/argent/id1358741926"
        case .coinbase:
            return "https://apps.apple.com/app/coinbase-wallet/id1278383455"
        case .zerion:
            return "https://apps.apple.com/app/zerion-wallet/id1456732565"
        case .oneInch:
            return "https://apps.apple.com/app/1inch-defi-wallet/id1546049391"
        case .imToken:
            return "https://apps.apple.com/app/imtoken-crypto-wallet/id1153230571"
        case .phantom:
            return "https://apps.apple.com/app/phantom-crypto-wallet/id1598432977"
        default:
            return nil
        }
    }
    
    /// Get available wallet apps installed on device
    func getAvailableWalletApps() -> [WalletAppInfo] {
        let walletApps = [
            WalletAppInfo(name: "Rainbow", scheme: "rainbow", icon: "rainbow"),
            WalletAppInfo(name: "Trust Wallet", scheme: "trust", icon: "trust"),
            WalletAppInfo(name: "Argent", scheme: "argent", icon: "argent"),
            WalletAppInfo(name: "Gnosis Safe", scheme: "gnosissafe", icon: "safe"),
            WalletAppInfo(name: "MetaMask", scheme: "metamask", icon: "metamask"),
            WalletAppInfo(name: "Family", scheme: "family", icon: "family"),
            WalletAppInfo(name: "Phantom", scheme: "phantom", icon: "phantom"),
            WalletAppInfo(name: "1inch Wallet", scheme: "oneinch", icon: "oneinch"),
            WalletAppInfo(name: "Zerion", scheme: "zerion", icon: "zerion"),
            WalletAppInfo(name: "imToken", scheme: "imtoken", icon: "imtoken"),
            WalletAppInfo(name: "TokenPocket", scheme: "tokenpocket", icon: "tokenpocket"),
            WalletAppInfo(name: "Spot", scheme: "spot", icon: "spot"),
            WalletAppInfo(name: "Omni", scheme: "omni", icon: "omni")
        ]
        
        // Filter to only installed apps
        return walletApps.filter { app in
            if let url = URL(string: "\(app.scheme)://") {
                return UIApplication.shared.canOpenURL(url)
            }
            return false
        }
    }
    
    
    // MARK: - Transaction Methods
    
    /// Send a transaction using the active wallet account
    func sendTransaction(
        to address: String,
        value: String? = nil,
        data: String? = nil,
        chainId: String = "1"
    ) async throws {
        // Get the active wallet from the profile
        guard let activeProfile = await SessionCoordinator.shared.activeProfile else {
            throw WalletError.noSession
        }
        
        // Check if user has linked wallet accounts
        // For now, we'll need to check linked accounts through a different approach
        // since SmartProfile doesn't contain linkedAccounts directly
        guard activeProfile.linkedAccountsCount > 0 else {
            throw WalletError.noAccountsFound
        }
        
        // For now, we'll use a placeholder since we need to fetch linked accounts separately
        // This would require accessing ProfileViewModel or making an API call
        let walletAddress = "0x0000000000000000000000000000000000000000" // Placeholder
        
        // TODO: Properly fetch linked accounts for the active profile
        // This should be done through ProfileViewModel.shared.linkedAccounts
        throw WalletError.noAccountsFound
        
        // Determine wallet type - placeholder for now
        let walletType = WalletType.metamask // Default
        
        // Open the wallet app with transaction deeplink
        let deepLinkGenerator = WalletDeepLinkGenerator.shared
        
        await withCheckedContinuation { continuation in
            deepLinkGenerator.openWalletForTransaction(
                walletType: walletType,
                to: address,
                value: value,
                data: data,
                chainId: chainId
            ) { success in
                if success {
                    print("💰 WalletService: Transaction deeplink opened successfully")
                } else {
                    print("❌ WalletService: Failed to open transaction deeplink")
                }
                continuation.resume()
            }
        }
    }
    
    
    /// Determine wallet type from linked account
    private func determineWalletType(from account: LinkedAccount) -> WalletType {
        // Check the account authStrategy and walletType
        if let walletTypeString = account.walletType?.lowercased() {
            switch walletTypeString {
            case "metamask":
                return .metamask
            case "coinbase":
                return .coinbase
            case "trust":
                return .trust
            case "family":
                return .family
            case "phantom":
                return .phantom
            case "zerion":
                return .zerion
            case "rainbow":
                return .rainbow
            case "argent":
                return .argent
            default:
                return .unknown
            }
        }
        
        // Default to unknown
        return .unknown
    }
}

// MARK: - Supporting Types

enum WalletConnectionStatus {
    case disconnected
    case connecting
    case connected
}

// WalletConnectionResult moved to WalletServiceV2.swift to avoid conflicts

// WalletError is now defined in WalletErrors.swift as WalletConnectionError
// The type alias in WalletErrors.swift provides backward compatibility

// MARK: - Response Types
// NonceResponse and NonceData are defined in SIWEModels.swift

