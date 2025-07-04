import Foundation
import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// Service to handle Farcaster authentication using Sign In with Ethereum (SIWE)
class FarcasterAuthService: ObservableObject {
    static let shared = FarcasterAuthService()
    
    @Published var isAuthenticating = false
    @Published var authChannel: FarcasterAuthChannel?
    @Published var qrCodeImage: UIImage?
    @Published var isWarpcastInstalled = false
    
    private var pollTimer: Timer?
    private let authAPI = AuthAPI.shared
    
    private init() {
        checkWarpcastInstallation()
    }
    
    struct FarcasterAuthChannel {
        let channelToken: String
        let url: String
        let nonce: String
        let domain: String
        let siweUri: String
        let expiresAt: Date
        let deepLink: String
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    struct FarcasterAuthResponse {
        let signature: String
        let message: String
        let fid: String
        let username: String?
        let displayName: String?
        let bio: String?
        let pfpUrl: String?
    }
    
    // MARK: - Channel Creation
    
    /// Create a new authentication channel with the backend
    func createAuthChannel() async throws -> FarcasterAuthChannel {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.interspace.ios"
        print("Creating Farcaster auth channel with domain: \(bundleId)")
        
        let response = try await authAPI.createFarcasterChannel(
            domain: bundleId,
            siweUri: "https://interspace.so"
        )
        
        guard let channel = response.channel else {
            print("FarcasterAuthService: No channel in response")
            throw AuthenticationError.unknown("Invalid channel response - no channel data")
        }
        
        print("FarcasterAuthService: Got channel with token: \(channel.channelToken)")
        print("FarcasterAuthService: Channel URL: \(channel.url)")
        print("FarcasterAuthService: Channel expires at: \(channel.expiresAt)")
        
        // Create formatter that handles milliseconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let expiresAt = formatter.date(from: channel.expiresAt) else {
            // Fallback to standard formatter without fractional seconds
            let standardFormatter = ISO8601DateFormatter()
            guard let expiresAt = standardFormatter.date(from: channel.expiresAt) else {
                print("FarcasterAuthService: Failed to parse date: \(channel.expiresAt)")
                throw AuthenticationError.unknown("Invalid channel response - date parsing failed")
            }
            print("FarcasterAuthService: Parsed date with standard formatter")
            return createAuthChannel(from: channel, expiresAt: expiresAt)
        }
        
        print("FarcasterAuthService: Parsed date with milliseconds formatter")
        
        return createAuthChannel(from: channel, expiresAt: expiresAt)
    }
    
    private func createAuthChannel(from channel: FarcasterChannelResponse.FarcasterChannel, expiresAt: Date) -> FarcasterAuthChannel {
        // Create deep link for Warpcast - use the web URL for QR code
        let deepLink = "https://warpcast.com/~/sign-in?channelToken=\(channel.channelToken)"
        
        let authChannel = FarcasterAuthChannel(
            channelToken: channel.channelToken,
            url: channel.url,
            nonce: channel.nonce,
            domain: channel.domain,
            siweUri: channel.siweUri,
            expiresAt: expiresAt,
            deepLink: deepLink
        )
        
        DispatchQueue.main.async {
            self.authChannel = authChannel
            self.generateQRCode(for: deepLink)
            self.checkWarpcastInstallation()
        }
        
        return authChannel
    }
    
    // MARK: - QR Code Generation
    
    private func generateQRCode(for string: String) {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        
        if let outputImage = filter.outputImage {
            // Scale the image
            let scaleX = 300 / outputImage.extent.size.width
            let scaleY = 300 / outputImage.extent.size.height
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                DispatchQueue.main.async {
                    self.qrCodeImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
    
    // MARK: - Authentication Flow
    
    /// Start the Farcaster authentication flow
    func startAuthentication() async throws -> FarcasterAuthResponse {
        isAuthenticating = true
        
        do {
            // Create auth channel
            let channel = try await createAuthChannel()
            
            // Start polling for signature
            let authResponse = try await pollForSignature(channelToken: channel.channelToken)
            
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.stopPolling()
            }
            
            return authResponse
        } catch {
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.stopPolling()
            }
            throw error
        }
    }
    
    // MARK: - Polling
    
    /// Poll for completion after channel is created
    func pollForCompletion() async throws -> FarcasterAuthResponse {
        guard let channel = authChannel else {
            throw AuthenticationError.unknown("No auth channel available")
        }
        
        return try await pollForSignature(channelToken: channel.channelToken)
    }
    
    private func pollForSignature(channelToken: String) async throws -> FarcasterAuthResponse {
        let maxAttempts = 120 // 2 minutes with 1 second intervals
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            // Check channel status
            let response = try await authAPI.checkFarcasterChannel(
                channelToken: channelToken
            )
            
            if response.status == "completed" {
                guard let authData = response.authData else {
                    throw AuthenticationError.unknown("Invalid authentication data")
                }
                
                return FarcasterAuthResponse(
                    signature: authData.signature,
                    message: authData.message,
                    fid: authData.fid,
                    username: authData.username,
                    displayName: authData.displayName,
                    bio: authData.bio,
                    pfpUrl: authData.pfpUrl
                )
            }
            
            // Wait 1 second before next poll
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        throw AuthenticationError.timeout
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    // MARK: - Deep Link Handling
    
    /// Check if Warpcast app is installed
    private func checkWarpcastInstallation() {
        // Check both warpcast:// and farcaster:// schemes
        let warpcastURL = URL(string: "warpcast://")
        let farcasterURL = URL(string: "farcaster://")
        
        DispatchQueue.main.async {
            self.isWarpcastInstalled = (warpcastURL != nil && UIApplication.shared.canOpenURL(warpcastURL!)) ||
                                     (farcasterURL != nil && UIApplication.shared.canOpenURL(farcasterURL!))
        }
    }
    
    /// Open Warpcast app with the authentication request
    func openWarpcast() {
        guard let channel = authChannel else { return }
        
        // Try native deep links first
        let deepLinkFormats = [
            // Try the URL from backend first (might be a proper deep link)
            channel.url,
            // Standard deep link formats
            "warpcast://sign-in?channelToken=\(channel.channelToken)",
            "farcaster://sign-in?channelToken=\(channel.channelToken)",
            // Alternative formats that might work
            "warpcast://auth?channelToken=\(channel.channelToken)",
            "farcaster://auth?channelToken=\(channel.channelToken)",
            // Try with the full channel URL as parameter
            "warpcast://sign-in?url=\(channel.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? channel.url)",
            "farcaster://sign-in?url=\(channel.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? channel.url)"
        ]
        
        // Try each deep link format
        for deepLinkString in deepLinkFormats {
            if let url = URL(string: deepLinkString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        print("Successfully opened Warpcast with deep link: \(deepLinkString)")
                    }
                }
                return // Exit after first successful attempt
            }
        }
        
        // Fallback to web URL if no deep links work
        print("No deep links worked, falling back to web URL")
        if let url = URL(string: channel.deepLink) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        isAuthenticating = false
        authChannel = nil
        qrCodeImage = nil
        stopPolling()
    }
}

// MARK: - Authentication Error Extension

extension AuthenticationError {
    static var timeout: AuthenticationError {
        AuthenticationError.unknown("Authentication timeout - please try again")
    }
}