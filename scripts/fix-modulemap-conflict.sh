#!/bin/bash

# This script fixes the module.modulemap conflict by ensuring only one exists at a time

echo "Fixing module.modulemap conflict..."

# Find the DerivedData path
DERIVED_DATA=$(xcodebuild -showBuildSettings | grep -m 1 BUILD_DIR | awk '{print $3}' | sed 's/\/Build.*//')

if [ -z "$DERIVED_DATA" ]; then
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/Interspace-*"
fi

# Function to handle module.modulemap files
handle_modulemap() {
    local framework_name=$1
    local module_name=$2
    
    find $DERIVED_DATA -name "module.modulemap" -path "*/${framework_name}.xcframework/*" 2>/dev/null | while read -r file; do
        echo "Processing: $file"
        # Check if file is empty or has wrong content
        if [ ! -s "$file" ] || ! grep -q "$module_name" "$file" 2>/dev/null; then
            echo "module $module_name {" > "$file"
            echo "    header \"${module_name,,}.h\"" >> "$file"
            echo "    export *" >> "$file"
            echo "}" >> "$file"
            echo "Fixed: $file"
        fi
    done
}

# Handle duo_schnorr
handle_modulemap "duo_schnorr" "duo_schnorrFFI"

# Handle Ecies
handle_modulemap "Ecies" "Ecies"

# Alternative: Just remove one of them temporarily
# This forces them to be processed sequentially
if [ "$1" == "remove-ecies" ]; then
    find $DERIVED_DATA -name "module.modulemap" -path "*/Ecies.xcframework/*" -exec mv {} {}.disabled \;
    echo "Temporarily disabled Ecies module.modulemap files"
elif [ "$1" == "restore-ecies" ]; then
    find $DERIVED_DATA -name "module.modulemap.disabled" -path "*/Ecies.xcframework/*" | while read -r file; do
        mv "$file" "${file%.disabled}"
    done
    echo "Restored Ecies module.modulemap files"
fi

echo "Module conflict fix complete"