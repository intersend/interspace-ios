# Wallet Connection Apple UX Enhancement Plan

## Overview
This plan outlines specific improvements to make the wallet connection experience in Interspace iOS feel as native and polished as Apple's own features, focusing on smoothness, robustness, and reliability.

## 1. User Experience Smoothness

### 1.1 Haptic Feedback Integration Points

```swift
// Enhanced HapticManager for wallet connections
extension HapticManager {
    static func walletConnection(_ event: WalletConnectionHapticEvent) {
        switch event {
        case .buttonTap:
            impact(.light)
        case .walletDetected:
            impact(.medium)
        case .connectionEstablished:
            notification(.success)
        case .signatureReceived:
            impact(.light)
        case .connectionFailed:
            notification(.error)
        case .timeout:
            notification(.warning)
        case .retry:
            impact(.medium)
        }
    }
    
    enum WalletConnectionHapticEvent {
        case buttonTap
        case walletDetected
        case connectionEstablished
        case signatureReceived
        case connectionFailed
        case timeout
        case retry
    }
}
```

**Implementation Points:**
- Tap on wallet selection: Light impact
- Wallet app detected/opened: Medium impact
- Connection established: Success notification
- Signature received: Light impact
- Error states: Error notification
- Timeout warnings: Warning notification

### 1.2 Visual Feedback and Animations

#### Connection Progress Indicator
```swift
struct WalletConnectionProgressView: View {
    @State private var phase: ConnectionPhase = .initializing
    @State private var pulseAnimation = false
    
    enum ConnectionPhase {
        case initializing
        case opening
        case waiting
        case signing
        case verifying
        case complete
        
        var icon: String {
            switch self {
            case .initializing: return "antenna.radiowaves.left.and.right"
            case .opening: return "app.connected.to.app.below.fill"
            case .waiting: return "hourglass"
            case .signing: return "signature"
            case .verifying: return "checkmark.shield"
            case .complete: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .complete: return .green
            default: return DesignTokens.Colors.primary
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Pulsing background
                Circle()
                    .fill(phase.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                
                // Main icon
                Image(systemName: phase.icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(phase.color)
                    .scaleEffect(phase == .complete ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: phase)
            }
            .onAppear {
                pulseAnimation = true
            }
            
            // Progress dots
            HStack(spacing: 12) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
        }
    }
    
    private func dotColor(for index: Int) -> Color {
        let phaseIndex = phase.index
        if index <= phaseIndex {
            return DesignTokens.Colors.primary
        } else {
            return DesignTokens.Colors.textTertiary.opacity(0.3)
        }
    }
}
```

#### Smooth State Transitions
```swift
struct WalletConnectionTransition: ViewModifier {
    let connectionState: ConnectionState
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 1.05).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: connectionState)
    }
}
```

### 1.3 Pre-flight Checks

```swift
struct WalletConnectionPreflightCheck {
    static func performChecks(for walletType: WalletType) async throws -> PreflightResult {
        var issues: [PreflightIssue] = []
        
        // Check network connectivity
        if !NetworkMonitor.shared.isConnected {
            issues.append(.noInternet)
        }
        
        // Check wallet availability
        if !isWalletInstalled(walletType) {
            issues.append(.walletNotInstalled(walletType))
        }
        
        // Check permissions (for notifications, deep links)
        if !hasRequiredPermissions() {
            issues.append(.missingPermissions)
        }
        
        // Check for pending connections
        if WalletService.shared.isConnectionInProgress {
            issues.append(.connectionInProgress)
        }
        
        return PreflightResult(issues: issues)
    }
    
    struct PreflightResult {
        let issues: [PreflightIssue]
        
        var canProceed: Bool { issues.isEmpty }
        
        var userMessage: String? {
            guard let firstIssue = issues.first else { return nil }
            
            switch firstIssue {
            case .noInternet:
                return "Please check your internet connection"
            case .walletNotInstalled(let wallet):
                return "\(wallet.displayName) app is not installed"
            case .missingPermissions:
                return "Please enable app permissions in Settings"
            case .connectionInProgress:
                return "Another connection is in progress"
            }
        }
    }
    
    enum PreflightIssue {
        case noInternet
        case walletNotInstalled(WalletType)
        case missingPermissions
        case connectionInProgress
    }
}
```

