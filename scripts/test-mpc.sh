#!/bin/bash

# MPC Testing Script for iOS
# This script runs MPC integration and UI tests

echo "🧪 Running MPC Tests for iOS"
echo "==============================="

# Configuration
SCHEME="Interspace"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0"
TEST_PLAN="MPCTests"

# Check if backend is running
echo "🔍 Checking backend availability..."
if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "❌ Backend is not running at http://localhost:3000"
    echo "Please run: docker-compose -f docker-compose.local.yml --profile local up"
    exit 1
fi

echo "✅ Backend is running"

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -scheme "$SCHEME" -quiet

# Run unit tests
echo -e "\n📱 Running MPC Integration Tests..."
xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:InterspaceTests/MPCIntegrationTests \
    -quiet \
    -resultBundlePath TestResults/MPCIntegrationTests.xcresult || {
    echo "❌ Integration tests failed"
    exit 1
}

echo "✅ Integration tests passed"

# Run UI tests
echo -e "\n🖥️  Running MPC UI Tests..."
xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:InterspaceUITests/MPCWalletUITests \
    -quiet \
    -resultBundlePath TestResults/MPCUITests.xcresult || {
    echo "❌ UI tests failed"
    exit 1
}

echo "✅ UI tests passed"

# Generate test report
echo -e "\n📊 Generating test report..."
xcrun xcresulttool get --path TestResults/MPCIntegrationTests.xcresult --format json > TestResults/integration-report.json
xcrun xcresulttool get --path TestResults/MPCUITests.xcresult --format json > TestResults/ui-report.json

echo -e "\n✨ All MPC tests completed successfully!"
echo "Test results saved in: TestResults/"

# Optional: Open test results in Xcode
echo -e "\nOpen test results in Xcode? (y/n)"
read -r response
if [[ "$response" == "y" ]]; then
    open TestResults/MPCIntegrationTests.xcresult
    open TestResults/MPCUITests.xcresult
fi