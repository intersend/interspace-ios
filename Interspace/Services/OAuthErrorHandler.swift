import Foundation

// MARK: - OAuth Error Types
enum OAuthProviderError: LocalizedError {
    case invalidConfiguration(provider: String)
    case missingClientId(provider: String)
    case authorizationFailed(provider: String, underlying: Error?)
    case tokenExchangeFailed(provider: String, underlying: Error?)
    case userInfoFetchFailed(provider: String, underlying: Error?)
    case userCancelled(provider: String)
    case networkError(provider: String, underlying: Error?)
    case rateLimited(provider: String, retryAfter: TimeInterval?)
    case invalidResponse(provider: String, details: String)
    case scopeDenied(provider: String, requiredScopes: [String])
    case providerSpecific(provider: String, code: String, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let provider):
            return "\(provider) OAuth configuration is invalid. Please check your settings."
            
        case .missingClientId(let provider):
            return "\(provider) client ID is missing. Please configure the app properly."
            
        case .authorizationFailed(let provider, let error):
            if let error = error {
                return "\(provider) authorization failed: \(error.localizedDescription)"
            }
            return "\(provider) authorization failed. Please try again."
            
        case .tokenExchangeFailed(let provider, let error):
            if let error = error {
                return "Failed to complete \(provider) sign-in: \(error.localizedDescription)"
            }
            return "Failed to complete \(provider) sign-in. Please try again."
            
        case .userInfoFetchFailed(let provider, _):
            return "Could not retrieve your \(provider) profile information."
            
        case .userCancelled(let provider):
            return "You cancelled the \(provider) sign-in."
            
        case .networkError(let provider, _):
            return "Network error while connecting to \(provider). Please check your connection."
            
        case .rateLimited(let provider, let retryAfter):
            if let retryAfter = retryAfter {
                let minutes = Int(retryAfter / 60)
                return "\(provider) rate limit exceeded. Please try again in \(minutes) minutes."
            }
            return "\(provider) rate limit exceeded. Please try again later."
            
        case .invalidResponse(let provider, let details):
            return "\(provider) returned an invalid response: \(details)"
            
        case .scopeDenied(let provider, let scopes):
            return "\(provider) requires the following permissions: \(scopes.joined(separator: ", "))"
            
        case .providerSpecific(let provider, _, let message):
            return "\(provider) error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidConfiguration, .missingClientId:
            return "Please contact support to report this configuration issue."
            
        case .authorizationFailed, .tokenExchangeFailed:
            return "Try signing in again. If the problem persists, try a different sign-in method."
            
        case .userInfoFetchFailed:
            return "Your account was created but some profile information is missing."
            
        case .userCancelled:
            return "You can try again or choose a different sign-in method."
            
        case .networkError:
            return "Check your internet connection and try again."
            
        case .rateLimited:
            return "Too many attempts. Please wait before trying again."
            
        case .invalidResponse:
            return "This might be a temporary issue. Please try again later."
            
        case .scopeDenied:
            return "Please accept all required permissions to continue."
            
        case .providerSpecific:
            return "Please try a different sign-in method or contact support."
        }
    }
}

// MARK: - OAuth Error Handler
class OAuthErrorHandler {
    
    // MARK: - Provider-Specific Error Handling
    
