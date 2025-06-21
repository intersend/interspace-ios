# Development Mode Guide

## Overview

The Interspace iOS app includes a comprehensive development mode system that provides debugging tools, environment switching, and test features for developers.

## Features

### 1. Environment Configuration

The app supports three environments:
- **Development**: Local/ngrok endpoints for testing
- **Staging**: Staging server for pre-production testing  
- **Production**: Live production API

### 2. Developer Settings Access

There are two ways to access developer settings:

#### Method 1: Version Tap (Hidden Entry)
1. Navigate to Profile tab
2. Scroll to the "About" section
3. Tap on the "Version" row 7 times quickly
4. Developer Settings will appear

#### Method 2: Shake Gesture (Debug Builds Only)
1. Shake your device while the app is open
2. Developer Settings will appear automatically
3. Note: This only works in DEBUG builds

### 3. Developer Settings Options

#### Environment Section
- **Environment Switcher**: Switch between Development, Staging, and Production
- **API Base URL**: View current API endpoint

#### Debug Options
- **Debug Overlay**: Shows environment info and API call counter
- **Detailed Logging**: Enables verbose console logging for API calls
- **Mock Data**: Use mock data instead of real API calls

#### Test Views
- Access various test views for UI development:
  - Test View: Basic UI testing
  - Profile Test View: Profile component testing
  - Glass Effect Test View: Visual effect testing

#### Actions
- **Clear All Data**: Removes all user defaults and keychain data
- **Reset to Defaults**: Resets all debug settings to default values

### 4. Debug Overlay

When enabled, a small overlay appears showing:
- Current environment (Dev/Staging/Prod)
- API call counter
- Mock data status

### 5. Build Configurations

The app uses different build configurations:

#### Debug Configuration
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`
- Enables development features
- Uses development API endpoint
- Shake gesture enabled

#### Release Configuration  
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE`
- Disables all debug features
- Uses production API endpoint
- No developer access

## Setup

### For Developers

1. The app automatically detects if running in DEBUG mode
2. Development mode is enabled by default in DEBUG builds
3. API endpoints can be configured in `BuildConfiguration.xcconfig`

### Customizing Endpoints

Edit `Interspace/Supporting/BuildConfiguration.xcconfig`:

```xcconfig
// Development endpoint
API_BASE_URL_DEBUG = https://your-dev-api.com/api/v1

// Production endpoint
API_BASE_URL_RELEASE = https://your-prod-api.com/api/v1
```

### Adding New Test Views

1. Create your test view in `Interspace/Views/`
2. Add it to `TestViewsListView` in `DeveloperSettingsView.swift`
3. Access it through Developer Settings > Test Views

## Best Practices

1. Always use `#if DEBUG` for development-only code
2. Never ship developer features in release builds
3. Test environment switching thoroughly
4. Keep sensitive data out of debug logs
5. Clear development data before switching environments

## Troubleshooting

### Developer Settings Not Appearing
- Ensure you're running a DEBUG build
- Try both access methods (version tap and shake)
- Check that development mode is enabled

### API Calls Failing After Environment Switch
- Check network connectivity
- Verify the API endpoint is correct
- Clear app data and restart

### Debug Overlay Not Showing
- Enable it in Developer Settings
- Make sure development mode is active
- Restart the app after enabling