#!/bin/bash

echo "🧪 Coinbase Wallet Integration Test Script"
echo "========================================"

# Check if Coinbase scheme is registered
echo "✅ Checking URL schemes in Info.plist..."
grep -A 10 "LSApplicationQueriesSchemes" Interspace/Info.plist | grep "cbwallet" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ cbwallet scheme is registered"
else
    echo "   ❌ cbwallet scheme is NOT registered"
fi

# Check AppDelegate configuration
echo ""
echo "✅ Checking AppDelegate configuration..."
grep "CoinbaseWalletSDK.configure" Interspace/AppDelegate.swift > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Coinbase SDK is configured in AppDelegate"
else
    echo "   ❌ Coinbase SDK is NOT configured in AppDelegate"
fi

# Check deep link handling
echo ""
echo "✅ Checking Coinbase URL handling..."
grep -A 5 "coinbase" Interspace/AppDelegate.swift | grep "handleResponse" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Coinbase deep link handling is implemented"
else
    echo "   ❌ Coinbase deep link handling is NOT implemented"
fi

# Check WalletService implementation
echo ""
echo "✅ Checking WalletService implementation..."
grep "connectCoinbaseWallet" Interspace/Services/WalletService.swift > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ connectCoinbaseWallet function exists"
    
    # Check if it's properly implemented
    grep "CoinbaseWalletSDK.shared.makeRequest" Interspace/Services/WalletService.swift > /dev/null
    if [ $? -eq 0 ]; then
        echo "   ✅ Coinbase SDK request is implemented"
    else
        echo "   ❌ Coinbase SDK request is NOT implemented"
    fi
else
    echo "   ❌ connectCoinbaseWallet function NOT found"
fi

# Test deep link
echo ""
echo "📱 Testing deep link handling..."
echo "   To test manually:"
echo "   1. Run the app on a physical device with Coinbase Wallet installed"
echo "   2. Select 'Coinbase Wallet' from the wallet options"
echo "   3. Approve the connection in Coinbase Wallet"
echo "   4. Check logs for successful authentication"

# Simulate deep link callback (for documentation)
echo ""
echo "📲 Example Coinbase callback URL:"
echo "   interspace://coinbase?p=..."

echo ""
echo "========================================"
echo "✅ Integration check complete!"
echo ""
echo "Next steps:"
echo "1. Add Coinbase Wallet SDK via Xcode's Swift Package Manager:"
echo "   - URL: https://github.com/coinbase/wallet-mobile-sdk"
echo "   - Branch/Version: main or latest release"
echo "2. Build and run on a physical device"
echo "3. Test wallet connection flow"