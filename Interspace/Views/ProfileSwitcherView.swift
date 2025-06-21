import SwiftUI

struct ProfileSwitcherView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: SmartProfile?
    @State private var showCreateProfile = false
    @State private var isSwitching = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ZStack {
                // iOS 26 Liquid Glass background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Current Profile Header
                        currentProfileHeader
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        // Other Profiles Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("OTHER PROFILES")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.profiles.filter { !$0.isActive }) { profile in
                                    ProfileSwitcherRow(
                                        profile: profile,
                                        isSwitching: isSwitching && selectedProfile?.id == profile.id,
                                        namespace: animation
                                    ) {
                                        switchToProfile(profile)
                                    }
                                }
                                
                                // Create New Profile Button
                                CreateNewProfileButton {
                                    showCreateProfile = true
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 32)
                        
                        // Bottom Padding
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color(white: 0.15))
                            )
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileView { name in
                Task {
                    await viewModel.createProfile(name: name)
                    showCreateProfile = false
                }
            }
        }
        .task {
            await viewModel.loadProfiles()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Current Profile Header
    
    private var currentProfileHeader: some View {
        VStack(spacing: 16) {
            Text("CURRENT PROFILE")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let activeProfile = sessionCoordinator.activeProfile {
                HStack(spacing: 16) {
                    // Profile Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 72, height: 72)
                        ProfileIconGenerator.generateIcon(for: activeProfile.id, size: 72)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Profile Name
                        HStack {
                            Text(activeProfile.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if activeProfile.isDevelopmentWallet == true {
                                Text("DEV")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.yellow)
                                    )
                            }
                        }
                        
                        // Stats
                        HStack(spacing: 12) {
                            Label("\(activeProfile.linkedAccountsCount)", systemImage: "wallet.pass")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Label("\(activeProfile.appsCount)", systemImage: "app.badge")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Active Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Switch Profile
    
    private func switchToProfile(_ profile: SmartProfile) {
        print("🔄 ProfileSwitcherView: switchToProfile called for profile: \(profile.name)")
        
        guard !isSwitching else { 
            print("🔄 ProfileSwitcherView: Already switching, returning")
            return 
        }
        
        selectedProfile = profile
        isSwitching = true
        
        Task {
            do {
                print("🔄 ProfileSwitcherView: Starting profile switch...")
                
                // Add haptic feedback
                HapticManager.impact(.medium)
                
                // Perform the switch
                try await sessionCoordinator.switchProfile(profile)
                
                print("🔄 ProfileSwitcherView: Profile switch successful")
                
                // Small delay for animation
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Dismiss the view only on success
                dismiss()
            } catch {
                print("🔄 ProfileSwitcherView: Profile switch failed with error: \(error)")
                
                // Handle error
                await MainActor.run {
                    errorMessage = "Failed to switch profile: \(error.localizedDescription)"
                    showError = true
                    isSwitching = false
                    selectedProfile = nil
                }
            }
        }
    }
}

// MARK: - Profile Switcher Row

struct ProfileSwitcherRow: View {
    let profile: SmartProfile
    let isSwitching: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Icon
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 60, height: 60)
                ProfileIconGenerator.generateIcon(for: profile.id, size: 60)
            }
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                // Profile Name
                HStack {
                    Text(profile.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if profile.isDevelopmentWallet == true {
                        Text("DEV")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.yellow)
                            )
                    }
                }
                
                // Stats
                HStack(spacing: 8) {
                    Label("\(profile.linkedAccountsCount)", systemImage: "wallet.pass")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Label("\(profile.appsCount)", systemImage: "app.badge")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Loading/Chevron
            if isSwitching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .contentShape(Rectangle()) // Add content shape to ensure tap area
        .onTapGesture {
            print("🔄 ProfileSwitcherRow: Tap detected for profile: \(profile.name)")
            if !isSwitching {
                print("🔄 ProfileSwitcherRow: Calling action...")
                action()
            } else {
                print("🔄 ProfileSwitcherRow: Already switching, ignoring tap")
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .disabled(isSwitching)
        .opacity(isSwitching ? 0.7 : 1.0)
    }
}

// MARK: - Create New Profile Button

struct CreateNewProfileButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Plus Icon
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Create New Profile")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text("Add a new profile for different use cases")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.blue)
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(.blue.opacity(0.5))
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            action()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Create Profile View

struct CreateProfileView: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var profileName = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Create New Profile")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Separate your activities with different profiles")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROFILE NAME")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("e.g., Trading, Gaming, Personal", text: $profileName)
                            .font(.body)
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .focused($isFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Create Button
                    Button(action: {
                        onComplete(profileName)
                        dismiss()
                    }) {
                        Text("Create Profile")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview

struct ProfileSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSwitcherView(viewModel: ProfileViewModel.shared)
            .environmentObject(SessionCoordinator.shared)
            .preferredColorScheme(.dark)
    }
}