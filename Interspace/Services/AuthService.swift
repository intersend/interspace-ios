import Foundation
import Combine
import SwiftUI
import UIKit
// TODO: Uncomment after adding GoogleSignIn via SPM
import GoogleSignIn
import AuthenticationServices

struct AuthRequest: Codable {
    let authToken: String
    let authStrategy: String
    let deviceId: String
    let deviceName: String
    let deviceType: String
    let walletAddress: String?
}

struct AuthResponse: Codable {
    let success: Bool
    let data: AuthTokens
    let message: String
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// MARK: - Additional Request/Response Models

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct LogoutRequest: Codable {
    let refreshToken: String
}

struct LogoutResponse: Codable {
    let success: Bool
    let message: String
}

struct UserResponse: Codable {
    let success: Bool
    let data: User
}


class AuthService {
    static let shared = AuthService()
    private let apiService = APIService.shared

    private init() {}

    func authenticate(
        authToken: String,
        authStrategy: String,
        walletAddress: String?,
        completion: @escaping (Result<AuthResponse, APIError>) -> Void
    ) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
        let deviceName = UIDevice.current.name
        let deviceType = "ios"

        let authRequest = AuthRequest(
            authToken: authToken,
            authStrategy: authStrategy,
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            walletAddress: walletAddress
        )

        do {
            let body = try JSONEncoder().encode(authRequest)
            apiService.request(
                endpoint: "/auth/authenticate",
                method: "POST",
                body: body,
                completion: completion
            )
        } catch {
            completion(.failure(.decodingFailed(error)))
        }
    }
}


// MARK: - GoogleSignInService

struct GoogleSignInResult {
    let email: String
    let name: String?
    let imageURL: String?
    let idToken: String?
    let userId: String
}

