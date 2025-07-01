#!/bin/bash

echo "🧪 Testing MPC Endpoints with curl"
echo "=================================="
echo ""

# First, let's check if we need a real auth token
echo "1. Testing backend health..."
curl -s http://localhost:3000/health | jq .
echo ""

# Let's try to get a test token or see what auth is required
echo "2. Testing auth requirements..."
echo "   Checking if test endpoints exist..."
curl -s -X POST http://localhost:3000/api/auth/test-token 2>/dev/null | jq . || echo "   No test token endpoint"
echo ""

# Test the MPC generate endpoint without auth to see error message
echo "3. Testing MPC generate endpoint (no auth)..."
curl -s -X POST http://localhost:3000/api/v2/mpc/generate \
  -H "Content-Type: application/json" \
  -d '{"profileId": "test-profile-123"}' | jq .
echo ""

# Test with a mock Bearer token to see if it gives more info
echo "4. Testing MPC generate endpoint (with mock token)..."
curl -s -X POST http://localhost:3000/api/v2/mpc/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJ0ZXN0LXVzZXIiLCJpYXQiOjE3MzU2NjU2MDB9.test" \
  -d '{"profileId": "test-profile-123"}' | jq .
echo ""

# Check available API routes
echo "5. Checking available routes..."
echo "   Testing root endpoint..."
curl -s http://localhost:3000/ | jq . || echo "   No root handler"
echo ""
echo "   Testing API root..."
curl -s http://localhost:3000/api/ | jq . || echo "   No API root handler"
echo ""

# Test V1 endpoints to see if they're still available
echo "6. Testing legacy v1 endpoints..."
curl -s http://localhost:3000/api/v1/mpc/generate \
  -H "Content-Type: application/json" \
  -d '{"profileId": "test"}' | jq .
echo ""

# Let's check the actual backend logs approach
echo "7. Backend Configuration Info:"
echo "   - Check docker logs: docker logs interspace-backend-dev"
echo "   - Database: PostgreSQL (check mpc_key_shares table)"
echo "   - Duo-node: https://interspace-duo-node-dev-784862970473.us-central1.run.app"
echo ""

echo "To get a real auth token:"
echo "1. Run the iOS app and login"
echo "2. Check the app logs for the auth token"
echo "3. Or check the backend database for user sessions"
echo ""