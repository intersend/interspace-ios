# MetaMask iOS SDK Integration

This directory contains the MetaMask wallet integration using the native MetaMask iOS SDK.

## Setup Instructions

### 1. Add MetaMask iOS SDK Dependency

Add the MetaMask iOS SDK to your project via Swift Package Manager:

1. In Xcode, go to File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/MetaMask/metamask-ios-sdk`
3. Choose the latest stable version
4. Add to your app target

### 2. Update Info.plist

The following URL schemes are already configured in Info.plist:
- `metamask` - For querying if MetaMask is installed
- `interspace` - For handling callbacks

### 3. Add Files to Xcode Project

Add these files to your Xcode project:
- `MetaMaskService.swift`
- `MetaMaskConfiguration.swift`

Make sure they're added to the correct target.

## Features

- ✅ One-click connect with SIWE authentication
- ✅ Session persistence and restoration
- ✅ Signature normalization (0x prefix, lowercase)
- ✅ Transaction signing and sending
- ✅ Deep link handling
- ✅ Comprehensive error handling
- ✅ Debug logging

## Architecture

The implementation follows the `WalletProtocol` pattern:

```swift
MetaMaskService: WalletProtocol
    ├── connect() - Establishes connection with MetaMask
    ├── signMessage() - Signs SIWE messages
    ├── signTransaction() - Signs transactions
    ├── sendTransaction() - Sends transactions
    └── handleDeepLink() - Processes MetaMask callbacks
```

## Configuration

All configuration is centralized in `MetaMaskConfiguration.swift`:
- App metadata (name, URL)
- Deep link schemes
- Timeouts
- Error messages

## Usage

The MetaMask service is automatically instantiated by `WalletFactory` when requested:

```swift
let walletService = WalletServiceV2.shared
let result = try await walletService.connectWallet(.metamask)
```

## One-Click Connect Flow

1. User clicks "Authorize MetaMask"
2. App opens MetaMask with connection request
3. User approves in MetaMask
4. App receives callback and requests SIWE signature
5. User signs message in MetaMask
6. App receives signature and authenticates with backend

## Error Handling

The service handles various error scenarios:
- MetaMask not installed
- User cancellation
- Connection timeouts
- Invalid signatures
- Network errors

## Testing

To test the integration:

1. Install MetaMask on your iOS device/simulator
2. Create or import a wallet in MetaMask
3. Run the app and tap on MetaMask in the wallet selection
4. Approve the connection and sign the SIWE message
5. Verify successful authentication

## Troubleshooting

### MetaMask not opening
- Ensure MetaMask is installed
- Check URL scheme configuration in Info.plist
- Verify `LSApplicationQueriesSchemes` includes `metamask`

### Connection fails
- Check network connectivity
- Ensure MetaMask is on the correct network (Ethereum Mainnet)
- Try disconnecting and reconnecting

### Signature errors
- Verify SIWE message format matches backend expectations
- Check address normalization (should be lowercase with 0x prefix)
- Ensure nonce is fresh from backend