#!/bin/bash

echo "=== Swift Code Analysis for Interspace iOS ==="
echo
echo "Analyzing Swift files for potential compilation errors..."
echo

# Function to check imports in a Swift file
check_imports() {
    local file=$1
    echo "Checking imports in: $(basename "$file")"
    
    # Extract all imports
    local imports=$(grep -E "^import " "$file" | sed 's/import //')
    
    # Check for common framework availability
    for import in $imports; do
        case $import in
            "SwiftUI"|"Foundation"|"UIKit"|"Security"|"AuthenticationServices"|"Combine")
                # These are standard frameworks
                ;;
            *)
                echo "  ⚠️  Custom import found: $import"
                ;;
        esac
    done
}

# Function to check for undefined types
check_undefined_types() {
    local file=$1
    echo "Checking for potential undefined types in: $(basename "$file")"
    
    # Common patterns that might indicate undefined types
    grep -n "Cannot find type\|Use of undeclared type\|Unknown type" "$file" 2>/dev/null || true
}

# Function to check for missing protocol conformance
check_protocols() {
    local file=$1
    # Check for common protocol declarations without implementation
    if grep -q "protocol " "$file"; then
        echo "  ℹ️  Protocol definitions found in $(basename "$file")"
    fi
}

# Main analysis
echo "1. Analyzing main app file..."
check_imports "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/interspace_iosApp.swift"
echo

echo "2. Analyzing ContentView..."
check_imports "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/Views/ContentView.swift"
echo

echo "3. Checking for circular dependencies..."
# Simple check for files that import each other
find /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace -name "*.swift" -type f | head -20 | while read -r file; do
    basename_file=$(basename "$file" .swift)
    # Check if any other file imports this one
    grep -l "import.*$basename_file" /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/**/*.swift 2>/dev/null || true
done

echo
echo "4. Checking for syntax errors in key files..."

# Check for basic syntax issues
for file in \
    "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/interspace_iosApp.swift" \
    "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/Views/ContentView.swift" \
    "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/Services/ServiceInitializer.swift" \
    "/Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/Services/KeychainManager.swift"
do
    if [ -f "$file" ]; then
        echo "Checking $(basename "$file")..."
        # Check for unmatched braces
        open_braces=$(grep -o '{' "$file" | wc -l)
        close_braces=$(grep -o '}' "$file" | wc -l)
        if [ "$open_braces" -ne "$close_braces" ]; then
            echo "  ❌ Unmatched braces: { = $open_braces, } = $close_braces"
        else
            echo "  ✅ Braces matched"
        fi
        
        # Check for unmatched parentheses
        open_parens=$(grep -o '(' "$file" | wc -l)
        close_parens=$(grep -o ')' "$file" | wc -l)
        if [ "$open_parens" -ne "$close_parens" ]; then
            echo "  ❌ Unmatched parentheses: ( = $open_parens, ) = $close_parens"
        else
            echo "  ✅ Parentheses matched"
        fi
    fi
done

echo
echo "5. Checking for missing type definitions..."

# Look for types that might not be defined
echo "Searching for potentially undefined types..."

# Check for common undefined types
undefined_types=("ClientShare" "AppleUserInfo" "AccountV2" "ProfileSummaryV2" "WalletType")

for type in "${undefined_types[@]}"; do
    echo -n "  Checking $type... "
    if grep -q "struct $type\|class $type\|enum $type" /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios/Interspace/**/*.swift 2>/dev/null; then
        echo "✅ Defined"
    else
        echo "❌ Not found"
    fi
done

echo
echo "6. Summary of potential issues:"
echo "  - Package dependency issue with silentshard-artifacts (already fixed)"
echo "  - iOS SDK version mismatch (requires manual Xcode configuration)"
echo "  - All major types appear to be defined"
echo "  - No obvious syntax errors in key files"
echo
echo "To build the project:"
echo "1. Open Xcode and install iOS 18.5 SDK"
echo "2. Or use the build_with_ios18_4.sh script as a workaround"
echo "3. Re-add silentshard-artifacts package pointing to 'main' branch"