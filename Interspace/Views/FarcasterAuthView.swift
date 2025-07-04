import SwiftUI

struct FarcasterAuthView: View {
    @Binding var isPresented: Bool
    let onSuccess: (FarcasterAuthService.FarcasterAuthResponse) -> Void
    
    @StateObject private var farcasterAuth = FarcasterAuthService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 20)
                        
                        Text("Setting up Farcaster authentication...")
                            .font(.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                } else if let qrCode = farcasterAuth.qrCodeImage {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 48))
                                    .foregroundColor(DesignTokens.Colors.farcaster)
                                
                                Text("Sign in with Farcaster")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text("Scan with Warpcast or tap the button below")
                                    .font(.body)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            
                            // QR Code
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .shadow(radius: 10, y: 5)
                                
                                Image(uiImage: qrCode)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(20)
                            }
                            .frame(width: 300, height: 300)
                            
                            // Open Warpcast Button
                            Button(action: {
                                farcasterAuth.openWarpcast()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Open Warpcast")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(DesignTokens.Colors.farcaster)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 20)
                            
                            // Instructions
                            VStack(alignment: .leading, spacing: 16) {
                                Text("How to sign in:")
                                    .font(.headline)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                InstructionRow(number: "1", text: "Open Warpcast on your phone")
                                InstructionRow(number: "2", text: "Scan the QR code or tap the button")
                                InstructionRow(number: "3", text: "Approve the sign-in request")
                                InstructionRow(number: "4", text: "You'll be signed in automatically")
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                            )
                            .padding(.horizontal, 20)
                            
                            // Waiting indicator
                            if farcasterAuth.isAuthenticating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Waiting for approval...")
                                        .font(.subheadline)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                }
                                .padding()
                            }
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        farcasterAuth.cleanup()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .background(Circle().fill(DesignTokens.Colors.backgroundSecondary))
                    }
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await startAuthentication()
        }
    }
    
    private func startAuthentication() async {
        do {
            let authResponse = try await farcasterAuth.startAuthentication()
            
            await MainActor.run {
                HapticManager.notification(.success)
                onSuccess(authResponse)
                isPresented = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.notification(.error)
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.farcaster.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.farcaster)
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Design Token Extension

extension DesignTokens.Colors {
    static let farcaster = Color(red: 133/255, green: 93/255, blue: 205/255) // Farcaster purple
}