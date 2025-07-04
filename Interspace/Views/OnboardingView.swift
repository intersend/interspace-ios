import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @EnvironmentObject var authManager: AuthenticationManagerV2
    
    @State private var profileName = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(DesignTokens.Colors.primary)
                        .padding(.top, 60)
                    
                    Text("Create Your First Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Profiles help you organize your apps and wallets")
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
                
                // Form
                VStack(spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Profile Name")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        TextField("Enter profile name", text: $profileName)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // Create Button
                    Button(action: createProfile) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Create Profile")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignTokens.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Footer info
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Text("Your authentication account will be automatically linked to this profile")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
            
            // Loading overlay
            if isCreating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProfile() {
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                // Create the profile
                // The backend automatically links the auth account to the first profile
                await viewModel.createProfile(name: trimmedName)
                
                // The profile creation already triggers MPC generation if needed
                // and switches to the new profile
                
                // Reload the session to transition to authenticated state
                await sessionCoordinator.loadUserSession()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
    
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(SessionCoordinator.shared)
            .environmentObject(AuthenticationManagerV2.shared)
    }
}
