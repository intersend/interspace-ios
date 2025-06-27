# WalletConnect Setup Guide for iOS

## Important: Xcode Configuration Required

The keychain error `-34018` occurs because WalletConnect requires specific capabilities to be enabled in Xcode. The entitlements file has been updated, but you need to configure these capabilities in Xcode:

### 1. Enable App Groups Capability
1. Open `Interspace.xcodeproj` in Xcode
2. Select the "Interspace" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" and add "App Groups"
5. Add the group: `group.com.interspace.walletconnect`
6. Make sure the checkbox is checked

### 2. Enable Keychain Sharing Capability
1. Still in "Signing & Capabilities" tab
2. Click "+ Capability" and add "Keychain Sharing"
3. Add the keychain group: `com.interspace.ios`
4. Make sure it's enabled

### 3. Verify Entitlements
After enabling capabilities in Xcode, verify that your `Interspace.entitlements` file contains:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.interspace.walletconnect</string>
</array>
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.interspace.ios</string>
    <string>$(AppIdentifierPrefix)group.com.interspace.walletconnect</string>
</array>
```

### 4. Clean Build
1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Delete derived data if needed
3. Rebuild the project

## Code Configuration

The WalletConnect service is configured with:
```swift
Networking.configure(
    groupIdentifier: "group.com.interspace.walletconnect",
    projectId: "936ce227c0152a29bdeef7d68794b0ac",
    socketFactory: DefaultSocketFactory()
)
```

## Testing WalletConnect

Test URI:
```
wc:744dbf71677ab076a60a6b297139d52cb798c0637e99f32edf6ae7f18affb9df@2?relay-protocol=irn&symKey=3f43cce1b6cfdf099331f4346264b8048cebd675fe817bf803ae9a17d1cff337&expiryTimestamp=1750990737
```

## Troubleshooting

If you still get keychain errors:
1. Ensure you're using a development team in Xcode (even for simulator)
2. Try resetting the simulator: Device → Erase All Content and Settings
3. Make sure the provisioning profile includes the entitlements
4. For simulator testing, you might need to run on a real device

## Implementation Based on Reown Examples

Based on the official Reown Swift examples, the proper implementation requires:
1. App Groups for shared container access
2. Keychain Sharing for session persistence
3. Proper group identifier configuration
4. Matching entitlements and code configuration

The examples show that both DApp and Wallet apps use the same pattern for configuration.