import SwiftUI

// MARK: - Wiggle Animation Modifier

struct WiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var rotation: Double = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var isAnimating = false
    
    // Random parameters for each icon - matching iOS behavior
    private let baseRotation = Double.random(in: 2.5...3.0) * (Bool.random() ? 1 : -1)
    private let verticalBounce = Double.random(in: 0.8...1.2)
    private let horizontalBounce = Double.random(in: 0.3...0.5)
    private let animationDelay = Double.random(in: 0...0.15)
    private let rotationDuration = Double.random(in: 0.12...0.14)
    private let bounceDuration = Double.random(in: 0.13...0.15)
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation), anchor: .center)
            .offset(x: horizontalOffset, y: verticalOffset)
            .scaleEffect(isAnimating ? 1.0 : 0.98)
            .onAppear {
                if isActive {
                    startWiggle()
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    startWiggle()
                } else {
                    stopWiggle()
                }
            }
    }
    
    private func startWiggle() {
        // Smooth scale-in animation
        withAnimation(.easeOut(duration: 0.15)) {
            isAnimating = true
        }
        
        // Delay the wiggle start for organic feel
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
            guard isActive else { return }
            
            // Rotation animation - alternating left and right
            withAnimation(
                Animation
                    .easeInOut(duration: rotationDuration)
                    .repeatForever(autoreverses: true)
            ) {
                rotation = baseRotation
            }
            
            // Vertical bounce - slightly offset from rotation for realism
            withAnimation(
                Animation
                    .easeInOut(duration: bounceDuration)
                    .repeatForever(autoreverses: true)
                    .delay(0.05)
            ) {
                verticalOffset = verticalBounce
            }
            
            // Subtle horizontal movement
            withAnimation(
                Animation
                    .easeInOut(duration: bounceDuration * 1.1)
                    .repeatForever(autoreverses: true)
                    .delay(0.1)
            ) {
                horizontalOffset = horizontalBounce * (baseRotation > 0 ? -1 : 1)
            }
        }
    }
    
    private func stopWiggle() {
        // Smooth transition back to rest state
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            rotation = 0
            verticalOffset = 0
            horizontalOffset = 0
            isAnimating = false
        }
    }
}

// MARK: - Edit Mode Plus Button

struct EditModePlusButton: View {
    let iconSize: CGFloat
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                HapticManager.impact(.medium)
                onTap()
            }) {
                ZStack {
                    // Circle background like profile plus button
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: iconSize, height: iconSize)
                    
                    Image(systemName: "plus")
                        .font(.system(size: iconSize * 0.5, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onLongPressGesture(
                minimumDuration: .infinity,
                maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                },
                perform: {}
            )
            
            // Empty space for consistent height with app icons
            Color.clear
                .frame(height: 28)
        }
    }
}

// MARK: - Edit Mode Toolbar

struct EditModeToolbar: View {
    @Binding var isEditMode: Bool
    let onDone: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            Button("Done") {
                HapticManager.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditMode = false
                }
                onDone()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(white: 0.2))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

// MARK: - View Extensions

extension View {
    func wiggle(isActive: Bool) -> some View {
        modifier(WiggleModifier(isActive: isActive))
    }
    
    func editModeScale(_ isEditMode: Bool) -> some View {
        self
            .scaleEffect(isEditMode ? 0.93 : 1.0)
            .animation(
                .spring(
                    response: 0.35,
                    dampingFraction: 0.75,
                    blendDuration: 0.15
                ),
                value: isEditMode
            )
    }
}