## 2. Robustness Requirements

### 2.1 Error Recovery Mechanisms

```swift
class WalletConnectionRecoveryManager {
    static let shared = WalletConnectionRecoveryManager()
    
    private var recoveryStrategies: [WalletError: RecoveryStrategy] = [:]
    
    init() {
        setupRecoveryStrategies()
    }
    
    private func setupRecoveryStrategies() {
        // Network errors: retry with exponential backoff
        recoveryStrategies[.networkError("")] = .retry(maxAttempts: 3, backoff: .exponential)
        
        // Timeout errors: offer immediate retry or switch wallet
        recoveryStrategies[.connectionFailed("timeout")] = .userChoice([
            .retry(maxAttempts: 1, backoff: .none),
            .switchWallet,
            .cancel
        ])
        
        // SDK errors: reinitialize and retry
        recoveryStrategies[.sdkNotInitialized] = .reinitialize
        
        // User cancelled: no recovery needed
        recoveryStrategies[.userCancelled] = .none
    }
    
    func recover(from error: WalletError) async throws -> RecoveryResult {
        guard let strategy = recoveryStrategies[error] else {
            return .failed(error)
        }
        
        switch strategy {
        case .retry(let maxAttempts, let backoff):
            return await retryWithBackoff(maxAttempts: maxAttempts, backoff: backoff)
            
        case .userChoice(let options):
            return await presentUserOptions(options)
            
        case .reinitialize:
            await WalletService.shared.initializeSDKsIfNeeded()
            return .retry
            
        case .none:
            return .failed(error)
        }
    }
    
    enum RecoveryStrategy {
        case retry(maxAttempts: Int, backoff: BackoffStrategy)
        case userChoice([RecoveryOption])
        case reinitialize
        case none
    }
    
    enum BackoffStrategy {
        case none
        case linear(TimeInterval)
        case exponential
    }
    
    enum RecoveryOption {
        case retry(maxAttempts: Int, backoff: BackoffStrategy)
        case switchWallet
        case cancel
    }
    
    enum RecoveryResult {
        case retry
        case switchWallet
        case cancelled
        case failed(WalletError)
    }
}
```

### 2.2 State Persistence

```swift
extension WalletConnectionManager {
    // Persist connection state across app launches
    func saveConnectionState() {
        let state = ConnectionStateSnapshot(
            walletType: connectedWallet,
            address: walletAddress,
            timestamp: Date(),
            sessionData: getSessionData()
        )
        
        do {
            let data = try JSONEncoder().encode(state)
            KeychainManager.shared.save(data, for: "wallet_connection_state")
        } catch {
            print("Failed to save connection state: \(error)")
        }
    }
    
    func restoreConnectionState() async {
        guard let data = KeychainManager.shared.load(for: "wallet_connection_state"),
              let state = try? JSONDecoder().decode(ConnectionStateSnapshot.self, from: data) else {
            return
        }
        
        // Check if state is still valid (within 24 hours)
        guard Date().timeIntervalSince(state.timestamp) < 86400 else {
            clearConnectionState()
            return
        }
        
        // Attempt to restore session
        await restoreSession(from: state)
    }
    
    struct ConnectionStateSnapshot: Codable {
        let walletType: WalletType?
        let address: String?
        let timestamp: Date
        let sessionData: Data?
    }
}
```

### 2.3 Background/Foreground Handling

