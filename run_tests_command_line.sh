#!/bin/bash

echo "🧪 Command Line Test Runner"
echo "========================="

# Check for workspace
if [ -f "Interspace.xcworkspace/contents.xcworkspacedata" ]; then
    echo "📱 Using workspace configuration..."
    BUILD_CMD="xcodebuild -workspace Interspace.xcworkspace"
else
    echo "📱 Using project configuration..."
    BUILD_CMD="xcodebuild -project Interspace.xcodeproj"
fi

# Set test configuration
SCHEME="Interspace"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.5"

echo "🔨 Building for testing..."
$BUILD_CMD \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    build-for-testing \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath ./build/DerivedData

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo ""
    echo "🧪 Running tests..."
    $BUILD_CMD \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -configuration Debug \
        test-without-building \
        -derivedDataPath ./build/DerivedData \
        -only-testing:InterspaceTests
else
    echo "❌ Build failed. Test files may not be properly linked."
    echo "   Please follow the manual instructions in TEST_CONFIGURATION_FIX.md"
fi
