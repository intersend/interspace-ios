import SwiftUI

struct ProfileCreationLoadingView: View {
    @State private var isAnimating = false
    @State private var progress: CGFloat = 0
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Soft background - no harsh overlays
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
                .opacity(opacity)
            
            VStack(spacing: 24) {
                // Minimalist loading indicator
                if !showCheckmark {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.5)
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.green)
                        .frame(width: 60, height: 60)
                        .transition(.scale.combined(with: .opacity))
                }
                
                VStack(spacing: 4) {
                    Text(showCheckmark ? "All set!" : "One moment")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if !showCheckmark {
                        Text("Setting up your space")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                }
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Fade in smoothly
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 1.0
            scale = 1.0
        }
        
        // Show success after profile is created (coordinated with SessionCoordinator timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completeAnimation()
        }
    }
    
    private func completeAnimation() {
        // Show checkmark with subtle animation
        withAnimation(.easeInOut(duration: 0.3)) {
            showCheckmark = true
        }
        
        // Light haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Auto-dismiss quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 0
                scale = 0.95
            }
            
            // Notify completion after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onComplete()
            }
        }
    }
}

// MARK: - Preview
struct ProfileCreationLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileCreationLoadingView {
            print("Animation complete")
        }
    }
}