```swift
extension WalletService {
    func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        // Save current state
        if isConnectionInProgress {
            saveConnectionProgress()
        }
        
        // Pause any active timers
        connectionTimeoutTask?.cancel()
    }
    
    @objc private func handleAppDidBecomeActive() {
        // Check if we're returning from wallet app
        if let progress = loadConnectionProgress() {
            resumeConnection(from: progress)
        }
        
        // Restart timers if needed
        if isConnectionInProgress {
            startConnectionTimeout(connectionId: currentConnectionId ?? "")
        }
    }
    
    private func saveConnectionProgress() {
        let progress = ConnectionProgress(
            walletType: pendingWalletType,
            stage: currentStage,
            startTime: connectionStartTime ?? Date()
        )
        
        UserDefaults.standard.set(try? JSONEncoder().encode(progress), forKey: "connection_progress")
    }
    
    private func loadConnectionProgress() -> ConnectionProgress? {
        guard let data = UserDefaults.standard.data(forKey: "connection_progress"),
              let progress = try? JSONDecoder().decode(ConnectionProgress.self, from: data) else {
            return nil
        }
        
        // Check if progress is recent (within 30 seconds)
        guard Date().timeIntervalSince(progress.startTime) < 30 else {
            UserDefaults.standard.removeObject(forKey: "connection_progress")
            return nil
        }
        
        return progress
    }
}
```

### 2.4 Network Connectivity Awareness

```swift
class NetworkAwareWalletConnection {
    private let networkMonitor = NetworkMonitor.shared
    private var networkObserver: AnyCancellable?
    
    func startNetworkAwareConnection(walletType: WalletType) async throws -> WalletConnectionResult {
        // Pre-check network
        guard networkMonitor.isConnected else {
            throw WalletError.networkError("No internet connection")
        }
        
        // Monitor network changes during connection
        var networkLostDuringConnection = false
        networkObserver = networkMonitor.$isConnected.sink { isConnected in
            if !isConnected && self.isConnecting {
                networkLostDuringConnection = true
            }
        }
        
        do {
            let result = try await performConnection(walletType: walletType)
            
            // Check if network was lost
            if networkLostDuringConnection {
                // Verify the connection is still valid
                try await verifyConnection(result)
            }
            
            return result
        } catch {
            networkObserver?.cancel()
            throw error
        }
    }
    
    private func verifyConnection(_ result: WalletConnectionResult) async throws {
        // Quick verification that connection is still valid
        // This could be a simple RPC call or signature verification
    }
}
```

## 3. Reliability Improvements

### 3.1 Connection Health Monitoring

```swift
class WalletConnectionHealthMonitor {
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 30.0
    
    func startMonitoring(for connection: WalletConnection) {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { _ in
            Task {
                await self.performHealthCheck(connection)
            }
        }
    }
    
    private func performHealthCheck(_ connection: WalletConnection) async {
        do {
            // Perform lightweight check (e.g., get latest block number)
            let isHealthy = try await connection.isHealthy()
            
            if !isHealthy {
                // Attempt to reconnect
                try await connection.reconnect()
            }
        } catch {
            // Log health check failure
            print("Health check failed: \(error)")
            
            // Notify user if multiple failures
            if consecutiveFailures > 3 {
                showConnectionIssueNotification()
            }
        }
    }
}
```

### 3.2 Automatic Retry Strategies

```swift
extension WalletConnectionManager {
    func connectWithSmartRetry(walletType: WalletType) async throws -> WalletConnectionResult {
        var lastError: Error?
        
        // Attempt 1: Normal connection
        do {
            return try await connect(walletType: walletType)
        } catch {
            lastError = error
            await handleConnectionFailure(error, attempt: 1)
        }
        
        // Attempt 2: After short delay with SDK refresh
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        do {
            await refreshSDKs()
            return try await connect(walletType: walletType)
        } catch {
            lastError = error
            await handleConnectionFailure(error, attempt: 2)
        }
        
        // Attempt 3: Deep link fallback
        if walletType.supportsDeepLinks {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            do {
                return try await connectViaDeepLink(walletType: walletType)
            } catch {
                lastError = error
            }
        }
        
        throw lastError ?? WalletError.connectionFailed("Failed after multiple attempts")
    }
    
    private func handleConnectionFailure(_ error: Error, attempt: Int) async {
        // Log error with context
        print("Connection attempt \(attempt) failed: \(error)")
        
        // Update UI with retry information
        await MainActor.run {
            self.connectionProgress = ConnectionProgress(
                stage: .initializing,
                message: "Retrying connection (attempt \(attempt + 1))...",
                progress: 0.0
            )
        }
    }
}
```

### 3.3 Clear Error Messaging

