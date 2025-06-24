# Interspace iOS - Credentials Setup Guide

## Important Security Notice

**NEVER commit real API keys or credentials to the repository!**

## Setup Instructions

1. **Copy the configuration template:**
   ```bash
   cp Interspace/Supporting/BuildConfiguration.xcconfig.template Interspace/Supporting/BuildConfiguration.xcconfig
   ```

2. **Update the configuration file with your actual credentials:**

   Edit `Interspace/Supporting/BuildConfiguration.xcconfig` and replace the placeholder values:

   - `YOUR_PRODUCTION_API_URL_HERE` - Your production API endpoint (e.g., https://api.interspace.fi/api/v2)
   - `YOUR_GOOGLE_CLIENT_ID_HERE` - Google OAuth Client ID from Google Cloud Console
   - `YOUR_GOOGLE_REVERSED_CLIENT_ID_HERE` - Reversed Google Client ID (format: com.googleusercontent.apps.YOUR_CLIENT_ID)
   - `YOUR_GOOGLE_SERVER_CLIENT_ID_HERE` - Web OAuth Client ID (must match backend configuration)
   - `YOUR_INFURA_API_KEY_HERE` - Infura API key from https://infura.io
   - `YOUR_WALLETCONNECT_PROJECT_ID_HERE` - WalletConnect Project ID from https://cloud.walletconnect.com

3. **Verify the file is ignored by git:**
   ```bash
   git status
   ```
   
   You should NOT see `BuildConfiguration.xcconfig` in the output.

## Getting Credentials

### Google OAuth Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select your project
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials:
   - iOS client for the app
   - Web client for backend validation
5. Add your iOS bundle ID to the iOS client
6. The reversed client ID format is: `com.googleusercontent.apps.<numeric-client-id>`

### Infura Setup
1. Sign up at [Infura](https://infura.io)
2. Create a new project
3. Copy the Project ID (this is your API key)

### WalletConnect Setup
1. Sign up at [WalletConnect Cloud](https://cloud.walletconnect.com)
2. Create a new project
3. Copy the Project ID

## Production Deployment

For production builds:
1. Use environment variables or CI/CD secrets
2. Never hardcode production credentials
3. Rotate API keys regularly
4. Monitor API key usage for anomalies

## Troubleshooting

If the app can't connect to services:
1. Verify all credentials are correctly entered
2. Check API key permissions and quotas
3. Ensure bundle ID matches OAuth configuration
4. Verify network connectivity

## Security Best Practices

1. **Use different credentials for development and production**
2. **Enable API key restrictions** (IP, bundle ID, etc.)
3. **Monitor usage** in respective dashboards
4. **Rotate keys** if exposed
5. **Use secret management tools** for team sharing