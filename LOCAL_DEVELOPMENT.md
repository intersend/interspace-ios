# iOS Local Development with Docker

## Connecting to Docker Containers from iOS Simulator

The iOS simulator cannot connect to Docker containers via `localhost` or `127.0.0.1`. You must use your Mac's actual IP address.

### Finding Your Host IP

```bash
# Get your Mac's IP address
ifconfig | grep "inet " | grep -v 127.0.0.1 | grep -v "inet6"
```

### Update Configuration

In `Interspace/Services/MPC/MPCKeyShareManager.swift`, update the `duoNodeUrl`:

```swift
var duoNodeUrl: String {
    #if DEBUG
    // Replace with your Mac's IP address
    return "192.168.2.79"
    #else
    return "interspace-duo-node-prod.a.run.app"
    #endif
}
```

### Verify Docker Container is Accessible

```bash
# Check that sigpair is bound to all interfaces
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep sigpair

# Test connectivity
curl -I http://YOUR_IP:8080
```

The container should show `0.0.0.0:8080->8080/tcp` which means it's accessible from any network interface.