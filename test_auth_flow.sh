#!/bin/bash

# Base URL for the development environment
BASE_URL="https://interspace-backend-dev-784862970473.us-central1.run.app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing Authentication Flow${NC}"
echo "Base URL: $BASE_URL"
echo "----------------------------------------"

# Generate unique test data
TIMESTAMP=$(date +%s)
TEST_EMAIL="test${TIMESTAMP}@example.com"
TEST_USERNAME="testuser${TIMESTAMP}"
TEST_PASSWORD="TestPassword123!"

# Test different auth endpoint patterns
echo -e "\n${BLUE}1. Testing Registration Endpoints${NC}"

# Try without token requirement
echo -e "\n${YELLOW}Testing POST /register (no api prefix)${NC}"
curl -s -X POST "$BASE_URL/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq '.' || echo "Failed"

# Try with different header configurations
echo -e "\n${YELLOW}Testing POST /api/v1/auth/register (with X-Skip-Auth header)${NC}"
curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -H "X-Skip-Auth: true" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq '.' || echo "Failed"

# Check if there's a public auth endpoint
echo -e "\n${YELLOW}Testing POST /public/auth/register${NC}"
curl -s -X POST "$BASE_URL/public/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq '.' || echo "Failed"

# Test OAuth endpoints
echo -e "\n${BLUE}2. Testing OAuth/Social Login Endpoints${NC}"

echo -e "\n${YELLOW}Testing GET /auth/google${NC}"
curl -s -I "$BASE_URL/auth/google" | head -5

echo -e "\n${YELLOW}Testing GET /api/v1/auth/google${NC}"
curl -s -I "$BASE_URL/api/v1/auth/google" | head -5

# Test API key based auth
echo -e "\n${BLUE}3. Testing API Key Authentication${NC}"

echo -e "\n${YELLOW}Testing with API key header${NC}"
curl -s -X GET "$BASE_URL/api/v1/wallets" \
  -H "X-API-Key: test-api-key" \
  -H "Content-Type: application/json" | jq '.' || echo "Failed"

# Check for webhook endpoints
echo -e "\n${BLUE}4. Testing Webhook Endpoints${NC}"

echo -e "\n${YELLOW}Testing POST /webhooks/auth${NC}"
curl -s -X POST "$BASE_URL/webhooks/auth" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"auth\",
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\"
  }" | jq '.' || echo "Failed"

# Try to find the correct auth flow from error messages
echo -e "\n${BLUE}5. Analyzing Error Messages for Hints${NC}"

echo -e "\n${YELLOW}Testing OPTIONS /api/v1/auth/register (preflight)${NC}"
curl -s -X OPTIONS "$BASE_URL/api/v1/auth/register" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" -I | head -10

# Check if there's a signup endpoint
echo -e "\n${YELLOW}Testing POST /signup${NC}"
curl -s -X POST "$BASE_URL/signup" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq '.' || echo "Failed"

echo -e "\n${YELLOW}Testing POST /api/v1/signup${NC}"
curl -s -X POST "$BASE_URL/api/v1/signup" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq '.' || echo "Failed"

echo -e "\n${BLUE}Testing Complete!${NC}"