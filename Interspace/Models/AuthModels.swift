import Foundation
import UIKit
import SwiftUI

// MARK: - Authentication Strategy
enum AuthStrategy: String, CaseIterable, Codable {
    case wallet = "wallet"
    case email = "email"
    case google = "google"
    case apple = "apple"
    case passkey = "passkey"
    case guest = "guest"
    case testWallet = "testWallet"
    
    var displayName: String {
        switch self {
        case .wallet: return "Wallet"
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple"
        case .passkey: return "Passkey"
        case .guest: return "Guest"
        case .testWallet: return "Test Wallet"
        }
    }
    
    var icon: String {
        switch self {
        case .wallet: return "wallet.pass.fill"
        case .email: return "envelope.fill"
        case .google: return "globe"
        case .apple: return "apple.logo"
        case .passkey: return "person.crop.circle.fill.badge.checkmark"
        case .guest: return "person.fill"
        case .testWallet: return "testtube.2"
        }
    }
    
    var description: String {
        switch self {
        case .wallet: return "Connect using MetaMask or Coinbase"
        case .email: return "Sign in with email verification"
        case .google: return "Continue with Google account"
        case .apple: return "Continue with Apple ID"
        case .passkey: return "Use biometric authentication"
        case .guest: return "Browse without an account"
        case .testWallet: return "Development testing only"
        }
    }
}


// MARK: - Authentication Request
struct AuthenticationRequest: Codable {
    let authToken: String
    let authStrategy: String
    let deviceId: String
    let deviceName: String
    let deviceType: String
    let walletAddress: String?
    let email: String?
    let verificationCode: String?
    let socialData: SocialAuthData?
}

// Social authentication data for Google/Apple Sign-In
struct SocialAuthData: Codable {
    let provider: String
    let providerId: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
}

// MARK: - Authentication Response
struct AuthenticationResponse: Codable {
    let success: Bool
    let data: AuthenticationData
    let message: String
}

struct AuthenticationData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let walletProfileInfo: WalletProfileInfo?
}

struct WalletProfileInfo: Codable {
    let isLinked: Bool
    let profileId: String?
    let profileName: String?
    let isActive: Bool?
    let linkedAccount: LegacySocialAccount?
}

// Legacy social account for authentication compatibility
struct LegacySocialAccount: Codable {
    let id: String
    let provider: String
    let providerId: String
    let email: String?
    let name: String?
    let picture: String?
}


// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let walletAddress: String?
    let isGuest: Bool
    let authStrategies: [String]
    let profilesCount: Int
    let linkedAccountsCount: Int
    let activeDevicesCount: Int
    let socialAccounts: [LegacySocialAccount]
    let createdAt: String
    let updatedAt: String
}

// MARK: - Wallet Connection Models
struct WalletConnectionConfig {
    let strategy: AuthStrategy
    let walletType: String?
    let email: String?
    let verificationCode: String?
    let walletAddress: String?
    let signature: String?
    let message: String?
    let socialProvider: String?
    let socialProfile: SocialProfile?
}

struct SocialProfile {
    let id: String
    let email: String?
    let name: String?
    let picture: String?
}

// MARK: - API Response Models
struct EmailCodeResponse: Codable {
    let success: Bool
    let message: String?
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
}

struct WalletCheckResponse: Codable {
    let success: Bool
    let data: WalletCheckData
}

struct WalletCheckData: Codable {
    let exists: Bool
    let hasProfile: Bool
    let profileId: String?
    let profileName: String?
    let isOrphan: Bool
}

// MARK: - Error Models
enum AuthenticationError: LocalizedError, Identifiable {
    case invalidCredentials
    case networkError(String)
    case walletConnectionFailed(String)
    case emailVerificationFailed
    case tokenExpired
    case unknown(String)
    
    var id: String {
        switch self {
        case .invalidCredentials:
            return "invalidCredentials"
        case .networkError(let message):
            return "networkError-\(message)"
        case .walletConnectionFailed(let message):
            return "walletConnectionFailed-\(message)"
        case .emailVerificationFailed:
            return "emailVerificationFailed"
        case .tokenExpired:
            return "tokenExpired"
        case .unknown(let message):
            return "unknown-\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .walletConnectionFailed(let message):
            return "Wallet connection failed: \(message)"
        case .emailVerificationFailed:
            return "Invalid verification code. Please check the code and try again."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Device Info
struct DeviceInfo {
    static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "device_id") {
            return id
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "device_id")
            return newId
        }
    }
    
    static var deviceName: String {
        let device = UIDevice.current
        return "\(device.name) (\(device.model))"
    }
    
    static let deviceType = "ios"
}