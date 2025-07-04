import SwiftUI

// MARK: - OAuth Provider Info
struct OAuthProviderInfo {
    let id: String
    let displayName: String
    let iconName: String
    let tintColor: Color
    
    static let providers: [OAuthProviderInfo] = [
        OAuthProviderInfo(id: "apple", displayName: "Apple", iconName: "apple_icon", tintColor: .black),
        OAuthProviderInfo(id: "google", displayName: "Google", iconName: "google_icon", tintColor: Color(red: 0.26, green: 0.52, blue: 0.96)),
        OAuthProviderInfo(id: "discord", displayName: "Discord", iconName: "discord_icon", tintColor: Color(red: 0.345, green: 0.396, blue: 0.949)),
        OAuthProviderInfo(id: "epicgames", displayName: "Epic Games", iconName: "epic_icon", tintColor: .black),
        OAuthProviderInfo(id: "facebook", displayName: "Facebook", iconName: "facebook_icon", tintColor: Color(red: 0.086, green: 0.467, blue: 0.949)),
        OAuthProviderInfo(id: "farcaster", displayName: "Farcaster", iconName: "farcaster_icon", tintColor: Color(red: 0.471, green: 0.318, blue: 0.663)),
        OAuthProviderInfo(id: "github", displayName: "GitHub", iconName: "github_icon", tintColor: .black),
        OAuthProviderInfo(id: "shopify", displayName: "Shopify", iconName: "shopify_icon", tintColor: Color(red: 0.384, green: 0.725, blue: 0.361)),
        OAuthProviderInfo(id: "spotify", displayName: "Spotify", iconName: "spotify_icon", tintColor: Color(red: 0.118, green: 0.843, blue: 0.376)),
        OAuthProviderInfo(id: "tiktok", displayName: "TikTok", iconName: "tiktok_icon", tintColor: .black),
        OAuthProviderInfo(id: "twitter", displayName: "X", iconName: "twitter_icon", tintColor: .black)
    ]
}