#!/bin/bash

# Simple Test Configuration Fix
# This script provides a direct solution for adding test files to Xcode project

set -e

echo "🔧 Simple iOS Test Configuration Fix"
echo "==================================="

# Create verification script first
cat > verify_test_setup.sh << 'EOF'
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
EOF
chmod +x verify_test_setup.sh

# Create a direct test runner
cat > run_tests_command_line.sh << 'EOF'
#!/bin/bash

echo "🧪 Command Line Test Runner"
echo "========================="

# Check for workspace
if [ -f "Interspace.xcworkspace/contents.xcworkspacedata" ]; then
    echo "📱 Using workspace configuration..."
    BUILD_CMD="xcodebuild -workspace Interspace.xcworkspace"
else
    echo "📱 Using project configuration..."
    BUILD_CMD="xcodebuild -project Interspace.xcodeproj"
fi

# Set test configuration
SCHEME="Interspace"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.5"

echo "🔨 Building for testing..."
$BUILD_CMD \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    build-for-testing \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath ./build/DerivedData

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo ""
    echo "🧪 Running tests..."
    $BUILD_CMD \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -configuration Debug \
        test-without-building \
        -derivedDataPath ./build/DerivedData \
        -only-testing:InterspaceTests
else
    echo "❌ Build failed. Test files may not be properly linked."
    echo "   Please follow the manual instructions in TEST_CONFIGURATION_FIX.md"
fi
EOF
chmod +x run_tests_command_line.sh

# Create a detailed manual fix guide
cat > MANUAL_TEST_FIX_STEPS.md << 'EOF'
# Manual Test Configuration Fix Steps

## Quick Fix in Xcode (5 minutes)

1. **Open the project**
   ```bash
   open Interspace.xcworkspace
   ```
   Or if no workspace exists:
   ```bash
   open Interspace.xcodeproj
   ```

2. **Add test files to InterspaceTests target**
   - In the Project Navigator (left sidebar), find the "InterspaceTests" folder
   - Right-click on "InterspaceTests" folder
   - Select "Add Files to 'Interspace'..."
   - Navigate to the InterspaceTests directory in the file dialog
   - Select all .swift files (Cmd+A after clicking on first file)
   - **IMPORTANT**: In the "Add to targets" section at the bottom:
     - ✅ Check "InterspaceTests" 
     - ❌ Uncheck "Interspace"
   - Click "Add"

3. **Verify the files were added**
   - Expand the InterspaceTests folder in Project Navigator
   - You should see all the test files listed
   - Each file should have a checkbox next to it in the Target Membership inspector

4. **Run the tests**
   - Press Cmd+U or Product → Test
   - Tests should now compile and run

## Command Line Alternative

If you prefer not to use Xcode, you can try:

```bash
# Build the main app first
xcodebuild -scheme Interspace -destination "platform=iOS Simulator,name=iPhone 15" build

# Then run tests
xcodebuild -scheme Interspace -destination "platform=iOS Simulator,name=iPhone 15" test -only-testing:InterspaceTests
```

## Verification

After fixing, run:
```bash
./verify_test_setup.sh
```

You should see "Test files in project: 11" or higher.
EOF

echo ""
echo "✅ Created helper scripts!"
echo ""
echo "📋 Next Steps:"
echo ""
echo "Option 1 - Manual Fix (Recommended):"
echo "  1. Read MANUAL_TEST_FIX_STEPS.md"
echo "  2. Follow the Xcode steps to add test files"
echo "  3. Run ./verify_test_setup.sh to confirm"
echo ""
echo "Option 2 - Try automated build:"
echo "  1. Run ./run_tests_command_line.sh"
echo "  2. If it fails, use Option 1"
echo ""
echo "The issue is that test source files exist but aren't linked in the Xcode project."
echo "This requires adding them through Xcode's UI or using xcodeproj tools."