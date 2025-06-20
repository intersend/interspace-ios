import SwiftUI

// MARK: - Development Mode Modifier

struct DevelopmentModeModifier: ViewModifier {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    let content: () -> AnyView
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            
            #if DEBUG
            if envConfig.currentEnvironment == .development {
                self.content()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
    }
}

// MARK: - View Extension

extension View {
    func developmentMode<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(DevelopmentModeModifier(content: {
            AnyView(content())
        }))
    }
}

// MARK: - Development Mode Container

struct DevelopmentModeContainer<Content: View>: View {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    let content: () -> Content
    
    var body: some View {
        #if DEBUG
        if envConfig.currentEnvironment == .development {
            content()
                .transition(.opacity.combined(with: .scale))
        }
        #endif
    }
}

// MARK: - Development Toggle with State

struct StatefulDevelopmentToggle: View {
    @State private var isEnabled: Bool
    let label: String
    let key: String
    let onChange: (Bool) -> Void
    
    init(label: String, key: String, defaultValue: Bool = false, onChange: @escaping (Bool) -> Void = { _ in }) {
        self.label = label
        self.key = key
        self.onChange = onChange
        _isEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "dev.\(key)") || defaultValue)
    }
    
    var body: some View {
        DevelopmentToggle(isEnabled: $isEnabled, label: label)
            .onChange(of: isEnabled) { newValue in
                UserDefaults.standard.set(newValue, forKey: "dev.\(key)")
                onChange(newValue)
            }
    }
}

// MARK: - Preview

struct DevelopmentModeModifier_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Main Content")
                .developmentMode {
                    StatefulDevelopmentToggle(
                        label: "Enable Feature",
                        key: "feature.enabled"
                    )
                    .padding()
                }
            
            DevelopmentModeContainer {
                VStack {
                    StatefulDevelopmentToggle(
                        label: "Auto Login",
                        key: "auto.login"
                    )
                    
                    StatefulDevelopmentToggle(
                        label: "Show Debug Info",
                        key: "debug.info"
                    )
                }
                .padding()
            }
        }
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}