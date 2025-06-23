#!/bin/bash

# Interspace iOS Deployment Validation Script
# This script validates the app is ready for deployment
# Returns exit code 0 on success, 1 on failure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Interspace"
WORKSPACE="Interspace.xcworkspace"
SCHEME="Interspace"
CONFIGURATION="Release"
DERIVED_DATA_PATH="build/DerivedData"
TEST_RESULTS_PATH="build/TestResults"
SIMULATOR_NAME="iPhone 15 Pro"
SIMULATOR_OS="17.0"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_pass() {
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    ((TOTAL_CHECKS++))
    ((FAILED_CHECKS++))
    echo -e "${RED}✗${NC} $1"
}

print_separator() {
    echo "=================================================="
}

# Check if required tools are installed
check_dependencies() {
    print_separator
    log_info "Checking dependencies..."
    
    if command -v xcodebuild &> /dev/null; then
        check_pass "xcodebuild found"
    else
        check_fail "xcodebuild not found"
        return 1
    fi
    
    if command -v xcrun &> /dev/null; then
        check_pass "xcrun found"
    else
        check_fail "xcrun not found"
        return 1
    fi
    
    if command -v plutil &> /dev/null; then
        check_pass "plutil found"
    else
        check_fail "plutil not found"
        return 1
    fi
    
    return 0
}

# Validate Info.plist configuration
validate_info_plist() {
    print_separator
    log_info "Validating Info.plist configuration..."
    
    INFO_PLIST_PATH="Interspace/Info.plist"
    
    if [ ! -f "$INFO_PLIST_PATH" ]; then
        check_fail "Info.plist not found at $INFO_PLIST_PATH"
        return 1
    fi
    
    # Check bundle identifier
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST_PATH" 2>/dev/null || echo "")
    if [ -n "$BUNDLE_ID" ]; then
        check_pass "Bundle identifier: $BUNDLE_ID"
    else
        check_fail "Bundle identifier not found"
    fi
    
    # Check version
    VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST_PATH" 2>/dev/null || echo "")
    if [ -n "$VERSION" ]; then
        check_pass "App version: $VERSION"
    else
        check_fail "App version not found"
    fi
    
    # Check build number
    BUILD=$(plutil -extract CFBundleVersion raw "$INFO_PLIST_PATH" 2>/dev/null || echo "")
    if [ -n "$BUILD" ]; then
        check_pass "Build number: $BUILD"
    else
        check_fail "Build number not found"
    fi
    
    # Check required permissions
    # Camera usage description (for QR scanning)
    CAMERA_DESC=$(plutil -extract NSCameraUsageDescription raw "$INFO_PLIST_PATH" 2>/dev/null || echo "")
    if [ -n "$CAMERA_DESC" ]; then
        check_pass "Camera usage description present"
    else
        check_fail "NSCameraUsageDescription missing"
    fi
    
    # Face ID usage description
    FACEID_DESC=$(plutil -extract NSFaceIDUsageDescription raw "$INFO_PLIST_PATH" 2>/dev/null || echo "")
    if [ -n "$FACEID_DESC" ]; then
        check_pass "Face ID usage description present"
    else
        check_warning "NSFaceIDUsageDescription missing (optional)"
    fi
    
    # Check URL schemes
    if plutil -extract CFBundleURLTypes raw "$INFO_PLIST_PATH" &>/dev/null; then
        check_pass "URL schemes configured"
    else
        check_fail "URL schemes not configured"
    fi
    
    return 0
}

