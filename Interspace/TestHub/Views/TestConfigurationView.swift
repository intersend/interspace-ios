import SwiftUI

struct TestConfigurationView: View {
    @Binding var configuration: TestConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // API Settings
                Section("API Settings") {
                    Toggle("Use Production API", isOn: $configuration.useProductionAPI)
                    
                    HStack {
                        Text("API Version")
                        Spacer()
                        Text(configuration.apiVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Base URL")
                        Spacer()
                        Text(configuration.baseURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Test Settings
                Section("Test Settings") {
                    Toggle("Enable Detailed Logging", isOn: $configuration.enableDetailedLogging)
                    
                    Toggle("Auto Run on Launch", isOn: $configuration.autoRunOnLaunch)
                    
                    HStack {
                        Text("Test Timeout")
                        Spacer()
                        Text("\(Int(configuration.testTimeout))s")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Test Credentials
                Section("Test Credentials") {
                    HStack {
                        Text("Test Email")
                        Spacer()
                        TextField("Email", text: $configuration.testEmail)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(maxWidth: 200)
                    }
                    
                    HStack {
                        Text("Test Wallet")
                        Spacer()
                        Text(String(configuration.testWalletAddress.prefix(10)) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions
                Section {
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Test Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Reset Configuration", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                configuration = TestConfiguration()
            }
        } message: {
            Text("This will reset all configuration settings to their default values.")
        }
    }
}