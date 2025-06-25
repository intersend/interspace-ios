#!/bin/bash
#
# iOS TestFlight Preparation Script
# Prepares the iOS app for TestFlight submission
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$IOS_DIR/Interspace/Supporting/BuildConfiguration.xcconfig"
PROJECT_FILE="$IOS_DIR/Interspace.xcodeproj/project.pbxproj"
INFO_PLIST="$IOS_DIR/Interspace/Info.plist"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check configuration
check_configuration() {
    log_info "Checking configuration..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "BuildConfiguration.xcconfig not found"
        log_info "Create it from template: cp BuildConfiguration.xcconfig.template BuildConfiguration.xcconfig"
        return 1
    fi
    
    # Check for placeholder values
    if grep -q "YOUR_.*_HERE" "$CONFIG_FILE"; then
        log_error "Configuration contains placeholder values:"
        grep "YOUR_.*_HERE" "$CONFIG_FILE" | while read -r line; do
            echo "  - $line"
        done
        return 1
    else
        log_success "No placeholder values found"
    fi
    
    # Check API URL
    API_URL=$(grep "API_BASE_URL_RELEASE" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d ' ' || echo "")
    if [[ "$API_URL" =~ ngrok ]]; then
        log_error "Production API URL contains ngrok: $API_URL"
        return 1
    elif [[ "$API_URL" =~ localhost ]]; then
        log_error "Production API URL contains localhost: $API_URL"
        return 1
    elif [ -n "$API_URL" ]; then
        log_success "Production API URL: $API_URL"
    else
        log_error "Production API URL not configured"
        return 1
    fi
    
    # Check Google configuration
    GOOGLE_CLIENT_ID=$(grep "GOOGLE_CLIENT_ID" "$CONFIG_FILE" | grep -v "//" | cut -d'=' -f2- | tr -d ' ' || echo "")
    if [ -n "$GOOGLE_CLIENT_ID" ] && [ "$GOOGLE_CLIENT_ID" != "YOUR_GOOGLE_CLIENT_ID_HERE" ]; then
        log_success "Google Client ID configured"
    else
        log_error "Google Client ID not configured"
        return 1
    fi
    
    return 0
}

# Check version and build number
check_version() {
    log_info "Checking version and build number..."
    
    # Extract version info
    MARKETING_VERSION=$(grep "MARKETING_VERSION = " "$PROJECT_FILE" | head -1 | cut -d'"' -f2)
    CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | head -1 | grep -o '[0-9]*')
    
    log_info "Current version: $MARKETING_VERSION (build $CURRENT_BUILD)"
    
    # Suggest next build number
    NEXT_BUILD=$((CURRENT_BUILD + 1))
    log_info "Suggested next build: $NEXT_BUILD"
    
    read -p "Increment build number to $NEXT_BUILD? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD/CURRENT_PROJECT_VERSION = $NEXT_BUILD/g" "$PROJECT_FILE"
        log_success "Build number updated to $NEXT_BUILD"
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check if Package.resolved exists
    if [ -f "$IOS_DIR/Interspace.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
        log_success "Swift Package dependencies resolved"
    else
        log_warning "Package.resolved not found - open project in Xcode to resolve dependencies"
    fi
}

# Check for development artifacts
check_dev_artifacts() {
    log_info "Checking for development artifacts..."
    
    # Check for TODO comments
    TODO_COUNT=$(find "$IOS_DIR/Interspace" -name "*.swift" -type f -exec grep -l "TODO\|FIXME\|HACK" {} \; | wc -l | tr -d ' ')
    if [ "$TODO_COUNT" -gt 0 ]; then
        log_warning "Found $TODO_COUNT files with TODO/FIXME/HACK comments"
    else
        log_success "No TODO/FIXME/HACK comments found"
    fi
    
    # Check for print statements
    PRINT_COUNT=$(find "$IOS_DIR/Interspace" -name "*.swift" -type f -exec grep -l "^[[:space:]]*print(" {} \; | wc -l | tr -d ' ')
    if [ "$PRINT_COUNT" -gt 0 ]; then
        log_warning "Found $PRINT_COUNT files with print statements"
        log_info "Consider using proper logging instead"
    else
        log_success "No print statements found"
    fi
}