# Check required assets
check_assets() {
    print_separator
    log_info "Checking required assets..."
    
    ASSETS_PATH="Interspace/Assets.xcassets"
    
    if [ ! -d "$ASSETS_PATH" ]; then
        check_fail "Assets.xcassets not found"
        return 1
    fi
    
    # Check AppIcon
    if [ -d "$ASSETS_PATH/AppIcon.appiconset" ]; then
        # Check for required icon sizes
        ICON_1024=$(find "$ASSETS_PATH/AppIcon.appiconset" -name "*1024*" | head -1)
        if [ -n "$ICON_1024" ]; then
            check_pass "App Store icon (1024x1024) present"
        else
            check_fail "App Store icon (1024x1024) missing"
        fi
        check_pass "AppIcon.appiconset found"
    else
        check_fail "AppIcon.appiconset missing"
    fi
    
    # Check Launch Screen assets
    if [ -f "$ASSETS_PATH/SplashScreenLogo.imageset/Contents.json" ]; then
        check_pass "Splash screen logo present"
    else
        check_fail "Splash screen logo missing"
    fi
    
    # Check other required images
    required_images=("google" "apple" "metamask")
    for image in "${required_images[@]}"; do
        if [ -d "$ASSETS_PATH/$image.imageset" ]; then
            check_pass "$image image asset present"
        else
            check_fail "$image image asset missing"
        fi
    done
    
    return 0
}

# Check configuration files
check_configuration() {
    print_separator
    log_info "Checking configuration files..."
    
    # Check for GoogleService-Info.plist
    if [ -f "Interspace/GoogleService-Info.plist" ]; then
        check_pass "GoogleService-Info.plist present"
    else
        check_fail "GoogleService-Info.plist missing"
    fi
    
    # Check for build configuration
    if [ -f "Interspace/Supporting/BuildConfiguration.xcconfig" ]; then
        check_pass "BuildConfiguration.xcconfig present"
    else
        # Check if template exists
        if [ -f "Interspace/Supporting/BuildConfiguration.xcconfig.template" ]; then
            check_warning "BuildConfiguration.xcconfig missing (template found)"
        else
            check_fail "BuildConfiguration.xcconfig missing"
        fi
    fi
    
    # Check entitlements
    if [ -f "Interspace/Interspace.entitlements" ]; then
        check_pass "Entitlements file present"
        
        # Validate keychain sharing
        if grep -q "keychain-access-groups" "Interspace/Interspace.entitlements"; then
            check_pass "Keychain sharing configured"
        else
            check_warning "Keychain sharing not configured"
        fi
        
        # Check associated domains
        if grep -q "associated-domains" "Interspace/Interspace.entitlements"; then
            check_pass "Associated domains configured"
        else
            check_warning "Associated domains not configured"
        fi
    else
        check_fail "Entitlements file missing"
    fi
    
    return 0
}

# Build the app in release mode
build_release() {
    print_separator
    log_info "Building app in Release mode..."
    
    # Clean build folder
    rm -rf "$DERIVED_DATA_PATH"
    
    # Build for generic iOS device
    if xcodebuild build \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        ONLY_ACTIVE_ARCH=NO \
        -quiet; then
        check_pass "Release build succeeded"
        return 0
    else
        check_fail "Release build failed"
        return 1
    fi
}

# Run unit tests
run_unit_tests() {
    print_separator
    log_info "Running unit tests..."
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_PATH"
    
    # Run tests
    if xcodebuild test \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -resultBundlePath "$TEST_RESULTS_PATH/UnitTests.xcresult" \
        -only-testing:InterspaceTests \
        -quiet; then
        check_pass "Unit tests passed"
        
        # Count test results
        TEST_COUNT=$(xcrun xcresulttool get --path "$TEST_RESULTS_PATH/UnitTests.xcresult" --format json | grep -c "TestSummaryIdentifiableObject" || echo "0")
        log_info "Executed $TEST_COUNT unit tests"
        
        return 0
    else
        check_fail "Unit tests failed"
        return 1
    fi
}

