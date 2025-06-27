# Xcode Configuration Setup

## Issue
The BuildConfiguration.xcconfig file is not properly linked to the Xcode project, causing configuration values like WALLETCONNECT_PROJECT_ID to not be resolved.

## Temporary Fix Applied
I've added a fallback to hardcode the WalletConnect project ID when the Info.plist value is not resolved. This allows WalletConnect to work, but it's not the ideal solution.

## Proper Fix - Link BuildConfiguration.xcconfig to Xcode Project

1. Open `Interspace.xcodeproj` in Xcode
2. Select the project (top level) in the navigator
3. Select the "Interspace" project (not target) in the editor
4. Go to the "Info" tab
5. Under "Configurations", expand both "Debug" and "Release"
6. For each configuration (Debug and Release):
   - Click on "Interspace" under the configuration
   - In the dropdown, select "Other..." 
   - Navigate to `Interspace/Supporting/BuildConfiguration.xcconfig`
   - Click "Choose"
7. Clean and rebuild the project

## Verify Configuration
After linking the xcconfig file, you should see:
- API_BASE_URL properly resolved in Info.plist
- WALLETCONNECT_PROJECT_ID properly resolved
- GOOGLE_CLIENT_ID and other values properly resolved

## Current Workaround
The code currently falls back to the hardcoded project ID `936ce227c0152a29bdeef7d68794b0ac` when the configuration is not properly linked.