import SwiftUI

struct FolderCreationPreview: View {
    let size: CGFloat
    @State private var animationPhase = 0.0
    @State private var pulseScale = 1.0
    
    var body: some View {
        ZStack {
            // Background morphing shape
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .scaleEffect(pulseScale)
            
            // Container for merging icons
            ZStack {
                // Left icon placeholder
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size * 0.35, height: size * 0.35)
                    .offset(x: -size * 0.15, y: -size * 0.15)
                    .rotationEffect(.degrees(-8))
                
                // Right icon placeholder
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: size * 0.35, height: size * 0.35)
                    .offset(x: size * 0.15, y: size * 0.15)
                    .rotationEffect(.degrees(8))
                
                // Center plus icon
                Image(systemName: "plus")
                    .font(.system(size: size * 0.25, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .scaleEffect(1.0 + animationPhase * 0.2)
                    .opacity(0.6 + animationPhase * 0.4)
            }
            .scaleEffect(0.8 + animationPhase * 0.2)
        }
        .onAppear {
            // Start pulsing animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
            
            // Start phase animation
            withAnimation(.easeInOut(duration: 0.5)) {
                animationPhase = 1.0
            }
        }
    }
}

// MARK: - Apple-style Empty Cell Highlight

struct EmptyCellHighlight: View {
    let size: CGFloat
    @State private var pulseScale = 1.0
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Soft radial gradient background
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: size * 0.2,
                endRadius: size * 0.5
            )
            .frame(width: size, height: size)
            .scaleEffect(pulseScale)
            
            // Plus icon in center
            Image(systemName: "plus")
                .font(.system(size: size * 0.3, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.3))
                .scaleEffect(pulseScale)
        }
        .opacity(opacity)
        .onAppear {
            // Fade in
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 1.0
            }
            
            // Gentle pulse
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }
}

// MARK: - Folder Creation Progress Ring

struct FolderCreationProgressRing: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 2)
                .frame(width: size * 0.9, height: size * 0.9)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.02), value: progress)
        }
    }
}