```swift
extension WalletError {
    var userFriendlyMessage: String {
        switch self {
        case .sdkNotInitialized:
            return "Wallet service is starting up. Please try again in a moment."
            
        case .connectionFailed(let details):
            if details.contains("timeout") {
                return "Connection timed out. Make sure \(currentWallet?.displayName ?? "the wallet") app is open."
            } else if details.contains("rejected") {
                return "Connection was rejected. Please approve the connection in your wallet app."
            } else {
                return "Unable to connect. Please check your wallet app and try again."
            }
            
        case .signatureFailed(let details):
            if details.contains("cancelled") {
                return "Signature was cancelled. Please try again and approve the signature."
            } else {
                return "Unable to sign message. Please try again."
            }
            
        case .noAccountsFound:
            return "No accounts found in your wallet. Please create or import an account first."
            
        case .userCancelled:
            return "Connection cancelled. Tap connect to try again."
            
        case .unsupportedWallet(let wallet):
            return "\(wallet) is not yet supported. Please choose another wallet."
            
        case .networkError(let details):
            if details.contains("offline") {
                return "You're offline. Please check your internet connection."
            } else {
                return "Network error. Please check your connection and try again."
            }
            
        case .qrCodeScanRequired:
            return "Please scan the QR code with your wallet app."
            
        case .showQRCode:
            return "Show this QR code to your wallet app."
        }
    }
    
    var recoveryAction: String? {
        switch self {
        case .sdkNotInitialized:
            return "Try Again"
        case .connectionFailed:
            return "Retry Connection"
        case .signatureFailed:
            return "Request Signature Again"
        case .noAccountsFound:
            return "Open Wallet App"
        case .userCancelled:
            return nil
        case .unsupportedWallet:
            return "Choose Different Wallet"
        case .networkError:
            return "Check Settings"
        case .qrCodeScanRequired, .showQRCode:
            return "Show QR Code"
        }
    }
}
```

### 3.4 Timeout Management

```swift
struct ConnectionTimeoutManager {
    static let quickTimeout: TimeInterval = 15.0  // For initial connection
    static let standardTimeout: TimeInterval = 30.0  // For signing
    static let extendedTimeout: TimeInterval = 60.0  // For complex operations
    
    static func timeout(for operation: WalletOperation) -> TimeInterval {
        switch operation {
        case .connect:
            return quickTimeout
        case .sign:
            return standardTimeout
        case .transaction:
            return extendedTimeout
        }
    }
    
    static func createTimeoutTask(
        duration: TimeInterval,
        warningAt: TimeInterval? = nil,
        onWarning: (() -> Void)? = nil,
        onTimeout: @escaping () -> Void
    ) -> Task<Void, Never> {
        Task {
            // Warning checkpoint
            if let warningAt = warningAt, let onWarning = onWarning {
                try? await Task.sleep(nanoseconds: UInt64(warningAt * 1_000_000_000))
                
                if !Task.isCancelled {
                    await MainActor.run {
                        onWarning()
                    }
                }
            }
            
            // Final timeout
            let remainingTime = duration - (warningAt ?? 0)
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            
            if !Task.isCancelled {
                await MainActor.run {
                    onTimeout()
                }
            }
        }
    }
}
```

## 4. Apple Design Patterns

### 4.1 Native iOS UI Components

```swift
// Use native iOS components with custom styling
struct NativeWalletConnectionSheet: View {
    @State private var selectedWallet: WalletType?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableWallets) { wallet in
                        WalletRow(wallet: wallet) {
                            selectedWallet = wallet
                        }
                    }
                } header: {
                    Text("Available Wallets")
                } footer: {
                    Text("Select a wallet to connect your crypto assets")
                }
                
                Section("Coming Soon") {
                    ForEach(comingSoonWallets) { wallet in
                        WalletRow(wallet: wallet, isDisabled: true)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedWallet) { wallet in
            WalletConnectionFlow(wallet: wallet)
        }
    }
}

struct WalletRow: View {
    let wallet: WalletType
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: isDisabled ? {} : action) {
            HStack {
                Image(wallet.iconName)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.displayName)
                        .font(.body)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    
                    if isDisabled {
                        Text("Coming Soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isDisabled)
    }
}
```

### 4.2 System Integration

