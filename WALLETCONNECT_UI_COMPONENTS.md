# Apple-Style Wallet Connection UI Components

## Ready-to-Use SwiftUI Components for Native iOS Feel

### 1. Native iOS Wallet Selection Sheet

```swift
// WalletSelectionSheet.swift
import SwiftUI

struct WalletSelectionSheet: View {
    @Binding var isPresented: Bool
    let onWalletSelected: (WalletType) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: WalletCategory = .all
    @Environment(\.dismiss) private var dismiss
    
    enum WalletCategory: String, CaseIterable {
        case all = "All"
        case popular = "Popular"
        case hardware = "Hardware"
        case mobile = "Mobile"
        
        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .popular: return "star"
            case .hardware: return "cpu"
            case .mobile: return "iphone"
            }
        }
    }
    
    var filteredWallets: [WalletType] {
        let wallets = WalletType.allCases.filter { $0 != .unknown }
        
        return wallets.filter { wallet in
            // Category filter
            let matchesCategory: Bool = {
                switch selectedCategory {
                case .all: return true
                case .popular: return wallet.isPopular
                case .hardware: return wallet.isHardware
                case .mobile: return wallet.isMobile
                }
            }()
            
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                wallet.displayName.localizedCaseInsensitiveContains(searchText)
            
            return matchesCategory && matchesSearch
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(WalletCategory.allCases, id: \.self) { category in
                            CategoryPill(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedCategory = category
                                }
                                HapticManager.selection()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                Divider()
                
                // Wallet List
                List {
                    ForEach(filteredWallets, id: \.self) { wallet in
                        WalletListRow(wallet: wallet) {
                            HapticManager.impact(.light)
                            onWalletSelected(wallet)
                            dismiss()
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search wallets")
            }
            .navigationTitle("Select Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryPill: View {
    let category: WalletSelectionSheet.WalletCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(category.rawValue, systemImage: category.systemImage)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? DesignTokens.Colors.primary : DesignTokens.Colors.fillTertiary)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : DesignTokens.Colors.borderPrimary,
                            lineWidth: 1
                        )
                )
        }
    }
}

struct WalletListRow: View {
    let wallet: WalletType
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Wallet Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(wallet.primaryColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(wallet.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                
                // Wallet Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.displayName)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    HStack(spacing: 8) {
                        if wallet.isPopular {
                            Label("Popular", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if wallet.isRecommended {
                            Label("Recommended", systemImage: "hand.thumbsup.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Status
                if isInstalled(wallet) {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .labelStyle(.iconOnly)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
    
    private func isInstalled(_ wallet: WalletType) -> Bool {
        // Check if wallet app is installed
        WalletService.shared.isWalletInstalled(wallet)
    }
}
```

### 2. Apple-Style Connection Progress View

```swift
// AppleStyleConnectionProgress.swift
import SwiftUI

struct AppleStyleConnectionProgress: View {
    let walletType: WalletType
    @Binding var connectionState: ConnectionState
    
    @State private var ringProgress: CGFloat = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        DesignTokens.Colors.fillTertiary,
                        lineWidth: 8
                    )
                    .frame(width: 140, height: 140)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                walletType.primaryColor,
                                walletType.primaryColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round
                        )
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: ringProgress)
                
                // Center content
                ZStack {
                    // Wallet icon
                    Image(walletType.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .scaleEffect(iconScale)
                        .opacity(showCheckmark ? 0 : 1)
                    
                    // Success checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.green)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showCheckmark)
            }
            
            // Status Text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(statusMessage)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            // Action Hint
            if showActionHint {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 20))
                    
                    Text("Open \(walletType.displayName) to continue")
                        .font(.callout)
                }
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.fillTertiary)
                )
            }
        }
        .onChange(of: connectionState) { newState in
            updateProgress(for: newState)
        }
        .onAppear {
            startPulseAnimation()
        }
    }
    
    private var statusTitle: String {
        switch connectionState {
        case .idle:
            return "Ready to Connect"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected!"
        case .failed:
            return "Connection Failed"
        case .timeout:
            return "Connection Timed Out"
        default:
            return ""
        }
    }
    
    private var statusMessage: String {
        switch connectionState {
        case .idle:
            return "Tap connect to link your \(walletType.displayName)"
        case .connecting:
            return "Opening secure connection"
        case .connected:
            return "Successfully connected to \(walletType.displayName)"
        case .failed(let error):
            return error.userFriendlyMessage
        case .timeout:
            return "The connection took too long. Please try again."
        default:
            return ""
        }
    }
    
    private var showActionHint: Bool {
        if case .connecting = connectionState {
            return true
        }
        return false
    }
    
    private func updateProgress(for state: ConnectionState) {
        switch state {
        case .idle:
            ringProgress = 0
            showCheckmark = false
        case .connecting:
            ringProgress = 0.7
            startPulseAnimation()
        case .connected:
            ringProgress = 1.0
            showCheckmark = true
            HapticManager.notification(.success)
        case .failed, .timeout:
            ringProgress = 0
            showCheckmark = false
            HapticManager.notification(.error)
        default:
            break
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            iconScale = 1.1
        }
    }
}
```

