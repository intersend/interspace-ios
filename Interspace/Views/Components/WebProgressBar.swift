import SwiftUI

// MARK: - Web Progress Bar
struct WebProgressBar: View {
    let progress: Double
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Progress bar
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * animatedProgress)
                    .animation(.linear(duration: 0.15), value: animatedProgress)
                
                // Subtle glow at the end
                if animatedProgress > 0 && animatedProgress < 1 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.blue.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)
                        .blur(radius: 3)
                        .offset(x: max(0, geometry.size.width * animatedProgress - 10))
                        .animation(.linear(duration: 0.15), value: animatedProgress)
                }
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newValue in
            animatedProgress = newValue
        }
    }
}