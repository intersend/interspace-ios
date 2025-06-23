import Foundation
import UIKit
import SwiftUI
import AuthenticationServices

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
    let oauthCode: String?
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
    case passkeyNotSupported
    case passkeyAuthenticationFailed(String)
    case passkeyRegistrationFailed(String)
    case notAuthenticated
    case emailRequired
    
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
        case .passkeyNotSupported:
            return "passkeyNotSupported"
        case .passkeyAuthenticationFailed(let message):
            return "passkeyAuthenticationFailed-\(message)"
        case .passkeyRegistrationFailed(let message):
            return "passkeyRegistrationFailed-\(message)"
        case .notAuthenticated:
            return "notAuthenticated"
        case .emailRequired:
            return "emailRequired"
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
        case .passkeyNotSupported:
            return "Passkeys are only supported on iOS 16 and later."
        case .passkeyAuthenticationFailed(let message):
            return "Passkey authentication failed: \(message)"
        case .passkeyRegistrationFailed(let message):
            return "Passkey registration failed: \(message)"
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .emailRequired:
            return "Email address is required for passkey registration."
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

// MARK: - Apple Sign-In Models
struct AppleSignInResult {
    let userId: String
    let identityToken: String
    let authorizationCode: String
    let email: String?
    let fullName: PersonNameComponents?
    let realUserStatus: ASUserDetectionStatus
}

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let user: AppleUserInfo
    let deviceId: String
    let deviceName: String
    let deviceType: String
}

struct AppleUserInfo: Codable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
}

// MARK: - V2 API Models

struct AccountV2: Codable {
    let id: String
    let strategy: String
    let identifier: String
    let metadata: [String: String]?
    let createdAt: String
    let updatedAt: String
}

struct ProfileSummaryV2: Codable {
    let id: String
    let displayName: String
    let username: String?
    let avatarUrl: String?
    let privacyMode: String
    var isActive: Bool
}

struct UserV2: Codable {
    let id: String
    let email: String?
    let isGuest: Bool
}

struct AuthResponseV2: Codable {
    let success: Bool
    let account: AccountV2
    let user: UserV2
    let profiles: [ProfileSummaryV2]
    let activeProfile: ProfileSummaryV2?
    let tokens: AuthTokens
    let isNewUser: Bool
    let privacyMode: String
    let sessionId: String
}

struct AuthenticationRequestV2: Codable {
    let strategy: String
    let identifier: String?
    let credential: String?
    let oauthCode: String?
    let appleAuth: AppleAuthRequest?
    let privacyMode: String?
    let deviceId: String?
    
    // Email-specific fields
    let email: String?
    let verificationCode: String?
    
    // Wallet-specific fields
    let walletAddress: String?
    let signature: String?
    let message: String?
    let walletType: String?
    
    // Social-specific fields
    let idToken: String?
}

struct LinkAccountRequestV2: Codable {
    let strategy: String
    let identifier: String?
    let credential: String?
    let oauthCode: String?
    let appleAuth: AppleAuthRequest?
}

struct IdentityGraphResponse: Codable {
    let success: Bool
    let accounts: [AccountV2]
    let links: [IdentityLink]?
    let currentAccountId: String?
}

struct IdentityLink: Codable {
    let id: String
    let accountAId: String
    let accountBId: String
    let privacyMode: String?  
    let createdAt: String
    let updatedAt: String
}
