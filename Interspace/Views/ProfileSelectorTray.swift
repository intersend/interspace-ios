import SwiftUI

struct ProfileSelectorTray: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    
    @State private var selectedProfileId: String?
    @State private var showCreateProfile = false
    @State private var newProfileName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid glass background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                VStack(spacing: 0) {
                    // Handle bar
                    Capsule()
                        .fill(Color.systemGray3)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    // Title
                    HStack {
                        Text("Switch Profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.label)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.systemGray3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Profiles Grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            // Existing profiles
                            ForEach(viewModel.profiles) { profile in
                                ProfileTrayCard(
                                    profile: profile,
                                    isActive: profile.isActive,
                                    isSelected: selectedProfileId == profile.id
                                ) {
                                    handleProfileSelection(profile)
                                }
                            }
                            
                            // Add new profile card
                            AddProfileTrayCard {
                                showCreateProfile = true
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.7)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
            .presentationDetents([.height(UIScreen.main.bounds.height * 0.7)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .interactiveDismissDisabled(false)
        }
        .alert("Create New Profile", isPresented: $showCreateProfile) {
            TextField("Profile Name", text: $newProfileName)
            Button("Cancel", role: .cancel) {
                newProfileName = ""
            }
            Button("Create") {
                Task {
                    await viewModel.createProfile(name: newProfileName)
                    newProfileName = ""
                }
            }
        }
    }
    
    private func handleProfileSelection(_ profile: SmartProfile) {
        guard !profile.isActive else { return }
        
        selectedProfileId = profile.id
        
        Task {
            do {
                try await sessionCoordinator.switchProfile(profile)
                
                // Dismiss after successful switch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } catch {
                // Handle error - reset selection state
                await MainActor.run {
                    selectedProfileId = nil
                }
                print("Failed to switch profile: \(error)")
            }
        }
    }
}

// MARK: - Profile Card
struct ProfileTrayCard: View {
    let profile: SmartProfile
    let isActive: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile Icon
            ZStack(alignment: .topTrailing) {
                ProfileIconGenerator.generateIcon(for: profile.id, size: 80)
                
                if isActive {
                    Circle()
                        .fill(Color.systemGreen)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 8, y: -8)
                }
            }
            
            // Profile Info
            VStack(spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.label)
                    .lineLimit(1)
                
                Text("\(profile.linkedAccountsCount) wallets")
                    .font(.caption)
                    .foregroundColor(.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isActive ? Color.systemBlue.opacity(0.15) : Color.systemGray6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isActive ? Color.systemBlue.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .overlay(
            // Selection animation
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.systemBlue, lineWidth: 3)
                .opacity(isSelected ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            if !isActive {
                action()
            }
        }
    }
}

// MARK: - Add Profile Card
struct AddProfileTrayCard: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Plus Icon
            ZStack {
                Circle()
                    .fill(Color.systemGray5)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.systemGray2)
            }
            
            // Text
            VStack(spacing: 4) {
                Text("New Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.label)
                
                Text("Create")
                    .font(.caption)
                    .foregroundColor(.systemBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.systemGray6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundColor(.systemGray3)
                )
        )
        .onTapGesture(perform: action)
    }
}

// MARK: - Preview
struct ProfileSelectorTray_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSelectorTray(viewModel: ProfileViewModel.shared)
            .environmentObject(SessionCoordinator.shared)
    }
}