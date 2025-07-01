# MPC iOS Testing Instructions

## Step-by-Step Testing Guide

### 1. Add Files to Xcode Project

1. Open Xcode project:
   ```bash
   open /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace.xcworkspace
   ```

2. In Xcode:
   - Right-click on `InterspaceTests` group
   - Select "Add Files to Interspace..."
   - Navigate to and select:
     - `InterspaceTests/MPCIntegrationTests.swift`
   - Make sure "InterspaceTests" target is checked
   - Click "Add"

3. For UI Tests:
   - Right-click on `InterspaceUITests` group
   - Add `InterspaceUITests/MPCWalletUITests.swift`
   - Make sure "InterspaceUITests" target is checked

### 2. Configure for Local Testing

Add this temporary code to test MPC locally:

**In `AppDelegate.swift` or `InterspaceApp.swift`:**

```swift
#if DEBUG
// Configure for local MPC testing
func configureMPCForLocalTesting() {
    // Enable MPC features
    UserDefaults.standard.set(true, forKey: "mpcWalletEnabled")
    UserDefaults.standard.set(true, forKey: "mpcUseHTTP")
    
    // Point to local backend
    if let apiService = ProfileAPI.shared.apiService {
        apiService.baseURL = "http://localhost:3000"
    }
    
    // Configure MPC for local environment
    MPCConfiguration.shared.environment = .development
}
#endif
```

### 3. Create a Test View

Create a simple test view to verify MPC functionality:

```swift
import SwiftUI

struct MPCTestView: View {
    @State private var isGenerating = false
    @State private var walletAddress: String?
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MPC Wallet Test")
                .font(.largeTitle)
            
            if let address = walletAddress {
                VStack {
                    Text("Wallet Generated!")
                        .foregroundColor(.green)
                    Text(address)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(action: generateTestWallet) {
                if isGenerating {
                    ProgressView()
                } else {
                    Text("Generate MPC Wallet")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
        }
        .padding()
    }
    
    func generateTestWallet() {
        Task {
            isGenerating = true
            error = nil
            
            do {
                // Use the HTTP service
                let service = MPCWalletServiceHTTP.shared
                let testProfileId = "test-\(UUID().uuidString)"
                
                let walletInfo = try await service.generateWallet(for: testProfileId)
                walletAddress = walletInfo.address
                
            } catch {
                self.error = error.localizedDescription
            }
            
            isGenerating = false
        }
    }
}
```

### 4. Run the Test

1. Make sure Docker is running:
   ```bash
   docker ps | grep interspace
   ```

2. In Xcode:
   - Select iPhone simulator
   - Build and run (Cmd+R)
   - Navigate to the test view
   - Tap "Generate MPC Wallet"

### 5. Monitor the Flow

Open three terminal windows:

**Terminal 1 - Backend logs:**
```bash
docker logs -f interspace-backend-local 2>&1 | grep -i mpc
```

**Terminal 2 - Duo-node logs:**
```bash
docker logs -f interspace-duo-node-local
```

**Terminal 3 - All logs:**
```bash
docker-compose -f docker-compose.local.yml logs -f
```

### 6. Expected Flow

1. iOS app calls `generateWallet()`
2. Backend receives request at `/api/v2/mpc/generate`
3. Backend returns cloud public key
4. iOS generates P1 messages (currently mocked)
5. iOS sends P1 messages to `/api/v2/mpc/keygen/start`
6. Backend forwards to duo-node via WebSocket
7. Duo-node processes with Silence Labs server
8. Session completes with wallet address

### 7. Debugging Tips

If wallet generation fails:

1. **Check auth token**: Make sure you're signed in
2. **Check network**: iOS simulator must reach `http://localhost:3000`
3. **Check logs**: Look for WebSocket connection errors
4. **Check duo-node**: Ensure it's connected to sigpair

### 8. Current Limitations

1. **Mock P1 Messages**: Real Silence Labs SDK integration needed
2. **No persistence**: P2 keyshares are in-memory only
3. **No retry logic**: Failed operations need manual retry
4. **Test environment only**: Not ready for production

## Quick Test Commands

```bash
# Check all services are running
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test backend health
curl http://localhost:3000/health | jq

# Watch all MPC logs
docker-compose -f docker-compose.local.yml logs -f | grep -i mpc

# Restart services if needed
docker-compose -f docker-compose.local.yml --profile local restart
```

## Success Criteria

✅ Wallet address generated (even if placeholder)
✅ No WebSocket errors in backend logs
✅ Duo-node shows connection established
✅ iOS receives response without timeout

The current implementation is ready for testing the HTTP flow, even though the actual MPC cryptography is mocked.