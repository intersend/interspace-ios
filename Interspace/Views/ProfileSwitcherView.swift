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
    @State private var profilesSnapshot: [SmartProfile] = []
    
    var body: some View {
        List {
            // All profiles in a single list
            ForEach(profilesSnapshot) { profile in
                Button {
                    if !profile.isActive && !isSwitching {
                        switchToProfile(profile)
                    }
                } label: {
                    AppleStyleProfileRow(
                        profile: profile,
                        isActive: profile.isActive,
                        isSwitching: isSwitching && selectedProfile?.id == profile.id
                    )
                }
                .disabled(profile.isActive || isSwitching)
            }
            
            // Add Profile row
            Button {
                showCreateProfile = true
            } label: {
                HStack {
                    Text("Add Profile")
                        .foregroundColor(.accentColor)
                    Spacer()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showCreateProfile) {
            NavigationStack {
                AppleStyleCreateProfileView { name in
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
            profilesSnapshot = viewModel.profiles
        }
        .onChange(of: viewModel.profiles) { newProfiles in
            profilesSnapshot = newProfiles
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidDelete)) { notification in
            Task {
                if let remainingProfiles = notification.userInfo?["remainingProfiles"] as? [SmartProfile] {
                    await MainActor.run {
                        viewModel.profiles = remainingProfiles
                        profilesSnapshot = remainingProfiles
                        if let active = remainingProfiles.first(where: { $0.isActive }) {
                            viewModel.activeProfile = active
                        }
                        if remainingProfiles.isEmpty {
                            dismiss()
                        }
                    }
                } else {
                    await viewModel.loadProfiles()
                    await MainActor.run {
                        profilesSnapshot = viewModel.profiles
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidChange)) { _ in
            dismiss()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func switchToProfile(_ profile: SmartProfile) {
        guard !isSwitching else { return }
        
        selectedProfile = profile
        isSwitching = true
        
        Task {
            do {
                try await sessionCoordinator.switchProfile(profile)
                dismiss()
            } catch {
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

// MARK: - Apple Style Profile Row

struct AppleStyleProfileRow: View {
    let profile: SmartProfile
    let isActive: Bool
    let isSwitching: Bool
    
    private var initials: String {
        let words = profile.name.components(separatedBy: .whitespaces)
        let firstLetters = words.compactMap { $0.first }
        let initials = firstLetters.prefix(2).map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "?" : initials
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple initials in circle
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                )
            
            // Profile name
            Text(profile.name)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Loading or checkmark
            if isSwitching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isActive {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .opacity(isSwitching ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSwitching)
    }
}

// MARK: - Apple Style Create Profile View

struct AppleStyleCreateProfileView: View {
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
                Button("Add") {
                    if isValidName {
                        onComplete(profileName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .fontWeight(.semibold)
                .disabled(!isValidName)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFieldFocused = true
            }
        }
    }
}

// MARK: - Preview

struct ProfileSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileSwitcherView(viewModel: ProfileViewModel.shared)
                .environmentObject(SessionCoordinator.shared)
        }
    }
}