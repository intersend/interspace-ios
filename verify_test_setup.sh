#!/bin/bash

echo "🔍 Verifying Test Setup"
echo "======================"

# Check if test files are in project
PROJECT_FILE="Interspace.xcodeproj/project.pbxproj"
TEST_FILES=$(find InterspaceTests -name "*.swift" -type f 2>/dev/null | wc -l)
echo "📁 Test files in directory: $TEST_FILES"

# Check if files are referenced in project
REFERENCED_FILES=$(grep -c "InterspaceTests.*\.swift" "$PROJECT_FILE" 2>/dev/null || echo "0")
echo "📋 Test files in project: $REFERENCED_FILES"

# Check test target configuration
echo ""
echo "🎯 Test Target Configuration:"
grep -A 5 "TEST_HOST" "$PROJECT_FILE" 2>/dev/null | head -10 || echo "Not found"

echo ""
echo "✅ Verification complete!"
