import SwiftUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Binding var isAddressHidden: Bool
    private let viewModel = ProfileViewModel.shared
    @State private var showDeleteConfirmation = false
    @State private var deletedProfileId: String?
    
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
        .onReceive(NotificationCenter.default.publisher(for: .profileDidDelete)) { notification in
            // Check if this was the profile we deleted
            if let profileId = notification.userInfo?["profileId"] as? String,
               profileId == deletedProfileId {
                // Profile deletion is complete, dismiss the view
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            // If session ends (last profile was deleted), dismiss
            dismiss()
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleProfileDeletion(_ profile: SmartProfile) async {
        // Store the profile ID we're deleting
        deletedProfileId = profile.id
        
        // Delete the profile
        await viewModel.deleteProfile(profile)
        
        // Don't dismiss here - wait for the notification that deletion is complete
        // The notification handler will dismiss after profile switching or sign out completes
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

