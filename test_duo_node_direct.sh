#!/bin/bash

echo "🧪 Testing Duo-Node Directly"
echo "============================"
echo ""

DUO_NODE_URL="https://interspace-duo-node-dev-784862970473.us-central1.run.app"

echo "1. Testing duo-node health endpoint (no auth)..."
curl -s -X GET "$DUO_NODE_URL/health" -w "\nHTTP Status: %{http_code}\n" 
echo ""

echo "2. Testing duo-node health endpoint (with Bearer token)..."
curl -s -X GET "$DUO_NODE_URL/health" \
  -H "Authorization: Bearer test-token" \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

echo "3. Testing duo-node root endpoint..."
curl -s -X GET "$DUO_NODE_URL/" -w "\nHTTP Status: %{http_code}\n"
echo ""

echo "4. Testing MPC keygen endpoint directly..."
curl -s -X POST "$DUO_NODE_URL/mpc/keygen" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "profileId": "test-profile-123",
    "clientPublicKey": "test-public-key"
  }' \
  -w "\nHTTP Status: %{http_code}\n" | jq . || echo "Response not JSON"
echo ""

echo "5. Testing with Google Cloud auth (checking if it uses Google IAM)..."
# Get the current gcloud access token
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)
if [ -n "$ACCESS_TOKEN" ]; then
    echo "   Using gcloud access token..."
    curl -s -X GET "$DUO_NODE_URL/health" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -w "\nHTTP Status: %{http_code}\n"
else
    echo "   No gcloud access token available"
fi
echo ""

echo "6. Testing WebSocket upgrade headers..."
curl -s -X GET "$DUO_NODE_URL/" \
  -H "Upgrade: websocket" \
  -H "Connection: Upgrade" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

echo "7. Checking CORS and allowed methods..."
curl -s -X OPTIONS "$DUO_NODE_URL/health" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -w "\nHTTP Status: %{http_code}\n" -I
echo ""

echo "8. Service Information:"
echo "   - Service: interspace-duo-node-dev"
echo "   - Region: us-central1"
echo "   - Project: intersend"
echo "   - Service Account: interspace-duo-dev@intersend.iam.gserviceaccount.com"
echo "   - Allowed Invoker: interspace-backend-dev@intersend.iam.gserviceaccount.com"
echo ""
echo "The 403 errors are expected since only the backend service account can invoke duo-node."
echo ""