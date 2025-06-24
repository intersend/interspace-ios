# iOS MPC Wallet Implementation Plan

## Overview
This document outlines the implementation plan for integrating Silence Labs MPC wallet functionality into the Interspace iOS application. Currently, the app only supports development mode with mock wallets. This plan details the steps needed to implement production-ready MPC wallets.

## Current State
- ✅ Silence Labs SDK (`silentshard-artifacts`) is added as a dependency
- ✅ Client share data models are defined
- ✅ Development wallet service provides mock functionality
- ❌ No actual MPC implementation
- ❌ No WebSocket communication for MPC operations
- ❌ No secure storage implementation
- ❌ No biometric authentication integration

## Implementation Components

### 1. MPCWalletService
**Purpose**: Main orchestration layer for MPC wallet operations

```swift
class MPCWalletService {
    private let keyShareManager: MPCKeyShareManager
    private let secureStorage: MPCSecureStorage
    private let sessionManager: MPCSessionManager
    private let biometricAuth: BiometricAuthManager
    
    func generateWallet(for profileId: String) async throws -> WalletInfo
    func signTransaction(profileId: String, transaction: Transaction) async throws -> Signature
    func rotateKey(for profileId: String) async throws
    func createBackup(profileId: String, rsaKey: String) async throws -> BackupData
    func exportKey(profileId: String) async throws -> ExportData
}
```

### 2. MPCKeyShareManager
**Purpose**: Manages Silence Labs SDK operations

```swift
class MPCKeyShareManager {
    private var duoSession: DuoSession?
    
    func initializeSession(algorithm: Algorithm, cloudPublicKey: String) async throws
    func generateKeyShare() async throws -> KeyShare
    func signMessage(keyShare: KeyShare, message: Data, chainPath: String?) async throws -> String
    func refreshKeyShare(keyShare: KeyShare) async throws -> KeyShare
}
```

### 3. MPCSecureStorage
**Purpose**: Hardware-backed secure storage using iOS Keychain

```swift
class MPCSecureStorage {
    private let keychain = KeychainWrapper()
    
    func storeKeyShare(_ keyShare: KeyShare, for profileId: String) async throws
    func retrieveKeyShare(for profileId: String) async throws -> KeyShare?
    func deleteKeyShare(for profileId: String) async throws
    
    // Uses Secure Enclave when available
    private func encryptWithSecureEnclave(_ data: Data) throws -> Data
    private func decryptWithSecureEnclave(_ data: Data) throws -> Data
}
```

### 4. MPCSessionManager
**Purpose**: WebSocket communication for real-time MPC operations

```swift
class MPCSessionManager: NSObject {
    private var webSocket: URLSessionWebSocketTask?
    private let authToken: String
    
    func connect(to url: URL) async throws
    func sendMessage(_ message: MPCMessage) async throws
    func receiveMessage() async throws -> MPCMessage
    func disconnect()
    
    // Auto-reconnection with exponential backoff
    private func handleDisconnection()
}
```

### 5. BiometricAuthManager
**Purpose**: Face ID/Touch ID authentication

```swift
class BiometricAuthManager {
    private let context = LAContext()
    
    func authenticateUser(reason: String) async throws
    func checkBiometricAvailability() -> BiometricType?
    func setBiometricTimeout(_ seconds: TimeInterval)
}
```

## Implementation Steps

### Phase 1: Core Infrastructure (Week 1-2)
1. **Create Service Architecture**
   - Define protocols for all services
   - Implement dependency injection
   - Set up error handling

2. **Implement Secure Storage**
   - Keychain wrapper with AES-256-GCM encryption
   - Secure Enclave integration
   - Key migration support

3. **Biometric Authentication**
   - LAContext integration
   - Fallback mechanisms
   - Session management

### Phase 2: Silence Labs Integration (Week 3-4)
1. **DuoSession Setup**
   ```swift
   import silentshardduo
   
   let websocketConfig = WebsocketConfigBuilder()
       .withBaseUrl(config.duoNodeUrl)
       .withPort("443")
       .withSecure(true)
       .withAuthenticationToken(authToken)
       .build()
   
   let duoSession = SilentShardDuo.ECDSA.createDuoSession(
       cloudVerifyingKey: cloudPublicKey,
       websocketConfig: websocketConfig
   )
   ```

2. **Key Generation Implementation**
   ```swift
   func generateKeyShare() async throws -> KeyShare {
       let result = await duoSession.keygen()
       switch result {
       case .success(let keyShareData):
           let publicKey = await SilentShardDuo.ECDSA.getKeysharePublicKeyAsHex(keyShareData)
           return KeyShare(data: keyShareData, publicKey: publicKey)
       case .failure(let error):
           throw MPCError.keyGenerationFailed(error)
       }
   }
   ```