# Run critical UI tests
run_critical_ui_tests() {
    print_separator
    log_info "Running critical UI tests..."
    
    # Define critical test suites
    CRITICAL_TESTS=(
        "InterspaceUITests/AuthenticationUITests"
        "InterspaceUITests/ProfileManagementUITests"
        "InterspaceUITests/WalletConnectionUITests"
    )
    
    for test_suite in "${CRITICAL_TESTS[@]}"; do
        log_info "Running $test_suite..."
        
        if xcodebuild test \
            -workspace "$WORKSPACE" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -only-testing:"$test_suite" \
            -quiet; then
            check_pass "$test_suite passed"
        else
            check_fail "$test_suite failed"
            return 1
        fi
    done
    
    return 0
}

# Check for common issues
check_common_issues() {
    print_separator
    log_info "Checking for common issues..."
    
    # Check for TODO/FIXME comments in release
    TODO_COUNT=$(grep -r "TODO\|FIXME" --include="*.swift" Interspace/ | grep -v "Tests" | wc -l || echo "0")
    if [ "$TODO_COUNT" -gt 0 ]; then
        check_warning "Found $TODO_COUNT TODO/FIXME comments"
    else
        check_pass "No TODO/FIXME comments found"
    fi
    
    # Check for print statements (should use proper logging)
    PRINT_COUNT=$(grep -r "print(" --include="*.swift" Interspace/ | grep -v "Tests" | grep -v "Debug" | wc -l || echo "0")
    if [ "$PRINT_COUNT" -gt 0 ]; then
        check_warning "Found $PRINT_COUNT print statements (consider using proper logging)"
    else
        check_pass "No print statements found"
    fi
    
    # Check for force unwraps
    FORCE_UNWRAP_COUNT=$(grep -r "!" --include="*.swift" Interspace/ | grep -v "Tests" | grep -v "!=" | grep -v "!" | wc -l || echo "0")
    if [ "$FORCE_UNWRAP_COUNT" -gt 10 ]; then
        check_warning "Found many force unwraps ($FORCE_UNWRAP_COUNT) - review for safety"
    else
        check_pass "Force unwrap usage is minimal"
    fi
    
    # Check for hardcoded URLs
    if grep -r "http://\|https://" --include="*.swift" Interspace/ | grep -v "Tests" | grep -v "example.com" &>/dev/null; then
        check_warning "Found hardcoded URLs - ensure they're configurable"
    else
        check_pass "No hardcoded URLs found"
    fi
    
    return 0
}

# Validate pod dependencies
check_dependencies_pods() {
    print_separator
    log_info "Checking CocoaPods dependencies..."
    
    if [ -f "Podfile.lock" ]; then
        check_pass "Podfile.lock present"
        
        # Check if pods are installed
        if [ -d "Pods" ]; then
            check_pass "Pods directory exists"
            
            # Count pods
            POD_COUNT=$(grep -c "^PODS:" Podfile.lock || echo "0")
            log_info "Found $POD_COUNT pod dependencies"
        else
            check_fail "Pods directory missing - run 'pod install'"
            return 1
        fi
    else
        check_fail "Podfile.lock missing"
        return 1
    fi
    
    return 0
}

# Generate validation report
generate_report() {
    print_separator
    print_separator
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}DEPLOYMENT VALIDATION PASSED${NC}"
        echo -e "All $TOTAL_CHECKS checks passed successfully! ✅"
    else
        echo -e "${RED}DEPLOYMENT VALIDATION FAILED${NC}"
        echo -e "Failed $FAILED_CHECKS out of $TOTAL_CHECKS checks ❌"
    fi
    
    print_separator
    echo "Summary:"
    echo "- Total checks: $TOTAL_CHECKS"
    echo "- Passed: $PASSED_CHECKS"
    echo "- Failed: $FAILED_CHECKS"
    
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "- Timestamp: $TIMESTAMP"
    
    print_separator
}

# Main validation flow
main() {
    echo "🚀 Interspace iOS Deployment Validation"
    print_separator
    
    # Run all checks
    check_dependencies || true
    validate_info_plist || true
    check_assets || true
    check_configuration || true
    check_dependencies_pods || true
    build_release || true
    run_unit_tests || true
    run_critical_ui_tests || true
    check_common_issues || true
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [ $FAILED_CHECKS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main