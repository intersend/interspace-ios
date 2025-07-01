#!/bin/bash

echo "📱 Running MPC Tests..."

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf build

# Build for testing
echo "🔨 Building for testing..."
xcodebuild build-for-testing \
    -project Interspace.xcodeproj \
    -scheme Interspace \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -derivedDataPath build \
    -quiet

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build succeeded"

# Run tests without building
echo "🧪 Running tests..."
xcodebuild test-without-building \
    -project Interspace.xcodeproj \
    -scheme Interspace \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -derivedDataPath build \
    -only-testing:InterspaceTests/SimpleMPCTest \
    -only-testing:InterspaceTests/MPCUnitTests \
    2>&1 | grep -E "(Test Suite|Test Case|passed|failed|Executed)"

echo "✅ Test run completed"