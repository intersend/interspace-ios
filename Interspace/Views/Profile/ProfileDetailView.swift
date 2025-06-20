import SwiftUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    @Binding var isAddressHidden: Bool
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Information Section
                Section {
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
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                }
                
                // Wallet Address Section
                Section(header: Text("WALLET ADDRESS")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)) {
                    
                    // Address Display
                    VStack(alignment: .leading, spacing: 12) {
                        Text(sessionCoordinator.activeProfile?.sessionWalletAddress ?? "")
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                        
                        // Copy Button
                        Button(action: {
                            UIPasteboard.general.string = sessionCoordinator.activeProfile?.sessionWalletAddress
                            HapticManager.notification(.success)
                        }) {
                            Label("Copy Address", systemImage: "doc.on.doc")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                
                // Privacy Settings Section
                Section(header: Text("PRIVACY")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)) {
                    
                    Toggle(isOn: $isAddressHidden) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide Addresses")
                                .font(.body)
                                .foregroundColor(.white)
                            
                            Text("Hide wallet addresses throughout the app")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                
                // Development Mode Section (if applicable)
                if sessionCoordinator.activeProfile?.isDevelopmentWallet == true {
                    Section(header: Text("DEVELOPMENT")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)) {
                        
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
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.yellow.opacity(0.15))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Profile Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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