final class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    private var isConfigured = false
    private let configurationQueue = DispatchQueue(label: "com.interspace.googleSignIn")
    
    private init() {}
    
    func configure() {
        configurationQueue.sync {
            guard !isConfigured else {
                print("🔐 GoogleSignInService: Already configured")
                return
            }
            
            print("🔐 GoogleSignInService: Starting configuration")
        
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("🔐 GoogleSignInService: ERROR - GoogleService-Info.plist not found in bundle")
            return
        }
        
        print("🔐 GoogleSignInService: Found GoogleService-Info.plist at: \(path)")
        
        guard let plist = NSDictionary(contentsOfFile: path) else {
            print("🔐 GoogleSignInService: ERROR - Could not read GoogleService-Info.plist")
            return
        }
        
        guard let clientId = plist["CLIENT_ID"] as? String else {
            print("🔐 GoogleSignInService: ERROR - Could not find CLIENT_ID in GoogleService-Info.plist")
            print("🔐 GoogleSignInService: Available keys: \(plist.allKeys)")
            return
        }
        
        print("🔐 GoogleSignInService: Found CLIENT_ID: \(clientId)")
        
        // Get server client ID from Info.plist if available
        var configuration: GIDConfiguration
        if let serverClientId = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
           !serverClientId.isEmpty,
           !serverClientId.contains("YOUR_") {
            print("🔐 GoogleSignInService: Found server client ID: \(serverClientId.prefix(20))...")
            configuration = GIDConfiguration(clientID: clientId, serverClientID: serverClientId)
        } else {
            print("⚠️ GoogleSignInService: No server client ID configured, using iOS client ID only")
            configuration = GIDConfiguration(clientID: clientId)
        }
        
        GIDSignIn.sharedInstance.configuration = configuration
        
        isConfigured = true
        
        print("🔐 GoogleSignInService: Configuration complete")
        print("🔐 GoogleSignInService: Current configuration: \(String(describing: GIDSignIn.sharedInstance.configuration))")
        }
    }
    
    private func ensureConfigured() {
        if !isConfigured {
            configure()
        }
    }
    
    func signIn() async throws -> GoogleSignInResult {
        ensureConfigured()
        print("🔐 GoogleSignInService: Starting Google Sign-In flow")
        
        // Try multiple methods to find the presenting view controller
        var presentingViewController: UIViewController?
        
        // Method 1: Get from active window scene
        if let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
            print("🔐 GoogleSignInService: Found window scene")
            if let window = await scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                print("🔐 GoogleSignInService: Found window: \(window)")
                presentingViewController = await window.rootViewController
                
                // If root view controller has a presented view controller, use that
                if let presented = await presentingViewController?.presentedViewController {
                    print("🔐 GoogleSignInService: Using presented view controller instead")
                    presentingViewController = presented
                }
            }
        }
        
        // Method 2: Fallback to key window
        if presentingViewController == nil {
            print("🔐 GoogleSignInService: Trying fallback method for view controller")
            if let keyWindow = await UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                presentingViewController = await keyWindow.rootViewController
            }
        }
        
        guard let viewController = presentingViewController else {
            print("🔐 GoogleSignInService: ERROR - No view controller available after trying all methods")
            throw GoogleSignInError.noViewController
        }
        
        print("🔐 GoogleSignInService: Found presenting view controller: \(type(of: viewController))")
        print("🔐 GoogleSignInService: View controller class: \(String(describing: viewController))")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                print("🔐 GoogleSignInService: Calling GIDSignIn.sharedInstance.signIn")
                GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                    if let error = error {
                        print("🔐 GoogleSignInService: Sign-in failed with error: \(error)")
                        print("🔐 GoogleSignInService: Error code: \((error as NSError).code)")
                        print("🔐 GoogleSignInService: Error domain: \((error as NSError).domain)")
                        continuation.resume(throwing: GoogleSignInError.signInFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let user = result?.user,
                          let profile = user.profile else {
                        print("🔐 GoogleSignInService: No user data received from Google Sign-In")
                        continuation.resume(throwing: GoogleSignInError.noUserData)
                        return
                    }
                    
                    print("🔐 GoogleSignInService: Sign-in successful!")
                    print("🔐 GoogleSignInService: User email: \(profile.email)")
                    print("🔐 GoogleSignInService: User name: \(profile.name ?? "N/A")")
                    print("🔐 GoogleSignInService: User ID: \(user.userID ?? "N/A")")
                    
                    // Refresh tokens to ensure we have the latest ID token
                    user.refreshTokensIfNeeded { _, error in
                        if let error = error {
                            print("⚠️ GoogleSignInService: Failed to refresh tokens: \(error.localizedDescription)")
                        }
                        
                        // Get the ID token for backend authentication
                        let idToken = user.idToken?.tokenString
                        print("🔐 GoogleSignInService: ID Token available: \(idToken != nil)")
                        
                        if idToken == nil {
                            print("⚠️ GoogleSignInService: No ID token available, backend auth may fail")
                        }
                        
                        let result = GoogleSignInResult(
                            email: profile.email,
                            name: profile.name,
                            imageURL: profile.imageURL(withDimension: 100)?.absoluteString,
                            idToken: idToken,
                            userId: user.userID ?? ""
                        )
                        
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func restorePreviousSignIn() async throws -> GoogleSignInResult? {
        print("🔐 GoogleSignInService: Attempting to restore previous sign-in")
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    print("🔐 GoogleSignInService: Failed to restore sign-in: \(error.localizedDescription)")
                    continuation.resume(throwing: GoogleSignInError.signInFailed(error.localizedDescription))
                    return
                }
                
                guard let user = user,
                      let profile = user.profile else {
                    print("🔐 GoogleSignInService: No previous sign-in found")
                    continuation.resume(returning: nil)
                    return
                }
                
                print("🔐 GoogleSignInService: Restored sign-in for: \(profile.email)")
                
                // Refresh tokens to ensure we have the latest ID token
                user.refreshTokensIfNeeded { _, error in
                    if let error = error {
                        print("⚠️ GoogleSignInService: Failed to refresh tokens: \(error.localizedDescription)")
                    }
                    
                    let idToken = user.idToken?.tokenString
                    print("🔐 GoogleSignInService: ID Token available: \(idToken != nil)")
                    
                    let result = GoogleSignInResult(
                        email: profile.email,
                        name: profile.name,
                        imageURL: profile.imageURL(withDimension: 100)?.absoluteString,
                        idToken: idToken,
                        userId: user.userID ?? ""
                    )
                    
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

// MARK: - GoogleSignInError

enum GoogleSignInError: LocalizedError {
    case noViewController
    case signInFailed(String)
    case noUserData
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "No view controller available for presenting Google Sign-In"
        case .signInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .noUserData:
            return "No user data received from Google Sign-In"
        }
    }
}

// MARK: - PasskeyService

struct PasskeyResult {
    let credentialID: String
    let signature: String
    let email: String?
}

final class PasskeyService {
    static let shared = PasskeyService()
    
    private init() {}
    
    static func isPasskeyAvailable() -> Bool {
        if #available(iOS 16.0, *) {
            return true
        } else {
            return false
        }
    }
    
    private func getPasskeyChallenge(for email: String? = nil) async throws -> Data {
        // In a real implementation, you'd get this from your server
        // For now, we'll generate a mock challenge
        // TODO: Implement proper server challenge request
        return Data.random(count: 32)
    }
    
    @available(iOS 16.0, *)
    func registerPasskey(for email: String) async throws -> PasskeyResult {
        // Get challenge from server
        guard let challengeData = try? await getPasskeyChallenge(for: email) else {
            throw PasskeyError.registrationFailed
        }
        
        let userID = Data(email.utf8)
        
        // Use your domain for relying party
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "interspace.ios")
        
        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: email,
            userID: userID
        )
        
        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let delegate = PasskeyAuthorizationDelegate { result in
                    switch result {
                    case .success(let passkeyResult):
                        continuation.resume(returning: passkeyResult)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                authController.delegate = delegate
                authController.presentationContextProvider = delegate
                authController.performRequests()
            }
        }
    }
    
    @available(iOS 16.0, *)
    func authenticateWithPasskey() async throws -> PasskeyResult {
        // Get challenge from server
        guard let challengeData = try? await getPasskeyChallenge() else {
            throw PasskeyError.authenticationFailed
        }
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "interspace.ios")
        
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let delegate = PasskeyAuthorizationDelegate { result in
                    switch result {
                    case .success(let passkeyResult):
                        continuation.resume(returning: passkeyResult)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                authController.delegate = delegate
                authController.presentationContextProvider = delegate
                authController.performRequests()
            }
        }
    }
}

