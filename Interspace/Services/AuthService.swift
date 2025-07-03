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
    let expiresIn: Int?
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

struct UserResponse: Codable {  // Legacy compatibility wrapper
    let success: Bool
    let data: User  // User struct represents Account in flat identity model
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
    let accountId: String  // Changed from userId to accountId
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
            let window = await MainActor.run {
                scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            }
            if let window = window {
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
            let keyWindow = await MainActor.run {
                UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            }
            if let keyWindow = keyWindow {
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
                    print("🔐 GoogleSignInService: User name: \(profile.name)")
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
                            accountId: user.userID ?? ""
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
                    continuation.resume(throwing: GoogleSignInError.cancelled)
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
                        accountId: user.userID ?? ""
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
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "No view controller available for presenting Google Sign-In"
        case .signInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .noUserData:
            return "No user data received from Google Sign-In"
        case .cancelled:
            return "Google Sign-In was cancelled"
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
    let isRegistration: Bool
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
    
    @available(iOS 16.0, *)
    static func registerPasskeyForLinking(username: String? = nil) async throws -> AuthTokens {
        return try await shared.registerPasskeyForLinking(username: username)
    }
    
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
        
        let response = try await APIService.shared.performRequest(
            endpoint: endpoint,
            method: .POST,
            body: body,
            responseType: PasskeyOptionsResponse.self,
            requiresAuth: isRegistration
        )
        
        guard let optionsData = try? JSONEncoder().encode(response.data) else {
            throw PasskeyError.registrationFailed
        }
        return (challenge: response.data.challenge, options: optionsData)
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
                    continuation.resume(with: result)
                }
                
                authController.delegate = delegate
                authController.presentationContextProvider = delegate
                authController.performRequests()
            }
        }
        
        // Verify registration with server
        let finalDeviceName: String
        if let deviceName = deviceName {
            finalDeviceName = deviceName
        } else {
            finalDeviceName = await MainActor.run { UIDevice.current.name }
        }
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
            deviceName: finalDeviceName
        )
        
        let body = try JSONEncoder().encode(verifyRequest)
        let verifyResponse = try await APIService.shared.performRequest(
            endpoint: "/auth/passkey/register-verify",
            method: .POST,
            body: body,
            responseType: PasskeyVerifyResponse.self,
            requiresAuth: true
        )
        
        if verifyResponse.success && verifyResponse.data?.verified == true {
            // Registration successful - no tokens returned for registration
            return AuthTokens(accessToken: "", refreshToken: "", expiresIn: nil)
        } else {
            throw PasskeyError.registrationFailed
        }
    }
    
    @available(iOS 16.0, *)
    func registerPasskeyForLinking(username: String? = nil) async throws -> AuthTokens {
        // For account linking, always register a new passkey without checking for existing ones
        print("🔑 Registering new passkey for account linking")
        return try await registerPasskeyV2(username: username)
    }
    
    @available(iOS 16.0, *)
    func authenticateOrRegisterWithPasskey(username: String? = nil) async throws -> AuthTokens {
        // Check if user has existing passkeys before showing any UI
        let hasPasskeys = await checkForExistingPasskeys(username: username)
        
        if hasPasskeys {
            print("🔑 Existing passkeys found, showing authentication flow")
            return try await authenticateWithPasskeyOnly(username: username)
        } else {
            print("🔑 No passkeys found, starting registration flow directly")
            return try await registerPasskeyV2(username: username)
        }
    }
    
    @available(iOS 16.0, *)
    private func checkForExistingPasskeys(username: String? = nil) async -> Bool {
        do {
            // Get authentication options to check for allowed credentials
            let (challenge, optionsData) = try await getPasskeyChallenge(for: username, isRegistration: false)
            
            guard let options = try? JSONDecoder().decode(PasskeyOptions.self, from: optionsData) else {
                return false
            }
            
            // If server returns allowed credentials, user has passkeys
            if let allowedCredentials = options.allowCredentials, !allowedCredentials.isEmpty {
                return true
            }
            
            // For enhanced checking, try silent credential discovery if available
            if #available(iOS 17.0, *) {
                return await performSilentPasskeyCheck(challenge: challenge, options: options)
            }
            
            // No credentials from server - user has no passkeys
            return false
            
        } catch {
            // Error checking - assume no passkeys
            print("🔑 Error checking for passkeys: \(error.localizedDescription)")
            return false
        }
    }
    
    @available(iOS 17.0, *)
    private func performSilentPasskeyCheck(challenge: String, options: PasskeyOptions) async -> Bool {
        guard let challengeData = Data(base64URLEncoded: challenge) else {
            return false
        }
        
        let rpId = options.rp?.id ?? PasskeyService.getDefaultRPID()
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let delegate = PasskeySilentCheckDelegate { hasCredentials in
                    continuation.resume(returning: hasCredentials)
                }
                
                authController.delegate = delegate
                authController.presentationContextProvider = delegate
                
                // Use preferImmediatelyAvailableCredentials for silent check
                authController.performRequests(options: .preferImmediatelyAvailableCredentials)
            }
        }
    }
    
    @available(iOS 16.0, *)
    private func authenticateWithPasskeyOnly(username: String? = nil) async throws -> AuthTokens {
        // Get authentication options from server
        let (challenge, optionsData) = try await getPasskeyChallenge(for: username, isRegistration: false)
        
        guard let options = try? JSONDecoder().decode(PasskeyOptions.self, from: optionsData),
              let challengeData = Data(base64URLEncoded: challenge) else {
            throw PasskeyError.authenticationFailed
        }
        
        let rpId = options.rp?.id ?? PasskeyService.getDefaultRPID()
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        // Create authentication request only
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
        
        // If we have allowed credentials from server, set them
        if let allowedCredentials = options.allowCredentials, !allowedCredentials.isEmpty {
            assertionRequest.allowedCredentials = allowedCredentials.compactMap { cred -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? in
                guard let credIdData = Data(base64URLEncoded: cred.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(
                    credentialID: credIdData
                )
            }
        }
        
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        
        do {
            let passkeyResult = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let delegate = PasskeyAuthorizationDelegate { result in
                        continuation.resume(with: result)
                    }
                    
                    authController.delegate = delegate
                    authController.presentationContextProvider = delegate
                    authController.performRequests()
                }
            }
            
            // Verify authentication with backend
            return try await verifyPasskeyAuthentication(passkeyResult, challenge: challenge)
        } catch let error as ASAuthorizationError {
            // Convert ASAuthorizationError to PasskeyError for better handling
            switch error.code {
            case .canceled:
                throw PasskeyError.authenticationCanceled
            case .failed, .invalidResponse, .notHandled:
                throw PasskeyError.noCredentialsAvailable
            case .unknown:
                throw PasskeyError.authenticationFailed
            case .notInteractive:
                throw PasskeyError.authenticationFailed
            case .matchedExcludedCredential:
                throw PasskeyError.noCredentialsAvailable
            @unknown default:
                throw PasskeyError.authenticationFailed
            }
        }
    }
    
    @available(iOS 16.0, *)
    private func registerPasskeyV2(username: String? = nil) async throws -> AuthTokens {
        // Get authentication challenge (we'll use it for registration in V2)
        let (challenge, optionsData) = try await getPasskeyChallenge(for: username, isRegistration: false)
        
        guard let options = try? JSONDecoder().decode(PasskeyOptions.self, from: optionsData),
              let challengeData = Data(base64URLEncoded: challenge) else {
            throw PasskeyError.registrationFailed
        }
        
        let rpId = options.rp?.id ?? PasskeyService.getDefaultRPID()
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        // Create registration request
        let tempUserId = UUID().uuidString.data(using: .utf8)!
        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: username ?? "user",
            userID: tempUserId
        )
        
        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        
        let passkeyResult = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let delegate = PasskeyAuthorizationDelegate { result in
                    continuation.resume(with: result)
                }
                
                authController.delegate = delegate
                authController.presentationContextProvider = delegate
                authController.performRequests()
            }
        }
        
        // For new passkeys, authenticate through V2 auth endpoint
        return try await handlePasskeyRegistrationV2(passkeyResult, challenge: challenge, username: username)
    }
    
    @available(iOS 16.0, *)
    private func handlePasskeyRegistrationV2(_ passkeyResult: PasskeyResult, challenge: String, username: String?) async throws -> AuthTokens {
        // For V2, we authenticate with the passkey strategy
        // The backend will handle account creation automatically
        let _ = PasskeyVerifyRequest(
            response: PasskeyResponse(
                id: passkeyResult.credentialID,
                rawId: passkeyResult.credentialID,
                type: "public-key",
                response: AuthenticatorResponse(
                    clientDataJSON: passkeyResult.clientDataJSON,
                    attestationObject: passkeyResult.attestationObject,
                    authenticatorData: passkeyResult.authenticatorData,
                    signature: passkeyResult.signature,
                    userHandle: passkeyResult.userHandle
                )
            ),
            challenge: challenge,
            deviceName: await MainActor.run { UIDevice.current.name }
        )
        
        // Use V2 authenticate endpoint with passkey strategy
        let credentialId = passkeyResult.credentialID
        let clientDataJSON = passkeyResult.clientDataJSON ?? ""
        let attestationObject = passkeyResult.attestationObject ?? ""
        let authenticatorData = passkeyResult.authenticatorData ?? ""
        let signature = passkeyResult.signature
        let userHandle = passkeyResult.userHandle ?? ""
        let deviceId = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "" }
        let deviceName = await MainActor.run { UIDevice.current.name }
        
        var requestBody: [String: Any] = [
            "strategy": "passkey",
            "passkeyResponse": [
                "id": credentialId,
                "rawId": credentialId,
                "type": "public-key",
                "response": [
                    "clientDataJSON": clientDataJSON,
                    "attestationObject": attestationObject,
                    "authenticatorData": authenticatorData,
                    "signature": signature,
                    "userHandle": userHandle
                ]
            ],
            "challenge": challenge,
            "deviceId": deviceId,
            "deviceName": deviceName
        ]
        
        if let username = username {
            requestBody["username"] = username
        }
        
        let body = try JSONSerialization.data(withJSONObject: requestBody)
        
        let verifyResult: Result<AuthenticationResponseV2, APIError> = await withCheckedContinuation { continuation in
            APIService.shared.request(
                endpoint: "/auth/authenticate",
                method: "POST",
                body: body
            ) { (result: Result<AuthenticationResponseV2, APIError>) in
                continuation.resume(returning: result)
            }
        }
        
        switch verifyResult {
        case .success(let response):
            if response.success,
               let tokens = response.tokens {
                return AuthTokens(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken,
                    expiresIn: tokens.expiresIn ?? 900
                )
            } else {
                throw PasskeyError.registrationFailed
            }
        case .failure(let error):
            throw error
        }
    }
    
    @available(iOS 16.0, *)
    private func verifyPasskeyAuthentication(_ passkeyResult: PasskeyResult, challenge: String) async throws -> AuthTokens {
        // For authentication, use the same V2 endpoint
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
            deviceName: await MainActor.run { UIDevice.current.name }
        )
        
        let body = try JSONEncoder().encode(verifyRequest)
        
        let verifyResult: Result<PasskeyVerifyResponse, APIError> = await withCheckedContinuation { continuation in
            APIService.shared.request(
                endpoint: "/auth/passkey/authenticate-verify",
                method: "POST",
                body: body
            ) { (result: Result<PasskeyVerifyResponse, APIError>) in
                continuation.resume(returning: result)
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
    
    @available(iOS 16.0, *)
    func authenticateWithPasskey(username: String? = nil) async throws -> AuthTokens {
        // This method now just calls the unified flow
        return try await authenticateOrRegisterWithPasskey(username: username)
    }
    
    static func getDefaultRPID() -> String {
        // Get the RP ID based on the current API URL
        let apiURL = EnvironmentConfiguration.shared.currentEnvironment.apiBaseURL
        
        // Extract the domain from the API URL
        if let url = URL(string: apiURL),
           let host = url.host {
            // Remove 'api.' prefix if present for the RP ID
            if host.hasPrefix("api.") {
                return String(host.dropFirst(4))
            } else if host.hasPrefix("staging-api.") {
                // For staging, use the staging subdomain
                return host
            } else if host.contains("ngrok") {
                // For ngrok URLs, use the full ngrok domain
                return host
            }
            return host
        }
        
        // Fallback to interspace.fi
        return "interspace.fi"
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
                userHandle: nil,
                isRegistration: true
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
                userHandle: credential.userID.base64URLEncodedString(),
                isRegistration: false
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

@available(iOS 17.0, *)
private class PasskeySilentCheckDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private let completion: (Bool) -> Void
    private var strongSelf: PasskeySilentCheckDelegate?
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
        self.strongSelf = self
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { strongSelf = nil }
        // If we got an authorization, user has passkeys
        completion(true)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { strongSelf = nil }
        
        // Check error to determine if user has no passkeys or other error
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // User canceled - but this shouldn't happen with preferImmediatelyAvailableCredentials
                completion(false)
            case .failed, .invalidResponse, .notHandled, .unknown:
                // No credentials available
                completion(false)
            case .notInteractive:
                // Cannot show UI - no credentials immediately available
                completion(false)
            case .matchedExcludedCredential:
                // Matched excluded credential
                completion(false)
            @unknown default:
                completion(false)
            }
        } else {
            completion(false)
        }
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
    case authenticationCanceled
    case noCredentialsAvailable
    case notConfigured
    case platformNotSupported
    
    var errorDescription: String? {
        switch self {
        case .unsupportedCredential:
            return "Unsupported credential type"
        case .registrationFailed:
            return "Passkey registration failed. Please try again."
        case .authenticationFailed:
            return "Passkey authentication failed. Please try again."
        case .authenticationCanceled:
            return "Passkey authentication was canceled"
        case .noCredentialsAvailable:
            return "No passkeys found for this account"
        case .notConfigured:
            return "Device not configured for passkeys. Please enable iCloud Keychain and set a device passcode."
        case .platformNotSupported:
            return "Passkeys require iOS 16 or later"
        }
    }
    
    var isUserCancellation: Bool {
        switch self {
        case .authenticationCanceled:
            return true
        default:
            return false
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

// MARK: - AppleSignInService

final class AppleSignInService: NSObject {
    static let shared = AppleSignInService()
    
    private var signInContinuation: CheckedContinuation<AppleSignInResult, Error>?
    
    override private init() {
        super.init()
    }
    
    @MainActor
    func signIn() async throws -> AppleSignInResult {
        print("🍎 AppleSignInService: Starting Apple Sign-In flow")
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            authorizationController.performRequests()
        }
    }
    
    func checkCredentialState(userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        return try await withCheckedThrowingContinuation { continuation in
            appleIDProvider.getCredentialState(forUserID: userID) { credentialState, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: credentialState)
                }
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎 AppleSignInService: Authorization completed successfully")
        
        // Ensure we have a continuation to resume
        guard let continuation = signInContinuation else {
            print("🍎 AppleSignInService: WARNING - No continuation available, already resumed")
            return
        }
        signInContinuation = nil // Clear immediately to prevent double resume
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("🍎 AppleSignInService: ERROR - Invalid credential type")
            continuation.resume(throwing: AppleSignInError.invalidCredential)
            return
        }
        
        // Extract identity token
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("🍎 AppleSignInService: ERROR - No identity token")
            continuation.resume(throwing: AppleSignInError.noIdentityToken)
            return
        }
        
        // Extract authorization code
        guard let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            print("🍎 AppleSignInService: ERROR - No authorization code")
            continuation.resume(throwing: AppleSignInError.noAuthorizationCode)
            return
        }
        
        print("🍎 AppleSignInService: Successfully extracted tokens")
        print("🍎 AppleSignInService: User ID: \(appleIDCredential.user)")
        print("🍎 AppleSignInService: Email: \(appleIDCredential.email ?? "Not provided")")
        print("🍎 AppleSignInService: Full Name: \(appleIDCredential.fullName?.formatted() ?? "Not provided")")
        print("🍎 AppleSignInService: Real User Status: \(appleIDCredential.realUserStatus.rawValue)")
        
        // Check if we have user info from Apple (first sign-in)
        var email = appleIDCredential.email
        var fullName = appleIDCredential.fullName
        
        // If Apple didn't provide email/name (subsequent sign-ins), check cache
        if email == nil || fullName == nil {
            print("🍎 AppleSignInService: Checking cache for missing user info")
            
            // Try to get cached Apple user info
            if let cachedUserInfo = KeychainManager.shared.getAppleUserInfo() {
                if cachedUserInfo.id == appleIDCredential.user {
                    // Use cached values if current ones are nil
                    if email == nil && cachedUserInfo.email != nil {
                        email = cachedUserInfo.email
                        print("🍎 AppleSignInService: Using cached email: \(email ?? "")")
                    }
                    
                    if fullName == nil && (cachedUserInfo.firstName != nil || cachedUserInfo.lastName != nil) {
                        var components = PersonNameComponents()
                        components.givenName = cachedUserInfo.firstName
                        components.familyName = cachedUserInfo.lastName
                        fullName = components
                        print("🍎 AppleSignInService: Using cached name: \(fullName?.formatted() ?? "")")
                    }
                }
            }
        }
        
        // Cache user info if we have it (first sign-in)
        if appleIDCredential.email != nil || appleIDCredential.fullName != nil {
            print("🍎 AppleSignInService: Caching Apple user info for future use")
            
            let userInfo = AppleUserInfo(
                id: appleIDCredential.user,
                email: appleIDCredential.email,
                firstName: appleIDCredential.fullName?.givenName,
                lastName: appleIDCredential.fullName?.familyName
            )
            
            do {
                try KeychainManager.shared.saveAppleUserInfo(userInfo)
                print("🍎 AppleSignInService: Successfully cached Apple user info")
            } catch {
                print("🍎 AppleSignInService: Failed to cache Apple user info: \(error)")
            }
        }
        
        let result = AppleSignInResult(
            accountId: appleIDCredential.user,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: email,
            fullName: fullName,
            realUserStatus: appleIDCredential.realUserStatus
        )
        
        continuation.resume(returning: result)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🍎 AppleSignInService: Authorization failed with error: \(error)")
        
        // Ensure we have a continuation to resume
        guard let continuation = signInContinuation else {
            print("🍎 AppleSignInService: WARNING - No continuation available, already resumed")
            return
        }
        signInContinuation = nil // Clear immediately to prevent double resume
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("🍎 AppleSignInService: User cancelled sign-in")
                continuation.resume(throwing: AppleSignInError.userCancelled)
            case .failed:
                print("🍎 AppleSignInService: Authorization failed")
                continuation.resume(throwing: AppleSignInError.authorizationFailed)
            case .invalidResponse:
                print("🍎 AppleSignInService: Invalid response")
                continuation.resume(throwing: AppleSignInError.invalidResponse)
            case .notHandled:
                print("🍎 AppleSignInService: Authorization not handled")
                continuation.resume(throwing: AppleSignInError.notHandled)
            case .unknown:
                print("🍎 AppleSignInService: Unknown error")
                continuation.resume(throwing: AppleSignInError.unknown)
            case .notInteractive:
                print("🍎 AppleSignInService: Not interactive")
                continuation.resume(throwing: AppleSignInError.notHandled)
            case .matchedExcludedCredential:
                print("🍎 AppleSignInService: Matched excluded credential")
                continuation.resume(throwing: AppleSignInError.invalidCredential)
            default:
                print("🍎 AppleSignInService: Other error: \(authError)")
                continuation.resume(throwing: error)
            }
        } else {
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            print("🍎 AppleSignInService: WARNING - No key window found, using new window")
            return UIWindow()
        }
        
        print("🍎 AppleSignInService: Using window: \(window)")
        return window
    }
}

// MARK: - AppleSignInError

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case noIdentityToken
    case noAuthorizationCode
    case userCancelled
    case authorizationFailed
    case invalidResponse
    case notHandled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .noIdentityToken:
            return "No identity token received from Apple"
        case .noAuthorizationCode:
            return "No authorization code received from Apple"
        case .userCancelled:
            return "Sign in with Apple was cancelled"
        case .authorizationFailed:
            return "Apple authorization failed"
        case .invalidResponse:
            return "Invalid response from Apple"
        case .notHandled:
            return "Apple authorization was not handled"
        case .unknown:
            return "Unknown error occurred during Apple Sign-In"
        }
    }
}
