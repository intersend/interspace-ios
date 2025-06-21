import SwiftUI
import GoogleSignIn

struct GoogleSignInTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var testResult: String = "Ready to test Google Sign-In"
    @State private var testStatus: TestStatus = .ready
    @State private var configuration: String = ""
    @State private var errorDetails: String = ""
    
    enum TestStatus {
        case ready
        case testing
        case success
        case failure
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status Indicator
                        statusIndicator
                        
                        // Configuration Info
                        configurationSection
                        
                        // Test Results
                        testResultsSection
                        
                        // Test Button
                        testButton
                        
                        // Error Details
                        if !errorDetails.isEmpty {
                            errorDetailsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Google Sign-In Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
        .onAppear {
            checkConfiguration()
        }
    }
    
    private var statusIndicator: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
//            LiquidGlassCard {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text(configuration)
//                        .font(.system(.caption, design: .monospaced))
//                        .foregroundColor(DesignTokens.Colors.textSecondary)
//                }
//                .padding()
//            }
        }
    }
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            
//            LiquidGlassCard {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text(testResult)
//                        .font(.system(.body, design: .monospaced))
//                        .foregroundColor(DesignTokens.Colors.textSecondary)
//                        .multilineTextAlignment(.leading)
//                }
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//            }
        }
    }
    
    private var testButton: some View {
        Button(action: runTest) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Run Google Sign-In Test")
                }
            }
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignTokens.Colors.primary)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
    
    private var errorDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Details")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.error)
            
//            LiquidGlassCard {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text(errorDetails)
//                        .font(.system(.caption, design: .monospaced))
//                        .foregroundColor(DesignTokens.Colors.error)
//                        .multilineTextAlignment(.leading)
//                }
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//            }
        }
    }
    
    private var statusColor: Color {
        switch testStatus {
        case .ready:
            return DesignTokens.Colors.primary
        case .testing:
            return DesignTokens.Colors.warning
        case .success:
            return DesignTokens.Colors.success
        case .failure:
            return DesignTokens.Colors.error
        }
    }
    
    private var statusIcon: String {
        switch testStatus {
        case .ready:
            return "questionmark.circle.fill"
        case .testing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch testStatus {
        case .ready:
            return "Ready to Test"
        case .testing:
            return "Testing..."
        case .success:
            return "Test Passed"
        case .failure:
            return "Test Failed"
        }
    }
    
    private func checkConfiguration() {
        var configInfo = "📱 Google Sign-In Configuration:\n"
        
        // Check GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            configInfo += "✅ GoogleService-Info.plist found\n"
            configInfo += "✅ Client ID: \(clientId.prefix(20))...\n"
        } else {
            configInfo += "❌ GoogleService-Info.plist not found\n"
        }
        
        // Check GIDSignIn configuration
        if let config = GIDSignIn.sharedInstance.configuration {
            configInfo += "✅ GIDSignIn configured\n"
            if let serverClientId = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
               !serverClientId.isEmpty,
               !serverClientId.contains("YOUR_") {
                configInfo += "✅ Server client ID configured\n"
            } else {
                configInfo += "⚠️ Server client ID not configured\n"
            }
        } else {
            configInfo += "❌ GIDSignIn not configured\n"
        }
        
        configuration = configInfo
    }
    
    private func runTest() {
        isLoading = true
        testStatus = .testing
        testResult = "Starting Google Sign-In test...\n"
        errorDetails = ""
        
        Task {
            do {
                testResult += "1️⃣ Attempting to sign in...\n"
                
                let result = try await GoogleSignInService.shared.signIn()
                
                testResult += "2️⃣ Sign-in successful!\n"
                testResult += "📧 Email: \(result.email)\n"
                testResult += "👤 Name: \(result.name ?? "N/A")\n"
                testResult += "🆔 User ID: \(result.userId)\n"
                testResult += "🔑 ID Token: \(result.idToken != nil ? "Available" : "Not available")\n"
                
                if result.idToken != nil {
                    testResult += "\n3️⃣ ID Token retrieved successfully\n"
                    testResult += "✅ Ready for backend authentication\n"
                } else {
                    testResult += "\n⚠️ No ID Token available\n"
                    testResult += "Backend authentication may fail\n"
                }
                
                testStatus = .success
                
                // Sign out after test
                GoogleSignInService.shared.signOut()
                testResult += "\n4️⃣ Signed out successfully"
                
            } catch {
                testStatus = .failure
                testResult += "\n❌ Test failed: \(error.localizedDescription)\n"
                
                // Detailed error information
                errorDetails = "Error Type: \(type(of: error))\n"
                errorDetails += "Description: \(error.localizedDescription)\n"
                
                if let nsError = error as NSError? {
                    errorDetails += "Domain: \(nsError.domain)\n"
                    errorDetails += "Code: \(nsError.code)\n"
                    if let userInfo = nsError.userInfo as? [String: Any] {
                        errorDetails += "User Info: \(userInfo)\n"
                    }
                }
            }
            
            isLoading = false
        }
    }
}

#if DEBUG
struct GoogleSignInTestView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInTestView()
    }
}
#endif
