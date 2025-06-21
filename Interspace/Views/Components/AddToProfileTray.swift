import SwiftUI

// MARK: - Add To Profile Tray
struct AddToProfileTray: View {
    @Binding var isPresented: Bool
    let onSelectProfile: (SmartProfile) -> Void
    
    @State private var profiles: [SmartProfile] = []
    @State private var isLoading = true
    @State private var selectedProfileId: String?
    @State private var dragOffset: CGFloat = 0
    
    private let profileAPI = ProfileAPI.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTray()
                }
            
            // Tray content
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(DesignTokens.Colors.textTertiary)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                // Header
                VStack(spacing: 8) {
                    Text("Add to Profile")
                        .font(DesignTokens.Typography.headlineMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Choose which profile to add this app to")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .padding(.bottom, 24)
                
                // Profiles list
                if isLoading {
                    LoadingProfilesView()
                        .frame(height: 200)
                } else if profiles.isEmpty {
                    EmptyProfilesView()
                        .frame(height: 200)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(profiles) { profile in
                                ProfileSelectionCard(
                                    profile: profile,
                                    isSelected: selectedProfileId == profile.id,
                                    onTap: {
                                        selectProfile(profile)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 400)
                }
                
                // Bottom safe area
                Color.clear
                    .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
            }
            .background(
                VisualEffectBlur(blurStyle: .systemMaterialDark)
                    .overlay(Color.black.opacity(0.1))
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .path(in: CGRect(x: 0, y: -20, width: UIScreen.main.bounds.width, height: 1000))
            )
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismissTray()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
        .onAppear {
            loadProfiles()
        }
    }
    
    private func loadProfiles() {
        Task {
            do {
                let fetchedProfiles = try await profileAPI.getProfiles()
                await MainActor.run {
                    profiles = fetchedProfiles.sorted { profile1, profile2 in
                        if profile1.isActive { return true }
                        if profile2.isActive { return false }
                        return profile1.name < profile2.name
                    }
                    isLoading = false
                }
            } catch {
                print("Failed to load profiles: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func selectProfile(_ profile: SmartProfile) {
        HapticManager.impact(.medium)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedProfileId = profile.id
        }
        
        // Delay to show selection animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSelectProfile(profile)
            dismissTray()
        }
    }
    
    private func dismissTray() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Profile Selection Card
private struct ProfileSelectionCard: View {
    let profile: SmartProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.GlassEffect.thin)
                        .frame(width: 48, height: 48)
                    
                    Text(profile.name.prefix(1).uppercased())
                        .font(DesignTokens.Typography.headlineSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                
                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile.name)
                            .font(DesignTokens.Typography.bodyLarge)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        if profile.isActive {
                            Text("Active")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignTokens.Colors.success.opacity(0.2))
                                )
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(profile.appsCount)", systemImage: "square.grid.3x3")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        Label("\(profile.linkedAccountsCount)", systemImage: "link")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Colors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignTokens.GlassEffect.regular : DesignTokens.GlassEffect.ultraThin)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? DesignTokens.Colors.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Loading Profiles View
private struct LoadingProfilesView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.textSecondary))
                .scaleEffect(1.2)
            
            Text("Loading profiles...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }
}

// MARK: - Empty Profiles View
private struct EmptyProfilesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            
            Text("No profiles found")
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            Text("Create a profile first to add apps")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }
}