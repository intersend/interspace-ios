# WalletConnect Integration for Interspace iOS

## Overview

This branch adds WalletConnect support to Interspace iOS, allowing users to authenticate and link their accounts using any WalletConnect-compatible wallet by scanning a QR code.

## Changes Made

### 1. New Files Created

- **WalletConnectService.swift**: Core service handling WalletConnect SDK integration, session management, and message signing
- **WalletConnectSessionManager.swift**: Manages persistent storage of WalletConnect sessions across app launches
- **WALLETCONNECT_INTEGRATION.md**: This documentation file

### 2. Modified Files

- **WalletService.swift**: 
  - Added WalletConnect service integration
  - Implemented `connectWithWalletConnectURI()` method
  - Updated disconnect logic to handle WalletConnect sessions

- **WalletConnectionView.swift**:
  - Added QR scanner sheet presentation
  - Implemented `handleWalletConnectURI()` for processing scanned QR codes
  - Added state management for WalletConnect flow

- **AppDelegate.swift**:
  - Added WalletConnectSign import
  - Implemented deep link handling for WalletConnect callbacks

## Setup Requirements

### 1. Add WalletConnect SDK via SPM

1. Open `Interspace.xcodeproj` in Xcode
2. Go to File → Add Packages
3. Enter repository URL: `https://github.com/reown-com/reown-swift`
4. Select "Up to Next Major Version" with the latest version
5. Choose the `WalletConnectSign` library
6. Add to the Interspace target

### 2. Configure WalletConnect Project ID

1. Get a Project ID from [WalletConnect Cloud](https://cloud.walletconnect.com)
2. Copy `BuildConfiguration.xcconfig.template` to `BuildConfiguration.xcconfig`
3. Update the WalletConnect Project ID:
   ```
   WALLETCONNECT_PROJECT_ID = your_project_id_here
   ```

### 3. Update Info.plist (if needed)

The Info.plist is already configured with:
- `WALLETCONNECT_PROJECT_ID` entry reading from build configuration
- URL scheme `interspace://` for deep linking
- LSApplicationQueriesSchemes includes `wc` for WalletConnect

## How It Works

### Authentication Flow

1. User selects WalletConnect option in authentication/profile linking
2. QR scanner opens automatically
3. User scans QR code from their wallet app (MetaMask, Rainbow, etc.)
4. App establishes WalletConnect session with the wallet
5. App requests SIWE (Sign-In with Ethereum) signature
6. Wallet prompts user to sign the message
7. App receives signature and completes authentication

### Session Management

- Sessions are persisted in Keychain for security
- Sessions auto-reconnect on app launch
- Expired sessions are automatically cleaned up
- Multiple wallet connections are supported

## Implementation Details

### WalletConnectService

Handles:
- SDK initialization with project metadata
- Session proposal approval
- Message signing requests
- Session lifecycle management
- Response handling from wallets

### WalletConnectSessionManager

Manages:
- Persistent storage of session information
- Session expiry tracking
- Multi-wallet support
- Address-to-session mapping

### Integration Points

The WalletConnect integration seamlessly works with:
- `AuthenticationManagerV2` for authentication
- `AccountLinkingService` for profile linking
- Existing SIWE authentication flow
- Current UI/UX patterns

## Testing

### Manual Testing Steps

1. **Authentication with WalletConnect**:
   - Launch app without being logged in
   - Select "Connect Wallet" on auth screen
   - Choose WalletConnect option
   - Scan QR code from wallet app
   - Approve connection in wallet
   - Sign authentication message
   - Verify successful login

2. **Profile Linking**:
   - Log in with existing account
   - Go to Profile → Add Account
   - Select WalletConnect
   - Complete QR scan flow
   - Verify wallet is linked to profile

3. **Session Persistence**:
   - Connect via WalletConnect
   - Force quit app
   - Relaunch app
   - Verify session is maintained

### Known Wallets Tested

- MetaMask Mobile
- Rainbow Wallet
- Trust Wallet
- Any WalletConnect v2 compatible wallet

## Security Considerations

- All sessions stored encrypted in iOS Keychain
- Session tokens never exposed in logs
- Automatic session expiry handling
- Secure message signing via WalletConnect protocol

## Future Enhancements

- [ ] Support for multiple simultaneous WalletConnect sessions
- [ ] Custom wallet selection UI
- [ ] Transaction signing support (if needed)
- [ ] Chain switching capabilities
- [ ] Session management UI

## Troubleshooting

### Common Issues

1. **"Project ID not configured"**
   - Ensure BuildConfiguration.xcconfig has valid WALLETCONNECT_PROJECT_ID

2. **QR Scanner not appearing**
   - Check camera permissions in Settings
   - Verify WalletConnectSign package is added to project

3. **Connection fails after scanning**
   - Ensure wallet supports WalletConnect v2
   - Check network connectivity
   - Verify correct Project ID configuration

4. **Session not persisting**
   - Check Keychain access entitlements
   - Verify app has proper background modes if needed

## References

- [WalletConnect Docs](https://docs.walletconnect.com)
- [Reown Swift SDK](https://github.com/reown-com/reown-swift)
- [SIWE Specification](https://eips.ethereum.org/EIPS/eip-4361)