#!/bin/bash

echo "🧪 MPC Wallet Creation Test Checklist"
echo "===================================="
echo ""

# Check if backend is running
echo "1. Checking backend connectivity..."
BACKEND_HEALTH=$(curl -s http://localhost:3000/health 2>/dev/null)
if [ -z "$BACKEND_HEALTH" ]; then
    echo "   ❌ Backend is not running on localhost:3000"
    echo "   Run: docker-compose -f ../interspace-backend/docker-compose.local.yml --profile local up"
else
    echo "   ✅ Backend is running"
fi

# Check if duo-node is accessible
echo ""
echo "2. Checking cloud duo-node connectivity..."
DUO_NODE_HEALTH=$(curl -s https://interspace-duo-node-dev-784862970473.us-central1.run.app/health 2>/dev/null)
if [[ "$DUO_NODE_HEALTH" == *"healthy"* ]]; then
    echo "   ✅ Duo-node is accessible"
else
    echo "   ⚠️  Duo-node returned: $DUO_NODE_HEALTH"
fi

echo ""
echo "3. iOS App Configuration:"
echo "   - MPC Feature: Enabled (hardcoded to true)"
echo "   - Development Mode: Disabled (using MPC wallets)"
echo "   - MPC Service: Using HTTP implementation"
echo "   - Backend URL: http://localhost:3000"

echo ""
echo "4. Testing Steps:"
echo "   a) Build and run the iOS app on simulator"
echo "   b) Create a new profile"
echo "   c) Watch console logs for MPC wallet generation"
echo "   d) Check if profile shows an Ethereum address"

echo ""
echo "5. Verify in Database:"
echo "   Run: node ../interspace-backend/scripts/check-mpc-keyshares.js"
echo ""
echo "Ready to test! 🚀"