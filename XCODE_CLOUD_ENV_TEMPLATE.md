# Xcode Cloud Environment Variables Template

This template contains all the environment variables needed for Xcode Cloud workflows. Copy these to App Store Connect → Xcode Cloud → Environment Variables.

## Required Variables

These variables must be set for the build to succeed:

```bash
# API Configuration
API_BASE_URL_DEBUG=https://dev-api.interspace.com/api/v1
API_BASE_URL_RELEASE=https://api.interspace.com/api/v1

# Google Sign-In
GOOGLE_CLIENT_ID=your-google-client-id-here

# Blockchain Integration
INFURA_API_KEY=your-infura-api-key-here
WALLETCONNECT_PROJECT_ID=your-walletconnect-project-id-here
```

## Optional Variables

These enhance the build process but aren't required:

```bash
# Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Crash Reporting
CRASHLYTICS_API_KEY=your-crashlytics-api-key-here

# Analytics
ANALYTICS_API_KEY=your-analytics-key-here

# Feature Flags
FEATURE_FLAGS_API_KEY=your-feature-flags-key-here
```

## Google Service Configuration

For Google Sign-In, you need to provide the GoogleService-Info.plist content as a base64-encoded string:

```bash
# First, encode your GoogleService-Info.plist:
base64 -i GoogleService-Info.plist -o encoded.txt

# Then set the variable:
GOOGLE_SERVICE_INFO_PLIST=<contents-of-encoded.txt>
```

## Workflow-Specific Variables

Different workflows can have different configurations:

### Development Builds
```bash
# Override API URL for dev builds
API_BASE_URL_DEBUG=https://dev-api.interspace.com/api/v1
ENABLE_DEBUG_LOGGING=true
ENABLE_TEST_FEATURES=true
```

### Beta/TestFlight Builds
```bash
# Beta testing configuration
BETA_FEATURES_ENABLED=true
TESTFLIGHT_NOTES_TEMPLATE=beta
INTERNAL_TESTING_GROUP=beta-testers
```

### Production Builds
```bash
# Production configuration
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
OPTIMIZE_FOR_RELEASE=true
```

## Security Best Practices

1. **Never commit these values to your repository**
2. **Use App Store Connect's secure storage**
3. **Rotate keys regularly**
4. **Use read-only API keys where possible**
5. **Limit scope of service accounts**

## Setting Environment Variables

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Xcode Cloud** → **Manage Workflows**
3. Select **Environment Variables**
4. Click **+** to add a new variable
5. Enter the name and value
6. Choose visibility:
   - **All Workflows**: Available to all workflows
   - **Specific Workflows**: Only for selected workflows
7. Mark as **Secret** for sensitive values

## Verifying Variables

Add this to your `ci_post_clone.sh` to verify variables are set:

```bash
# Check required variables
required_vars=(
    "API_BASE_URL_RELEASE"
    "GOOGLE_CLIENT_ID"
    "INFURA_API_KEY"
    "WALLETCONNECT_PROJECT_ID"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required variable $var is not set"
        exit 1
    fi
done
```

## Example Values for Testing

For initial testing, you can use these placeholder values (replace with real values for production):

```bash
# Test API (points to mock server)
API_BASE_URL_DEBUG=https://jsonplaceholder.typicode.com
API_BASE_URL_RELEASE=https://jsonplaceholder.typicode.com

# Test Google Client ID (non-functional)
GOOGLE_CLIENT_ID=123456789-test.apps.googleusercontent.com

# Test Infura Key (Ethereum testnet)
INFURA_API_KEY=test1234567890abcdef

# Test WalletConnect ID
WALLETCONNECT_PROJECT_ID=test1234567890abcdef1234567890ab
```

## Troubleshooting

### Variable Not Available in Build

1. Ensure variable name matches exactly (case-sensitive)
2. Check workflow has access to the variable
3. Verify variable is marked as available to the workflow
4. Check for typos in variable names

### Secret Values Appearing in Logs

1. Mark variables as "Secret" in App Store Connect
2. Xcode Cloud will automatically mask these in logs
3. Avoid echoing secret values in scripts

### Build Fails Due to Missing Variable

1. Check the build logs for which variable is missing
2. Ensure all required variables are set
3. Verify no typos in variable names
4. Check that templates were properly replaced

## Next Steps

After setting up environment variables:

1. Create your first workflow in Xcode
2. Run a test build to verify configuration
3. Check build logs for any issues
4. Iterate on workflow configuration
5. Enable for your team

For more information, see the [Xcode Cloud documentation](https://developer.apple.com/documentation/xcode/configuring-environment-variables-in-xcode-cloud).