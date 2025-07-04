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
    
    // Sorted profiles with active profile first
    private var sortedProfiles: [SmartProfile] {
        viewModel.profiles.sorted { profile1, profile2 in
            // Active profile always comes first
            if profile1.isActive { return true }
            if profile2.isActive { return false }
            
            // Then sort by last updated date (most recent first)
            let dateFormatter = ISO8601DateFormatter()
            if let date1 = dateFormatter.date(from: profile1.updatedAt),
               let date2 = dateFormatter.date(from: profile2.updatedAt) {
                return date1 > date2
            }
            
            // Fallback to string comparison if date parsing fails
            return profile1.updatedAt > profile2.updatedAt
        }
    }
    
    var body: some View {
        List {
            // Active Profile Section
            if let activeProfile = sessionCoordinator.activeProfile {
                Section {
                    NativeActiveProfileRow(profile: activeProfile)
                } header: {
                    Text("CURRENT PROFILE")
                }
            }
            
            // Other Profiles Section
            let otherProfiles = sortedProfiles.filter { !$0.isActive }
            if !otherProfiles.isEmpty {
                Section {
                    ForEach(otherProfiles) { profile in
                        Button {
                            if !isSwitching {
                                switchToProfile(profile)
                            }
                        } label: {
                            NativeProfileRow(
                                profile: profile,
                                isSwitching: isSwitching && selectedProfile?.id == profile.id
                            )
                        }
                        .disabled(isSwitching)
                    }
                } header: {
                    Text("OTHER PROFILES")
                }
            }
            
            // Actions Section
            Section {
                Button {
                    showCreateProfile = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.tint)
                        
                        Text("Create New Profile")
                            .foregroundStyle(Color.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profiles")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showCreateProfile) {
            NavigationStack {
                NativeCreateProfileView { name in
                    Task {
                        await viewModel.createProfile(name: name)
                        showCreateProfile = false
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadProfiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidDelete)) { notification in
            Task {
                print("🔄 ProfileSwitcherView: Received profile deletion notification, refreshing...")
                
                // If we have the remaining profiles in the notification, use them directly
                if let remainingProfiles = notification.userInfo?["remainingProfiles"] as? [SmartProfile] {
                    await MainActor.run {
                        viewModel.profiles = remainingProfiles
                        // Update active profile if needed
                        if let active = remainingProfiles.first(where: { $0.isActive }) {
                            viewModel.activeProfile = active
                        }
                        
                        // If no profiles remain or if the deleted profile was shown in this view, dismiss
                        if remainingProfiles.isEmpty {
                            dismiss()
                        }
                    }
                } else {
                    // Fallback to loading from API (bypasses cache)
                    await viewModel.loadProfiles()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidChange)) { notification in
            // Dismiss the profile switcher when a profile change happens
            // This ensures smooth transition after profile deletion
            print("🔄 ProfileSwitcherView: Profile changed, dismissing...")
            dismiss()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

// MARK: - Native Active Profile Row

struct NativeActiveProfileRow: View {
    let profile: SmartProfile
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Icon with Checkmark
            ZStack(alignment: .bottomTrailing) {
                ProfileIconGenerator.generateIcon(for: profile.id, size: 44)
                    .clipShape(Circle())
                
                // Active checkmark badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, Color.accentColor)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .systemBackground))
                            .frame(width: 20, height: 20)
                    )
                    .offset(x: 4, y: 4)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if profile.isDevelopmentWallet == true {
                        Text("DEV")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.yellow, in: Capsule())
                    }
                }
                
                HStack(spacing: 15) {
                    Label {
                        Text("\(profile.linkedAccountsCount) wallets")
                    } icon: {
                        Image(systemName: "wallet.pass")
                    }
                    
                    Label {
                        Text("\(profile.appsCount) apps")
                    } icon: {
                        Image(systemName: "square.stack.3d.up")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Native Profile Row

struct NativeProfileRow: View {
    let profile: SmartProfile
    let isSwitching: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Icon
            ProfileIconGenerator.generateIcon(for: profile.id, size: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.separator.opacity(0.2), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if profile.isDevelopmentWallet == true {
                        Text("DEV")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.yellow, in: Capsule())
                    }
                }
                
                HStack(spacing: 15) {
                    if let lastUpdated = ISO8601DateFormatter().date(from: profile.updatedAt) {
                        Text(lastUpdatedText(lastUpdated))
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "wallet.pass")
                        Text("\(profile.linkedAccountsCount)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up")
                        Text("\(profile.appsCount)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isSwitching {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isSwitching ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSwitching)
    }
    
    private func lastUpdatedText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Native Create Profile View

struct NativeCreateProfileView: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var profileName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    private var isValidName: Bool {
        !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Profile Name", text: $profileName)
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if isValidName {
                            onComplete(profileName.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
            } header: {
                Text("NAME")
            } footer: {
                Text("Choose a descriptive name for your profile, like \"Work\", \"Gaming\", or \"Personal\".")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileFeatureRow(
                        icon: "person.2.fill",
                        title: "Separate Identities",
                        description: "Keep different aspects of your digital life organized"
                    )
                    
                    ProfileFeatureRow(
                        icon: "lock.shield.fill",
                        title: "Enhanced Privacy",
                        description: "Isolate activities between profiles"
                    )
                    
                    ProfileFeatureRow(
                        icon: "apps.iphone",
                        title: "App Management",
                        description: "Different apps and settings for each profile"
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("WHAT ARE PROFILES?")
            }
        }
        .navigationTitle("New Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    if isValidName {
                        onComplete(profileName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .fontWeight(.semibold)
                .disabled(!isValidName)
            }
        }
        .onAppear {
            // Delay focus to ensure keyboard appears smoothly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isNameFieldFocused = true
            }
        }
    }
}

// MARK: - Feature Row

private struct ProfileFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
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
