# Development Mode Implementation

## Overview

This implementation adds a development mode switch that allows creating profiles with placeholder wallets instead of using the MPC (Multi-Party Computation) server. This makes development and testing significantly easier while maintaining the same interface.

## Features Implemented

### Backend Changes

1. **Database Schema Update**
   - Added `isDevelopmentWallet` boolean field to SmartProfile model
   - Migration file created: `20240101000000_add_development_wallet_flag/migration.sql`

2. **Smart Profile Service**
   - Modified to use mock wallet service when `developmentMode` is true or `DISABLE_MPC` env var is set
   - Returns mock clientShare data for development profiles
   - Updates profile response to include isDevelopmentWallet flag

3. **Mock Session Wallet Service**
   - Enhanced to return complete mock clientShare data structure
   - Generates deterministic addresses and keys based on profile ID
   - Provides consistent wallet data for testing

4. **Smart Profile Controller**
   - Updated to accept `developmentMode` flag in create profile request
   - Made clientShare optional when developmentMode is true

### iOS Changes

1. **Models and Types**
   - Added `isDevelopmentWallet` and `clientShare` properties to SmartProfile model
   - Created ClientShare structure for storing development wallet data
   - Updated CreateProfileRequest to include developmentMode flag

2. **Session Coordinator**
   - Updated `createInitialProfile` to check EnvironmentConfiguration for development mode
   - Stores clientShare in keychain for development profiles

3. **Profile API**
   - Updated createProfile to accept developmentMode parameter
   - Passes developmentMode flag to backend when creating profiles

4. **Keychain Manager**
   - Already has methods to store/retrieve development client shares
   - Provides secure storage for development wallet data

5. **Development Wallet Service**
   - Provides mock wallet functionality for development
   - Generates deterministic addresses and signatures
   - Includes helper methods for development authentication

6. **UI Updates**
   - **ProfileHeaderView**: Shows yellow "DEV" badge for development wallets
   - **ProfileListRow**: Shows development indicator in profile list
   - **CreateProfileView**: Shows development mode banner when enabled
   - **DeveloperSettingsView**: Toggle for enabling/disabling development wallets

7. **Authentication Manager**
   - Added `authenticateWithDevelopmentWallet` extension method
   - Added `signOut` alias method for SessionCoordinator compatibility

## How It Works

1. When development mode is enabled (via Developer Settings in iOS app):
   - Profile creation requests include `developmentMode: true` flag
   - Backend uses mock wallet service instead of MPC server
   - Mock clientShare is generated and returned to iOS app
   - iOS app stores clientShare in keychain

2. Visual Indicators:
   - Yellow "DEV" badges appear on all development wallets
   - Development mode banner shows in profile creation view
   - Clear distinction between development and production wallets

3. Security:
   - Development mode only available in DEBUG builds
   - Mock wallets generate non-functional addresses
   - Clear visual separation prevents confusion

## Usage

### Enable Development Mode

1. In iOS app, go to Settings > Developer Settings
2. Toggle "Development Wallets" ON
3. Create new profiles - they will be created as development wallets

### Backend Configuration

Set environment variable to bypass MPC for all profiles:
```bash
DISABLE_MPC=true
```

Or let iOS app control it per profile via the developmentMode flag.

## Benefits

1. **No MPC Setup Required**: Developers can test full profile/wallet flows without complex MPC infrastructure
2. **Consistent Interface**: Same API and UI flow for both development and production
3. **Fast Development**: Instant wallet creation without network calls to MPC server
4. **Modular Design**: Easy to swap wallet providers (Silence Labs, Fireblocks, etc.)
5. **Clear Separation**: Visual indicators prevent mixing development and production data

## Next Steps

1. Run backend migration: `npx prisma migrate dev`
2. Test profile creation with development mode enabled
3. Verify clientShare storage and retrieval
4. Test authentication flows with development wallets