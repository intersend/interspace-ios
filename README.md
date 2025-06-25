# Orby Wallet Injection Browser

A minimal iOS browser with Web3 wallet injection capabilities for testing decentralized applications (dApps). This browser implements EIP-6963 (Multi Injected Provider Discovery) and other wallet standards to help test wallet integrations.

## Features

- **Minimal Browser**: Stripped-down WebView with essential navigation
- **EIP-6963 Support**: Multi Injected Provider Discovery
- **EIP-1193 Support**: Ethereum Provider JavaScript API
- **Multiple Wallet Providers**: Impersonate MetaMask, Coinbase, Trust, Rainbow, and WalletConnect
- **Configurable Testing**: Control wallet address, chain ID, and auto-connect behavior
- **Debug Logging**: Monitor all wallet interactions and RPC calls
- **Mock Responses**: Realistic responses for common Web3 methods

## Project Structure

```
OrbySample/
├── OrbySampleApp.swift          # App entry point
├── Views/
│   └── ContentView.swift        # Main container
├── Browser/
│   ├── MinimalBrowserView.swift # Browser UI
│   ├── InjectedWebView.swift    # WebView with injection
│   └── WalletInjector.swift     # Injection configuration
└── WalletInjection/
    ├── EIP6963Provider.swift    # EIP-6963 implementation
    ├── WalletProviderScripts.swift # JavaScript generation
    └── MockWalletProvider.swift # Mock RPC responses
```

## Quick Start

### 1. Open in Xcode

Since the project file needs to be regenerated for the minimal structure, you'll need to create a new Xcode project:

1. Open Xcode
2. Create a new iOS App project
3. Name it "OrbySample"
4. Choose SwiftUI interface
5. Replace the generated files with the files from this directory
6. Add files to the project target

### 2. Configure Bundle Identifier

Set the bundle identifier to something unique like `com.orby.wallet-injection-browser`

### 3. Run the App

1. Select a simulator or device
2. Build and run (⌘R)
3. The browser will launch with Uniswap loaded by default

## Using the Wallet Injection

### Access Wallet Settings

Tap the wallet icon in the navigation bar to configure:

- **Provider Type**: Choose which wallet to impersonate
- **Wallet Address**: Set the test address
- **Chain ID**: Select the network
- **Auto-Connect**: Automatically connect on page load
- **Debug Logging**: Enable console logging

### Testing with dApps

1. Navigate to any dApp (e.g., Uniswap, OpenSea, etc.)
2. The selected wallet provider will be injected automatically
3. Click "Connect Wallet" on the dApp
4. The wallet will appear in the list (if EIP-6963 is supported)
5. Monitor the Xcode console for debug output

### Supported RPC Methods

The mock provider supports common methods:
- `eth_requestAccounts` / `eth_accounts`
- `eth_chainId` / `net_version`
- `eth_getBalance`
- `eth_blockNumber`
- `eth_sendTransaction`
- `personal_sign` / `eth_sign`
- `eth_signTypedData_v4`
- `wallet_addEthereumChain`
- `wallet_switchEthereumChain`

## Customization

### Adding New Wallet Providers

1. Add the provider to the `WalletProvider` enum in `WalletInjector.swift`
2. Configure its `EIP6963ProviderInfo` with appropriate metadata
3. Set provider-specific flags in `WalletProviderScripts.swift`

### Modifying Mock Responses

Edit `MockWalletProvider.swift` to customize RPC responses:

```swift
case "eth_getBalance":
    return "0x1BC16D674EC80000" // 2 ETH in wei
```

### Testing Events

The provider emits standard events:
- `connect`
- `disconnect`
- `accountsChanged`
- `chainChanged`

## Debug Tips

1. **Enable Debug Logging**: Toggle in wallet settings to see all RPC calls
2. **Check Console**: View Xcode console for injection status and errors
3. **Test Multiple Providers**: Switch between wallets to test compatibility
4. **Verify EIP-6963**: Look for "eip6963:announceProvider" events in console

## Common Issues

### Provider Not Detected
- Ensure the dApp supports EIP-6963 or legacy injection
- Check that JavaScript injection is enabled
- Verify the provider type matches what the dApp expects

### Connection Failures
- Some dApps validate addresses - use realistic test addresses
- Ensure chain ID matches the dApp's expectations
- Check console for specific error messages

## Next Steps

This minimal browser provides a foundation for testing wallet injection. You can:

1. Add more sophisticated mock responses
2. Implement actual wallet functionality
3. Add transaction simulation
4. Create automated testing scripts
5. Extend provider compatibility

## Support

For questions or issues, please contact the Interspace team or create an issue in the repository.