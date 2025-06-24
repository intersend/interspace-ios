# Email Account Linking Fix Summary

## Problem
When users tried to add an email account to their existing wallet profile, the iOS app was creating a new profile instead of linking the email to the existing account.

## Root Cause
The iOS app was calling `/api/v2/auth/authenticate` (which creates new accounts) instead of `/api/v2/auth/link-accounts` (which links accounts to the existing identity).

## Changes Made

### 1. Updated LinkAccountRequestV2 Model
**File:** `Interspace/Models/AuthModels.swift`

Changed from:
```swift
struct LinkAccountRequestV2: Codable {
    let strategy: String
    let identifier: String?
    let credential: String?
    let oauthCode: String?
    let appleAuth: AppleAuthRequest?
}
```

To:
```swift
struct LinkAccountRequestV2: Codable {
    let targetType: String
    let targetIdentifier: String
    let targetProvider: String?
    let linkType: String?
    let privacyMode: String?
}
```

### 2. Added New Response Models
**File:** `Interspace/Models/AuthModels.swift`

Added:
```swift
struct LinkAccountResponseV2: Codable {
    let success: Bool
    let link: IdentityLink
    let linkedAccount: AccountV2
    let accessibleProfiles: [ProfileSummary]
}

struct ProfileSummary: Codable {
    let id: String
    let name: String
    let linkedAccountsCount: Int
}
```

### 3. Updated AuthAPI
**File:** `Interspace/Services/AuthAPI.swift`

- Changed `linkAccountsV2` return type from `AuthResponseV2` to `LinkAccountResponseV2`
- Added `verifyEmailCodeV2` method for email verification

### 4. Fixed AccountLinkingService
**File:** `Interspace/Services/AccountLinkingService.swift`

Updated `linkEmailAccount` to:
1. First verify the email code
2. Then link the verified email using the proper endpoint

### 5. Updated AuthenticationManagerV2
**File:** `Interspace/Services/AuthenticationManagerV2.swift`

- Updated `linkAccount` method to use new request structure
- Added notification for account updates
- Added `Notification.Name.accountsUpdated`

### 6. Added Error Handling
**File:** `Interspace/Models/AuthModels.swift`

Added `invalidVerificationCode` error case to `AuthenticationError` enum.

## Result
Now when users add an email account while logged in:
1. The app verifies the email code
2. Uses `/api/v2/auth/link-accounts` to link the email to existing account
3. User maintains the same profile with multiple login methods
4. No new profile is created

## Testing
To test:
1. Log in with wallet
2. Go to profile settings
3. Add email account
4. Enter verification code
5. Verify the same profile is maintained (no new profile created)
6. Can now log in with either wallet OR email to access the same profile