### 3. iOS-Native Error Alert

```swift
// NativeErrorAlert.swift
struct NativeErrorAlert: ViewModifier {
    @Binding var error: WalletError?
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Connection Issue",
                isPresented: .constant(error != nil),
                presenting: error
            ) { error in
                // Actions
                if let recoveryAction = error.recoveryAction {
                    Button(recoveryAction) {
                        HapticManager.impact(.light)
                        onRetry()
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    self.error = nil
                    onDismiss()
                }
            } message: { error in
                VStack {
                    Text(error.userFriendlyMessage)
                    
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension WalletError {
    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed(let details) where details.contains("timeout"):
            return "Make sure \(WalletService.shared.connectedWallet?.displayName ?? "the wallet") app is open and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .sdkNotInitialized:
            return "The app is still loading. Please wait a moment."
        default:
            return nil
        }
    }
}
```

### 4. Smooth Success Animation

```swift
// ConnectionSuccessView.swift
struct ConnectionSuccessView: View {
    let walletType: WalletType
    let address: String
    let onComplete: () -> Void
    
    @State private var showContent = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var addressOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            // Success Checkmark with Animation
            ZStack {
                // Circular background
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(checkmarkScale)
            }
            
            // Success Text
            VStack(spacing: 12) {
                Text("Successfully Connected!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                // Wallet Info
                HStack(spacing: 8) {
                    Image(walletType.iconName)
                        .resizable()
                        .frame(width: 24, height: 24)
                    
                    Text(walletType.displayName)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                // Address
                Text(formatAddress(address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .opacity(addressOpacity)
            }
            
            // Continue Button
            Button(action: onComplete) {
                Text("Continue")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignTokens.Colors.primary)
                    .cornerRadius(DesignTokens.CornerRadius.button)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
        }
        .padding()
        .onAppear {
            animateSuccess()
        }
    }
    
    private func animateSuccess() {
        // Stage 1: Show background
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = true
        }
        
        // Stage 2: Checkmark spring animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
            checkmarkScale = 1.0
        }
        
        // Stage 3: Fade in address
        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            addressOpacity = 1.0
        }
        
        // Haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.notification(.success)
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
}
```

### 5. Interactive Wallet Connection Button

```swift
// InteractiveWalletButton.swift
struct InteractiveWalletButton: View {
    let walletType: WalletType
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var showRipple = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button)
                    .fill(
                        LinearGradient(
                            colors: [
                                walletType.primaryColor,
                                walletType.primaryColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Ripple effect
                if showRipple {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .scaleEffect(showRipple ? 3 : 0)
                        .opacity(showRipple ? 0 : 1)
                }
                
                // Content
                HStack(spacing: 12) {
                    Image(walletType.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                    
                    Text("Connect \(walletType.displayName)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
                
                if pressing {
                    // Trigger ripple
                    withAnimation(.easeOut(duration: 0.6)) {
                        showRipple = true
                    }
                    
                    // Reset ripple
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showRipple = false
                    }
                }
            },
            perform: {}
        )
    }
}
```

### 6. Usage Example

```swift
// Example implementation in WalletConnectionView
struct EnhancedWalletConnectionView: View {
    @State private var showWalletSelection = false
    @State private var selectedWallet: WalletType?
    @State private var connectionState: ConnectionState = .idle
    @State private var error: WalletError?
    
    var body: some View {
        NavigationStack {
            VStack {
                if let wallet = selectedWallet {
                    // Show connection progress
                    AppleStyleConnectionProgress(
                        walletType: wallet,
                        connectionState: $connectionState
                    )
                    
                    if connectionState == .idle {
                        InteractiveWalletButton(walletType: wallet) {
                            connectWallet()
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    // Show wallet selection
                    Button("Select Wallet") {
                        showWalletSelection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showWalletSelection) {
                WalletSelectionSheet(isPresented: $showWalletSelection) { wallet in
                    selectedWallet = wallet
                    showWalletSelection = false
                }
            }
            .modifier(NativeErrorAlert(
                error: $error,
                onRetry: { connectWallet() },
                onDismiss: { connectionState = .idle }
            ))
        }
    }
    
    private func connectWallet() {
        // Connection logic here
    }
}
```

These components provide an Apple-native feel with smooth animations, proper haptic feedback, and iOS-standard design patterns. They can be immediately integrated into the existing codebase to enhance the wallet connection experience.