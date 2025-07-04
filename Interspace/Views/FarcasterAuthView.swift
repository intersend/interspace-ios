import SwiftUI

struct FarcasterAuthView: View {
    @Binding var isPresented: Bool
    let onSuccess: (FarcasterAuthService.FarcasterAuthResponse) -> Void
    
    @StateObject private var farcasterAuth = FarcasterAuthService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = true
    @State private var hasOpenedWarpcast = false
    @Environment(\.scenePhase) var scenePhase
    
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
                    .onAppear {
                        print("FarcasterAuthView: Showing loading state")
                    }
                } else if let qrCode = farcasterAuth.qrCodeImage {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: farcasterAuth.isWarpcastInstalled ? "arrow.up.forward.app" : "qrcode")
                                    .font(.system(size: 48))
                                    .foregroundColor(DesignTokens.Colors.farcaster)
                                
                                Text("Sign in with Farcaster")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                
                                Text(farcasterAuth.isWarpcastInstalled 
                                    ? "Tap the button below to open Warpcast"
                                    : "Scan with Warpcast or tap the button below")
                                    .font(.body)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            
                            // Show Open Warpcast button first if app is installed
                            if farcasterAuth.isWarpcastInstalled {
                                // Open Warpcast Button (prominent when app is installed)
                                Button(action: {
                                    hasOpenedWarpcast = true
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
                                
                                Text("or scan the QR code below")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                            }
                            
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
                            .frame(width: farcasterAuth.isWarpcastInstalled ? 250 : 300, 
                                   height: farcasterAuth.isWarpcastInstalled ? 250 : 300)
                            
                            // Show Open Warpcast button below QR if app is not installed
                            if !farcasterAuth.isWarpcastInstalled {
                                Button(action: {
                                    hasOpenedWarpcast = true
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
                            }
                            
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
        .onChange(of: scenePhase) { newPhase in
            // When app comes back to foreground after opening Warpcast
            if newPhase == .active && hasOpenedWarpcast && farcasterAuth.isAuthenticating {
                // Show a subtle animation or feedback that we're still waiting
                HapticManager.impact(.light)
            }
        }
    }
    
    private func startAuthentication() async {
        do {
            // First create the auth channel to display QR code
            _ = try await farcasterAuth.createAuthChannel()
            
            // Once channel is created, hide loading and show QR code
            await MainActor.run {
                isLoading = false
                
                // Automatically open Warpcast if installed
                if farcasterAuth.isWarpcastInstalled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hasOpenedWarpcast = true
                        farcasterAuth.openWarpcast()
                    }
                }
            }
            
            // Now wait for the user to scan and complete authentication
            let authResponse = try await farcasterAuth.pollForCompletion()
            
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