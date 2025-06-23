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
