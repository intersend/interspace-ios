#!/bin/bash

echo "=== Building Interspace iOS Project ==="
echo

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo "  ❌ Xcode not found. Please install Xcode from the App Store."
        return 1
    fi
    
    # Check Xcode version
    xcode_version=$(xcodebuild -version | head -1)
    echo "  ✅ $xcode_version"
    
    # Check for iOS SDK
    if xcodebuild -showsdks | grep -q "iOS"; then
        echo "  ✅ iOS SDK available"
    else
        echo "  ❌ iOS SDK not found"
        return 1
    fi
    
    return 0
}

# Main build function
build_project() {
    echo "Building project..."
    
    # Clean build folder
    rm -rf build
    rm -rf ~/Library/Developer/Xcode/DerivedData/Interspace-*
    
    # Resolve packages
    echo "Resolving Swift packages..."
    xcodebuild -resolvePackageDependencies \
        -scheme Interspace \
        -project Interspace.xcodeproj
    
    # Build for simulator
    echo "Building for iPhone 16 Pro simulator..."
    xcodebuild build \
        -scheme Interspace \
        -project Interspace.xcodeproj \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
        -derivedDataPath build \
        IPHONEOS_DEPLOYMENT_TARGET=16.0 \
        | tee build_output.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ Build succeeded!"
        return 0
    else
        echo "❌ Build failed. Check build_output.log for details."
        return 1
    fi
}

# Check prerequisites
if check_prerequisites; then
    build_project
else
    echo "Prerequisites check failed. Please install required tools."
    exit 1
fi
