# MPC WebSocket to HTTP Migration Guide

## Overview
This guide explains how to migrate the iOS MPC implementation from direct WebSocket communication to HTTP endpoints via the backend proxy.

## Architecture Change

### Before (Direct WebSocket)
```
iOS App <--WebSocket--> Duo-Node <---> Silence Labs Server
```

### After (HTTP Proxy)
```
iOS App <--HTTP--> Backend <--WebSocket--> Duo-Node <---> Silence Labs Server
```

## Implementation Steps

### 1. Add New Files to Xcode Project
- `ProfileAPI+MPC.swift` - New HTTP endpoint methods
- `MPCWalletServiceHTTP.swift` - Updated wallet service using HTTP

### 2. Update MPCKeyShareManager
The `MPCKeyShareManager` needs new methods to generate P1 messages:

```swift
// Add to MPCKeyShareManager.swift
extension MPCKeyShareManager {
    /// Generate initial P1 messages for key generation
    func getInitialP1Messages() async throws -> [[String: Any]] {
        // Use Silence Labs SDK to generate P1 messages
        // This replaces the WebSocket message flow
        let p1KeyGen = P1KeyGen(sessionId: UUID().uuidString, x1: generateRandomBytes())
        let firstMessage = try await p1KeyGen.processMessage(nil)
        
        return [firstMessage.toDictionary()]
    }
    
    /// Generate P1 messages for signing
    func getSigningP1Messages(keyShare: MPCKeyShare, message: Data) async throws -> [[String: Any]] {
        // Use Silence Labs SDK to generate signing messages
        let p1Signature = P1Signature(
            sessionId: UUID().uuidString,
            messageHash: message,
            p1KeyShare: keyShare.silenceLabsKeyShare
        )
        let firstMessage = try await p1Signature.processMessage(nil)
        
        return [firstMessage.toDictionary()]
    }
}
```

### 3. Replace WebSocket Usage
In your views and view models, replace `MPCWalletService` with `MPCWalletServiceHTTP`:

```swift
// Before
@StateObject private var mpcService = MPCWalletService.shared

// After
@StateObject private var mpcService = MPCWalletServiceHTTP.shared
```

### 4. Update Key Generation Flow

```swift
// Example in a SwiftUI View
func generateWallet() async {
    do {
        showLoading = true
        
        let walletInfo = try await mpcService.generateWallet(for: profile.id)
        
        // Update UI with new wallet
        self.walletAddress = walletInfo.address
        showSuccess = true
        
    } catch {
        showError = true
        errorMessage = error.localizedDescription
    }
    showLoading = false
}
```

### 5. Update Transaction Signing

```swift
func signTransaction(_ transaction: TransactionRequest) async {
    do {
        let signature = try await mpcService.signTransaction(
            profileId: profile.id,
            transaction: transaction
        )
        
        // Use signature to submit transaction
        await submitTransaction(signature: signature)
        
    } catch {
        handleError(error)
    }
}
```

## Testing

### 1. Enable MPC Feature Flag (Debug)
```swift
UserDefaults.standard.set(true, forKey: "mpcWalletEnabled")
```

### 2. Test Key Generation
1. Create a new profile
2. The profile should automatically attempt MPC wallet generation
3. Verify the wallet address is stored

### 3. Test Signing
1. Create a test transaction
2. Sign it using the MPC wallet
3. Verify the signature is valid

## Environment Configuration

Update your app's configuration:

```swift
// Development
let API_BASE_URL = "https://interspace-backend-dev-784862970473.us-central1.run.app"

// Production
let API_BASE_URL = "https://api.interspace.chat"
```

## Error Handling

The new HTTP implementation includes better error handling:

```swift
enum MPCError: LocalizedError {
    case operationInProgress
    case keyShareNotFound
    case websocketNotConnected // No longer used
    case requestTimeout
    case operationFailed(String)
    case operationCancelled(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return "Another MPC operation is in progress"
        case .keyShareNotFound:
            return "No MPC wallet found for this profile"
        case .requestTimeout:
            return "Operation timed out"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .operationCancelled(let reason):
            return "Operation cancelled: \(reason)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

## Rollback Plan

If issues arise, you can temporarily switch back to WebSocket:
1. Keep both implementations (`MPCWalletService` and `MPCWalletServiceHTTP`)
2. Use a feature flag to toggle between them
3. Monitor error rates and performance

## Next Steps

1. Remove WebSocket dependencies once HTTP is stable
2. Implement proper 2FA for backup/export operations
3. Add analytics to track MPC operation success rates
4. Implement retry logic for failed operations