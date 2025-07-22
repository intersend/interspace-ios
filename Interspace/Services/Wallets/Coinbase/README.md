# Coinbase Wallet Integration

This directory contains the native Coinbase Wallet SDK integration for Interspace iOS.

## Overview

Simple and clean Coinbase Wallet integration using the SDK as documented:
- Uses `initiateHandshake` with `eth_requestAccounts` to connect
- Uses `makeRequest` with `personal_sign` for SIWE authentication
- One-click connect flow similar to MetaMask

## Implementation

### CoinbaseService.swift
The main service implementing `WalletProtocol`:

1. **Connect**: Uses `cbwallet.initiateHandshake` to establish connection
2. **Sign SIWE**: Uses `cbwallet.makeRequest` with `personal_sign` action
3. **One-Click Flow**: `connectAndSignSIWE` combines both steps

### CoinbaseConfiguration.swift
Configuration constants:
- App metadata (name, URL)
- Deep link schemes
- Error messages
- Chain configurations

## Usage

The integration follows the standard wallet flow:

```swift
// Step 1: Connect
cbwallet.initiateHandshake(
    initialActions: [Action(jsonRpc: .eth_requestAccounts)]
) { result, account in
    // Handle connection
}

// Step 2: Sign SIWE
cbwallet.makeRequest(
    Request(actions: [
        Action(jsonRpc: .personal_sign(address: address, message: siweMessage))
    ])
) { result in
    // Handle signature
}
```

## SDK Installation

Add via Swift Package Manager:
```
https://github.com/MobileWalletProtocol/wallet-mobile-sdk
Version: 1.0.3
```

## Deep Link Configuration

The app is configured to handle:
- `cbwallet://` - Coinbase Wallet scheme (in Info.plist)
- SDK handles deep links internally