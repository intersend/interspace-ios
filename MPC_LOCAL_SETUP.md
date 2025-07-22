# MPC Local Development Setup for iOS

When developing MPC functionality locally with Docker containers, the iOS simulator needs to connect to services running on your host machine. This guide explains how to configure your local environment.

## Quick Setup

1. **Find your machine's IP address:**
   ```bash
   ifconfig | grep -E "inet.*broadcast" | grep -v 127.0.0.1 | awk '{print $2}' | head -1
   ```

2. **Update the configuration:**
   Edit `Interspace/Configuration/MPCLocalConfig.swift`:
   ```swift
   static let hostIP = "YOUR_IP_HERE"  // e.g., "192.168.2.79"
   ```

3. **Ensure Docker services are running:**
   ```bash
   cd ../interspace-backend
   docker-compose -f docker-compose.local.yml --profile local up -d
   ```

4. **Rebuild and run the iOS app**

## Why This Is Needed

- iOS Simulator has its own network stack
- `localhost` or `127.0.0.1` in the simulator refers to the simulator itself, not your Mac
- Docker containers expose ports on your Mac's network interface
- The simulator needs your Mac's actual IP address to reach Docker containers

## Troubleshooting

### Connection Refused Errors
If you see "Connection refused" errors:
1. Verify your IP hasn't changed (routers may assign new IPs)
2. Check Docker containers are running: `docker ps`
3. Test connectivity: `curl http://YOUR_IP:8080`

### WebSocket Connection Issues
- Ensure the WebSocket URL doesn't have double protocol prefixes (e.g., `ws://ws://...`)
- Check sigpair logs: `docker logs interspace-sigpair-local`

### Network Changes
If you switch networks (e.g., home to office):
1. Find your new IP address
2. Update `MPCLocalConfig.swift`
3. Clean build folder and rebuild

## Alternative Solutions

For a more permanent solution, consider:
- Using ngrok to expose local services
- Setting up a local DNS entry
- Using Docker Desktop's host.docker.internal (doesn't work for iOS)