    static func handleDiscordError(_ error: Error) -> OAuthProviderError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(provider: "Discord", underlying: error)
            case .timedOut:
                return .authorizationFailed(provider: "Discord", underlying: error)
            default:
                break
            }
        }
        
        // Check for specific Discord error codes in response
        if let nsError = error as NSError?,
           let errorCode = nsError.userInfo["error"] as? String {
            switch errorCode {
            case "invalid_scope":
                return .scopeDenied(provider: "Discord", requiredScopes: ["identify", "email"])
            case "access_denied":
                return .userCancelled(provider: "Discord")
            case "rate_limited":
                return .rateLimited(provider: "Discord", retryAfter: nil)
            default:
                return .providerSpecific(provider: "Discord", code: errorCode, message: nsError.localizedDescription)
            }
        }
        
        return .authorizationFailed(provider: "Discord", underlying: error)
    }
    
    static func handleSpotifyError(_ error: Error) -> OAuthProviderError {
        // Spotify-specific rate limiting
        if let httpResponse = (error as NSError?)?.userInfo["response"] as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                return .rateLimited(provider: "Spotify", retryAfter: retryAfter)
            }
        }
        
        return .authorizationFailed(provider: "Spotify", underlying: error)
    }
    
    static func handleGitHubError(_ error: Error) -> OAuthProviderError {
        // GitHub-specific error handling
        if let nsError = error as NSError?,
           let errorDescription = nsError.userInfo["error_description"] as? String {
            if errorDescription.contains("email") {
                return .scopeDenied(provider: "GitHub", requiredScopes: ["read:user", "user:email"])
            }
        }
        
        return .authorizationFailed(provider: "GitHub", underlying: error)
    }
    
    static func handleFacebookError(_ error: Error) -> OAuthProviderError {
        // Facebook Graph API errors
        if let nsError = error as NSError?,
           let graphError = nsError.userInfo["com.facebook.sdk:FBSDKGraphRequestErrorGraphErrorCodeKey"] as? Int {
            switch graphError {
            case 190: // Invalid OAuth token
                return .tokenExchangeFailed(provider: "Facebook", underlying: error)
            case 10: // Permission denied
                return .scopeDenied(provider: "Facebook", requiredScopes: ["email", "public_profile"])
            default:
                return .providerSpecific(provider: "Facebook", code: "\(graphError)", message: error.localizedDescription)
            }
        }
        
        return .authorizationFailed(provider: "Facebook", underlying: error)
    }
    
    static func handleTikTokError(_ error: Error) -> OAuthProviderError {
        // TikTok-specific error codes
        if let nsError = error as NSError?,
           let errorCode = nsError.userInfo["error_code"] as? String {
            switch errorCode {
            case "10005": // Invalid client key
                return .invalidConfiguration(provider: "TikTok")
            case "10007": // Access denied
                return .userCancelled(provider: "TikTok")
            default:
                return .providerSpecific(provider: "TikTok", code: errorCode, message: error.localizedDescription)
            }
        }
        
        return .authorizationFailed(provider: "TikTok", underlying: error)
    }
    
    static func handleTwitterError(_ error: Error) -> OAuthProviderError {
        // Twitter API v2 errors
        if let nsError = error as NSError?,
           let twitterError = nsError.userInfo["errors"] as? [[String: Any]],
           let firstError = twitterError.first,
           let code = firstError["code"] as? Int {
            switch code {
            case 88: // Rate limit exceeded
                return .rateLimited(provider: "Twitter", retryAfter: 900) // 15 minutes
            case 89: // Invalid or expired token
                return .tokenExchangeFailed(provider: "Twitter", underlying: error)
            default:
                let message = firstError["message"] as? String ?? error.localizedDescription
                return .providerSpecific(provider: "Twitter", code: "\(code)", message: message)
            }
        }
        
        return .authorizationFailed(provider: "Twitter", underlying: error)
    }
    
    static func handleEpicGamesError(_ error: Error) -> OAuthProviderError {
        // Epic Games specific errors
        if let nsError = error as NSError?,
           let errorCode = nsError.userInfo["error"] as? String {
            switch errorCode {
            case "invalid_client":
                return .invalidConfiguration(provider: "Epic Games")
            case "consent_required":
                return .scopeDenied(provider: "Epic Games", requiredScopes: ["openid", "profile", "email"])
            default:
                return .providerSpecific(provider: "Epic Games", code: errorCode, message: error.localizedDescription)
            }
        }
        
        return .authorizationFailed(provider: "Epic Games", underlying: error)
    }
    
    static func handleShopifyError(_ error: Error) -> OAuthProviderError {
        // Shopify-specific errors
        if let nsError = error as NSError?,
           let shopifyError = nsError.userInfo["errors"] as? String {
            if shopifyError.contains("shop") {
                return .invalidConfiguration(provider: "Shopify")
            }
        }
        
        return .authorizationFailed(provider: "Shopify", underlying: error)
    }
    
    // MARK: - Generic Error Handler
    
    static func handle(_ error: Error, for provider: String) -> OAuthProviderError {
        // First check for common OAuth errors
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return .userCancelled(provider: provider)
            case .failed:
                return .authorizationFailed(provider: provider, underlying: error)
            case .invalidResponse:
                return .invalidResponse(provider: provider, details: error.localizedDescription)
            case .notHandled:
                return .providerSpecific(provider: provider, code: "not_handled", message: "The request was not handled")
            default:
                return .authorizationFailed(provider: provider, underlying: error)
            }
        }
        
        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(provider: provider, underlying: error)
            default:
                break
            }
        }
        
        // Provider-specific handling
        switch provider.lowercased() {
        case "discord":
            return handleDiscordError(error)
        case "spotify":
            return handleSpotifyError(error)
        case "github":
            return handleGitHubError(error)
        case "facebook":
            return handleFacebookError(error)
        case "tiktok":
            return handleTikTokError(error)
        case "twitter", "x":
            return handleTwitterError(error)
        case "epicgames", "epic":
            return handleEpicGamesError(error)
        case "shopify":
            return handleShopifyError(error)
        default:
            return .authorizationFailed(provider: provider, underlying: error)
        }
    }
}

// MARK: - Error Recovery Actions
extension OAuthProviderError {
    var shouldRetry: Bool {
        switch self {
        case .networkError, .tokenExchangeFailed:
            return true
        case .rateLimited:
            return false // Should wait before retrying
        default:
            return false
        }
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .scopeDenied, .userCancelled:
            return true
        default:
            return false
        }
    }
    
    var isConfigurationError: Bool {
        switch self {
        case .invalidConfiguration, .missingClientId:
            return true
        default:
            return false
        }
    }
}