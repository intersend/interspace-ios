# Deployment Guide

This guide covers the complete deployment process for Interspace iOS, from development builds to App Store release.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [Build Process](#build-process)
4. [Code Signing](#code-signing)
5. [TestFlight Deployment](#testflight-deployment)
6. [App Store Release](#app-store-release)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Post-Release](#post-release)

## Prerequisites

### Apple Developer Account
- Enrolled in Apple Developer Program ($99/year)
- Admin or App Manager role
- Access to App Store Connect

### Certificates and Profiles
1. **Development Certificate**: For local builds
2. **Distribution Certificate**: For TestFlight/App Store
3. **Provisioning Profiles**: Match bundle ID and capabilities

### Required Tools
```bash
# Install fastlane (recommended)
brew install fastlane

# Verify installation
fastlane --version
```

## Environment Configuration

### 1. Production Configuration

Update `BuildConfiguration.xcconfig` for production:
```
API_BASE_URL_RELEASE = https://api.interspace.com/api/v1
GOOGLE_CLIENT_ID = your_production_google_client_id
INFURA_API_KEY = your_production_infura_key
WALLETCONNECT_PROJECT_ID = your_production_walletconnect_id
```

### 2. Bundle Identifier

Ensure production bundle ID in Xcode:
- Select project → Target → General
- Bundle Identifier: `com.interspace.ios`

### 3. Version Management

```xml
<!-- Info.plist -->
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>  <!-- User-facing version -->
<key>CFBundleVersion</key>
<string>100</string>     <!-- Build number -->
```

## Build Process

### Manual Build

1. **Select Release Scheme**:
   - Xcode → Product → Scheme → Edit Scheme
   - Run → Build Configuration → Release

2. **Archive the App**:
   ```
   Product → Archive
   ```
   Or via command line:
   ```bash
   xcodebuild archive \
     -workspace Interspace.xcworkspace \
     -scheme Interspace \
     -configuration Release \
     -archivePath build/Interspace.xcarchive
   ```

3. **Export for Distribution**:
   - Window → Organizer
   - Select archive → Distribute App
   - App Store Connect → Next

### Automated Build with Fastlane

1. **Setup Fastlane**:
   ```bash
   fastlane init
   ```

2. **Configure Fastfile**:
   ```ruby
   # fastlane/Fastfile
   default_platform(:ios)

   platform :ios do
     desc "Build and upload to TestFlight"
     lane :beta do
       increment_build_number
       build_app(
         workspace: "Interspace.xcworkspace",
         scheme: "Interspace",
         export_method: "app-store"
       )
       upload_to_testflight
     end

     desc "Release to App Store"
     lane :release do
       build_app(
         workspace: "Interspace.xcworkspace",
         scheme: "Interspace",
         export_method: "app-store"
       )
       upload_to_app_store(
         skip_metadata: false,
         skip_screenshots: false
       )
     end
   end
   ```

3. **Run Deployment**:
   ```bash
   # TestFlight
   fastlane beta

   # App Store
   fastlane release
   ```

## Code Signing

### Automatic Signing (Recommended)

1. In Xcode:
   - Target → Signing & Capabilities
   - ✓ Automatically manage signing
   - Select team

### Manual Signing

1. **Download Certificates**:
   - Apple Developer → Certificates
   - Download and install in Keychain

2. **Download Provisioning Profiles**:
   - Apple Developer → Profiles
   - Download and double-click to install

3. **Configure in Xcode**:
   - Target → Signing & Capabilities
   - Uncheck "Automatically manage signing"
   - Select profiles manually

### Match (Team Signing)

Using fastlane match for team certificate management:

```bash
# Setup
fastlane match init

# Sync certificates
fastlane match appstore
fastlane match development
```

## TestFlight Deployment

### 1. Upload Build

Via Xcode Organizer:
1. Window → Organizer
2. Select archive → Distribute App
3. App Store Connect → Upload

Via Fastlane:
```bash
fastlane beta
```

### 2. Configure TestFlight

In App Store Connect:
1. My Apps → Interspace → TestFlight
2. Add build to test group
3. Complete test information:
   - What to Test
   - Test Notes
   - Beta App Description

### 3. Internal Testing
- Automatically available to team
- Up to 100 internal testers
- No review required

### 4. External Testing
- Up to 10,000 testers
- Requires Beta App Review
- Add testers via:
  - Email invitation
  - Public link

## App Store Release

### 1. App Store Connect Setup

1. **App Information**:
   - Name: Interspace
   - Primary Language
   - Bundle ID
   - SKU

2. **Pricing and Availability**:
   - Price: Free
   - Availability: Select countries

3. **App Privacy**:
   - Complete privacy questionnaire
   - Data types collected
   - Data usage

### 2. Version Information

1. **Screenshots** (Required sizes):
   - 6.7" (iPhone 15 Pro Max)
   - 6.5" (iPhone 14 Plus)
   - 5.5" (iPhone 8 Plus)
   - 12.9" (iPad Pro)

2. **App Preview** (Optional):
   - Up to 3 videos
   - 15-30 seconds each

3. **Description**:
   ```
   Interspace is your gateway to managing digital identities...
   
   Features:
   • Multi-profile management
   • Secure wallet connections
   • Social account integration
   • Privacy-first design
   ```

4. **Keywords**:
   - Separate with commas
   - Maximum 100 characters
   - Example: "digital identity,wallet,social,privacy,profiles"

5. **Support URL**: https://interspace.app/support
6. **Marketing URL**: https://interspace.app

### 3. Build Selection

1. Select build from TestFlight builds
2. Add export compliance information
3. Set release options:
   - Manual release
   - Automatic release after approval
   - Scheduled release

### 4. Submit for Review

1. Answer review questions:
   - Sign-in required?
   - Demo account needed?
   - Export compliance

2. Add review notes:
   ```
   Test Account:
   Email: reviewer@interspace.app
   Password: [secure password]
   
   Special Instructions:
   - Use Google Sign-In for full feature access
   - Wallet features require testnet tokens
   ```

3. Submit for review

## CI/CD Pipeline

### GitHub Actions Configuration

```yaml
# .github/workflows/deploy.yml
name: Deploy to App Store

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    
    - name: Install Dependencies
      run: |
        pod install
        brew install fastlane
    
    - name: Setup Certificates
      env:
        MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
      run: |
        fastlane match appstore --readonly
    
    - name: Build and Deploy
      env:
        FASTLANE_USER: ${{ secrets.APPLE_ID }}
        FASTLANE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
        FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: ${{ secrets.APP_SPECIFIC_PASSWORD }}
      run: |
        fastlane release
```

### Environment Secrets

Configure in GitHub repository settings:
- `APPLE_ID`: Your Apple ID
- `APPLE_PASSWORD`: App-specific password
- `MATCH_PASSWORD`: Certificate encryption password
- `MATCH_GIT_URL`: Private repo for certificates

## Post-Release

### 1. Monitor Performance

In App Store Connect:
- **Crashes**: Monitor crash reports
- **Reviews**: Respond to user feedback
- **Analytics**: Track downloads and usage

### 2. Phased Release

Consider phased release for major updates:
- 7-day rollout
- Monitor metrics at each phase
- Pause if issues detected

### 3. Version Maintenance

```bash
# After release, bump version
agvtool next-version -all
agvtool new-marketing-version 1.1.0
```

### 4. Release Notes

Template for release notes:
```
What's New in Version X.X.X

✨ New Features:
• Feature 1
• Feature 2

🐛 Bug Fixes:
• Fixed issue with...
• Resolved problem where...

🚀 Improvements:
• Enhanced performance
• Updated UI elements

Thank you for using Interspace!
```

## Troubleshooting

### Common Issues

1. **Archive Not Appearing**:
   - Check scheme settings
   - Ensure Release configuration
   - Clean build folder

2. **Upload Fails**:
   - Verify App Store Connect access
   - Check bundle ID matches
   - Ensure valid certificates

3. **Validation Errors**:
   - Missing Info.plist keys
   - Invalid bundle version
   - Asset catalog issues

### Validation Checklist

Before submission:
- [ ] Increment version and build number
- [ ] Test on real devices
- [ ] Check all API endpoints point to production
- [ ] Remove debug code and logs
- [ ] Update screenshots if UI changed
- [ ] Test in-app purchases (if any)
- [ ] Verify deep links work
- [ ] Check push notifications
- [ ] Review app privacy details

## Best Practices

1. **Version Strategy**:
   - Semantic versioning (X.Y.Z)
   - Major.Minor.Patch
   - Build number always increases

2. **Release Cadence**:
   - Regular updates (2-4 weeks)
   - Critical fixes immediately
   - Major features quarterly

3. **Testing Strategy**:
   - Internal testing first
   - Beta test for 1-2 weeks
   - Gradual rollout

4. **Communication**:
   - Release notes in multiple languages
   - Update website/social media
   - Notify beta testers

## Emergency Procedures

### Expedited Review

For critical issues:
1. App Store Connect → Contact Us
2. Request expedited review
3. Explain critical nature
4. Usually processed within 48 hours

### Removing from Sale

If critical issue found:
1. App Store Connect → Pricing and Availability
2. Remove from all territories
3. Fix issue and resubmit

## Conclusion

Following this deployment guide ensures smooth releases of Interspace iOS. Always test thoroughly, maintain good release notes, and monitor post-release metrics for continuous improvement.