@available(iOS 16.0, *)
private class PasskeyAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private let completion: (Result<PasskeyResult, Error>) -> Void
    private var strongSelf: PasskeyAuthorizationDelegate?
    
    init(completion: @escaping (Result<PasskeyResult, Error>) -> Void) {
        self.completion = completion
        super.init()
        self.strongSelf = self
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { strongSelf = nil }
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let result = PasskeyResult(
                credentialID: credential.credentialID.base64EncodedString(),
                signature: credential.rawAttestationObject?.base64EncodedString() ?? "",
                email: nil
            )
            completion(.success(result))
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let result = PasskeyResult(
                credentialID: credential.credentialID.base64EncodedString(),
                signature: credential.signature.base64EncodedString(),
                email: nil
            )
            completion(.success(result))
        } else {
            completion(.failure(PasskeyError.unsupportedCredential))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { strongSelf = nil }
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.windows.first { $0.isKeyWindow } ?? UIWindow()
        }
        return UIWindow()
    }
}

enum PasskeyError: LocalizedError {
    case unsupportedCredential
    case registrationFailed
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedCredential:
            return "Unsupported credential type"
        case .registrationFailed:
            return "Passkey registration failed"
        case .authenticationFailed:
            return "Passkey authentication failed"
        }
    }
}

extension Data {
    static func random(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, count, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        return data
    }
}
