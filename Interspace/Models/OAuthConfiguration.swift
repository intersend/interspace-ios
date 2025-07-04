import Foundation

// MARK: - OAuth Configuration
struct OAuthConfiguration {
    let providerName: String
    let displayName: String
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userInfoEndpoint: URL?
    let scopes: [String]
    let additionalParameters: [String: String]?
    
    // Client ID is loaded from Info.plist
    var clientId: String {
        let key = "\(providerName.uppercased())_CLIENT_ID"
        return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
    
    // Standard redirect URI format
    var redirectUri: URL {
        // Providers that don't support custom URL schemes need to use backend callback
        let providersNeedingBackendCallback = ["github", "facebook", "shopify"]
        
        if providersNeedingBackendCallback.contains(providerName.lowercased()) {
            // Use backend callback URL based on environment
            let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? 
                         Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? 
                         "https://api.interspace.com"
            return URL(string: "\(baseURL)/auth/oauth/callback/\(providerName)")!
        } else {
            // Use custom URL scheme for providers that support it
            return URL(string: "com.interspace.ios:/oauth2redirect/\(providerName)")!
        }
    }
}

// MARK: - OAuth Provider Registry
struct OAuthProviderRegistry {
    static let providers: [String: OAuthConfiguration] = [
        "google": OAuthConfiguration(
            providerName: "google",
            displayName: "Google",
            authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo"),
            scopes: ["openid", "email", "profile"],
            additionalParameters: nil
        ),
        
        "github": OAuthConfiguration(
            providerName: "github",
            displayName: "GitHub",
            authorizationEndpoint: URL(string: "https://github.com/login/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://github.com/login/oauth/access_token")!,
            userInfoEndpoint: URL(string: "https://api.github.com/user"),
            scopes: ["read:user", "user:email"],
            additionalParameters: nil
        ),
        
        "discord": OAuthConfiguration(
            providerName: "discord",
            displayName: "Discord",
            authorizationEndpoint: URL(string: "https://discord.com/api/oauth2/authorize")!,
            tokenEndpoint: URL(string: "https://discord.com/api/oauth2/token")!,
            userInfoEndpoint: URL(string: "https://discord.com/api/users/@me"),
            scopes: ["identify", "email"],
            additionalParameters: nil
        ),
        
        "spotify": OAuthConfiguration(
            providerName: "spotify",
            displayName: "Spotify",
            authorizationEndpoint: URL(string: "https://accounts.spotify.com/authorize")!,
            tokenEndpoint: URL(string: "https://accounts.spotify.com/api/token")!,
            userInfoEndpoint: URL(string: "https://api.spotify.com/v1/me"),
            scopes: ["user-read-email", "user-read-private"],
            additionalParameters: nil
        ),
        
        "twitter": OAuthConfiguration(
            providerName: "twitter",
            displayName: "X (Twitter)",
            authorizationEndpoint: URL(string: "https://twitter.com/i/oauth2/authorize")!,
            tokenEndpoint: URL(string: "https://api.twitter.com/2/oauth2/token")!,
            userInfoEndpoint: URL(string: "https://api.twitter.com/2/users/me"),
            scopes: ["users.read", "tweet.read"],
            additionalParameters: ["code_challenge_method": "S256"]
        ),
        
        "facebook": OAuthConfiguration(
            providerName: "facebook",
            displayName: "Facebook",
            authorizationEndpoint: URL(string: "https://www.facebook.com/v18.0/dialog/oauth")!,
            tokenEndpoint: URL(string: "https://graph.facebook.com/v18.0/oauth/access_token")!,
            userInfoEndpoint: URL(string: "https://graph.facebook.com/me?fields=id,name,email,picture"),
            scopes: ["email", "public_profile"],
            additionalParameters: ["display": "touch"]
        ),
        
        "tiktok": OAuthConfiguration(
            providerName: "tiktok",
            displayName: "TikTok",
            authorizationEndpoint: URL(string: "https://www.tiktok.com/v2/auth/authorize")!,
            tokenEndpoint: URL(string: "https://open.tiktokapis.com/v2/oauth/token")!,
            userInfoEndpoint: URL(string: "https://open.tiktokapis.com/v2/user/info/"),
            scopes: ["user.info.basic", "user.info.profile"],
            additionalParameters: nil
        ),
        
        "epicgames": OAuthConfiguration(
            providerName: "epicgames",
            displayName: "Epic Games",
            authorizationEndpoint: URL(string: "https://www.epicgames.com/id/authorize")!,
            tokenEndpoint: URL(string: "https://api.epicgames.dev/epic/oauth/v2/token")!,
            userInfoEndpoint: URL(string: "https://api.epicgames.dev/epic/id/v2/accounts"),
            scopes: ["openid", "profile", "email"],
            additionalParameters: nil
        ),
        
        "apple": OAuthConfiguration(
            providerName: "apple",
            displayName: "Apple",
            authorizationEndpoint: URL(string: "https://appleid.apple.com/auth/authorize")!,
            tokenEndpoint: URL(string: "https://appleid.apple.com/auth/token")!,
            userInfoEndpoint: nil, // Apple doesn't have a separate user info endpoint
            scopes: ["name", "email"],
            additionalParameters: ["response_mode": "form_post"]
        ),
        
        "shopify": OAuthConfiguration(
            providerName: "shopify",
            displayName: "Shopify",
            authorizationEndpoint: URL(string: "https://shop.myshopify.com/admin/oauth/authorize")!, // Dynamic
            tokenEndpoint: URL(string: "https://shop.myshopify.com/admin/oauth/access_token")!, // Dynamic
            userInfoEndpoint: URL(string: "https://shop.myshopify.com/admin/api/2024-01/shop.json"), // Dynamic
            scopes: ["read_customers", "read_orders"],
            additionalParameters: nil
        )
    ]
    
    static func provider(for name: String) -> OAuthConfiguration? {
        return providers[name.lowercased()]
    }
}

// MARK: - Dynamic Provider Handling
extension OAuthConfiguration {
    // For providers that need dynamic URLs (like Shopify)
    func withDynamicUrls(shopDomain: String? = nil) -> OAuthConfiguration {
        guard providerName == "shopify", let domain = shopDomain else {
            return self
        }
        
        return OAuthConfiguration(
            providerName: providerName,
            displayName: displayName,
            authorizationEndpoint: URL(string: "https://\(domain)/admin/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://\(domain)/admin/oauth/access_token")!,
            userInfoEndpoint: URL(string: "https://\(domain)/admin/api/2024-01/shop.json"),
            scopes: scopes,
            additionalParameters: additionalParameters
        )
    }
}