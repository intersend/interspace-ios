# Reown (WalletConnect) Integration for MVP

## Overview
This document explains how to complete the Reown SDK integration to enable Ethereum wallet connections via WalletConnect v2.

## ✅ Project ID Configuration
**Good news!** Your `BuildConfiguration.xcconfig` already has a WalletConnect Project ID configured:
```
WALLETCONNECT_PROJECT_ID = 936ce227c0152a29bdeef7d68794b0ac
```

If this project ID doesn't work or you need your own:

1. Go to https://cloud.walletconnect.com/
2. Sign up/Sign in (it's free)
3. Create a new project:
   - Name: "Interspace"
   - Homepage: "https://interspace.fi"
   - Type: "dApp"
4. Copy your Project ID
5. Update it in your `BuildConfiguration.xcconfig` file

**Note:** The project ID is read from configuration at runtime. The app will show an error in the console if the project ID is missing or invalid.

## Current Implementation Status

### ✅ Completed
1. Created `ReownWalletService` with **real WalletConnect SDK implementation**
2. Updated `WalletFactory` to use `ReownWalletService` for all supported wallets
3. Updated UI to display WalletConnect URI in `ConnectionProgressView`
4. Added copy URI functionality and deep link support
5. Removed Solana-specific code from Phantom integration
6. Implemented real pairing URI generation using `Pair.instance.create()`
7. Added proper event handlers for session management
8. Implemented personal_sign for SIWE authentication
9. Fixed AppKitService errors by removing old presentModal() and authResponsePublisher references
10. Updated UniversalAddTray to use custom wallet selection flow
11. Updated WalletConnectOptionsView to use WalletFactory for wallet discovery

### 🚀 Ready to Use
The implementation now uses the real Reown/WalletConnect SDK. No more mock data!

## 1. Add Reown SDK to Project

### Option A: Swift Package Manager (Recommended)
1. In Xcode, go to File → Add Package Dependencies
2. Add the Reown SDK URL: `https://github.com/reown-com/reown-swift`
3. Select the latest stable version
4. Add the following products to your target:
   - `WalletConnectSign`
   - `WalletConnectPairing`
   - `WalletConnectRelay`
   - `WalletConnectNetworking`

### Option B: CocoaPods
Add to your Podfile:
```ruby
pod 'WalletConnectSwiftV2', '~> 1.0'
```

## 2. ✅ SDK Integration Complete!

The SDK has been integrated and the implementation is using real WalletConnect functionality:

- ✅ Real pairing URI generation with `Pair.instance.create()`
- ✅ Proper session management with event handlers
- ✅ Personal sign implementation for SIWE
- ✅ Deep link support for all major wallets
- ✅ Ethereum-only focus (removed Solana support)

**The only thing you need to do is update the Project ID!**

## 3. Test the Integration

### Testing Steps:
1. Run the app
2. Select any wallet (Phantom, MetaMask, Rainbow, etc.)
3. You should see:
   - Connection progress view
   - WalletConnect URI displayed
   - "Open [Wallet Name]" button
   - Copy URI button
4. Click "Open [Wallet]" to deep link to the wallet app
5. Or copy the URI and paste it in the wallet's WalletConnect scanner

### Expected Flow:
1. User selects wallet → Reown generates pairing URI
2. URI is displayed in ConnectionProgressView
3. User opens wallet app via deep link or copies URI
4. Wallet connects and returns Ethereum address
5. App requests SIWE signature
6. User signs message in wallet
7. Authentication completes

## Current Features (MVP)
- ✅ Real WalletConnect v2 implementation
- ✅ Ethereum mainnet support
- ✅ SIWE (Sign-In With Ethereum) authentication
- ✅ Deep linking to wallet apps
- ✅ URI copy functionality
- ✅ Session persistence
- ✅ Automatic reconnection

## How It Works
1. User selects a wallet (Phantom, MetaMask, Rainbow, etc.)
2. ReownWalletService generates a real WalletConnect pairing URI
3. URI is displayed with copy button and "Open [Wallet]" button
4. User approves connection in their wallet
5. Session is established and Ethereum address is returned
6. App requests SIWE signature
7. User signs the message in their wallet
8. Authentication completes and user is logged in

## Files Modified
- `/Interspace/Services/Wallets/Reown/ReownWalletService.swift` - Main service implementation
- `/Interspace/Services/Wallets/WalletFactory.swift` - Updated to use Reown for wallets
- `/Interspace/Services/WalletServiceV2.swift` - Added URI exposure
- `/Interspace/Views/Components/ConnectionProgressView.swift` - Added URI display
- `/Interspace/Services/Wallets/PhantomWallet/PhantomWalletService.swift` - Disabled for Ethereum

## Notes
- All wallets now use ReownWalletService for Ethereum connections
- Phantom deep links are disabled in favor of WalletConnect
- The UI remains unchanged except for URI display
- Deep links are configured for each wallet type

## Troubleshooting

### If you get build errors:
1. Make sure all 4 WalletConnect packages are added:
   - WalletConnectSign
   - WalletConnectPairing
   - WalletConnectRelay
   - WalletConnectNetworking

2. Clean build folder (Cmd+Shift+K)
3. Reset package caches: File → Packages → Reset Package Caches

### If wallet connection fails:
1. Check that you have a valid Project ID
2. Make sure the wallet app is installed on the device/simulator
3. Check console logs for detailed error messages

### Testing on Simulator:
- MetaMask and Rainbow work well on iOS Simulator
- Copy the URI and paste it in the wallet's WalletConnect scanner