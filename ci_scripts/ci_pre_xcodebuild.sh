#!/bin/sh
#
# Xcode Cloud Pre-Build Script
# This script runs after dependencies are resolved but before the build starts
#

set -e

echo "🔨 Starting Xcode Cloud pre-build setup..."

# Script directory
PROJECT_DIR="$CI_PRIMARY_REPOSITORY_PATH"

# Helper functions
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[✓] $1"
}

log_error() {
    echo "[✗] $1"
}

log_warning() {
    echo "[!] $1"
}

# Update build number
update_build_number() {
    log_info "Updating build number..."
    
    if [ -n "$CI_BUILD_NUMBER" ]; then
        # Use Xcode Cloud build number
        cd "$PROJECT_DIR"
        agvtool new-version -all "$CI_BUILD_NUMBER"
        log_success "Build number set to: $CI_BUILD_NUMBER"
    else
        log_warning "CI_BUILD_NUMBER not available"
    fi
}

# Update version for release builds
update_version_for_release() {
    if [ -n "$CI_TAG" ]; then
        log_info "Release build detected (tag: $CI_TAG)"
        
        # Extract version from tag (assumes format v1.2.3)
        VERSION=$(echo "$CI_TAG" | sed 's/^v//')
        
        if [ -n "$VERSION" ]; then
            cd "$PROJECT_DIR"
            agvtool new-marketing-version "$VERSION"
            log_success "Marketing version set to: $VERSION"
        fi
    fi
}

# Configure build settings
configure_build_settings() {
    log_info "Configuring build settings..."
    
    # Set build configuration based on workflow
    case "$CI_WORKFLOW" in
        *Release*|*Production*)
            export CONFIGURATION="Release"
            log_info "Using Release configuration"
            ;;
        *Beta*|*TestFlight*)
            export CONFIGURATION="Release"
            log_info "Using Release configuration for TestFlight"
            ;;
        *)
            export CONFIGURATION="Debug"
            log_info "Using Debug configuration"
            ;;
    esac
}

# Run SwiftLint
run_swiftlint() {
    log_info "Running SwiftLint..."
    
    cd "$PROJECT_DIR"
    
    if command -v swiftlint > /dev/null 2>&1; then
        # Run SwiftLint - don't fail build on warnings
        swiftlint lint || log_warning "SwiftLint found issues"
        log_success "SwiftLint check completed"
    else
        log_warning "SwiftLint not available"
    fi
}

# Update Info.plist with build information
update_info_plist() {
    log_info "Updating Info.plist with build information..."
    
    INFO_PLIST="$PROJECT_DIR/Interspace/Info.plist"
    
    if [ -f "$INFO_PLIST" ]; then
        # Add build metadata
        /usr/libexec/PlistBuddy -c "Set :BuildDate $(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :BuildDate string $(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INFO_PLIST"
        
        /usr/libexec/PlistBuddy -c "Set :BuildEnvironment XcodeCloud" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :BuildEnvironment string XcodeCloud" "$INFO_PLIST"
        
        if [ -n "$CI_WORKFLOW" ]; then
            /usr/libexec/PlistBuddy -c "Set :BuildWorkflow $CI_WORKFLOW" "$INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :BuildWorkflow string $CI_WORKFLOW" "$INFO_PLIST"
        fi
        
        if [ -n "$CI_BRANCH" ]; then
            /usr/libexec/PlistBuddy -c "Set :BuildBranch $CI_BRANCH" "$INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :BuildBranch string $CI_BRANCH" "$INFO_PLIST"
        fi
        
        if [ -n "$CI_COMMIT" ]; then
            # Get short commit hash
            SHORT_COMMIT=$(echo "$CI_COMMIT" | cut -c1-7)
            /usr/libexec/PlistBuddy -c "Set :BuildCommit $SHORT_COMMIT" "$INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :BuildCommit string $SHORT_COMMIT" "$INFO_PLIST"
        fi
        
        log_success "Info.plist updated with build metadata"
    else
        log_warning "Info.plist not found"
    fi
}

# Generate build notes
generate_build_notes() {
    log_info "Generating build notes..."
    
    BUILD_NOTES_FILE="$PROJECT_DIR/BUILD_NOTES.md"
    
    cat > "$BUILD_NOTES_FILE" << EOF
# Build Information

**Build Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Build Number:** ${CI_BUILD_NUMBER:-N/A}
**Workflow:** ${CI_WORKFLOW:-N/A}
**Branch:** ${CI_BRANCH:-N/A}
**Tag:** ${CI_TAG:-N/A}
**Pull Request:** ${CI_PULL_REQUEST_NUMBER:-N/A}

## Recent Changes

EOF

    # Add recent commit messages
    if command -v git > /dev/null 2>&1; then
        echo "### Recent Commits:" >> "$BUILD_NOTES_FILE"
        echo "" >> "$BUILD_NOTES_FILE"
        git log --oneline -10 >> "$BUILD_NOTES_FILE" 2>/dev/null || echo "Unable to fetch commit history" >> "$BUILD_NOTES_FILE"
    fi
    
    log_success "Build notes generated"
}

# Validate project state
validate_project() {
    log_info "Validating project state..."
    
    # Check for required files
    if [ ! -e "$PROJECT_DIR/Interspace.xcodeproj" ]; then
        log_error "Interspace.xcodeproj not found"
        return 1
    fi
    
    if [ ! -f "$PROJECT_DIR/Interspace/Supporting/BuildConfiguration.xcconfig" ]; then
        log_warning "BuildConfiguration.xcconfig not found - will be created by post-clone script"
    fi
    
    log_success "Project validation completed"
}

# Setup test environment
setup_test_environment() {
    case "$CI_XCODEBUILD_ACTION" in
        *test*)
            log_info "Setting up test environment..."
            export RUNNING_TESTS="YES"
            export TEST_BUILD="$CI_BUILD_NUMBER"
            log_success "Test environment configured"
            ;;
    esac
}

# Main execution
main() {
    echo "================================================"
    echo "     Xcode Cloud Pre-Build Setup"
    echo "================================================"
    echo ""
    
    # Run setup steps
    update_build_number
    update_version_for_release
    configure_build_settings
    run_swiftlint
    update_info_plist
    generate_build_notes
    validate_project
    setup_test_environment
    
    echo ""
    log_success "Pre-build setup completed successfully!"
    echo ""
}

# Run main function
main