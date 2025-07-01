import SwiftUI

// MARK: - Create Profile View with MPC Integration
// Example of how to use the HTTP-based MPC wallet service

/*
 NOTE: This extension is commented out temporarily as it references
 properties from CreateProfileView that are either private or don't exist.
 
 To use this functionality:
 1. Add the required @State properties to CreateProfileView
 2. Make profileName accessible (currently private)
 3. Add the navigateToProfile method
 4. Uncomment this code
 
extension CreateProfileView {
    
    /// Create profile with MPC wallet using HTTP endpoints
    @MainActor
    func createProfileWithMPCWallet() async {
        // Update UI state
        isCreatingProfile = true
        mpcGenerationState = .generating
        
        do {
            // Step 1: Create the profile
            let profile = try await profileService.createProfile(
                name: profileName,
                developmentMode: false
            )
            
            // Step 2: Generate MPC wallet using HTTP service
            let walletService = MPCServiceFactory.createWalletService()
            
            // Show MPC generation progress
            withAnimation {
                mpcGenerationState = .inProgress
                mpcProgressMessage = "Generating secure MPC wallet..."
            }
            
            // Generate wallet
            let walletInfo = try await walletService.generateWallet(for: profile.id)
            
            // Step 3: Update profile with wallet address
            try await profileService.updateProfile(
                profileId: profile.id,
                walletAddress: walletInfo.address
            )
            
            // Success
            withAnimation {
                mpcGenerationState = .completed
                mpcProgressMessage = "MPC wallet created successfully!"
                self.generatedWalletAddress = walletInfo.address
            }
            
            // Navigate to profile
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.navigateToProfile(profile)
            }
            
        } catch MPCError.biometricAuthFailed {
            showError("Biometric authentication is required to create an MPC wallet")
            mpcGenerationState = .failed
            
        } catch MPCError.keyGenerationFailed(let reason) {
            showError("Failed to generate wallet: \(reason)")
            mpcGenerationState = .failed
            
        } catch MPCError.networkTimeout {
            showError("Network timeout. Please check your connection and try again.")
            mpcGenerationState = .failed
            
        } catch {
            showError("Failed to create profile: \(error.localizedDescription)")
            mpcGenerationState = .failed
        }
        
        isCreatingProfile = false
    }
}

// MARK: - MPC Generation State

enum MPCGenerationState {
    case idle
    case generating
    case inProgress
    case completed
    case failed
}

// MARK: - MPC Progress View

struct MPCProgressView: View {
    let state: MPCGenerationState
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .idle:
                EmptyView()
                
            case .generating, .inProgress:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 48))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
                
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 48))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - MPC Wallet Info View

struct MPCWalletInfoView: View {
    let walletAddress: String
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("MPC Wallet", systemImage: "lock.shield.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(walletAddress)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button(action: copyAddress) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(isCopied ? .green : .accentColor)
                    }
                }
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Your wallet uses multi-party computation for enhanced security")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = walletAddress
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension CreateProfileView {
    static var mpcPreview: some View {
        VStack(spacing: 20) {
            MPCProgressView(state: .inProgress, message: "Generating MPC wallet...")
            
            MPCWalletInfoView(walletAddress: "0x1234567890abcdef1234567890abcdef12345678")
            
            // Test wallet service
            Button("Test MPC Wallet Generation") {
                Task {
                    do {
                        let walletService = MPCServiceFactory.createWalletService()
                        let walletInfo = try await walletService.generateWallet(for: "test-profile-id")
                        print("Generated wallet: \(walletInfo.address)")
                    } catch {
                        print("MPC generation failed: \(error)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
*/