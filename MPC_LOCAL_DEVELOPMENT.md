# MPC Local Development Guide for iOS

This guide helps you set up MPC wallet generation for local development.

## Quick Fix for WebSocket Timeout

If you're getting WebSocket timeout errors like:
```
Task finished with error [-1001] Error Domain=NSURLErrorDomain Code=-1001 "The request timed out."
```

### Solution 1: Update Your Machine's IP Address

1. Find your Mac's IP address:
   ```bash
   ifconfig | grep -E "inet.*broadcast" | awk '{print $2}'
   ```

2. Update `Interspace/Configuration/MPCConfiguration.swift`:
   ```swift
   #if targetEnvironment(simulator)
   return "YOUR_MAC_IP_HERE" // e.g., "192.168.2.79"
   ```

### Solution 2: Use Environment Variables

Set a custom host in your Xcode scheme:
1. Edit Scheme → Run → Environment Variables
2. Add: `MPC_WEBSOCKET_HOST` = `YOUR_MAC_IP`

### Solution 3: Use ngrok (Recommended for Teams)

1. Install ngrok:
   ```bash
   brew install ngrok
   ```

2. Expose sigpair:
   ```bash
   ngrok tcp 8080
   ```

3. Use the ngrok URL in your app configuration

## Docker Services Setup

Ensure all MPC services are running:
```bash
# Start all services
docker-compose -f docker-compose.local.yml --profile local up -d

# Check services are running
docker ps | grep -E "sigpair|duo-node"

# Check sigpair is accessible
curl http://localhost:8080/v3/verifying-key
```

## Troubleshooting

### macOS Firewall
If you still get timeouts, check macOS firewall:
1. System Preferences → Security & Privacy → Firewall
2. Firewall Options → Allow incoming connections for Docker

### Wrong IP Address
The app needs your Mac's actual IP address, not localhost:
- ✅ Correct: `192.168.2.79` (your Mac's IP)
- ❌ Wrong: `localhost` or `127.0.0.1` (these refer to the iOS device)

### Verify Connection
Test WebSocket connection from your Mac:
```bash
# Install wscat
npm install -g wscat

# Test connection
wscat -c ws://YOUR_MAC_IP:8080/v3/eddsa/keygen
```

## Auto-Detection (Future Enhancement)

The app includes IP auto-detection in `MPCConfiguration+LocalIP.swift` which will automatically detect your Mac's IP address in future versions.