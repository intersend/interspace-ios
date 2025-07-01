#!/bin/bash

echo "🔨 Checking iOS Build..."
echo "========================"
echo ""

# Change to iOS directory
cd /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios

# Try to build for testing
echo "Building for iPhone 16 Simulator..."
xcodebuild build \
  -scheme Interspace \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -quiet 2>&1 | grep -E "error:|warning:|FAILED|SUCCEEDED" || true

echo ""
echo "If you see any errors above, they need to be fixed."
echo "Common issues:"
echo "- Missing method implementations"
echo "- Type mismatches"
echo "- Module import errors"