3. **Signature Generation**
   ```swift
   func signTransaction(keyShare: Data, messageHash: String, chainPath: String = "m") async throws -> String {
       let result = await duoSession.signature(
           keyshare: keyShare,
           message: messageHash,
           chainPath: chainPath
       )
       // Handle result
   }
   ```

### Phase 3: UI Integration (Week 5-6)
1. **MPCWalletSetupView**
   - Step-by-step wallet creation
   - Progress indicators
   - Error recovery UI

2. **MPCTransactionApprovalView**
   - Transaction details display
   - Biometric prompt
   - Signing feedback

3. **MPCSettingsView**
   - Backup/Export options
   - Key rotation
   - Security settings

### Phase 4: Testing & Security (Week 7-8)
1. **Unit Tests**
   - Service layer tests
   - Mock SDK responses
   - Error scenarios

2. **Integration Tests**
   - End-to-end flows
   - WebSocket reliability
   - Biometric edge cases

3. **Security Audit**
   - Key storage security
   - Network communication
   - Authentication flows

## Configuration

### Environment Variables
```swift
struct MPCConfiguration {
    static let duoNodeUrl: String = {
        #if DEBUG
        return "https://interspace-duo-node-dev.a.run.app"
        #else
        return "https://interspace-duo-node-prod.a.run.app"
        #endif
    }()
    
    static let cloudPublicKey = "..." // From backend
    static let websocketTimeout: TimeInterval = 30
    static let maxReconnectAttempts = 3
}
```

### Info.plist Updates
```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your MPC wallet</string>
```

## Error Handling

```swift
enum MPCError: LocalizedError {
    case sdkNotInitialized
    case keyShareNotFound
    case biometricAuthFailed
    case websocketConnectionFailed
    case signingFailed(String)
    case networkTimeout
    case invalidConfiguration
    
    var errorDescription: String? {
        // User-friendly error messages
    }
    
    var recoverySuggestion: String? {
        // Actionable recovery steps
    }
}
```

## Migration Strategy

1. **Feature Flag**
   ```swift
   if FeatureFlags.mpcWalletEnabled {
       // Use MPCWalletService
   } else {
       // Use DevelopmentWalletService
   }
   ```

2. **Gradual Rollout**
   - Internal testing with TestFlight
   - Beta user group
   - Phased production release

3. **Backward Compatibility**
   - Support existing development wallets
   - Migration path for users
   - Data preservation

## Security Considerations

1. **Key Storage**
   - Hardware-backed encryption
   - No cloud sync for key shares
   - Secure deletion

2. **Network Security**
   - Certificate pinning
   - Request signing
   - Replay protection

3. **User Authentication**
   - Biometric required for all operations
   - No fallback to passcode for critical operations
   - Session timeout after 5 minutes

## Performance Optimization

1. **Lazy Initialization**
   - Initialize MPC only when needed
   - Cache DuoSession instances
   - Preload WebSocket connections

2. **Background Processing**
   - Key generation in background queue
   - Progress updates on main thread
   - Cancellable operations

3. **Memory Management**
   - Clear sensitive data after use
   - Weak references where appropriate
   - Monitor memory usage

## Monitoring & Analytics

1. **Success Metrics**
   - Wallet creation success rate
   - Transaction signing time
   - WebSocket reliability

2. **Error Tracking**
   - Sentry integration
   - Detailed error context
   - User impact analysis

3. **Performance Metrics**
   - Operation latency
   - Network round trips
   - Battery impact

## Timeline

- **Week 1-2**: Core infrastructure
- **Week 3-4**: Silence Labs integration
- **Week 5-6**: UI implementation
- **Week 7-8**: Testing and security
- **Week 9-10**: Beta testing and fixes
- **Week 11-12**: Production release

## Dependencies

- `silentshardduo` SDK (already added)
- `CryptoKit` for additional cryptography
- `LocalAuthentication` for biometrics
- `Network` framework for WebSocket

## Success Criteria

1. ✅ Successful wallet generation with proper key distribution
2. ✅ Transaction signing within 3 seconds
3. ✅ 99.9% WebSocket connection reliability
4. ✅ Zero key material exposure
5. ✅ Comprehensive test coverage (>80%)
6. ✅ Security audit passed
7. ✅ User satisfaction score >4.5/5

## Next Steps

1. Review and approve implementation plan
2. Set up development environment
3. Create feature branch
4. Begin Phase 1 implementation
5. Weekly progress reviews