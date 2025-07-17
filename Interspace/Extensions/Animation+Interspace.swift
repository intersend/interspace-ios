import SwiftUI

// MARK: - Apple-style Animation Extensions

extension Animation {
    /// Smooth spring animation for profile transitions
    static var profileTransition: Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }
    
    /// Quick fade for loading states
    static var quickFade: Animation {
        .easeInOut(duration: 0.2)
    }
    
    /// Smooth interaction feedback
    static var smoothInteraction: Animation {
        .easeInOut(duration: 0.3)
    }
    
    /// Bouncy success animation
    static var successBounce: Animation {
        .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    }
    
    /// Gentle error shake
    static var errorShake: Animation {
        .default.repeatCount(2, autoreverses: true).speed(3)
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Smooth scale and opacity transition
    static var scaleOpacity: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }
    
    /// Profile card transition
    static var profileCard: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    /// Slide and fade from bottom
    static var slideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }
    
    /// Quick fade for overlays
    static var quickFade: AnyTransition {
        .opacity.animation(.quickFade)
    }
}

// MARK: - View Extensions for Animations

extension View {
    /// Add smooth interaction feedback
    func interactionFeedback() -> some View {
        self
            .scaleEffect(1.0)
            .onTapGesture { }
            .pressEvents { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.scaleEffect(pressing ? 0.95 : 1.0)
                }
            }
    }
    
    /// Add subtle bounce on appear
    func bounceOnAppear(delay: Double = 0) -> some View {
        self
            .scaleEffect(1.0)
            .onAppear {
                withAnimation(.successBounce.delay(delay)) {
                    // Trigger re-render
                }
            }
    }
    
    /// Add error shake animation
    func shakeOnError(_ shouldShake: Bool) -> some View {
        self
            .offset(x: shouldShake ? -5 : 0)
            .animation(shouldShake ? .errorShake : .default, value: shouldShake)
    }
}

// MARK: - Custom Button Press Handler

struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void = {}, onRelease: @escaping () -> Void = {}, _ handler: @escaping (Bool) -> Void) -> some View {
        self.modifier(PressActions(onPress: {
            handler(true)
            onPress()
        }, onRelease: {
            handler(false)
            onRelease()
        }))
    }
}