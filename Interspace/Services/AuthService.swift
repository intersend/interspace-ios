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
        
        // First try to get client ID from GoogleService-Info.plist
        var clientId: String?
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            print("🔐 GoogleSignInService: Found GoogleService-Info.plist")
            clientId = plist["CLIENT_ID"] as? String
        }
        
        // Fallback to Info.plist if GoogleService-Info.plist not found or doesn't have CLIENT_ID
        if clientId == nil {
            print("🔐 GoogleSignInService: Falling back to Info.plist for configuration")
            clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        }
        
        guard let finalClientId = clientId, !finalClientId.isEmpty else {
            print("🔐 GoogleSignInService: ERROR - Could not find CLIENT_ID in GoogleService-Info.plist or GIDClientID in Info.plist")
            return
        }
        
        print("🔐 GoogleSignInService: Found CLIENT_ID: \(finalClientId)")
        
        // Get server client ID from Info.plist if available
        var configuration: GIDConfiguration
        if let serverClientId = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
           !serverClientId.isEmpty,
           !serverClientId.contains("YOUR_") {
            print("🔐 GoogleSignInService: Found server client ID: \(serverClientId.prefix(20))...")
            configuration = GIDConfiguration(clientID: finalClientId, serverClientID: serverClientId)
        } else {
            print("⚠️ GoogleSignInService: No server client ID configured, using iOS client ID only")
            configuration = GIDConfiguration(clientID: finalClientId)
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
    let clientDataJSON: String?
    let attestationObject: String?
    let authenticatorData: String?
    let userHandle: String?
}

struct PasskeyOptionsResponse: Codable {
    let success: Bool
    let data: PasskeyOptions
}

struct PasskeyOptions: Codable {
    let challenge: String
    let rp: RelyingParty?
    let user: PasskeyUser?
    let pubKeyCredParams: [PublicKeyCredParam]?
    let timeout: Int?
    let attestation: String?
    let excludeCredentials: [CredentialDescriptor]?
    let allowCredentials: [CredentialDescriptor]?
    let userVerification: String?
}

struct RelyingParty: Codable {
    let name: String
    let id: String
}

struct PasskeyUser: Codable {
    let id: String
    let name: String
    let displayName: String
}

struct PublicKeyCredParam: Codable {
    let type: String
    let alg: Int
}

struct CredentialDescriptor: Codable {
    let type: String
    let id: String
    let transports: [String]?
}

struct PasskeyVerifyRequest: Codable {
    let response: PasskeyResponse
    let challenge: String
    let deviceName: String?
}

struct PasskeyResponse: Codable {
    let id: String
    let rawId: String
    let type: String
    let response: AuthenticatorResponse
}

struct AuthenticatorResponse: Codable {
    // For registration
    let clientDataJSON: String?
    let attestationObject: String?
    
    // For authentication
    let authenticatorData: String?
    let signature: String?
    let userHandle: String?
}

struct PasskeyVerifyResponse: Codable {
    let success: Bool
    let data: PasskeyVerifyData?
    let message: String?
}

struct PasskeyVerifyData: Codable {
    let verified: Bool
    let credentialId: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
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
    
