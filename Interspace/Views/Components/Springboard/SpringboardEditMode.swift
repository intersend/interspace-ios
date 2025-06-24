import SwiftUI

// MARK: - Wiggle Animation Modifier

struct WiggleModifier: ViewModifier {
    let isActive: Bool
    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0
    
    // Random parameters for each icon
    private let rotationAngle = Double.random(in: -2.3...2.3)
    private let verticalBounce = Double.random(in: -1.5...1.5)
    private let animationDelay = Double.random(in: 0...0.2)
    private let animationDuration = 0.125
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? rotation : 0))
            .offset(y: isActive ? offset : 0)
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
        withAnimation(
            Animation
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
                .delay(animationDelay)
        ) {
            rotation = rotationAngle
            offset = verticalBounce
        }
    }
    
    private func stopWiggle() {
        withAnimation(.easeOut(duration: 0.2)) {
            rotation = 0
            offset = 0
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
        self.scaleEffect(isEditMode ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditMode)
    }
}