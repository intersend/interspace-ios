#!/bin/sh
#
# Xcode Cloud Pre-Build Script - Simplified version
#

echo "🔨 Starting Xcode Cloud pre-build setup..."

# Get project directory
PROJECT_DIR="$CI_PRIMARY_REPOSITORY_PATH"

# Simple logging
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[✓] $1"
}

# Update build number if available
if [ -n "$CI_BUILD_NUMBER" ]; then
    log_info "Build number: $CI_BUILD_NUMBER"
    cd "$PROJECT_DIR" || exit 0
    
    # Try to update build number, but don't fail if it doesn't work
    if command -v agvtool > /dev/null 2>&1; then
        agvtool new-version -all "$CI_BUILD_NUMBER" > /dev/null 2>&1 || true
    fi
fi

# Simple configuration based on workflow
log_info "Workflow: ${CI_WORKFLOW:-unknown}"
log_info "Branch: ${CI_BRANCH:-unknown}"
log_info "Action: ${CI_XCODEBUILD_ACTION:-unknown}"

# Success
log_success "Pre-build setup completed!"
exit 0