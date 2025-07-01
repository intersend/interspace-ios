#!/bin/bash

echo "🧪 Testing MPC Backend Integration..."
echo ""

# Check if backend is running
echo "📡 Checking backend connectivity..."
HEALTH_RESPONSE=$(curl -s http://localhost:3000/health)
if [ -z "$HEALTH_RESPONSE" ]; then
    echo "❌ Backend is not running!"
    echo "Please ensure Docker containers are running:"
    echo "  docker-compose -f ../interspace-backend/docker-compose.local.yml --profile local up"
    exit 1
fi

echo "✅ Backend is healthy"
echo "$HEALTH_RESPONSE" | jq .

# Test MPC endpoints
echo ""
echo "🔑 Testing MPC Endpoints..."

# Test 1: Check if MPC endpoints exist
echo ""
echo "1. Testing cloud public key endpoint..."
RESPONSE=$(curl -s -X POST http://localhost:3000/api/v2/mpc/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mock-token" \
  -d '{
    "profileId": "test-profile"
  }' | jq .)
  
echo "$RESPONSE"

# Test 2: Check key generation start endpoint
echo ""
echo "2. Testing key generation start endpoint..."
RESPONSE=$(curl -s -X POST http://localhost:3000/api/v2/mpc/keygen/start \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mock-token" \
  -d '{
    "profileId": "test-profile",
    "p1Messages": []
  }' | jq .)
  
echo "$RESPONSE"

# Test 3: Check session status endpoint
echo ""
echo "3. Testing session status endpoint..."
RESPONSE=$(curl -s http://localhost:3000/api/v2/mpc/session/test-session \
  -H "Authorization: Bearer mock-token" | jq .)
  
echo "$RESPONSE"

# Test 4: Check duo-node connectivity
echo ""
echo "4. Testing duo-node service..."
RESPONSE=$(curl -s http://localhost:3001/health 2>/dev/null || echo '{"error": "Duo node not accessible"}')
echo "$RESPONSE"

echo ""
echo "📊 Test Summary:"
echo "- Backend: ✅ Running"
echo "- MPC endpoints: Need authentication"
echo "- Duo-node: Check if accessible"
echo ""
echo "To run full integration tests:"
echo "1. Ensure all services are running"
echo "2. Fix package dependency issues"
echo "3. Run: xcodebuild test -scheme Interspace"