import SwiftUI

/// A beautiful, Apple-like connection progress view with smooth animations
struct ConnectionProgressView: View {
    @ObservedObject var connectionManager = WalletConnectionManager.shared
    @State private var ringAnimation = false
    @State private var pulseAnimation = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var errorShake = 0
    
    let walletType: WalletType
    let onCancel: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        DesignTokens.Colors.backgroundTertiary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressValue)
                
                // Pulse effect when waiting
                if shouldShowPulse {
                    Circle()
                        .stroke(progressColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                // Center content
                centerContent
                    .frame(width: 80, height: 80)
            }
            .overlay(
                // Rotating dots for active connection
                rotatingDots
                    .opacity(isConnecting ? 1 : 0)
            )
            
            // Status text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .modifier(ShakeEffect(animatableData: CGFloat(errorShake)))
            
            // Action buttons
            actionButtons
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(DesignTokens.Colors.backgroundPrimary)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .padding(.horizontal, 20)
        .onAppear {
            startAnimations()
        }
        .onChange(of: connectionManager.connectionState) { _ in
            handleStateChange()
        }
    }
    
    // MARK: - Computed Properties
    
    private var progressValue: CGFloat {
        guard let progress = connectionManager.connectionProgress else { return 0 }
        return progress.progress
    }
    
    private var progressColor: Color {
        switch connectionManager.connectionState {
        case .connected:
            return .green
        case .failed:
            return .red
        case .timeout:
            return .orange
        default:
            return walletType.primaryColor
        }
    }
    
    private var shouldShowPulse: Bool {
        if case .connecting = connectionManager.connectionState {
            return connectionManager.connectionProgress?.stage == .waitingForApproval
        }
        return false
    }
    
    private var isConnecting: Bool {
        if case .connecting = connectionManager.connectionState {
            return true
        }
        return false
    }
    
    @ViewBuilder
    private var centerContent: some View {
        switch connectionManager.connectionState {
        case .connected:
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.green)
                .scaleEffect(checkmarkScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: checkmarkScale)
            
        case .failed, .timeout:
            Image(systemName: connectionManager.connectionState == .timeout ? "clock.badge.xmark" : "xmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(connectionManager.connectionState == .timeout ? .orange : .red)
            
        default:
            // Wallet icon
            if let walletIcon = UIImage(named: walletType.icon) {
                Image(uiImage: walletIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            } else {
                Image(systemName: walletType.systemIconName)
                    .font(.system(size: 40))
                    .foregroundColor(walletType.primaryColor)
            }
        }
    }
    
    @ViewBuilder
    private var rotatingDots: some View {
        ForEach(0..<3) { index in
            Circle()
                .fill(walletType.primaryColor)
                .frame(width: 8, height: 8)
                .offset(y: -70)
                .rotationEffect(.degrees(Double(index) * 120 + (ringAnimation ? 360 : 0)))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: ringAnimation
                )
        }
    }
    
    private var statusTitle: String {
        switch connectionManager.connectionState {
        case .idle:
            return "Ready to Connect"
        case .connecting:
            return connectionManager.connectionProgress?.stage.title ?? "Connecting..."
        case .connected:
            return "Connected!"
        case .failed(let error):
            return "Connection Failed"
        case .timeout:
            return "Connection Timed Out"
        }
    }
    
    private var statusMessage: String {
        if let progress = connectionManager.connectionProgress {
            return progress.message
        }
        
        switch connectionManager.connectionState {
        case .idle:
            return "Tap connect to start"
        case .failed(let error):
            return error.localizedDescription
        case .timeout:
            return "The wallet didn't respond in time. Make sure \(walletType.displayName) is open."
        case .connected(_, let address):
            return "Wallet: \(address.prefix(6))...\(address.suffix(4))"
        default:
            return ""
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 16) {
            switch connectionManager.connectionState {
            case .connecting:
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DesignTokens.Colors.backgroundSecondary)
                        )
                }
                
            case .failed, .timeout:
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(walletType.primaryColor)
                        )
                }
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(DesignTokens.Colors.backgroundSecondary)
                        )
                }
                
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Methods
    
    private func startAnimations() {
        withAnimation {
            ringAnimation = true
            pulseAnimation = true
        }
    }
    
    private func handleStateChange() {
        switch connectionManager.connectionState {
        case .connected:
            // Success animation
            withAnimation(.spring()) {
                checkmarkScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring()) {
                    checkmarkScale = 1.0
                }
            }
            // Success haptic
            HapticManager.notification(.success)
            
        case .failed:
            // Error shake animation
            withAnimation(.default) {
                errorShake = 3
            }
            // Error haptic
            HapticManager.notification(.error)
            
        case .timeout:
            // Warning haptic
            HapticManager.notification(.warning)
            
        default:
            break
        }
    }
}

// MARK: - Supporting Types

extension WalletConnectionManager.ConnectionStage {
    var title: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .creatingSession:
            return "Creating Session"
        case .waitingForApproval:
            return "Waiting for Approval"
        case .signingMessage:
            return "Signing Message"
        case .verifying:
            return "Verifying"
        case .completing:
            return "Almost Done"
        }
    }
}

// MARK: - Shake Effect
// ShakeEffect is already defined in StatefulAuthorizationTray.swift

// MARK: - Preview

struct ConnectionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ConnectionProgressView(
                walletType: .rainbow,
                onCancel: {},
                onRetry: {}
            )
        }
        .background(Color.gray.opacity(0.1))
    }
}