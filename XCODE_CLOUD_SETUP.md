# Xcode Cloud Setup Guide for Interspace iOS

This guide provides comprehensive instructions for setting up and managing Xcode Cloud workflows for the Interspace iOS project.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Workflow Configurations](#workflow-configurations)
5. [Environment Variables](#environment-variables)
6. [Custom Scripts](#custom-scripts)
7. [TestFlight Integration](#testflight-integration)
8. [Monitoring and Debugging](#monitoring-and-debugging)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Overview

Xcode Cloud provides native CI/CD integration directly within Xcode, offering:
- Automatic code signing management
- Native TestFlight integration
- Visual workflow configuration
- Optimized build infrastructure
- Seamless App Store Connect integration

## Prerequisites

Before setting up Xcode Cloud:

1. **Apple Developer Account**: Ensure you have admin access to the Apple Developer account
2. **App Store Connect Access**: Admin or App Manager role required
3. **Xcode 13+**: Latest version recommended
4. **Git Repository**: Project must be in a Git repository (GitHub, GitLab, or Bitbucket)

## Initial Setup

### Step 1: Enable Xcode Cloud

1. Open `Interspace.xcodeproj` in Xcode
2. Navigate to **Product → Xcode Cloud → Create Workflow**
3. Sign in with your Apple ID
4. Select your team: `579ZB4FX6N`
5. Grant Xcode Cloud access to your repository

### Step 2: Configure App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Xcode Cloud**
3. Select your app
4. Configure team settings and permissions

### Step 3: Set Up Environment Variables

In App Store Connect → Xcode Cloud → Environment Variables, add:

```bash
# API Configuration
API_BASE_URL_DEBUG=https://dev-api.interspace.com/api/v1
API_BASE_URL_RELEASE=https://api.interspace.com/api/v1

# Third-party Services
GOOGLE_CLIENT_ID=your-google-client-id
INFURA_API_KEY=your-infura-api-key
WALLETCONNECT_PROJECT_ID=your-walletconnect-project-id

# Notifications (Optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Crash Reporting (Optional)
CRASHLYTICS_API_KEY=your-crashlytics-key

# Google Service Info (Base64 encoded)
GOOGLE_SERVICE_INFO_PLIST=<base64-encoded-plist-content>
```

## Workflow Configurations

### 1. Development Workflow

**Purpose**: Quick feedback on feature branches

```yaml
Name: Development CI
Start Conditions:
  - Branch Changes: develop, feature/*
  
Actions:
  1. Build
     - Scheme: Interspace
     - Configuration: Debug
     - Platform: iOS
  2. Test
     - Scheme: Interspace
     - Destination: iPhone 15 (iOS 17.5)
  
Post-Actions:
  - Notify on failure only
  - Slack notification to #ios-dev
```

### 2. Pull Request Workflow

**Purpose**: Validate PRs before merging

```yaml
Name: PR Validation
Start Conditions:
  - Pull Request Changes
    - Target Branch: main
    - Source: Any
  
Actions:
  1. Build
     - Scheme: Interspace
     - Configuration: Debug
  2. Test
     - Scheme: Interspace
     - Destinations:
       - iPhone 15 Pro (iOS 17.5)
       - iPhone 13 (iOS 16.4)
     - Code Coverage: Required
  
Post-Actions:
  - Comment on PR with results
  - Require all tests to pass
```

### 3. Beta Release Workflow

**Purpose**: Deploy to TestFlight for internal testing

```yaml
Name: Beta Release
Start Conditions:
  - Branch Changes: beta
  
Actions:
  1. Archive
     - Scheme: Interspace
     - Configuration: Release
     - Platform: iOS
     - Distribution: TestFlight (Internal Testing)
  
Post-Actions:
  - Deploy to TestFlight
  - Notify Internal Testers group
  - Send email to QA team
```

### 4. Production Release Workflow

**Purpose**: Full release to App Store

```yaml
Name: Production Release
Start Conditions:
  - Tag Changes: v*.*.*
  
Actions:
  1. Test
     - Full test suite
     - All supported devices
  2. Archive
     - Scheme: Interspace
     - Configuration: Release
     - Platform: iOS
     - Distribution: TestFlight and App Store
  
Post-Actions:
  - Submit to App Store
  - Deploy to TestFlight External
  - Upload dSYMs
  - Notify release team
```

### 5. Nightly Build Workflow

**Purpose**: Regular integration testing

```yaml
Name: Nightly Build
Start Conditions:
  - Scheduled
    - Branch: develop
    - Time: 2:00 AM UTC
    - Frequency: Daily
  
Actions:
  1. Build
  2. Test (full suite)
  3. Archive
  
Post-Actions:
  - Deploy to TestFlight (Nightly Testers)
  - Generate test report
```

## Custom Scripts

The project includes three custom scripts in the `ci_scripts` directory:

### ci_post_clone.sh
- Sets up build configuration from environment variables
- Configures Google Service plist
- Validates environment setup
- Installs additional tools if needed

### ci_pre_xcodebuild.sh
- Updates build numbers automatically
- Runs SwiftLint checks
- Updates Info.plist with build metadata
- Generates build notes

### ci_post_xcodebuild.sh
- Processes test results
- Handles archive artifacts
- Uploads dSYMs to crash reporting
- Sends notifications
- Generates build summaries

## TestFlight Integration

### Internal Testing Setup

1. In App Store Connect:
   - Create "Internal Testers" group
   - Add team members
   - Configure automatic distribution

2. In Xcode Cloud workflow:
   - Select "TestFlight (Internal Testing Only)"
   - Choose the Internal Testers group
   - Enable automatic distribution

### External Testing Setup

1. In App Store Connect:
   - Create "Beta Testers" group
   - Set up public TestFlight link
   - Configure test information

2. In Xcode Cloud workflow:
   - Select "TestFlight and App Store"
   - Enable external testing
   - Set up beta app review

### Test Notes Automation

The `ci_pre_xcodebuild.sh` script automatically generates test notes including:
- Build information
- Recent changes
- Testing instructions
- Known issues

## Monitoring and Debugging

### Build Status

Monitor builds in:
1. **Xcode**: Report Navigator → Cloud tab
2. **App Store Connect**: Xcode Cloud section
3. **Notifications**: Email, Slack, or push notifications

### Accessing Build Logs

1. In Xcode:
   - Open Report Navigator (⌘9)
   - Select Cloud tab
   - Click on build
   - View detailed logs

2. In App Store Connect:
   - Navigate to Xcode Cloud
   - Select build
   - Download logs

### Common Build Artifacts

- **Test Results**: `.xcresult` bundles
- **Archives**: `.xcarchive` files
- **dSYMs**: Debug symbols for crash reporting
- **Build Summaries**: Markdown reports

## Best Practices

### 1. Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: Feature development
- `beta`: TestFlight releases
- `hotfix/*`: Emergency fixes

### 2. Version Management
- Use semantic versioning (v1.2.3)
- Let Xcode Cloud manage build numbers
- Tag releases consistently

### 3. Secret Management
- Never commit secrets to repository
- Use environment variables in App Store Connect
- Rotate API keys regularly

### 4. Performance Optimization
- Use parallel testing
- Enable build caching
- Run expensive tests only on release builds
- Use incremental builds

### 5. Cost Management
- Monitor compute hour usage
- Optimize workflow triggers
- Use scheduled builds efficiently
- Clean up old artifacts

## Troubleshooting

### Common Issues

#### Build Configuration Not Found
```bash
# Ensure BuildConfiguration.xcconfig exists
# Check environment variables are set in App Store Connect
```

#### Code Signing Failures
```bash
# Xcode Cloud manages signing automatically
# Ensure app ID and team are correct
# Check provisioning profiles in App Store Connect
```

#### Test Failures
```bash
# Review test logs in Xcode
# Check for environment-specific issues
# Ensure test data is available
```

#### Archive Distribution Issues
```bash
# Verify export compliance
# Check Info.plist requirements
# Ensure all capabilities are configured
```

### Debug Commands

Add these to scripts for debugging:

```bash
# Print all environment variables
env | grep CI_ | sort

# Check file system
ls -la "$CI_PRIMARY_REPOSITORY_PATH"

# Verify Xcode version
xcodebuild -version

# Check available simulators
xcrun simctl list devices
```

## Migration from GitHub Actions

During the transition period:

1. Run both systems in parallel
2. Start with non-critical workflows
3. Compare build times and results
4. Gradually migrate all iOS workflows
5. Keep security scanning in GitHub Actions

## Conclusion

Xcode Cloud provides a streamlined CI/CD experience specifically optimized for iOS development. The custom scripts and workflow configurations in this guide ensure:

- Fast feedback cycles
- Reliable TestFlight deployments
- Comprehensive testing
- Automated release processes

For support or questions, contact the iOS development team or refer to [Apple's Xcode Cloud documentation](https://developer.apple.com/documentation/xcode/xcode-cloud).