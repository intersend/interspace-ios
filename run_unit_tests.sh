#!/bin/bash

echo "🧪 Running MPC Unit Tests..."

# Clean previous test results
rm -rf TestResults/UnitTests-*.xcresult

# Build the test target only
echo "🔨 Building test target..."
xcodebuild build-for-testing \
    -project Interspace.xcodeproj \
    -scheme Interspace \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -derivedDataPath build \
    -quiet || { echo "❌ Build failed"; exit 1; }

echo "✅ Build succeeded"

# Run unit tests only (not integration tests)
echo "🧪 Running unit tests..."
xcodebuild test-without-building \
    -project Interspace.xcodeproj \
    -scheme Interspace \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -derivedDataPath build \
    -only-testing:InterspaceTests/MPCUnitTests \
    -resultBundlePath TestResults/UnitTests-$(date +%s).xcresult \
    2>&1 | tee test_output.log

# Check if tests passed
if grep -q "** TEST SUCCEEDED **" test_output.log; then
    echo "✅ Unit tests passed!"
    exit 0
else
    echo "❌ Unit tests failed"
    echo "Check test_output.log for details"
    exit 1
fi