```swift
// Haptic feedback patterns matching iOS system behavior
extension HapticManager {
    static func systemFeedback(_ event: SystemFeedbackEvent) {
        switch event {
        case .buttonPress:
            // Match iOS button press feedback
            impact(.light)
            
        case .toggleOn:
            // Match iOS toggle feedback
            impact(.medium)
            
        case .success:
            // Match iOS success feedback (like Face ID success)
            notification(.success)
            
        case .error:
            // Match iOS error feedback
            notification(.error)
            
        case .warning:
            // Match iOS warning feedback
            notification(.warning)
            
        case .selection:
            // Match iOS selection feedback (like in pickers)
            selection()
        }
    }
    
    enum SystemFeedbackEvent {
        case buttonPress
        case toggleOn
        case success
        case error
        case warning
        case selection
    }
}

// System sounds
struct SystemSoundManager {
    static func play(_ sound: SystemSound) {
        switch sound {
        case .connectionSuccess:
            // Play system success sound
            AudioServicesPlaySystemSound(1519) // Bloom
            
        case .connectionError:
            // Play system error sound
            AudioServicesPlaySystemSound(1053) // Error
            
        case .notification:
            // Play system notification sound
            AudioServicesPlaySystemSound(1007) // Notification
        }
    }
    
    enum SystemSound {
        case connectionSuccess
        case connectionError
        case notification
    }
}
```

### 4.3 Accessibility Support

```swift
extension WalletConnectionView {
    func accessibilitySetup() -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Wallet Connection")
            .accessibilityHint("Connect your \(walletType.displayName) wallet")
            .accessibilityAddTraits(.isModal)
    }
}

// Voice Over announcements
struct AccessibilityAnnouncer {
    static func announce(_ message: String, priority: UIAccessibility.Notification.Priority = .high) {
        UIAccessibility.post(
            notification: .announcement,
            argument: NSAttributedString(
                string: message,
                attributes: [.accessibilitySpeechQueueAnnouncement: priority]
            )
        )
    }
    
    static func announceConnectionProgress(_ stage: ConnectionStage) {
        switch stage {
        case .initializing:
            announce("Initializing wallet connection")
        case .creatingSession:
            announce("Creating secure session")
        case .waitingForApproval:
            announce("Waiting for wallet approval. Please check your wallet app.")
        case .signingMessage:
            announce("Signing authentication message")
        case .verifying:
            announce("Verifying signature")
        case .completing:
            announce("Connection successful", priority: .high)
        }
    }
}
```

### 4.4 Dark Mode Support

The current implementation already uses the DesignTokens system which should handle dark mode well. Additional enhancements:

```swift
extension DesignTokens.Colors {
    // Dynamic colors that adapt to dark/light mode
    static let walletConnectionBackground = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray6
                : UIColor.systemBackground
        }
    )
    
    static let walletConnectionBorder = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray4
                : UIColor.systemGray5
        }
    )
}
```

## Implementation Priority

1. **Phase 1 - Core Improvements (Week 1-2)**
   - Implement pre-flight checks
   - Add connection progress indicator with animations
   - Enhance haptic feedback
   - Implement smart retry logic

2. **Phase 2 - Robustness (Week 3-4)**
   - Add state persistence
   - Implement background/foreground handling
   - Add network awareness
   - Implement error recovery mechanisms

3. **Phase 3 - Polish (Week 5-6)**
   - Add health monitoring
   - Enhance error messages
   - Implement accessibility features
   - Add system sounds
   - Polish animations and transitions

## Testing Checklist

- [ ] Test with all supported wallets
- [ ] Test network interruptions during connection
- [ ] Test app backgrounding during connection
- [ ] Test with VoiceOver enabled
- [ ] Test in both light and dark modes
- [ ] Test error recovery flows
- [ ] Test on various iOS versions (iOS 16+)
- [ ] Test with poor network conditions
- [ ] Test timeout scenarios
- [ ] Test cancellation at each stage

## Success Metrics

- Connection success rate > 95%
- Average connection time < 5 seconds
- User retry rate < 10%
- Crash rate < 0.1%
- User satisfaction score > 4.5/5