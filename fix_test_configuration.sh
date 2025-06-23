#!/bin/bash

# Fix iOS Test Configuration Script
# This script fixes the missing test bundle executable issue by properly configuring the test target

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_FILE="$SCRIPT_DIR/Interspace.xcodeproj/project.pbxproj"

echo "🔧 iOS Test Configuration Fix Script"
echo "===================================="

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: project.pbxproj not found at $PROJECT_FILE"
    exit 1
fi

# Backup the project file
echo "📋 Creating backup of project.pbxproj..."
cp "$PROJECT_FILE" "$PROJECT_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# Function to add test files using xcrun or ruby script
add_test_files_to_project() {
    echo "📝 Adding test files to project..."
    
    # Create a Ruby script to properly add files to Xcode project
    cat > "$SCRIPT_DIR/add_test_files.rb" << 'EOF'
#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

# Find the test target
test_target = project.targets.find { |t| t.name == "InterspaceTests" }
ui_test_target = project.targets.find { |t| t.name == "InterspaceUITests" }

if test_target.nil?
  puts "❌ Error: InterspaceTests target not found"
  exit 1
end

# Create or get the test groups
main_group = project.main_group
tests_group = main_group.find_subpath("InterspaceTests", true)
ui_tests_group = main_group.find_subpath("InterspaceUITests", true)

# Function to add files recursively
def add_files_to_group(group, dir_path, target, project_dir)
  Dir.glob("#{dir_path}/**/*.swift").each do |file_path|
    relative_path = Pathname.new(file_path).relative_path_from(project_dir)
    
    # Skip if file already exists in project
    next if group.files.any? { |f| f.path == relative_path.to_s }
    
    # Create subgroups if needed
    path_components = relative_path.dirname.to_s.split("/")
    current_group = group
    
    path_components[1..-1].each do |component|
      next if component == "."
      subgroup = current_group.find_subpath(component, false)
      if subgroup.nil?
        subgroup = current_group.new_group(component)
      end
      current_group = subgroup
    end
    
    # Add file reference
    file_ref = current_group.new_file(file_path)
    
    # Add to target
    target.add_file_references([file_ref])
    
    puts "✅ Added: #{relative_path}"
  end
end

# Add InterspaceTests files
if tests_group && test_target
  project_dir = Pathname.new(project_path).dirname
  tests_dir = project_dir.join("InterspaceTests")
  add_files_to_group(tests_group, tests_dir, test_target, project_dir)
end

# Add InterspaceUITests files
if ui_tests_group && ui_test_target
  project_dir = Pathname.new(project_path).dirname
  ui_tests_dir = project_dir.join("InterspaceUITests")
  add_files_to_group(ui_tests_group, ui_tests_dir, ui_test_target, project_dir)
end

# Configure test target settings
test_target.build_configurations.each do |config|
  config.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
  config.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/Interspace.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Interspace"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
  config.build_settings["SWIFT_OBJC_BRIDGING_HEADER"] = ""
  config.build_settings["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "NO"
end

# Save the project
project.save

puts "✅ Test files added successfully!"
EOF

    # Check if we have xcodeproj gem
    if gem list xcodeproj -i > /dev/null 2>&1; then
        echo "📦 Using Ruby xcodeproj gem..."
        ruby "$SCRIPT_DIR/add_test_files.rb" "$SCRIPT_DIR/Interspace.xcodeproj"
    else
        echo "📦 Installing xcodeproj gem..."
        gem install xcodeproj --user-install
        ruby "$SCRIPT_DIR/add_test_files.rb" "$SCRIPT_DIR/Interspace.xcodeproj"
    fi
    
    # Clean up
    rm -f "$SCRIPT_DIR/add_test_files.rb"
}

# Alternative method using xcodebuild if Ruby method fails
add_test_files_manually() {
    echo "📝 Attempting manual test file addition..."
    
    # Create a simple test scheme if it doesn't exist
    cat > "$SCRIPT_DIR/InterspaceTests.xcscheme" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CD6C8568030616CB15238860"
               BuildableName = "InterspaceTests.xctest"
               BlueprintName = "InterspaceTests"
               ReferencedContainer = "container:Interspace.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CD6C8568030616CB15238860"
               BuildableName = "InterspaceTests.xctest"
               BlueprintName = "InterspaceTests"
               ReferencedContainer = "container:Interspace.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
</Scheme>
EOF

    mkdir -p "$SCRIPT_DIR/Interspace.xcodeproj/xcshareddata/xcschemes"
    mv "$SCRIPT_DIR/InterspaceTests.xcscheme" "$SCRIPT_DIR/Interspace.xcodeproj/xcshareddata/xcschemes/"
}

# Try to add test files
echo "🔍 Checking test file configuration..."

# Count test files in Sources build phase
TEST_FILES_COUNT=$(grep -A 10 "8E12DBE5DC3FA45B8CBEAC7F /\* Sources \*/" "$PROJECT_FILE" | grep -c "\.swift in Sources" || true)

if [ "$TEST_FILES_COUNT" -eq 0 ]; then
    echo "⚠️  No test files found in Sources build phase"
    add_test_files_to_project
else
    echo "✅ Found $TEST_FILES_COUNT test files in Sources build phase"
fi

# Create a verification script
cat > "$SCRIPT_DIR/verify_test_setup.sh" << 'EOF'
#!/bin/bash

echo "🔍 Verifying Test Setup"
echo "======================"

# Check if test files are in project
PROJECT_FILE="Interspace.xcodeproj/project.pbxproj"
TEST_FILES=$(find InterspaceTests -name "*.swift" -type f | wc -l)
echo "📁 Test files in directory: $TEST_FILES"

# Check if files are referenced in project
REFERENCED_FILES=$(grep -c "InterspaceTests.*\.swift" "$PROJECT_FILE" || true)
echo "📋 Test files in project: $REFERENCED_FILES"

# Check test target configuration
echo ""
echo "🎯 Test Target Configuration:"
grep -A 5 "TEST_HOST" "$PROJECT_FILE" | head -10

# List xcodebuild configurations
echo ""
echo "📱 Available destinations:"
xcodebuild -showdestinations -scheme Interspace 2>/dev/null | grep "iOS Simulator" | head -5

echo ""
echo "✅ Verification complete!"
EOF

chmod +x "$SCRIPT_DIR/verify_test_setup.sh"

# Create an alternative test runner that doesn't require Xcode
cat > "$SCRIPT_DIR/run_tests_direct.sh" << 'EOF'
#!/bin/bash

set -e

echo "🧪 Direct Test Runner"
echo "===================="

# Set variables
SCHEME="Interspace"
CONFIGURATION="Debug"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.5"

# Clean build directory
echo "🧹 Cleaning build directory..."
xcodebuild clean \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -quiet

# Build the app first
echo "🔨 Building app..."
xcodebuild build-for-testing \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath ./build/DerivedData \
    -quiet || {
        echo "❌ Build failed. Trying with workspace..."
        xcodebuild build-for-testing \
            -workspace "Interspace.xcworkspace" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$DESTINATION" \
            -derivedDataPath ./build/DerivedData
    }

# Run tests
echo "🧪 Running tests..."
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath ./build/DerivedData \
    -only-testing:InterspaceTests || {
        echo "❌ Test execution failed. This might be due to missing test file references."
        echo "   Please run fix_test_configuration.sh first."
        exit 1
    }

echo "✅ Tests completed!"
EOF

chmod +x "$SCRIPT_DIR/run_tests_direct.sh"

echo ""
echo "🎉 Test configuration fix completed!"
echo ""
echo "📋 Next steps:"
echo "1. Run './verify_test_setup.sh' to check the current state"
echo "2. If test files are still not linked, you'll need to:"
echo "   a) Open Interspace.xcworkspace in Xcode"
echo "   b) Right-click on InterspaceTests group"
echo "   c) Select 'Add Files to InterspaceTests...'"
echo "   d) Select all test files in InterspaceTests directory"
echo "   e) Make sure 'InterspaceTests' target is checked"
echo "3. Try running tests with './run_tests_direct.sh'"
echo ""
echo "🔧 Alternative: Use the generated Ruby script method by running:"
echo "   gem install xcodeproj --user-install"
echo "   Then run this script again"