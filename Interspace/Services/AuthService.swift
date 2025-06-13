import Foundation
import Combine
import AuthenticationServices

class AuthService: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isAuthenticated: Bool = false
    @Published var user: User?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var cancellables = Set<AnyCancellable>()

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signInWithGoogle() {
        // Google Sign-In logic will be implemented here.
    }

    func signOut() {
        self.isAuthenticated = false
        self.user = nil
    }

    func handleAppleSignIn(authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityToken = appleIDCredential.identityToken,
                  let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                self.error = NSError(domain: "com.interspace.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get identity token from Apple."])
                return
            }

            APIService.shared.authenticateWithApple(identityToken: identityTokenString) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let authResponse):
                        // Here you would typically save the tokens to the keychain
                        // and fetch user profile, etc.
                        self.user = User(id: appleIDCredential.user, email: appleIDCredential.email)
                        self.isAuthenticated = true
                    case .failure(let error):
                        self.error = error
                    }
                }
            }
        }
    }

    func handleAppleSignInError(error: Error) {
        self.error = error
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first!
    }
}

struct User {
    let id: String
    let email: String?
}