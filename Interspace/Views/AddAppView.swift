import SwiftUI

struct AddAppView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppsViewModel
    
    @State private var appName = ""
    @State private var appUrl = ""
    @State private var isAddingApp = false
    @FocusState private var focusedField: Field?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum Field {
        case name, url
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color(UIColor.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // Content
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primary.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 30))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("Add New App")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Bookmark your favorite Web3 app")
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Form Fields
                VStack(spacing: 20) {
                    // App Name
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("App Name", text: $appName)
                            .textFieldStyle(NativeTextFieldStyle())
                            .focused($focusedField, equals: .name)
                            .autocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit {
                                focusedField = .url
                            }
                        
                        if !appName.isEmpty && appName.count < 2 {
                            Text("Name must be at least 2 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // App URL
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("https://app.example.com", text: $appUrl)
                            .textFieldStyle(NativeTextFieldStyle())
                            .focused($focusedField, equals: .url)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit {
                                if isFormValid {
                                    addApp()
                                }
                            }
                            .onChange(of: appUrl) { _, newValue in
                                // Auto-generate app name from URL if name is empty
                                if appName.isEmpty, let url = URL(string: newValue) {
                                    appName = url.host?.replacingOccurrences(of: "www.", with: "").capitalized ?? ""
                                }
                            }
                        
                        if !appUrl.isEmpty && !isValidURL {
                            Text("Please enter a valid URL")
                                .font(.caption)
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Continue button
                Button(action: addApp) {
                    HStack {
                        if isAddingApp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isAddingApp ? "Adding..." : "Continue")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFormValid ? DesignTokens.Colors.primary : Color.gray.opacity(0.3))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
                }
                .disabled(!isFormValid || isAddingApp)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .presentationDetents([.height(440)])
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidURL: Bool {
        URL(string: appUrl) != nil && appUrl.hasPrefix("http")
    }
    
    private var isFormValid: Bool {
        !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        appName.count >= 2 &&
        !appUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidURL
    }
    
    // MARK: - Methods
    
    private func addApp() {
        guard isFormValid else { return }
        
        isAddingApp = true
        HapticManager.impact(.medium)
        
        // Dismiss keyboard
        focusedField = nil
        
        Task {
            do {
                // Get active profile
                let profiles = try await ProfileAPI.shared.getProfiles()
                guard let activeProfile = profiles.first(where: { $0.isActive }) else {
                    await MainActor.run {
                        errorMessage = "No active profile found"
                        showingError = true
                        isAddingApp = false
                    }
                    return
                }
                
                let request = CreateAppRequest(
                    name: appName.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: appUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                    iconUrl: nil,
                    folderId: nil,
                    position: 0
                )
                
                // Create the app
                let createdApp = try await ProfileAPI.shared.createApp(profileId: activeProfile.id, request: request)
                print("📱 AddAppView: Successfully created app: \(createdApp.name) with id: \(createdApp.id)")
                
                // Reload apps
                await viewModel.loadApps()
                
                // Success feedback
                await MainActor.run {
                    HapticManager.notification(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add app: \(error.localizedDescription)"
                    showingError = true
                    isAddingApp = false
                    HapticManager.notification(.error)
                }
            }
        }
    }
}

// MARK: - Preview

struct AddAppView_Previews: PreviewProvider {
    static var previews: some View {
        AddAppView(viewModel: AppsViewModel())
            .preferredColorScheme(.dark)
    }
}