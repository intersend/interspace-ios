import SwiftUI

struct AuthLoadingOverlay: View {
    let provider: SocialProvider
    let message: String?
    
    init(provider: SocialProvider, message: String? = nil) {
        self.provider = provider
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .blur(radius: 0.5)
            
            VStack(spacing: 20) {
                // Provider icon with loading animation
                ZStack {
                    Circle()
                        .fill(provider.color.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: provider.iconName)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(provider.color)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            provider.color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .modifier(RotatingAnimation())
                }
                
                VStack(spacing: 8) {
                    Text("Authenticating with \(provider.displayName)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let message = message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Rotating Animation Modifier
struct RotatingAnimation: ViewModifier {
    @State private var isRotating = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                isRotating ? .linear(duration: 1.5).repeatForever(autoreverses: false) : .default,
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
            .onDisappear {
                isRotating = false
            }
    }
}

// MARK: - Preview
struct AuthLoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()
            
            AuthLoadingOverlay(
                provider: .google,
                message: "Please complete authentication in your browser"
            )
        }
        .preferredColorScheme(.dark)
    }
}