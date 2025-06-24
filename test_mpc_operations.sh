#!/bin/bash

# Base URL for the development environment
BASE_URL="https://interspace-backend-dev-784862970473.us-central1.run.app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing MPC Operations on Development Environment${NC}"
echo "Base URL: $BASE_URL"
echo "----------------------------------------"

# Test 1: Create MPC Wallet
echo -e "\n${BLUE}1. Testing MPC Wallet Creation${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/mpc/create" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-'$(date +%s)'",
    "walletName": "Test Wallet"
  }')

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MPC Creation Request Sent${NC}"
    echo "Response: $RESPONSE"
    
    # Extract wallet ID if available
    WALLET_ID=$(echo $RESPONSE | grep -o '"walletId":"[^"]*' | grep -o '[^"]*$')
    if [ ! -z "$WALLET_ID" ]; then
        echo "Wallet ID: $WALLET_ID"
    fi
else
    echo -e "${RED}✗ MPC Creation Failed${NC}"
fi

# Test 2: Get MPC Status
echo -e "\n${BLUE}2. Testing MPC Status Endpoint${NC}"
curl -s -X GET "$BASE_URL/api/mpc/status" \
  -H "Content-Type: application/json" | jq '.' || echo "Status check failed"

# Test 3: List MPC Wallets
echo -e "\n${BLUE}3. Testing List MPC Wallets${NC}"
curl -s -X GET "$BASE_URL/api/mpc/wallets" \
  -H "Content-Type: application/json" | jq '.' || echo "List wallets failed"

# Test 4: Test Signature Operation (if wallet exists)
if [ ! -z "$WALLET_ID" ]; then
    echo -e "\n${BLUE}4. Testing MPC Signature${NC}"
    SIGNATURE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/mpc/sign" \
      -H "Content-Type: application/json" \
      -d '{
        "walletId": "'$WALLET_ID'",
        "message": "0x1234567890abcdef",
        "signatureType": "ECDSA"
      }')
    
    echo "Signature Response: $SIGNATURE_RESPONSE"
fi

# Test 5: Key Rotation
echo -e "\n${BLUE}5. Testing Key Rotation Endpoint${NC}"
curl -s -X POST "$BASE_URL/api/mpc/rotate-keys" \
  -H "Content-Type: application/json" \
  -d '{
    "walletId": "test-wallet-id"
  }' | jq '.' || echo "Key rotation test failed"

# Test 6: Health Check
echo -e "\n${BLUE}6. Testing Health Endpoint${NC}"
HEALTH_STATUS=$(curl -s -w "\nHTTP Status: %{http_code}" "$BASE_URL/health")
echo "$HEALTH_STATUS"

echo -e "\n${BLUE}Testing Complete!${NC}"