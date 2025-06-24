#!/bin/bash

# Base URL for the development environment
BASE_URL="https://interspace-backend-dev-784862970473.us-central1.run.app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing V2 Authentication API${NC}"
echo "Base URL: $BASE_URL"
echo "----------------------------------------"

# Generate unique test data
TIMESTAMP=$(date +%s)
TEST_EMAIL="test${TIMESTAMP}@example.com"
TEST_USERNAME="testuser${TIMESTAMP}"

# Test 1: Send Email Code (should not require auth)
echo -e "\n${BLUE}1. Testing Email Authentication Flow${NC}"
echo -e "${YELLOW}Testing POST /api/v2/auth/send-email-code${NC}"
EMAIL_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v2/auth/send-email-code" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\"
  }")
echo "Response: $EMAIL_RESPONSE" | jq '.' || echo "$EMAIL_RESPONSE"

# Test 2: Try to authenticate with email strategy
echo -e "\n${YELLOW}Testing POST /api/v2/auth/authenticate (email strategy)${NC}"
AUTH_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v2/auth/authenticate" \
  -H "Content-Type: application/json" \
  -d "{
    \"strategy\": \"email\",
    \"identifier\": \"$TEST_EMAIL\",
    \"email\": \"$TEST_EMAIL\",
    \"verificationCode\": \"123456\",
    \"deviceId\": \"test-device-id\",
    \"privacyMode\": \"linked\"
  }")
echo "Response: $AUTH_RESPONSE" | jq '.' || echo "$AUTH_RESPONSE"

# Test 3: Get SIWE Nonce
echo -e "\n${BLUE}2. Testing SIWE Authentication Flow${NC}"
echo -e "${YELLOW}Testing GET /api/v2/siwe/nonce${NC}"
NONCE_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v2/siwe/nonce")
echo "Response: $NONCE_RESPONSE" | jq '.' || echo "$NONCE_RESPONSE"

# Test 4: Try Google OAuth
echo -e "\n${BLUE}3. Testing OAuth Authentication${NC}"
echo -e "${YELLOW}Testing POST /api/v2/auth/authenticate (google strategy)${NC}"
GOOGLE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v2/auth/authenticate" \
  -H "Content-Type: application/json" \
  -d "{
    \"strategy\": \"google\",
    \"identifier\": \"$TEST_EMAIL\",
    \"oauthCode\": \"fake-oauth-code\",
    \"deviceId\": \"test-device-id\",
    \"privacyMode\": \"linked\"
  }")
echo "Response: $GOOGLE_RESPONSE" | jq '.' || echo "$GOOGLE_RESPONSE"

# Test 5: Check if there's a health endpoint that shows available routes
echo -e "\n${BLUE}4. Checking API Status${NC}"
echo -e "${YELLOW}Testing GET /api/v2/status${NC}"
curl -s -X GET "$BASE_URL/api/v2/status" | jq '.' || echo "No v2 status endpoint"

# Test 6: Try authenticated endpoints to see different error
echo -e "\n${BLUE}5. Testing Protected Endpoints${NC}"
echo -e "${YELLOW}Testing GET /api/v2/auth/me${NC}"
ME_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v2/auth/me")
echo "Response: $ME_RESPONSE" | jq '.' || echo "$ME_RESPONSE"

echo -e "${YELLOW}Testing GET /api/v2/auth/identity-graph${NC}"
GRAPH_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v2/auth/identity-graph")
echo "Response: $GRAPH_RESPONSE" | jq '.' || echo "$GRAPH_RESPONSE"

# Test 7: Check for MPC endpoints in V2
echo -e "\n${BLUE}6. Testing V2 MPC/Wallet Endpoints${NC}"
echo -e "${YELLOW}Testing GET /api/v2/wallets${NC}"
curl -s -X GET "$BASE_URL/api/v2/wallets" | jq '.' || echo "Failed"

echo -e "${YELLOW}Testing GET /api/v2/mpc/status${NC}"
curl -s -X GET "$BASE_URL/api/v2/mpc/status" | jq '.' || echo "Failed"

echo -e "\n${BLUE}Testing Complete!${NC}"