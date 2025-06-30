import Foundation
import AppAuth
import AuthenticationServices

// MARK: - OAuth Provider Protocol
protocol OAuthProvider {
    var providerName: String { get }
    var authorizationEndpoint: URL { get }
    var tokenEndpoint: URL { get }
    var clientId: String { get }
    var redirectUri: URL { get }
    var scopes: [String] { get }
    var additionalParameters: [String: String]? { get }
}

// MARK: - OAuth Provider Configurations
struct GoogleOAuthProvider: OAuthProvider {
    let providerName = "google"
    let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/google")!
    let scopes = ["openid", "email", "profile"]
    let additionalParameters: [String: String]? = nil
}

struct DiscordOAuthProvider: OAuthProvider {
    let providerName = "discord"
    let authorizationEndpoint = URL(string: "https://discord.com/api/oauth2/authorize")!
    let tokenEndpoint = URL(string: "https://discord.com/api/oauth2/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "DISCORD_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/discord")!
    let scopes = ["identify", "email"]
    let additionalParameters: [String: String]? = nil
}

struct SpotifyOAuthProvider: OAuthProvider {
    let providerName = "spotify"
    let authorizationEndpoint = URL(string: "https://accounts.spotify.com/authorize")!
    let tokenEndpoint = URL(string: "https://accounts.spotify.com/api/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/spotify")!
    let scopes = ["user-read-email", "user-read-private"]
    let additionalParameters: [String: String]? = nil
}

struct GitHubOAuthProvider: OAuthProvider {
    let providerName = "github"
    let authorizationEndpoint = URL(string: "https://github.com/login/oauth/authorize")!
    let tokenEndpoint = URL(string: "https://github.com/login/oauth/access_token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "GITHUB_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/github")!
    let scopes = ["read:user", "user:email"]
    let additionalParameters: [String: String]? = nil
}

struct FacebookOAuthProvider: OAuthProvider {
    let providerName = "facebook"
    let authorizationEndpoint = URL(string: "https://www.facebook.com/v18.0/dialog/oauth")!
    let tokenEndpoint = URL(string: "https://graph.facebook.com/v18.0/oauth/access_token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "FACEBOOK_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/facebook")!
    let scopes = ["email", "public_profile"]
    let additionalParameters: [String: String]? = ["display": "touch"]
}

struct ShopifyOAuthProvider: OAuthProvider {
    let providerName = "shopify"
    var authorizationEndpoint: URL {
        // Shopify requires shop domain, this will be set dynamically
        URL(string: "https://\(shopDomain)/admin/oauth/authorize")!
    }
    var tokenEndpoint: URL {
        URL(string: "https://\(shopDomain)/admin/oauth/access_token")!
    }
    let clientId = Bundle.main.object(forInfoDictionaryKey: "SHOPIFY_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/shopify")!
    let scopes = ["read_customers", "read_orders"]
    let additionalParameters: [String: String]? = nil
    
    private var shopDomain: String {
        // This would be set by user input or configuration
        UserDefaults.standard.string(forKey: "shopify_shop_domain") ?? "shop.myshopify.com"
    }
}

struct TwitterOAuthProvider: OAuthProvider {
    let providerName = "twitter"
    let authorizationEndpoint = URL(string: "https://twitter.com/i/oauth2/authorize")!
    let tokenEndpoint = URL(string: "https://api.twitter.com/2/oauth2/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "TWITTER_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/twitter")!
    let scopes = ["users.read", "tweet.read"]
    let additionalParameters: [String: String]? = ["code_challenge_method": "S256"]
}

struct TikTokOAuthProvider: OAuthProvider {
    let providerName = "tiktok"
    let authorizationEndpoint = URL(string: "https://www.tiktok.com/v2/auth/authorize")!
    let tokenEndpoint = URL(string: "https://open.tiktokapis.com/v2/oauth/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "TIKTOK_CLIENT_KEY") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/tiktok")!
    let scopes = ["user.info.basic", "user.info.profile"]
    let additionalParameters: [String: String]? = nil
}

struct EpicGamesOAuthProvider: OAuthProvider {
    let providerName = "epicgames"
    let authorizationEndpoint = URL(string: "https://www.epicgames.com/id/authorize")!
    let tokenEndpoint = URL(string: "https://api.epicgames.dev/epic/oauth/v2/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "EPIC_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/epicgames")!
    let scopes = ["openid", "profile", "email"]
    let additionalParameters: [String: String]? = nil
}

struct AppleOAuthProvider: OAuthProvider {
    let providerName = "apple"
    let authorizationEndpoint = URL(string: "https://appleid.apple.com/auth/authorize")!
    let tokenEndpoint = URL(string: "https://appleid.apple.com/auth/token")!
    let clientId = Bundle.main.object(forInfoDictionaryKey: "APPLE_CLIENT_ID") as? String ?? ""
    let redirectUri = URL(string: "com.interspace.ios:/oauth2redirect/apple")!
    let scopes = ["name", "email"]
    let additionalParameters: [String: String]? = ["response_mode": "form_post"]
}

// MARK: - OAuth Service
class OAuthProviderService: NSObject {
    static let shared = OAuthProviderService()
    
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    // Get provider by name
    func provider(for name: String) -> OAuthProvider? {
        switch name.lowercased() {
        case "apple": return AppleOAuthProvider()
        case "google": return GoogleOAuthProvider()
        case "discord": return DiscordOAuthProvider()
        case "spotify": return SpotifyOAuthProvider()
        case "github": return GitHubOAuthProvider()
        case "facebook": return FacebookOAuthProvider()
        case "shopify": return ShopifyOAuthProvider()
        case "twitter", "x": return TwitterOAuthProvider()
        case "tiktok": return TikTokOAuthProvider()
        case "epicgames", "epic": return EpicGamesOAuthProvider()
        default: return nil
        }
    }
    
    // Authenticate with provider
    func authenticate(
        with provider: OAuthProvider,
        presentingViewController: UIViewController,
        completion: @escaping (Result<OAuthTokens, Error>) -> Void
    ) {
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
            } else if let error = error {
                // Use error handler for provider-specific error handling
                let oauthError = OAuthErrorHandler.handle(error, for: provider.providerName)
                completion(.failure(oauthError))
            } else {
                completion(.failure(OAuthProviderError.authorizationFailed(provider: provider.providerName, underlying: nil)))
            }
            
            self?.currentAuthorizationFlow = nil
        }
    }
    
    // Handle redirect URL
    func handleRedirect(url: URL) -> Bool {
        if let authFlow = currentAuthorizationFlow,
           authFlow.resumeExternalUserAgentFlow(with: url) {
            currentAuthorizationFlow = nil
            return true
        }
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

