#!/bin/bash

# Base URL for the development environment
BASE_URL="https://interspace-backend-dev-784862970473.us-central1.run.app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing Wallet Operations on Development Environment${NC}"
echo "Base URL: $BASE_URL"
echo "----------------------------------------"

# Generate test user data
TEST_USER="test-user-$(date +%s)"
TEST_EMAIL="${TEST_USER}@test.com"

# Test 1: Try to access wallet endpoints without auth
echo -e "\n${BLUE}1. Testing Wallet Endpoints (No Auth)${NC}"
echo -e "${YELLOW}Testing GET /api/v1/wallets${NC}"
curl -s -X GET "$BASE_URL/api/v1/wallets" \
  -H "Content-Type: application/json" | jq '.' || echo "Failed"

# Test 2: Check authentication endpoints
echo -e "\n${BLUE}2. Checking Authentication Endpoints${NC}"
echo -e "${YELLOW}Testing POST /api/v1/auth/register${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'$TEST_EMAIL'",
    "username": "'$TEST_USER'",
    "password": "TestPassword123!"
  }')
echo "Response: $REGISTER_RESPONSE" | jq '.' || echo "$REGISTER_RESPONSE"

# Test 3: Login
echo -e "\n${YELLOW}Testing POST /api/v1/auth/login${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'$TEST_EMAIL'",
    "password": "TestPassword123!"
  }')
echo "Response: $LOGIN_RESPONSE" | jq '.' || echo "$LOGIN_RESPONSE"

# Extract token if login successful
TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

if [ ! -z "$TOKEN" ]; then
    echo -e "${GREEN}✓ Authentication successful, token obtained${NC}"
    
    # Test 4: Access wallet endpoints with auth
    echo -e "\n${BLUE}3. Testing Wallet Operations with Authentication${NC}"
    
    echo -e "\n${YELLOW}Testing GET /api/v1/wallets (with auth)${NC}"
    curl -s -X GET "$BASE_URL/api/v1/wallets" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq '.' || echo "Failed"
    
    echo -e "\n${YELLOW}Testing POST /api/v1/wallets/create${NC}"
    CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/wallets/create" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Test MPC Wallet",
        "type": "MPC"
      }')
    echo "Response: $CREATE_RESPONSE" | jq '.' || echo "$CREATE_RESPONSE"
    
    # Extract wallet ID if available
    WALLET_ID=$(echo $CREATE_RESPONSE | grep -o '"id":"[^"]*' | grep -o '[^"]*$')
    
    if [ ! -z "$WALLET_ID" ]; then
        echo -e "${GREEN}✓ Wallet created with ID: $WALLET_ID${NC}"
        
        # Test wallet operations
        echo -e "\n${YELLOW}Testing GET /api/v1/wallets/$WALLET_ID${NC}"
        curl -s -X GET "$BASE_URL/api/v1/wallets/$WALLET_ID" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" | jq '.' || echo "Failed"
        
        echo -e "\n${YELLOW}Testing POST /api/v1/wallets/$WALLET_ID/sign${NC}"
        SIGN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/wallets/$WALLET_ID/sign" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "message": "0x1234567890abcdef",
            "messageType": "hex"
          }')
        echo "Response: $SIGN_RESPONSE" | jq '.' || echo "$SIGN_RESPONSE"
    fi
else
    echo -e "${RED}✗ Authentication failed${NC}"
fi

# Test 5: Check other available endpoints
echo -e "\n${BLUE}4. Checking Other Available Endpoints${NC}"

echo -e "\n${YELLOW}Testing GET /api/v1/users/profile (requires auth)${NC}"
if [ ! -z "$TOKEN" ]; then
    curl -s -X GET "$BASE_URL/api/v1/users/profile" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq '.' || echo "Failed"
fi

# Test 6: Check for MPC-specific endpoints
echo -e "\n${BLUE}5. Checking for MPC-specific Endpoints${NC}"

echo -e "\n${YELLOW}Testing GET /api/v1/mpc/status${NC}"
curl -s -X GET "$BASE_URL/api/v1/mpc/status" \
  -H "Content-Type: application/json" | jq '.' || echo "Failed"

echo -e "\n${YELLOW}Testing GET /api/v1/mpc/operations${NC}"
if [ ! -z "$TOKEN" ]; then
    curl -s -X GET "$BASE_URL/api/v1/mpc/operations" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" | jq '.' || echo "Failed"
fi

echo -e "\n${BLUE}Testing Complete!${NC}"