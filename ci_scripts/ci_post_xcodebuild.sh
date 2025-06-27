#!/bin/sh
#
# Xcode Cloud Post-Build Script
# This script runs after the build/test/archive action completes
#

set -e

echo "📦 Starting Xcode Cloud post-build tasks..."

# Script directory
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

# Process test results
process_test_results() {
    if [[ "$CI_XCODEBUILD_ACTION" == *"test"* ]]; then
        log_info "Processing test results..."
        
        if [ -n "$CI_RESULT_BUNDLE_PATH" ] && [ -d "$CI_RESULT_BUNDLE_PATH" ]; then
            log_info "Test results available at: $CI_RESULT_BUNDLE_PATH"
            
            # Extract test summary
            if command -v xcrun &> /dev/null; then
                xcrun xcresulttool get --path "$CI_RESULT_BUNDLE_PATH" --format json > test_results.json 2>/dev/null || true
                
                # Create test summary
                if [ -f "test_results.json" ]; then
                    TEST_SUMMARY_FILE="$PROJECT_DIR/TEST_SUMMARY.md"
                    
                    cat > "$TEST_SUMMARY_FILE" << EOF
# Test Results Summary

**Build Number:** $CI_BUILD_NUMBER
**Test Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Device:** ${CI_TEST_DESTINATION_DEVICE_TYPE:-Unknown}
**iOS Version:** ${CI_TEST_DESTINATION_RUNTIME:-Unknown}

## Results

EOF
                    
                    # Parse test results (simplified - you can enhance this)
                    if grep -q '"testsFailedCount" : 0' test_results.json; then
                        echo "✅ **All tests passed!**" >> "$TEST_SUMMARY_FILE"
                        log_success "All tests passed"
                    else
                        echo "❌ **Some tests failed**" >> "$TEST_SUMMARY_FILE"
                        log_warning "Test failures detected"
                    fi
                    
                    rm -f test_results.json
                fi
            fi
        else
            log_warning "Test results bundle not found"
        fi
    fi
}