    private func getPasskeyChallenge(for username: String? = nil, isRegistration: Bool = false) async throws -> (challenge: String, options: Data) {
        let endpoint = isRegistration ? "/auth/passkey/register-options" : "/auth/passkey/authenticate-options"
        
        var body: Data? = nil
        if let username = username {
            let requestData = ["username": username]
            body = try? JSONEncoder().encode(requestData)
        }
        
        let result: Result<PasskeyOptionsResponse, APIError> = await withCheckedContinuation { continuation in
            APIService.shared.request(
                endpoint: endpoint,
                method: "POST",
                body: body,
                requiresAuth: isRegistration
            ) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch result {
        case .success(let response):
            guard let optionsData = try? JSONEncoder().encode(response.data) else {
                throw PasskeyError.registrationFailed
            }
            return (challenge: response.data.challenge, options: optionsData)
        case .failure(let error):
            throw error
        }
    }
    
    @available(iOS 16.0, *)
    func registerPasskey(for email: String, deviceName: String? = nil) async throws -> AuthTokens {
        // Get registration options from server
        let (challenge, optionsData) = try await getPasskeyChallenge(for: email, isRegistration: true)
        
        guard let options = try? JSONDecoder().decode(PasskeyOptions.self, from: optionsData),
              let rpId = options.rp?.id,
              let userId = options.user?.id.data(using: .utf8),
              let userName = options.user?.name,
              let challengeData = Data(base64URLEncoded: challenge) else {
            throw PasskeyError.registrationFailed
        }
        
        // Create platform provider with server's RP ID
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: userName,
            userID: userId
        )
        
        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        
        let passkeyResult = try await withCheckedThrowingContinuation { continuation in
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
        
        // Verify registration with server
        let verifyRequest = PasskeyVerifyRequest(
            response: PasskeyResponse(
                id: passkeyResult.credentialID,
                rawId: passkeyResult.credentialID,
                type: "public-key",
                response: AuthenticatorResponse(
                    clientDataJSON: passkeyResult.clientDataJSON,
                    attestationObject: passkeyResult.attestationObject,
                    authenticatorData: nil,
                    signature: nil,
                    userHandle: nil
                )
            ),
            challenge: challenge,
            deviceName: deviceName ?? UIDevice.current.name
        )
        
        let verifyResult: Result<PasskeyVerifyResponse, APIError> = await withCheckedContinuation { continuation in
            do {
                let body = try JSONEncoder().encode(verifyRequest)
                APIService.shared.request(
                    endpoint: "/auth/passkey/register-verify",
                    method: "POST",
                    body: body,
                    requiresAuth: true
                ) { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(returning: .failure(.decodingFailed(error)))
            }
        }
        
        switch verifyResult {
        case .success(let response):
            if response.success && response.data?.verified == true {
                // Registration successful - no tokens returned for registration
                return AuthTokens(accessToken: "", refreshToken: "", expiresIn: 0)
            } else {
                throw PasskeyError.registrationFailed
            }
        case .failure(let error):
            throw error
        }
    }
    
    @available(iOS 16.0, *)
    func authenticateWithPasskey(username: String? = nil) async throws -> AuthTokens {
        // Get authentication options from server
        let (challenge, optionsData) = try await getPasskeyChallenge(for: username, isRegistration: false)
        
        guard let options = try? JSONDecoder().decode(PasskeyOptions.self, from: optionsData),
              let rpId = options.rp?.id ?? PasskeyService.getDefaultRPID(),
              let challengeData = Data(base64URLEncoded: challenge) else {
            throw PasskeyError.authenticationFailed
        }
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        // If we have allowed credentials from server, set them
        if let allowedCredentials = options.allowCredentials, !allowedCredentials.isEmpty {
            assertionRequest.allowedCredentials = allowedCredentials.compactMap { cred in
                guard let credIdData = Data(base64URLEncoded: cred.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialAssertionRequest.Credential(
                    credentialID: credIdData,
                    transports: []
                )
            }
        }
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        
        let passkeyResult = try await withCheckedThrowingContinuation { continuation in
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
        
        // Verify authentication with server
        let verifyRequest = PasskeyVerifyRequest(
            response: PasskeyResponse(
                id: passkeyResult.credentialID,
                rawId: passkeyResult.credentialID,
                type: "public-key",
                response: AuthenticatorResponse(
                    clientDataJSON: passkeyResult.clientDataJSON,
                    attestationObject: nil,
                    authenticatorData: passkeyResult.authenticatorData,
                    signature: passkeyResult.signature,
                    userHandle: passkeyResult.userHandle
                )
            ),
            challenge: challenge,
            deviceName: UIDevice.current.name
        )
        
        let verifyResult: Result<PasskeyVerifyResponse, APIError> = await withCheckedContinuation { continuation in
            do {
                let body = try JSONEncoder().encode(verifyRequest)
                APIService.shared.request(
                    endpoint: "/auth/passkey/authenticate-verify",
                    method: "POST",
                    body: body,
                    requiresAuth: false
                ) { result in
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(returning: .failure(.decodingFailed(error)))
            }
        }
        
        switch verifyResult {
        case .success(let response):
            if response.success,
               let data = response.data,
               data.verified == true,
               let accessToken = data.accessToken,
               let refreshToken = data.refreshToken,
               let expiresIn = data.expiresIn {
                return AuthTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: expiresIn
                )
            } else {
                throw PasskeyError.authenticationFailed
            }
        case .failure(let error):
            throw error
        }
    }
    
    static func getDefaultRPID() -> String {
        // Default to bundle identifier if no RP ID is set
        return Bundle.main.bundleIdentifier ?? "interspace.com"
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
                credentialID: credential.credentialID.base64URLEncodedString(),
                signature: "",
                email: nil,
                clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                attestationObject: credential.rawAttestationObject?.base64URLEncodedString(),
                authenticatorData: nil,
                userHandle: nil
            )
            completion(.success(result))
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let result = PasskeyResult(
                credentialID: credential.credentialID.base64URLEncodedString(),
                signature: credential.signature.base64URLEncodedString(),
                email: nil,
                clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                attestationObject: nil,
                authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
                userHandle: credential.userID.base64URLEncodedString()
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
    
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    init?(base64URLEncoded: String) {
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        
        self.init(base64Encoded: base64)
    }
}
