import SwiftUI

struct DevelopmentToggle: View {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    @Binding var isEnabled: Bool
    let label: String
    var isCompact: Bool = false
    
    var body: some View {
        #if DEBUG
        if envConfig.currentEnvironment == .development {
            if isCompact {
                // Compact version for toolbar
                Toggle(isOn: $isEnabled) {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.circle.fill")
                            .font(.system(size: 16))
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.yellow.opacity(0.8))
                }
                .toggleStyle(SwitchToggleStyle(tint: .yellow.opacity(0.8)))
                .scaleEffect(0.9)
            } else {
                // Full version
                HStack {
                    Toggle(isOn: $isEnabled) {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow.opacity(0.8))
                            
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .yellow.opacity(0.8)))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        #endif
    }
}

// MARK: - Development Mode Badge

struct DevelopmentModeBadge: View {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    
    var body: some View {
        #if DEBUG
        if envConfig.currentEnvironment == .development {
            HStack(spacing: 4) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 10))
                Text("DEV")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.yellow)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        #endif
    }
}

// MARK: - Preview

struct DevelopmentToggle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            DevelopmentToggle(isEnabled: .constant(false), label: "Auto-fill Code")
                .padding()
            
            DevelopmentModeBadge()
                .padding()
        }
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}