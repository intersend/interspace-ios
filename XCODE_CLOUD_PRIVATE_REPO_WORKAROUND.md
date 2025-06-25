# Xcode Cloud Private Repository Workaround

## The Issue
The project includes a private Swift Package dependency (SilentShard) that requires authentication. Xcode Cloud needs access to all dependencies to build the project.

## Solutions

### Option 1: Use Xcode Cloud Secrets (Recommended)

1. **Remove hardcoded credentials from the package URL**
   - Open `Interspace.xcodeproj` in Xcode
   - Go to Project Settings → Package Dependencies
   - Find the SilentShard package
   - Update the URL from:
     ```
     https://dushyantsutharsilencelaboratories:TOKEN@github.com/...
     ```
     To:
     ```
     https://github.com/dushyantsutharsilencelaboratories/silentshard-artifacts
     ```

2. **Add GitHub Personal Access Token to Xcode Cloud**
   - In App Store Connect → Xcode Cloud → Settings
   - Add a new secret named `GITHUB_PAT`
   - Set the value to a GitHub Personal Access Token with `repo` scope

3. **Configure Git credentials in ci_post_clone.sh**
   ```bash
   # Add this to ci_post_clone.sh
   if [ -n "$GITHUB_PAT" ]; then
       git config --global url."https://${GITHUB_PAT}@github.com/".insteadOf "https://github.com/"
   fi
   ```

### Option 2: Use SSH Authentication

1. **Change package URL to SSH format**
   ```
   git@github.com:dushyantsutharsilencelaboratories/silentshard-artifacts.git
   ```

2. **Add SSH key to Xcode Cloud**
   - Generate a new SSH key pair
   - Add public key to the private repo as a deploy key
   - Add private key to Xcode Cloud secrets

### Option 3: Mirror to Your Organization (If Allowed)

1. **Fork or mirror the private repo to your organization**
2. **Update the package URL to point to your fork**
3. **Grant Xcode Cloud access to your organization's repos**

### Option 4: Local Package Override (Development Only)

1. **Clone the private repo locally**
2. **Add local package override in Xcode**
   - File → Add Package Dependencies
   - Click "Add Local..."
   - Select the cloned repository

3. **For Xcode Cloud, use a pre-build script**
   ```bash
   # In ci_post_clone.sh
   if [ ! -d "LocalPackages/silentshard-artifacts" ]; then
       git clone https://${GITHUB_PAT}@github.com/dushyantsutharsilencelaboratories/silentshard-artifacts.git \
           LocalPackages/silentshard-artifacts
   fi
   ```

### Option 5: Bundle as XCFramework

If you have access to the source:
1. Build SilentShard as an XCFramework
2. Include it directly in your project
3. Remove the Swift Package dependency

## Temporary Workaround for Initial Setup

If you just want to test Xcode Cloud setup without the private dependency:

1. **Comment out SilentShard imports temporarily**
   ```swift
   // import silentshard
   ```

2. **Use conditional compilation**
   ```swift
   #if !XCODE_CLOUD_TEST
   import silentshard
   #endif
   ```

3. **Set up Xcode Cloud workflows**
4. **Re-enable once authentication is configured**

## Best Practice: Remove Hardcoded Credentials

The current setup has credentials in the URL:
```
https://dushyantsutharsilencelaboratories:github_pat_11BD3IJDI...@github.com/...
```

This is a security risk because:
- Credentials are stored in the project file
- They're visible to anyone with repo access
- They can't be rotated easily

Instead, use one of the authentication methods above.

## Next Steps

1. Choose one of the solutions above
2. Update the package configuration
3. Test locally first
4. Then proceed with Xcode Cloud setup

For help with SilentShard access, contact the Silence Labs team.