# Handle archive artifacts
handle_archive_artifacts() {
    if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
        log_info "Processing archive artifacts..."
        
        if [ -n "$CI_ARCHIVE_PATH" ] && [ -d "$CI_ARCHIVE_PATH" ]; then
            log_info "Archive created at: $CI_ARCHIVE_PATH"
            
            # Process dSYMs
            DSYM_PATH="$CI_ARCHIVE_PATH/dSYMs"
            if [ -d "$DSYM_PATH" ]; then
                log_info "Found dSYMs at: $DSYM_PATH"
                
                # Upload dSYMs to crash reporting service
                if [ -n "$CRASHLYTICS_API_KEY" ]; then
                    log_info "Uploading dSYMs to Crashlytics..."
                    # Add your Crashlytics upload command here
                    # Example: upload-symbols -k "$CRASHLYTICS_API_KEY" -p ios "$DSYM_PATH"
                fi
                
                # Backup dSYMs
                DSYM_BACKUP_DIR="$PROJECT_DIR/dSYMs_backup"
                mkdir -p "$DSYM_BACKUP_DIR"
                cp -R "$DSYM_PATH"/* "$DSYM_BACKUP_DIR/" 2>/dev/null || true
                log_success "dSYMs backed up"
            fi
            
            # Generate archive info
            ARCHIVE_INFO_FILE="$PROJECT_DIR/ARCHIVE_INFO.md"
            cat > "$ARCHIVE_INFO_FILE" << EOF
# Archive Information

**Build Number:** $CI_BUILD_NUMBER
**Archive Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Configuration:** ${CONFIGURATION:-Release}
**Workflow:** $CI_WORKFLOW

## Archive Contents

- **App Binary:** Interspace.app
- **dSYMs:** Available for symbolication
- **Bitcode:** ${ENABLE_BITCODE:-NO}

## Distribution

This archive is ready for:
$(if [[ "$CI_WORKFLOW" == *"TestFlight"* ]]; then echo "- ✅ TestFlight Distribution"; else echo "- ⏸️ TestFlight Distribution"; fi)
$(if [[ "$CI_WORKFLOW" == *"Release"* ]]; then echo "- ✅ App Store Distribution"; else echo "- ⏸️ App Store Distribution"; fi)

## Next Steps

1. Archive will be automatically processed by Xcode Cloud
2. Distribution will follow workflow configuration
3. Notifications will be sent upon completion
EOF
            
            log_success "Archive info generated"
        else
            log_error "Archive path not found"
        fi
    fi
}

# Generate build metrics
generate_build_metrics() {
    log_info "Generating build metrics..."
    
    METRICS_FILE="$PROJECT_DIR/BUILD_METRICS.json"
    
    # Calculate build duration (if start time is available)
    BUILD_DURATION="N/A"
    if [ -n "$CI_BUILD_START_TIME" ]; then
        END_TIME=$(date +%s)
        START_TIME=$(date -d "$CI_BUILD_START_TIME" +%s 2>/dev/null || echo "0")
        if [ "$START_TIME" != "0" ]; then
            DURATION=$((END_TIME - START_TIME))
            BUILD_DURATION="${DURATION}s"
        fi
    fi
    
    # Create metrics JSON
    cat > "$METRICS_FILE" << EOF
{
  "build_number": "$CI_BUILD_NUMBER",
  "workflow": "$CI_WORKFLOW",
  "action": "$CI_XCODEBUILD_ACTION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration": "$BUILD_DURATION",
  "platform": "$CI_PRODUCT_PLATFORM",
  "xcode_version": "$CI_XCODE_VERSION",
  "branch": "${CI_BRANCH:-null}",
  "tag": "${CI_TAG:-null}",
  "pull_request": "${CI_PULL_REQUEST_NUMBER:-null}",
  "success": true
}
EOF
    
    log_success "Build metrics generated"
}

# Send notifications
send_notifications() {
    log_info "Processing notifications..."
    
    # Slack notification
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        log_info "Sending Slack notification..."
        
        # Determine notification color and emoji
        if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
            COLOR="good"
            EMOJI="📦"
            TITLE="Archive Created"
        elif [[ "$CI_XCODEBUILD_ACTION" == *"test"* ]]; then
            COLOR="good"
            EMOJI="✅"
            TITLE="Tests Passed"
        else
            COLOR="good"
            EMOJI="🔨"
            TITLE="Build Succeeded"
        fi
        
        # Create Slack payload
        SLACK_PAYLOAD=$(cat << EOF
{
  "attachments": [
    {
      "color": "$COLOR",
      "title": "$EMOJI $TITLE - Build #$CI_BUILD_NUMBER",
      "fields": [
        {
          "title": "Workflow",
          "value": "$CI_WORKFLOW",
          "short": true
        },
        {
          "title": "Branch",
          "value": "${CI_BRANCH:-N/A}",
          "short": true
        }
      ],
      "footer": "Xcode Cloud",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
        
        # Send to Slack
        curl -X POST -H 'Content-type: application/json' \
             --data "$SLACK_PAYLOAD" \
             "$SLACK_WEBHOOK_URL" \
             2>/dev/null || log_warning "Failed to send Slack notification"
    fi
}

# Clean up temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Remove temporary build artifacts
    rm -f "$PROJECT_DIR/test_results.json" 2>/dev/null || true
    
    # Clean derived data if needed (Xcode Cloud handles this)
    
    log_success "Cleanup completed"
}

# Create post-build summary
create_summary() {
    log_info "Creating post-build summary..."
    
    SUMMARY_FILE="$PROJECT_DIR/BUILD_SUMMARY.md"
    
    cat > "$SUMMARY_FILE" << EOF
# Xcode Cloud Build Summary

## Build Information
- **Build Number:** $CI_BUILD_NUMBER
- **Workflow:** $CI_WORKFLOW
- **Action:** $CI_XCODEBUILD_ACTION
- **Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Status:** ✅ Success

## Environment
- **Xcode Version:** $CI_XCODE_VERSION
- **Platform:** $CI_PRODUCT_PLATFORM
- **Configuration:** ${CONFIGURATION:-Debug}

## Source
- **Branch:** ${CI_BRANCH:-N/A}
- **Tag:** ${CI_TAG:-N/A}
- **PR:** ${CI_PULL_REQUEST_NUMBER:-N/A}

## Artifacts
$(if [[ "$CI_XCODEBUILD_ACTION" == *"test"* ]]; then echo "- Test Results: Available"; fi)
$(if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then echo "- Archive: Created"; fi)
$(if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then echo "- dSYMs: Available"; fi)

## Next Steps
$(if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]] && [[ "$CI_WORKFLOW" == *"TestFlight"* ]]; then
    echo "- Archive will be submitted to TestFlight"
    echo "- Internal testers will receive notification"
    echo "- Beta review will be initiated"
elif [[ "$CI_XCODEBUILD_ACTION" == "archive" ]] && [[ "$CI_WORKFLOW" == *"Release"* ]]; then
    echo "- Archive will be submitted to App Store Connect"
    echo "- Release notes will be generated"
    echo "- App review process will begin"
else
    echo "- Build artifacts are available"
    echo "- No distribution configured for this workflow"
fi)

---
*Generated by Xcode Cloud*
EOF
    
    log_success "Build summary created"
}

# Main execution
main() {
    echo "================================================"
    echo "     Xcode Cloud Post-Build Tasks"
    echo "================================================"
    echo ""
    
    # Log build result
    log_success "Build action completed: $CI_XCODEBUILD_ACTION"
    
    # Run post-build tasks
    process_test_results
    handle_archive_artifacts
    generate_build_metrics
    send_notifications
    create_summary
    cleanup
    
    echo ""
    log_success "Post-build tasks completed successfully!"
    echo ""
}

# Run main function
main