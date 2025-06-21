import SwiftUI

struct DebugOverlay: View {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    @State private var lastAPICall: String = "None"
    @State private var apiCallCount: Int = 0
    
    var body: some View {
        if envConfig.showDebugOverlay && envConfig.isDevelopmentModeEnabled {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.green)
                    Text("DEBUG")
                        .font(.caption.bold())
                    Spacer()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Env: \(envConfig.currentEnvironment.displayName)")
                        .font(.caption2)
                    Text("API Calls: \(apiCallCount)")
                        .font(.caption2)
                    Text("Mock Data: \(envConfig.enableMockData ? "ON" : "OFF")")
                        .font(.caption2)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
            )
            .foregroundColor(.white)
            .frame(maxWidth: 150)
            .position(x: UIScreen.main.bounds.width - 85, y: 100)
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: .apiCallMade)) { _ in
                apiCallCount += 1
            }
        }
    }
}

extension Notification.Name {
    static let apiCallMade = Notification.Name("com.interspace.apiCallMade")
}

// View modifier to easily add debug overlay
struct DebugOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                DebugOverlay()
            }
    }
}

extension View {
    func debugOverlay() -> some View {
        modifier(DebugOverlayModifier())
    }
}