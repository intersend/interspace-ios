import SwiftUI
import AuthenticationServices

struct PasskeyLinkingView: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    
    @EnvironmentObject var authManager: AuthenticationManagerV2
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        // Passkey Icon
                        Image(systemName: "key.badge.shield.fill")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 40)
                        
                        Text("Add Passkey")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Create a new passkey for secure access to your profile")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Info box
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Multiple Passkeys")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white)
                                
                                Text("You can create multiple passkeys for different devices or browsers")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.15))
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Create Passkey Button
                        Button(action: createPasskey) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 20, weight: .medium))
                                    Text("Create Passkey")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading)
                        
                        // Cancel button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.body.weight(.medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createPasskey() {
        guard !isLoading else { return }
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                // Register a new passkey for the current profile
                _ = try await PasskeyService.shared.registerPasskeyForLinking()
                
                // Refresh linked accounts
                await profileViewModel.loadLinkedAccounts()
                
                // Success haptic feedback
                HapticManager.notification(.success)
                
                // Call success handler and close
                await MainActor.run {
                    onSuccess()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.notification(.error)
                }
                
                print("🔑 Passkey linking error: \(error)")
            }
        }
    }
}