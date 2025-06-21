# API Integration Guide

This document describes how the Interspace iOS app integrates with the backend API.

## Table of Contents

1. [API Overview](#api-overview)
2. [Authentication](#authentication)
3. [Endpoints](#endpoints)
4. [Error Handling](#error-handling)
5. [Data Models](#data-models)
6. [Best Practices](#best-practices)

## API Overview

### Base URLs

```swift
// Environment-based URLs
Development: http://localhost:3000/api/v1
Staging: https://staging-api.interspace.com/api/v1
Production: https://api.interspace.com/api/v1
```

### Request Format

All requests use JSON format with the following headers:

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <access_token>
X-App-Version: 1.0.0
X-Platform: iOS
```

## Authentication

### Login Flow

1. **Email/Password Login**
   ```swift
   POST /auth/login
   {
     "email": "user@example.com",
     "password": "secure_password"
   }
   
   Response:
   {
     "accessToken": "eyJ...",
     "refreshToken": "eyJ...",
     "user": {
       "id": "user_id",
       "email": "user@example.com",
       "profiles": [...]
     }
   }
   ```

2. **Google Sign-In**
   ```swift
   POST /auth/google
   {
     "idToken": "google_id_token"
   }
   ```

3. **Apple Sign-In**
   ```swift
   POST /auth/apple
   {
     "identityToken": "apple_identity_token",
     "authorizationCode": "apple_auth_code",
     "user": {
       "email": "user@privaterelay.apple.com",
       "firstName": "John",
       "lastName": "Doe"
     }
   }
   ```

### Token Management

1. **Refresh Token**
   ```swift
   POST /auth/refresh
   {
     "refreshToken": "current_refresh_token"
   }
   
   Response:
   {
     "accessToken": "new_access_token",
     "refreshToken": "new_refresh_token"
   }
   ```

2. **Logout**
   ```swift
   POST /auth/logout
   {
     "refreshToken": "current_refresh_token"
   }
   ```

### Passkey Authentication

1. **Register Passkey**
   ```swift
   POST /auth/passkey/register
   {
     "challenge": "server_challenge",
     "credentialId": "credential_id",
     "publicKey": "public_key_data"
   }
   ```

2. **Authenticate with Passkey**
   ```swift
   POST /auth/passkey/authenticate
   {
     "credentialId": "credential_id",
     "signature": "auth_signature",
     "clientData": "client_data_json"
   }
   ```

## Endpoints

### User Management

1. **Get Current User**
   ```swift
   GET /users/me
   
   Response:
   {
     "id": "user_id",
     "email": "user@example.com",
     "profiles": [...],
     "settings": {...}
   }
   ```

2. **Update User**
   ```swift
   PATCH /users/me
   {
     "email": "newemail@example.com",
     "settings": {
       "notifications": true,
       "theme": "dark"
     }
   }
   ```

### Profile Management

1. **List Profiles**
   ```swift
   GET /profiles
   
   Response:
   {
     "profiles": [
       {
         "id": "profile_id",
         "username": "johndoe",
         "displayName": "John Doe",
         "bio": "Digital identity enthusiast",
         "avatar": "avatar_url",
         "isDefault": true
       }
     ]
   }
   ```

2. **Create Profile**
   ```swift
   POST /profiles
   {
     "username": "newprofile",
     "displayName": "New Profile",
     "bio": "Profile description",
     "avatar": "avatar_data_or_url"
   }
   ```

3. **Update Profile**
   ```swift
   PATCH /profiles/{profileId}
   {
     "displayName": "Updated Name",
     "bio": "Updated bio",
     "settings": {
       "privacy": "public"
     }
   }
   ```

4. **Delete Profile**
   ```swift
   DELETE /profiles/{profileId}
   ```

### Social Accounts

1. **Link Social Account**
   ```swift
   POST /profiles/{profileId}/social-accounts
   {
     "platform": "twitter",
     "accountId": "twitter_user_id",
     "username": "@johndoe",
     "accessToken": "platform_access_token"
   }
   ```

2. **List Social Accounts**
   ```swift
   GET /profiles/{profileId}/social-accounts
   
   Response:
   {
     "accounts": [
       {
         "id": "account_id",
         "platform": "twitter",
         "username": "@johndoe",
         "verified": true,
         "connectedAt": "2024-01-15T10:00:00Z"
       }
     ]
   }
   ```

3. **Unlink Social Account**
   ```swift
   DELETE /profiles/{profileId}/social-accounts/{accountId}
   ```

### Wallet Management

1. **Connect Wallet**
   ```swift
   POST /wallets/connect
   {
     "address": "0x...",
     "signature": "signed_message",
     "message": "original_message",
     "walletType": "metamask"
   }
   ```

2. **List Wallets**
   ```swift
   GET /wallets
   
   Response:
   {
     "wallets": [
       {
         "id": "wallet_id",
         "address": "0x...",
         "type": "metamask",
         "isPrimary": true,
         "balance": {
           "ETH": "1.5",
           "USDC": "1000"
         }
       }
     ]
   }
   ```

3. **Disconnect Wallet**
   ```swift
   DELETE /wallets/{walletId}
   ```

### App Management

1. **List Connected Apps**
   ```swift
   GET /profiles/{profileId}/apps
   
   Response:
   {
     "apps": [
       {
         "id": "app_id",
         "name": "DeFi App",
         "icon": "app_icon_url",
         "permissions": ["read_profile", "read_wallet"],
         "connectedAt": "2024-01-15T10:00:00Z"
       }
     ]
   }
   ```

2. **Revoke App Access**
   ```swift
   DELETE /profiles/{profileId}/apps/{appId}
   ```

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional context"
    }
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| UNAUTHORIZED | 401 | Invalid or expired token |
| FORBIDDEN | 403 | Insufficient permissions |
| NOT_FOUND | 404 | Resource not found |
| VALIDATION_ERROR | 400 | Invalid request data |
| RATE_LIMITED | 429 | Too many requests |
| SERVER_ERROR | 500 | Internal server error |

### iOS Error Handling

```swift
enum APIError: Error {
    case unauthorized
    case forbidden
    case notFound
    case validationError(String)
    case rateLimited(retryAfter: Int)
    case serverError
    case networkError
    case decodingError
}

// Usage
do {
    let profile = try await APIService.shared.fetchProfile()
} catch APIError.unauthorized {
    // Refresh token or re-authenticate
} catch APIError.rateLimited(let retryAfter) {
    // Wait and retry
} catch {
    // Handle other errors
}
```

## Data Models

### User Model
```swift
struct User: Codable {
    let id: String
    let email: String
    let profiles: [Profile]
    let settings: UserSettings
    let createdAt: Date
    let updatedAt: Date
}
```

### Profile Model
```swift
struct Profile: Codable {
    let id: String
    let username: String
    let displayName: String
    let bio: String?
    let avatar: String?
    let isDefault: Bool
    let socialAccounts: [SocialAccount]
    let settings: ProfileSettings
}
```

### Wallet Model
```swift
struct Wallet: Codable {
    let id: String
    let address: String
    let type: WalletType
    let isPrimary: Bool
    let balance: [String: String]?
    let chain: BlockchainNetwork
}
```

### Social Account Model
```swift
struct SocialAccount: Codable {
    let id: String
    let platform: SocialPlatform
    let username: String
    let profileUrl: String?
    let verified: Bool
    let connectedAt: Date
}
```

## Best Practices

### 1. Request Optimization

```swift
// Batch requests when possible
struct BatchRequest: Codable {
    let requests: [APIRequest]
}

// Use pagination for large datasets
GET /profiles?page=1&limit=20
```

### 2. Caching Strategy

```swift
// Cache responses with appropriate TTL
let cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
request.cachePolicy = cachePolicy

// Custom cache headers
Cache-Control: max-age=300
ETag: "resource_version"
```

### 3. Network Monitoring

```swift
// Monitor network status
NetworkMonitor.shared.isConnected

// Implement offline mode
if !NetworkMonitor.shared.isConnected {
    return cachedData
}
```

### 4. Security Best Practices

1. **Always use HTTPS in production**
2. **Implement certificate pinning**
3. **Store tokens securely in Keychain**
4. **Clear sensitive data from memory**
5. **Validate all server responses**

### 5. Rate Limiting

The API implements rate limiting:
- 100 requests per minute for authenticated users
- 20 requests per minute for unauthenticated users

Handle rate limits gracefully:
```swift
if response.statusCode == 429 {
    let retryAfter = response.headers["Retry-After"] ?? "60"
    await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
    return try await retry()
}
```

### 6. API Versioning

Always include API version in requests:
- Current version: v1
- Version included in base URL
- Check for deprecation headers

## WebSocket Connection

For real-time updates:

```swift
// Connect to WebSocket
let socket = WebSocket(url: "wss://api.interspace.com/ws")

// Subscribe to events
socket.send(json: [
    "type": "subscribe",
    "channels": ["profile_updates", "wallet_updates"]
])

// Handle messages
socket.onMessage { message in
    switch message.type {
    case "profile_updated":
        updateProfile(message.data)
    case "wallet_balance_changed":
        updateWalletBalance(message.data)
    default:
        break
    }
}
```

## Testing

### Mock Server

For development, use mock responses:

```swift
#if DEBUG
if ProcessInfo.processInfo.environment["USE_MOCK_API"] == "1" {
    return MockAPIService()
}
#endif
```

### API Documentation

Interactive API documentation available at:
- Development: http://localhost:3000/api-docs
- Production: https://api.interspace.com/api-docs

## Conclusion

This API integration guide provides the foundation for communicating with the Interspace backend. Always refer to the latest API documentation for updates and changes.