# Create pre-submission checklist
create_checklist() {
    log_info "Creating TestFlight submission checklist..."
    
    CHECKLIST_FILE="$IOS_DIR/TESTFLIGHT_CHECKLIST_$(date +%Y%m%d).md"
    
    cat > "$CHECKLIST_FILE" << EOF
# TestFlight Submission Checklist

Generated on: $(date)

## Pre-submission Checks

### Configuration
- [ ] All API keys and credentials are production values
- [ ] Production API URL is correctly set
- [ ] No placeholder values in configuration
- [ ] Bundle identifier matches App Store Connect

### Build Settings
- [ ] Version number is appropriate
- [ ] Build number is incremented
- [ ] Release configuration selected
- [ ] Optimization enabled

### Code Quality
- [ ] All tests pass
- [ ] No compiler warnings
- [ ] Development features disabled
- [ ] Proper error handling in place

### Assets
- [ ] App icon provided (all sizes)
- [ ] Launch screen configured
- [ ] Screenshots prepared (if needed)

### Privacy & Security
- [ ] Privacy manifest complete
- [ ] Entitlements configured correctly
- [ ] No hardcoded secrets
- [ ] Proper keychain usage

## App Store Connect Setup

### TestFlight Information
- [ ] App description written
- [ ] What to test section filled
- [ ] Test credentials provided (if needed)
- [ ] Contact information added

### Beta Testing
- [ ] Test groups configured
- [ ] Testers invited
- [ ] Feedback email set up
- [ ] Beta app description written

## Submission Process

1. **Archive the app**
   - Select "Any iOS Device" as destination
   - Product → Archive
   - Wait for archive to complete

2. **Upload to App Store Connect**
   - Click "Distribute App"
   - Select "TestFlight & App Store"
   - Follow upload wizard
   - Wait for processing

3. **Configure TestFlight**
   - Add build to test group
   - Fill in test information
   - Submit for beta review

4. **Post-submission**
   - Monitor for processing completion
   - Check for any validation issues
   - Wait for beta review approval
   - Send invites to testers

## Current Configuration

- **Version:** $MARKETING_VERSION
- **Build:** $CURRENT_BUILD
- **API URL:** $API_URL
- **Bundle ID:** com.interspace.ios

## Notes

Add any specific notes for this build here:

EOF
    
    log_success "Checklist created: $CHECKLIST_FILE"
}

# Generate test notes
generate_test_notes() {
    log_info "Generating TestFlight test notes..."
    
    TEST_NOTES_FILE="$IOS_DIR/TESTFLIGHT_TEST_NOTES.md"
    
    cat > "$TEST_NOTES_FILE" << EOF
# TestFlight Test Notes

## What's New in This Build

- Initial TestFlight release
- Email authentication with verification codes
- Profile management
- Secure wallet functionality
- Google Sign-In integration

## What to Test

### Authentication Flow
1. Sign up with email
2. Verify email with code
3. Sign in with existing account
4. Sign in with Google
5. Sign out functionality

### Profile Management
1. Create new profile
2. Switch between profiles
3. View profile details
4. Update profile settings

### General Testing
1. App performance and responsiveness
2. Error handling and messages
3. Network connectivity handling
4. UI/UX consistency

## Known Issues

- MPC wallet creation is in development mode
- Some features may be limited in this beta

## How to Provide Feedback

Please report any issues or feedback through:
1. TestFlight feedback feature
2. Email: support@interspace.fi

Include the following in your feedback:
- Device model and iOS version
- Steps to reproduce any issues
- Screenshots if applicable
- Expected vs actual behavior

## Test Credentials

For testing purposes, you can use your own email address.
Verification codes will be sent to the email provided.

Thank you for testing Interspace!
EOF
    
    log_success "Test notes created: $TEST_NOTES_FILE"
}

# Final summary
show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "     TestFlight Preparation Summary"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    if check_configuration; then
        echo "✅ Configuration: Ready"
    else
        echo "❌ Configuration: Needs attention"
    fi
    
    echo "📱 Version: $MARKETING_VERSION (build $CURRENT_BUILD)"
    echo "🔗 API URL: $API_URL"
    echo ""
    
    echo "Next steps:"
    echo "1. Open Interspace.xcodeproj in Xcode"
    echo "2. Select 'Any iOS Device' as destination"
    echo "3. Product → Archive"
    echo "4. Distribute App → TestFlight & App Store"
    echo "5. Follow the upload wizard"
    echo ""
    echo "Files created:"
    echo "- Checklist: TESTFLIGHT_CHECKLIST_$(date +%Y%m%d).md"
    echo "- Test notes: TESTFLIGHT_TEST_NOTES.md"
}

# Main function
main() {
    cd "$IOS_DIR"
    
    echo "TestFlight Preparation Script"
    echo ""
    
    check_configuration
    check_version
    check_dependencies
    check_dev_artifacts
    create_checklist
    generate_test_notes
    show_summary
}

# Run main
main