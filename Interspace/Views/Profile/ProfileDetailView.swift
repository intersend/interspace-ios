import SwiftUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Binding var isAddressHidden: Bool
    @StateObject private var viewModel = ProfileViewModel.shared
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        StandardTray(
            title: "Profile Details",
            titleDisplayMode: .inline,
            onDismiss: { dismiss() }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Information Section
                    VStack(spacing: 0) {
                        // Profile Icon and Name
                        HStack(spacing: 16) {
                            if let profile = sessionCoordinator.activeProfile {
                                ProfileIconGenerator.generateIcon(for: profile.id, size: 80)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sessionCoordinator.activeProfile?.name ?? "Profile")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Active Profile")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                
                    // Wallet Address Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WALLET ADDRESS")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        // Address Display with Apple Style Copy Button
                        if let address = sessionCoordinator.activeProfile?.sessionWalletAddress {
                            SingleLineAddressView(address: address, maxWidth: UIScreen.main.bounds.width - 120)
                                .padding(.horizontal, 20)
                        }
                        
                        // Glass background card
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }
                
                    // Privacy Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRIVACY")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide Addresses")
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Text("Hide wallet addresses throughout the app")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isAddressHidden)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.thinMaterial)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                
                    // Development Mode Section (if applicable)
                    if sessionCoordinator.activeProfile?.isDevelopmentWallet == true {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DEVELOPMENT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                            
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.yellow)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Development Mode Active")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Text("This profile is using a development wallet")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                ZStack {
                                    Rectangle()
                                        .fill(.thinMaterial)
                                    Color.yellow.opacity(0.1)
                                }
                            )
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                    }
                
                    // Delete Profile Section
                    VStack(spacing: 0) {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                Text("Delete Profile")
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.thinMaterial)
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                    }
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
            }
        }
        .standardTrayStyle()
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let profile = sessionCoordinator.activeProfile {
                    Task {
                        await handleProfileDeletion(profile)
                    }
                }
            }
        } message: {
            // Show different message based on whether this is the last profile
            if viewModel.profiles.count <= 1 {
                Text("This is your last profile. Deleting it will sign you out and you'll need to sign in again to create a new profile.\n\nAre you sure you want to continue?")
            } else {
                Text("Are you sure you want to delete this profile? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleProfileDeletion(_ profile: SmartProfile) async {
        // Check if this is the last profile
        let isLastProfile = viewModel.profiles.count <= 1
        
        // Delete the profile
        await viewModel.deleteProfile(profile)
        
        // If it was the last profile, the session coordinator will handle sign out
        // Otherwise, it should have switched to another profile
        if !isLastProfile {
            // Add a small delay to ensure the profile switch completes smoothly
            // This prevents UI glitches from dismissing the sheet too early
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Dismiss the sheet after successful deletion and profile switch
            dismiss()
        }
        // If it's the last profile, SessionCoordinator will handle the sign out
        // and navigation back to auth screen
    }
}

// MARK: - Preview

struct ProfileDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileDetailView(isAddressHidden: .constant(false))
            .environmentObject(SessionCoordinator.shared)
            .preferredColorScheme(.dark)
    }
}