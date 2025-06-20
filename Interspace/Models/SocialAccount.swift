import Foundation
import SwiftUI

struct SocialAccount: Identifiable, Codable {
    let id: String
    let provider: SocialProvider
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let createdAt: Date
    let updatedAt: Date
}

enum SocialProvider: String, Codable, CaseIterable, Identifiable {
    case google = "google"
    case apple = "apple"
    case telegram = "telegram"
    case farcaster = "farcaster"
    case twitter = "twitter"
    case github = "github"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        case .telegram:
            return "Telegram"
        case .farcaster:
            return "Farcaster"
        case .twitter:
            return "Twitter"
        case .github:
            return "GitHub"
        }
    }
    
    var iconName: String {
        switch self {
        case .google:
            return "g.circle.fill"
        case .apple:
            return "apple.logo"
        case .telegram:
            return "paperplane.fill"
        case .farcaster:
            return "f.square.fill"
        case .twitter:
            return "bird.fill"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var color: Color {
        switch self {
        case .google:
            return .red
        case .apple:
            return .black
        case .telegram:
            return .blue
        case .farcaster:
            return .purple
        case .twitter:
            return .blue
        case .github:
            return .black
        }
    }
}