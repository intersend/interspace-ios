#!/bin/bash

echo "🔄 Rebuilding Interspace Backend..."
echo "=================================="

# Navigate to backend directory
cd ../interspace-backend

# Stop existing containers
echo "📦 Stopping existing containers..."
docker-compose --profile local down

# Remove old dist folder (already done, but including for completeness)
echo "🗑️  Cleaning old build files..."
rm -rf dist

# Rebuild and start containers
echo "🏗️  Building and starting backend with latest code..."
docker-compose --profile local up --build

echo "✅ Backend rebuild complete!"