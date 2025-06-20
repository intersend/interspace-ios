import SwiftUI

struct ProfileCreationTray: View {
    @Binding var isPresented: Bool
    let onComplete: (String) -> Void
    
    @State private var profileName = ""
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool
    
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
                    
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("Name Your Profile")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text("Give your profile a memorable name")
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(NativeTextFieldStyle())
                        .focused($isNameFocused)
                        .autocorrectionDisabled()
                        .onSubmit {
                            if isFormValid {
                                createProfile()
                            }
                        }
                    
                    if !profileName.isEmpty && profileName.count < 3 {
                        Text("Name must be at least 3 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                
                // Continue button
                Button(action: createProfile) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isCreating ? "Creating..." : "Continue")
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
                .disabled(!isFormValid || isCreating)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .presentationDetents([.height(360)])
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
    
    private var isFormValid: Bool {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
    
    private func createProfile() {
        guard isFormValid else { return }
        
        isCreating = true
        HapticManager.impact(.medium)
        
        // Dismiss keyboard
        isNameFocused = false
        
        // Add a small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(profileName.trimmingCharacters(in: .whitespacesAndNewlines))
            isPresented = false
        }
    }
}

// MARK: - Native Text Field Style

struct NativeTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
            )
            .font(.system(size: 17))
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }
}

// MARK: - Preview

struct ProfileCreationTray_Previews: PreviewProvider {
    static var previews: some View {
        ProfileCreationTray(isPresented: .constant(true)) { name in
            print("Profile name: \(name)")
        }
        .preferredColorScheme(.dark)
    }
}