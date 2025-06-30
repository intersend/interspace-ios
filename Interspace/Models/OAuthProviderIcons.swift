import Foundation

// OAuth Provider Icon URLs from Google Cloud Storage
struct OAuthProviderIconURLs {
    static let baseURL = "https://storage.googleapis.com/interspace-oauth-icons/"
    
    static let icons: [String: IconSet] = [
        "apple": IconSet(
            standard: "\(baseURL)apple_icon.png",
            retina: "\(baseURL)apple_icon@2x.png",
            retinaHD: "\(baseURL)apple_icon@3x.png"
        ),
        "discord": IconSet(
            standard: "\(baseURL)discord_icon.png",
            retina: "\(baseURL)discord_icon@2x.png",
            retinaHD: "\(baseURL)discord_icon@3x.png"
        ),
        "epic": IconSet(
            standard: "\(baseURL)epic_icon.png",
            retina: "\(baseURL)epic_icon@2x.png",
            retinaHD: "\(baseURL)epic_icon@3x.png"
        ),
        "epicgames": IconSet(
            standard: "\(baseURL)epic_icon.png",
            retina: "\(baseURL)epic_icon@2x.png",
            retinaHD: "\(baseURL)epic_icon@3x.png"
        ),
        "facebook": IconSet(
            standard: "\(baseURL)facebook_icon.png",
            retina: "\(baseURL)facebook_icon@2x.png",
            retinaHD: "\(baseURL)facebook_icon@3x.png"
        ),
        "github": IconSet(
            standard: "\(baseURL)github_icon.png",
            retina: "\(baseURL)github_icon@2x.png",
            retinaHD: "\(baseURL)github_icon@3x.png"
        ),
        "google": IconSet(
            standard: "\(baseURL)google_icon.png",
            retina: "\(baseURL)google_icon@2x.png",
            retinaHD: "\(baseURL)google_icon@3x.png"
        ),
        "shopify": IconSet(
            standard: "\(baseURL)shopify_icon.png",
            retina: "\(baseURL)shopify_icon@2x.png",
            retinaHD: "\(baseURL)shopify_icon@3x.png"
        ),
        "spotify": IconSet(
            standard: "\(baseURL)spotify_icon.png",
            retina: "\(baseURL)spotify_icon@2x.png",
            retinaHD: "\(baseURL)spotify_icon@3x.png"
        ),
        "tiktok": IconSet(
            standard: "\(baseURL)tiktok_icon.png",
            retina: "\(baseURL)tiktok_icon@2x.png",
            retinaHD: "\(baseURL)tiktok_icon@3x.png"
        ),
        "twitter": IconSet(
            standard: "\(baseURL)twitter_icon.png",
            retina: "\(baseURL)twitter_icon@2x.png",
            retinaHD: "\(baseURL)twitter_icon@3x.png"
        )
    ]
    
    struct IconSet {
        let standard: String    // 1x - 60x60
        let retina: String      // 2x - 120x120
        let retinaHD: String    // 3x - 180x180
    }
}