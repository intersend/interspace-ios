import SwiftUI

struct DeveloperSettingsView: View {
    @StateObject private var envConfig = EnvironmentConfiguration.shared
    @State private var showEnvironmentPicker = false
    @State private var tapCount = 0
    @State private var showTestViews = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("Developer Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Current Environment: \(envConfig.currentEnvironment.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
                
                // Environment Section
                SettingsSection(header: "ENVIRONMENT") {
                    SettingsRow(
                        icon: "server.rack",
                        iconColor: .blue,
                        title: "Environment",
                        value: envConfig.currentEnvironment.displayName,
                        action: { showEnvironmentPicker = true }
                    )
                    
                    SettingsRow(
                        icon: "link",
                        iconColor: .green,
                        title: "API Base URL",
                        subtitle: envConfig.currentEnvironment.apiBaseURL,
                        action: {}
                    )
                }
                
                // Wallet Section
                SettingsSection(header: "WALLET SETTINGS") {
                    HStack {
                        SettingsRow(
                            icon: "hammer.fill",
                            iconColor: .yellow,
                            title: "Development Wallets",
                            subtitle: "Create profiles without MPC setup",
                            showDisclosure: false
                        )
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { envConfig.isDevelopmentModeEnabled },
                            set: { _ in envConfig.toggleDevelopmentMode() }
                        ))
                        .labelsHidden()
                    }
                    
                    if envConfig.isDevelopmentModeEnabled {
                        SettingsRow(
                            icon: "info.circle",
                            iconColor: .blue,
                            title: "Note",
                            subtitle: "Development wallets are for testing only and cannot be used in production",
                            action: {}
                        )
                    }
                }
                
                // Debug Options Section
                SettingsSection(header: "DEBUG OPTIONS") {
                    HStack {
                        SettingsRow(
                            icon: "eye",
                            iconColor: .purple,
                            title: "Debug Overlay",
                            showDisclosure: false
                        )
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { envConfig.showDebugOverlay },
                            set: { _ in envConfig.toggleDebugOverlay() }
                        ))
                        .labelsHidden()
                    }
                    
                    HStack {
                        SettingsRow(
                            icon: "doc.text",
                            iconColor: .orange,
                            title: "Detailed Logging",
                            showDisclosure: false
                        )
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { envConfig.enableDetailedLogging },
                            set: { _ in envConfig.toggleDetailedLogging() }
                        ))
                        .labelsHidden()
                    }
                    
                    HStack {
                        SettingsRow(
                            icon: "theatermasks",
                            iconColor: .red,
                            title: "Mock Data",
                            showDisclosure: false
                        )
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { envConfig.enableMockData },
                            set: { _ in envConfig.toggleMockData() }
                        ))
                        .labelsHidden()
                    }
                }
                
                // Test Views Section
                SettingsSection(header: "TEST VIEWS") {
                    SettingsRow(
                        icon: "flask",
                        iconColor: .green,
                        title: "Show Test Views",
                        action: { showTestViews = true }
                    )
                }
                
                // Actions Section
                SettingsSection(header: "ACTIONS") {
                    SettingsRow(
                        icon: "trash",
                        iconColor: .red,
                        title: "Clear All Data",
                        action: clearAllData
                    )
                    
                    SettingsRow(
                        icon: "arrow.clockwise",
                        iconColor: .blue,
                        title: "Reset to Defaults",
                        action: resetToDefaults
                    )
                }
                
                // Build Info Section
                SettingsSection(header: "BUILD INFO") {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        SettingsRow(
                            icon: "info.circle",
                            iconColor: .gray,
                            title: "Version",
                            value: version,
                            action: {}
                        )
                    }
                    
                    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        SettingsRow(
                            icon: "hammer",
                            iconColor: .gray,
                            title: "Build",
                            value: build,
                            action: {}
                        )
                    }
                    
                    #if DEBUG
                    SettingsRow(
                        icon: "ladybug",
                        iconColor: .green,
                        title: "Configuration",
                        value: "Debug",
                        action: {}
                    )
                    #else
                    SettingsRow(
                        icon: "checkmark.seal",
                        iconColor: .blue,
                        title: "Configuration",
                        value: "Release",
                        action: {}
                    )
                    #endif
                }
            }
            .padding(.horizontal)
        }
        .background(Color.systemGroupedBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEnvironmentPicker) {
            EnvironmentPickerView(
                currentEnvironment: envConfig.currentEnvironment,
                onSelect: { environment in
                    envConfig.setEnvironment(environment)
                    showEnvironmentPicker = false
                }
            )
        }
        .sheet(isPresented: $showTestViews) {
            TestViewsListView()
        }
    }
    
    private func clearAllData() {
        // Clear user defaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear keychain
        KeychainManager.shared.clearAll()
        
        // Sign out
        Task {
            await AuthenticationManager.shared.signOut()
        }
    }
    
    private func resetToDefaults() {
        envConfig.setEnvironment(.development)
        envConfig.showDebugOverlay = false
        envConfig.enableDetailedLogging = false
        envConfig.enableMockData = false
    }
}

struct EnvironmentPickerView: View {
    let currentEnvironment: AppEnvironment
    let onSelect: (AppEnvironment) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppEnvironment.allCases, id: \.self) { environment in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(environment.displayName)
                                .font(.headline)
                            Text(environment.apiBaseURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if environment == currentEnvironment {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(environment)
                    }
                }
            }
            .navigationTitle("Select Environment")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct TestViewsListView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Test View", destination: TestView())
                NavigationLink("Profile Test View", destination: ProfileTestView())
                NavigationLink("Glass Effect Test View", destination: TestGlassEffectView())
            }
            .navigationTitle("Test Views")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    NavigationView {
        DeveloperSettingsView()
    }
}