import SwiftUI

// MARK: - Glass Progress Bar
struct GlassProgressBar: View {
    let progress: Double
    
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                
                // Progress fill with glass effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 50)
                        .offset(x: geometry.size.width * shimmerOffset)
                        .allowsHitTesting(false)
                    )
                    .clipShape(Rectangle())
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: shimmerOffset)
            }
        }
        .onAppear {
            shimmerOffset = 2
        }
    }
}