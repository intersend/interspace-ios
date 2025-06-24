#!/bin/bash

# Base URL for the development environment
BASE_URL="https://interspace-backend-dev-784862970473.us-central1.run.app"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Discovering Available Endpoints on Development Environment${NC}"
echo "Base URL: $BASE_URL"
echo "----------------------------------------"

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    echo -e "\n${YELLOW}Testing $method $endpoint${NC}"
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    body=$(echo "$response" | sed '$d')
    
    echo "Status: $http_status"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
}

# Test common endpoints
echo -e "${BLUE}1. Testing Common Endpoints${NC}"
test_endpoint "GET" "/"
test_endpoint "GET" "/health"
test_endpoint "GET" "/api"
test_endpoint "GET" "/api/v1"

# Test authentication endpoints
echo -e "\n${BLUE}2. Testing Authentication Endpoints${NC}"
test_endpoint "POST" "/auth/register" '{"email":"test@example.com","username":"testuser","password":"Test123!"}'
test_endpoint "POST" "/auth/login" '{"email":"test@example.com","password":"Test123!"}'
test_endpoint "POST" "/api/auth/register" '{"email":"test@example.com","username":"testuser","password":"Test123!"}'
test_endpoint "POST" "/api/auth/login" '{"email":"test@example.com","password":"Test123!"}'
test_endpoint "POST" "/api/v1/auth/register" '{"email":"test@example.com","username":"testuser","password":"Test123!"}'
test_endpoint "POST" "/api/v1/auth/login" '{"email":"test@example.com","password":"Test123!"}'

# Test wallet endpoints
echo -e "\n${BLUE}3. Testing Wallet Endpoints${NC}"
test_endpoint "GET" "/wallets"
test_endpoint "GET" "/api/wallets"
test_endpoint "GET" "/api/v1/wallets"
test_endpoint "POST" "/api/v1/wallets/create" '{"name":"Test Wallet","type":"MPC"}'

# Test MPC endpoints
echo -e "\n${BLUE}4. Testing MPC Endpoints${NC}"
test_endpoint "GET" "/mpc/status"
test_endpoint "GET" "/api/mpc/status"
test_endpoint "GET" "/api/v1/mpc/status"
test_endpoint "POST" "/mpc/create" '{"userId":"test-user","walletName":"Test MPC"}'
test_endpoint "POST" "/api/mpc/create" '{"userId":"test-user","walletName":"Test MPC"}'
test_endpoint "POST" "/api/v1/mpc/create" '{"userId":"test-user","walletName":"Test MPC"}'

# Test user endpoints
echo -e "\n${BLUE}5. Testing User Endpoints${NC}"
test_endpoint "GET" "/users/profile"
test_endpoint "GET" "/api/users/profile"
test_endpoint "GET" "/api/v1/users/profile"

# Check for OpenAPI/Swagger
echo -e "\n${BLUE}6. Testing Documentation Endpoints${NC}"
test_endpoint "GET" "/swagger"
test_endpoint "GET" "/api-docs"
test_endpoint "GET" "/docs"
test_endpoint "GET" "/openapi.json"

echo -e "\n${BLUE}Discovery Complete!${NC}"