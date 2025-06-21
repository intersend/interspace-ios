#!/bin/bash

# Interspace V2 API Test Runner Script
# Usage: ./run-v2-tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
CATEGORY=""
OUTPUT_FORMAT="console"
VERBOSE=false
SCHEME="Interspace"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--category)
            CATEGORY="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--device)
            DESTINATION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -e, --env <environment>     Set environment (dev, staging, prod) [default: dev]"
            echo "  -c, --category <category>   Run specific category (auth, profile, linking, token, edge)"
            echo "  -o, --output <format>       Output format (console, json, junit, xcpretty) [default: console]"
            echo "  -v, --verbose              Enable verbose logging"
            echo "  -d, --device <destination>  Xcode destination [default: iPhone 15 Pro Simulator]"
            echo "  -h, --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all tests"
            echo "  $0 -e prod                            # Run against production"
            echo "  $0 -c auth -v                         # Run auth tests with verbose output"
            echo "  $0 -o junit > test-results.xml        # Output JUnit format"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 Interspace V2 API Test Suite${NC}"
echo "================================"
echo "Environment: $ENVIRONMENT"
echo "Category: ${CATEGORY:-All}"
echo "Output: $OUTPUT_FORMAT"
echo "Verbose: $VERBOSE"
echo ""

# Set environment variables
export TEST_ENV="$ENVIRONMENT"
export TEST_VERBOSE="$VERBOSE"

# Build test command
TEST_CMD="xcodebuild test \
    -scheme \"$SCHEME\" \
    -destination \"$DESTINATION\" \
    -configuration Debug"

# Add specific test filter if category is specified
if [ -n "$CATEGORY" ]; then
    case $CATEGORY in
        auth|authentication)
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testEmailAuthNewUser"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testEmailAuthReturningUser"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testWalletAuthNewUser"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testGuestAuthentication"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testLogout"
            ;;
        profile|profiles)
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testAutomaticProfileCreation"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testGetProfiles"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testCreateAdditionalProfile"
            ;;
        linking|account-linking)
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testLinkEmailToWallet"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testGetIdentityGraph"
            ;;
        token|tokens)
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testTokenRefresh"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testTokenValidation"
            ;;
        edge|edge-cases)
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testInvalidEmailCode"
            TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests/testRateLimiting"
            ;;
        *)
            echo -e "${RED}Unknown category: $CATEGORY${NC}"
            exit 1
            ;;
    esac
else
    # Run all tests
    TEST_CMD="$TEST_CMD -only-testing:InterspaceTests/V2APITests"
fi

# Handle output format
case $OUTPUT_FORMAT in
    console)
        # Run tests with standard output
        echo -e "${YELLOW}Running tests...${NC}"
        echo ""
        eval $TEST_CMD | grep -E "(Test Suite|Test Case|Executed|passed|failed)"
        ;;
    xcpretty)
        # Use xcpretty for formatted output
        if ! command -v xcpretty &> /dev/null; then
            echo -e "${RED}xcpretty not installed. Install with: gem install xcpretty${NC}"
            exit 1
        fi
        eval $TEST_CMD | xcpretty --color --simple
        ;;
    json)
        # Output JSON format
        eval $TEST_CMD -resultBundlePath TestResults.xcresult
        xcrun xcresulttool get --format json --path TestResults.xcresult
        rm -rf TestResults.xcresult
        ;;
    junit)
        # Output JUnit XML format
        if ! command -v xcpretty &> /dev/null; then
            echo -e "${RED}xcpretty not installed. Install with: gem install xcpretty${NC}"
            exit 1
        fi
        eval $TEST_CMD | xcpretty --report junit
        ;;
    *)
        echo -e "${RED}Unknown output format: $OUTPUT_FORMAT${NC}"
        exit 1
        ;;
esac

# Check exit code
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Tests completed successfully!${NC}"
else
    echo ""
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi