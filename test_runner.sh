#!/bin/bash
# Test runner script
set -e

echo "🧪 Running iOS Tests"
echo "==================="

# Check if workspace exists
if [ -f "Interspace.xcworkspace/contents.xcworkspacedata" ]; then
    BUILD_ROOT="-workspace Interspace.xcworkspace"
else
    BUILD_ROOT="-project Interspace.xcodeproj"
fi

# Build and test
xcodebuild $BUILD_ROOT \
    -scheme Interspace \
    -destination "platform=iOS Simulator,name=iPhone 15,OS=17.5" \
    -configuration Debug \
    test \
    -only-testing:InterspaceTests \
    CODE_SIGNING_ALLOWED=NO