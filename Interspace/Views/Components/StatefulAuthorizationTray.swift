import SwiftUI

// MARK: - Authorization State Protocol

protocol AuthorizationTrayState {
    var icon: String { get }
    var iconColor: Color { get }
    var title: String { get }
    var subtitle: String { get }
    var height: CGFloat { get }
}

// MARK: - Base Stateful Authorization Tray

struct StatefulAuthorizationTray<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color(UIColor.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // Content
            content
                .padding(.bottom, 40)
        }
        .background(Color.black.opacity(0.001))
        .background(Material.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}

// MARK: - Loading Button Component

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        color: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && isEnabled {
                HapticManager.impact(.medium)
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "\(title)..." : title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .animation(.none, value: isLoading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? color : Color.gray.opacity(0.3))
            )
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Success Checkmark Animation

struct SuccessCheckmark: View {
    @State private var animationAmount = 0.0
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 80, height: 80)
                .scaleEffect(animationAmount)
            
            Circle()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(animationAmount)
            
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.green)
                .scaleEffect(showCheckmark ? 1 : 0)
                .rotationEffect(.degrees(showCheckmark ? 0 : -30))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animationAmount = 1
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
            
            HapticManager.notification(.success)
        }
    }
}

// MARK: - Error Shake Modifier

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shake(animatableData: CGFloat) -> some View {
        self.modifier(ShakeEffect(animatableData: animatableData))
    }
}