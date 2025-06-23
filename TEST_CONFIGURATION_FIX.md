# iOS Test Configuration Fix Guide

## Issue Summary

The iOS test bundle is missing its executable because test source files are not properly linked in the Xcode project file. While the test files exist in the filesystem, they are not referenced in the `project.pbxproj` file's Sources build phase.

## Root Cause

The `InterspaceTests` target's Sources build phase is empty:
```
8E12DBE5DC3FA45B8CBEAC7F /* Sources */ = {
    isa = PBXSourcesBuildPhase;
    buildActionMask = 2147483647;
    files = (
    );  // <-- Empty array, no files included
    runOnlyForDeploymentPostprocessing = 0;
};
```

## Solutions

### Solution 1: Automated Fix Script (Recommended)

Run the provided fix script:
```bash
./fix_test_configuration.sh
```

This script will:
1. Back up your project file
2. Attempt to add test files using Ruby xcodeproj gem
3. Create verification and direct test runner scripts

### Solution 2: Manual Xcode Fix

1. Open `Interspace.xcworkspace` in Xcode
2. In the project navigator, right-click on the `InterspaceTests` group
3. Select "Add Files to 'InterspaceTests'..."
4. Navigate to the `InterspaceTests` directory
5. Select all `.swift` files (use Cmd+A)
6. **Important**: In the dialog, ensure:
   - ✅ "InterspaceTests" target is checked
   - ✅ "Copy items if needed" is unchecked (files already exist)
   - ✅ "Create groups" is selected
7. Click "Add"
8. Repeat for `InterspaceUITests` if needed

### Solution 3: Command Line Fix (Without Opening Xcode)

If you have Ruby and the xcodeproj gem installed:

```bash
# Install xcodeproj gem if not already installed
gem install xcodeproj --user-install

# Run the Ruby script to add files
ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('Interspace.xcodeproj')
test_target = project.targets.find { |t| t.name == 'InterspaceTests' }
test_group = project.main_group.find_subpath('InterspaceTests', true)

Dir.glob('InterspaceTests/**/*.swift').each do |file|
  file_ref = test_group.new_file(file)
  test_target.add_file_references([file_ref])
end

project.save
"
```

## Verification

After applying any fix, verify the setup:

```bash
# Run the verification script
./verify_test_setup.sh

# Or manually check:
grep -c "\.swift in Sources" Interspace.xcodeproj/project.pbxproj
```

You should see test files listed in the project file.

## Running Tests Without Xcode

Once files are properly linked, use:

```bash
# Using the direct runner script
./run_tests_direct.sh

# Or using xcodebuild directly
xcodebuild test \
  -scheme Interspace \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=17.5" \
  -only-testing:InterspaceTests
```

## Test Target Configuration Details

The test target already has correct build settings:
- `BUNDLE_LOADER = "$(TEST_HOST)"`
- `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Interspace.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Interspace"`
- `PRODUCT_BUNDLE_IDENTIFIER = com.interspace.InterspaceTests`
- `IPHONEOS_DEPLOYMENT_TARGET = 16.0`

The only missing piece is adding the source files to the Sources build phase.

## Troubleshooting

### Error: "Test bundle at path '.../InterspaceTests.xctest' does not contain an executable"
- **Cause**: No source files compiled into the test bundle
- **Fix**: Apply one of the solutions above to add test files

### Error: "Could not find test host for InterspaceTests"
- **Cause**: Main app target not built first
- **Fix**: Build the main app target before running tests

### Error: "No such module 'XCTest'"
- **Cause**: Test files not properly marked as test sources
- **Fix**: Ensure files are added to the test target, not the main app target

## Prevention

To prevent this issue in the future:
1. Always add test files through Xcode's UI when creating new tests
2. Verify test files are added to the correct target
3. Run tests immediately after adding new test files
4. Use source control to track changes to `project.pbxproj`