# iOS App Migration to Flat Identity Model

## Overview

This guide explains how to update the iOS app to work with the new flat identity backend architecture.

## Key Changes

### 1. Authentication Flow

**Before (Hierarchical)**
```swift
1. Authenticate with wallet/email
2. Check if user has profiles
3. If no profiles → Show profile creation
4. Create profile manually
5. Enter app
```

**After (Flat Identity)**
```swift
1. Authenticate with wallet/email
2. Backend auto-creates "My Smartprofile"
3. Enter app immediately
```

### 2. Remove Profile Creation Step

The following components should be updated or removed:

- ✅ `EmailAuthorizationTray` - Already updated to not require profile creation
- ❌ `WalletConnectionView` - Remove profile creation sheet
- ❌ `AuthenticationCoordinator` - Remove profile creation logic
- ❌ `SessionCoordinator` - Update to handle automatic profiles

### 3. Use AuthenticationManagerV2

Replace `AuthenticationManager` with `AuthenticationManagerV2`:

```swift
// Before
@StateObject private var authManager = AuthenticationManager.shared

// After
@StateObject private var authManager = AuthenticationManagerV2.shared
```

### 4. Update Authentication Calls

```swift
// Email authentication
try await authManager.authenticate(with: WalletConnectionConfig(
    strategy: .email,
    email: email,
    verificationCode: code
))

// Wallet authentication
try await authManager.authenticate(with: WalletConnectionConfig(
    strategy: .wallet,
    walletAddress: address,
    signature: signature,
    message: message,
    walletType: walletType
))
```

### 5. Handle New User Flag

```swift
if authManager.isNewUser {
    // First time user - profile already created
    // Maybe show onboarding or tutorial
} else {
    // Returning user - show existing profiles
}
```

### 6. Profile Switching

```swift
// Switch between profiles
try await authManager.switchProfile(to: profileId)

// Access current profile
if let activeProfile = authManager.activeProfile {
    // Use active profile
}
```

### 7. Privacy Mode Selection

Add UI for privacy mode selection during account linking:

```swift
struct PrivacyModeSelector: View {
    @Binding var mode: PrivacyMode
    
    var body: some View {
        Picker("Privacy Mode", selection: $mode) {
            Text("Linked").tag(PrivacyMode.linked)
            Text("Partial").tag(PrivacyMode.partial)
            Text("Isolated").tag(PrivacyMode.isolated)
        }
    }
}
```

## Migration Checklist

### Phase 1: Core Updates
- [ ] Add `AuthenticationManagerV2.swift`
- [ ] Update `AccountType` and `PrivacyMode` enums
- [ ] Add new response models
- [ ] Update `APIService` to handle V2 endpoints

### Phase 2: UI Updates
- [ ] Remove profile creation requirement from `WalletConnectionView`
- [ ] Update `UniversalAddTray` to use new auth flow
- [ ] Remove `CreateProfileView` from auth flow
- [ ] Add privacy mode selector

### Phase 3: Session Management
- [ ] Update `SessionCoordinator` for automatic profiles
- [ ] Handle `isNewUser` flag appropriately
- [ ] Update profile switching UI
- [ ] Add identity graph visualization (optional)

### Phase 4: Testing
- [ ] Test new user onboarding
- [ ] Test existing user login
- [ ] Test account linking
- [ ] Test privacy modes
- [ ] Test profile switching

## Code Examples

### Remove Profile Creation from WalletConnectionView

```swift
// Remove these lines:
@State private var showProfileCreation = false
@State private var needsProfileCreation = false

// Remove the sheet:
.sheet(isPresented: $showProfileCreation) {
    CreateProfileView { profileName in
        // Not needed anymore
    }
}

// Update performAuthentication:
private func performAuthentication() async throws {
    // ... existing code ...
    
    try await authManager.authenticate(with: config)
    
    // Profile is automatically created for new users
    // No need to check or create profiles
}
```

### Update SessionCoordinator

```swift
// Remove manual profile creation
func handlePostAuthentication() async {
    // Old code - REMOVE
    // if profiles.isEmpty {
    //     showProfileCreation = true
    //     return
    // }
    
    // New code - profiles are auto-created
    if authManager.isNewUser {
        // Maybe show welcome message
        print("Welcome new user!")
    }
    
    // Continue to main app
    navigationPath.append(.main)
}
```

### Add Account Linking

```swift
struct AccountLinkingView: View {
    @StateObject private var authManager = AuthenticationManagerV2.shared
    @State private var privacyMode: PrivacyMode = .linked
    
    func linkEmail(_ email: String) async {
        do {
            try await authManager.linkAccount(
                type: .email,
                identifier: email
            )
        } catch {
            // Handle error
        }
    }
    
    func linkWallet(_ address: String) async {
        do {
            try await authManager.linkAccount(
                type: .wallet,
                identifier: address
            )
        } catch {
            // Handle error
        }
    }
}
```

## Benefits for Users

1. **Faster Onboarding** - No profile creation step
2. **Flexible Login** - Use any linked account
3. **Better Privacy** - Control account visibility
4. **Seamless Experience** - Apple-like simplicity

## Timeline

1. **Week 1**: Core authentication updates
2. **Week 2**: UI updates and testing
3. **Week 3**: Privacy features and polish
4. **Week 4**: Full deployment

## Support

For questions about the migration:
- Check backend docs: `/docs/FLAT_IDENTITY_ARCHITECTURE.md`
- Review API changes: `/src/routes/authRoutesV2.js`
- Test with dev backend first