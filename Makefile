# Interspace iOS Makefile
# Convenient commands for development and testing

.PHONY: help test test-v2 test-auth test-profile test-linking test-token test-edge test-all clean

# Default target
help:
	@echo "Interspace iOS Development Commands"
	@echo "=================================="
	@echo "make test-v2          - Run all V2 API tests"
	@echo "make test-auth        - Run authentication tests"
	@echo "make test-profile     - Run profile tests"
	@echo "make test-linking     - Run account linking tests"
	@echo "make test-token       - Run token management tests"
	@echo "make test-edge        - Run edge case tests"
	@echo "make test-prod        - Run tests against production"
	@echo "make test-report      - Generate test report"
	@echo "make clean            - Clean build artifacts"

# Run all V2 API tests
test-v2:
	@echo "🧪 Running all V2 API tests..."
	@./Scripts/run-v2-tests.sh -v

# Run specific test categories
test-auth:
	@echo "🔐 Running authentication tests..."
	@./Scripts/run-v2-tests.sh -c auth -v

test-profile:
	@echo "👤 Running profile tests..."
	@./Scripts/run-v2-tests.sh -c profile -v

test-linking:
	@echo "🔗 Running account linking tests..."
	@./Scripts/run-v2-tests.sh -c linking -v

test-token:
	@echo "🎫 Running token management tests..."
	@./Scripts/run-v2-tests.sh -c token -v

test-edge:
	@echo "⚠️  Running edge case tests..."
	@./Scripts/run-v2-tests.sh -c edge -v

# Run tests against different environments
test-dev:
	@echo "🔧 Running tests against development..."
	@./Scripts/run-v2-tests.sh -e dev -v

test-staging:
	@echo "🚧 Running tests against staging..."
	@./Scripts/run-v2-tests.sh -e staging -v

test-prod:
	@echo "🚀 Running tests against production..."
	@./Scripts/run-v2-tests.sh -e prod

# Generate test report
test-report:
	@echo "📊 Generating test report..."
	@./Scripts/run-v2-tests.sh -o junit > test-results.xml
	@echo "Report saved to test-results.xml"

# Run tests with specific output format
test-json:
	@./Scripts/run-v2-tests.sh -o json

test-junit:
	@./Scripts/run-v2-tests.sh -o junit

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf DerivedData/
	@rm -rf TestResults.xcresult
	@rm -f test-results.xml
	@rm -f test-output.log
	@echo "✨ Clean complete"

# Run tests in CI mode
test-ci:
	@echo "🤖 Running tests in CI mode..."
	@./Scripts/run-v2-tests.sh -o junit > test-results.xml

# Quick test (only critical tests)
test-quick:
	@echo "⚡ Running quick tests..."
	@./Scripts/run-v2-tests.sh -c auth

# Full regression test
test-full:
	@echo "🔍 Running full regression tests..."
	@make test-auth
	@make test-profile
	@make test-linking
	@make test-token
	@make test-edge

# Install test dependencies
test-deps:
	@echo "📦 Installing test dependencies..."
	@gem install xcpretty
	@echo "✅ Dependencies installed"