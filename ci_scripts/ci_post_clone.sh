#!/bin/sh
#
# Xcode Cloud Post-Clone Script
# This script runs after the repository is cloned and before dependencies are resolved
#

set -e

echo "🚀 Starting Xcode Cloud post-clone setup..."

# Script directory
SCRIPT_DIR="$CI_PRIMARY_REPOSITORY_PATH/ci_scripts"
PROJECT_DIR="$CI_PRIMARY_REPOSITORY_PATH"

# Helper functions (simplified for sh compatibility)
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

# Setup build configuration
setup_build_configuration() {
    log_info "Setting up build configuration..."
    
    CONFIG_FILE="$PROJECT_DIR/Interspace/Supporting/BuildConfiguration.xcconfig"
    TEMPLATE_FILE="$CONFIG_FILE.template"
    
    # Check if configuration already exists
    if [ -f "$CONFIG_FILE" ]; then
        log_info "BuildConfiguration.xcconfig already exists"
        return 0
    fi
    
    # Copy from template
    if [ -f "$TEMPLATE_FILE" ]; then
        cp "$TEMPLATE_FILE" "$CONFIG_FILE"
        log_success "Created BuildConfiguration.xcconfig from template"
    else
        log_error "Template file not found: $TEMPLATE_FILE"
        return 1
    fi
    
    # Replace placeholder values with environment variables
    if [ -n "$API_BASE_URL_DEBUG" ]; then
        sed -i '' "s|YOUR_DEBUG_API_URL_HERE|$API_BASE_URL_DEBUG|g" "$CONFIG_FILE"
        log_success "Set debug API URL"
    fi
    
    if [ -n "$API_BASE_URL_RELEASE" ]; then
        # For TestFlight/Beta builds, use staging API
        if case "$CI_WORKFLOW" in *TestFlight*|*Beta*) true;; *) false;; esac || [ "$CI_BRANCH" = "beta" ]; then
            STAGING_API_URL="https://staging-api.interspace.fi/api/v2"
            sed -i '' "s|YOUR_PRODUCTION_API_URL_HERE|$STAGING_API_URL|g" "$CONFIG_FILE"
            log_success "Set staging API URL for TestFlight: $STAGING_API_URL"
        else
            sed -i '' "s|YOUR_PRODUCTION_API_URL_HERE|$API_BASE_URL_RELEASE|g" "$CONFIG_FILE"
            log_success "Set production API URL"
        fi
    fi
    
    if [ -n "$GOOGLE_CLIENT_ID" ]; then
        sed -i '' "s|YOUR_GOOGLE_CLIENT_ID_HERE|$GOOGLE_CLIENT_ID|g" "$CONFIG_FILE"
        log_success "Set Google Client ID"
    fi
    
    if [ -n "$INFURA_API_KEY" ]; then
        sed -i '' "s|YOUR_INFURA_API_KEY_HERE|$INFURA_API_KEY|g" "$CONFIG_FILE"
        log_success "Set Infura API key"
    fi
    
    if [ -n "$WALLETCONNECT_PROJECT_ID" ]; then
        sed -i '' "s|YOUR_WALLETCONNECT_PROJECT_ID_HERE|$WALLETCONNECT_PROJECT_ID|g" "$CONFIG_FILE"
        log_success "Set WalletConnect Project ID"
    fi
}

# Setup Google Service configuration
setup_google_service() {
    log_info "Setting up Google Service configuration..."
    
    GOOGLE_PLIST="$PROJECT_DIR/Interspace/GoogleService-Info.plist"
    TEMPLATE_PLIST="$GOOGLE_PLIST.template"
    
    # Check if plist already exists
    if [ -f "$GOOGLE_PLIST" ]; then
        log_info "GoogleService-Info.plist already exists"
        return 0
    fi
    
    # If we have the content as environment variable
    if [ -n "$GOOGLE_SERVICE_INFO_PLIST" ]; then
        echo "$GOOGLE_SERVICE_INFO_PLIST" > "$GOOGLE_PLIST"
        log_success "Created GoogleService-Info.plist from environment variable"
        return 0
    fi
    
    # Copy from template if available
    if [ -f "$TEMPLATE_PLIST" ]; then
        cp "$TEMPLATE_PLIST" "$GOOGLE_PLIST"
        log_success "Created GoogleService-Info.plist from template"
    else
        log_warning "GoogleService-Info.plist template not found"
    fi
}

# Cache dependencies
cache_dependencies() {
    log_info "Setting up dependency caching..."
    
    # SPM cache is handled automatically by Xcode Cloud
    # We can add custom caching logic here if needed
    
    # Example: Cache derived data for faster builds
    if [ -n "$CI_DERIVED_DATA_PATH" ]; then
        log_info "Derived data path: $CI_DERIVED_DATA_PATH"
    fi
    
    log_success "Dependency caching configured"
}

# Validate environment
validate_environment() {
    log_info "Validating Xcode Cloud environment..."
    
    # Check required environment variables
    local missing_vars=()
    
    # These should be set in App Store Connect
    [ -z "$API_BASE_URL_RELEASE" ] && missing_vars+=("API_BASE_URL_RELEASE")
    [ -z "$GOOGLE_CLIENT_ID" ] && missing_vars+=("GOOGLE_CLIENT_ID")
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "Missing environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        log_info "Set these in App Store Connect > Xcode Cloud > Environment Variables"
    else
        log_success "All required environment variables are set"
    fi
    
    # Log Xcode Cloud specific variables
    log_info "Xcode Cloud Environment:"
    echo "  - Workflow: $CI_WORKFLOW"
    echo "  - Build Number: $CI_BUILD_NUMBER"
    echo "  - Product Platform: $CI_PRODUCT_PLATFORM"
    echo "  - Xcode Version: $CI_XCODE_VERSION"
    
    if [ -n "$CI_BRANCH" ]; then
        echo "  - Branch: $CI_BRANCH"
    fi
    
    if [ -n "$CI_TAG" ]; then
        echo "  - Tag: $CI_TAG"
    fi
    
    if [ -n "$CI_PULL_REQUEST_NUMBER" ]; then
        echo "  - Pull Request: #$CI_PULL_REQUEST_NUMBER"
    fi
}

# Configure Git for private repositories
configure_git_auth() {
    log_info "Configuring Git authentication..."
    
    # Use GitHub PAT for private repos
    if [ -n "$GITHUB_PAT" ]; then
        # Configure git to use the PAT for GitHub
        git config --global url."https://x-access-token:${GITHUB_PAT}@github.com/".insteadOf "https://github.com/"
        git config --global url."https://x-access-token:${GITHUB_PAT}@github.com/".insteadOf "git@github.com:"
        
        # Also handle the specific private repo with embedded credentials
        git config --global url."https://x-access-token:${GITHUB_PAT}@github.com/dushyantsutharsilencelaboratories/".insteadOf "https://dushyantsutharsilencelaboratories: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@github.com/dushyantsutharsilencelaboratories/"
        
        log_success "Git authentication configured"
    else
        log_warning "GITHUB_PAT not set - private repositories may fail"
    fi
}

# Install additional tools if needed
install_tools() {
    log_info "Checking for additional tools..."
    
    # SwiftLint is included in Xcode Cloud by default
    if command -v swiftlint &> /dev/null; then
        log_success "SwiftLint is available ($(swiftlint version))"
    else
        log_warning "SwiftLint not found"
    fi
    
    # Install any custom tools here if needed
    # Example: brew install <tool>
}

# Main execution
main() {
    echo "================================================"
    echo "     Xcode Cloud Post-Clone Setup"
    echo "================================================"
    echo ""
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Run setup steps
    configure_git_auth
    setup_build_configuration
    setup_google_service
    cache_dependencies
    validate_environment
    install_tools
    
    echo ""
    log_success "Post-clone setup completed successfully!"
    echo ""
}

# Run main function
main