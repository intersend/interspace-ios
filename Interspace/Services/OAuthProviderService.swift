import Foundation
import AppAuth
import AuthenticationServices

// MARK: - OAuth Service
class OAuthProviderService: NSObject {
    static let shared = OAuthProviderService()
    
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    // Get provider configuration by name
    func providerConfig(for name: String, shopDomain: String? = nil) -> OAuthConfiguration? {
        guard var config = OAuthProviderRegistry.provider(for: name) else {
            return nil
        }
        
        // Handle dynamic providers like Shopify
        if name.lowercased() == "shopify" {
            config = config.withDynamicUrls(shopDomain: shopDomain)
        }
        
        return config
    }
    
    // Store completion handler for backend redirect flow
    private var pendingCompletion: ((Result<OAuthTokens, Error>) -> Void)?
    private var pendingProvider: String?
    
    // Authenticate with provider
    func authenticate(
        withProviderNamed providerName: String,
        shopDomain: String? = nil,
        presentingViewController: UIViewController,
        completion: @escaping (Result<OAuthTokens, Error>) -> Void
    ) {
        guard let provider = providerConfig(for: providerName, shopDomain: shopDomain) else {
            completion(.failure(OAuthProviderError.invalidConfiguration(provider: providerName)))
            return
        }
        
        print("🔐 OAuth: Starting authentication for \(providerName)")
        print("🔐 OAuth: Client ID: \(provider.clientId)")
        print("🔐 OAuth: Redirect URI: \(provider.redirectUri)")
        print("🔐 OAuth: Scopes: \(provider.scopes)")
        
        // Store completion for backend redirect flow
        self.pendingCompletion = completion
        self.pendingProvider = providerName
        
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: provider.authorizationEndpoint,
            tokenEndpoint: provider.tokenEndpoint
        )
        
        var additionalParams = provider.additionalParameters ?? [:]
        
        // Add PKCE for providers that support it
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: provider.clientId,
            clientSecret: nil,
            scopes: provider.scopes,
            redirectURL: provider.redirectUri,
            responseType: OIDResponseTypeCode,
            additionalParameters: additionalParams
        )
        
        // Perform authorization request
        currentAuthorizationFlow = OIDAuthState.authState(
            byPresenting: request,
            presenting: presentingViewController
        ) { [weak self] authState, error in
            if let authState = authState {
                // Extract tokens
                let tokens = OAuthTokens(
                    accessToken: authState.lastTokenResponse?.accessToken ?? "",
                    refreshToken: authState.lastTokenResponse?.refreshToken,
                    idToken: authState.lastTokenResponse?.idToken,
                    expiresIn: authState.lastTokenResponse?.accessTokenExpirationDate?.timeIntervalSinceNow,
                    provider: provider.providerName
                )
                completion(.success(tokens))
                self?.pendingCompletion = nil
                self?.pendingProvider = nil
            } else if let error = error {
                print("🔐 OAuth: Authentication failed with error: \(error)")
                // Use error handler for provider-specific error handling
                let oauthError = OAuthErrorHandler.handle(error, for: provider.providerName)
                completion(.failure(oauthError))
                self?.pendingCompletion = nil
                self?.pendingProvider = nil
            } else {
                print("🔐 OAuth: Authentication failed with no error")
                completion(.failure(OAuthProviderError.authorizationFailed(provider: provider.providerName, underlying: nil)))
                self?.pendingCompletion = nil
                self?.pendingProvider = nil
            }
            
            self?.currentAuthorizationFlow = nil
        }
    }
    
    // Handle redirect URL
    func handleRedirect(url: URL) -> Bool {
        print("🔐 OAuth: Handling redirect URL: \(url)")
        
        // Check if this is a backend redirect with access token
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            // Check for error first
            if let error = queryItems.first(where: { $0.name == "error" })?.value {
                let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
                print("🔐 OAuth: Redirect contains error: \(errorDescription)")
                
                if let completion = pendingCompletion, let provider = pendingProvider {
                    let oauthError = OAuthProviderError.authorizationFailed(
                        provider: provider,
                        underlying: NSError(domain: "OAuthError", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: errorDescription
                        ])
                    )
                    completion(.failure(oauthError))
                    pendingCompletion = nil
                    pendingProvider = nil
                    currentAuthorizationFlow = nil
                    return true
                }
            }
            
            // Check for access token (backend already exchanged code)
            if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
               let provider = url.pathComponents.last {
                
                print("🔐 OAuth: Found access token in redirect for \(provider)")
                
                if let completion = pendingCompletion {
                    let tokens = OAuthTokens(
                        accessToken: accessToken,
                        refreshToken: nil,
                        idToken: nil,
                        expiresIn: nil,
                        provider: provider
                    )
                    completion(.success(tokens))
                    pendingCompletion = nil
                    pendingProvider = nil
                    currentAuthorizationFlow = nil
                    return true
                }
            }
        }
        
        // Standard OAuth flow (for providers that don't use backend callback)
        if let authFlow = currentAuthorizationFlow,
           authFlow.resumeExternalUserAgentFlow(with: url) {
            print("🔐 OAuth: Successfully resumed auth flow")
            currentAuthorizationFlow = nil
            return true
        }
        
        print("🔐 OAuth: Failed to resume auth flow - no current flow")
        return false
    }
}

// MARK: - OAuth Models
struct OAuthTokens {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: TimeInterval?
    let provider: String
}

