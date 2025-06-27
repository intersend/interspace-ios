#!/bin/bash

# Script to fix module.modulemap conflicts between packages
# This script renames conflicting module.modulemap files to unique names

set -e

# Get the build products directory
BUILD_DIR="${BUILT_PRODUCTS_DIR}"
INCLUDE_DIR="${BUILD_DIR}/include"

echo "Fixing module.modulemap conflicts..."

# Check if include directory exists
if [ -d "$INCLUDE_DIR" ]; then
    # If there's a generic module.modulemap, check what created it
    if [ -f "$INCLUDE_DIR/module.modulemap" ]; then
        # Read the module name from the file
        MODULE_NAME=$(grep -o 'module [a-zA-Z_][a-zA-Z0-9_]*' "$INCLUDE_DIR/module.modulemap" | head -1 | awk '{print $2}')
        
        if [ ! -z "$MODULE_NAME" ]; then
            # Rename it to a unique name based on the module
            NEW_NAME="${MODULE_NAME}.modulemap"
            echo "Renaming module.modulemap to $NEW_NAME (module: $MODULE_NAME)"
            mv "$INCLUDE_DIR/module.modulemap" "$INCLUDE_DIR/$NEW_NAME"
        fi
    fi
fi

# Handle duo_schnorr specific case
DUO_SCHNORR_MAP="${BUILD_DIR}/duo_schnorr.framework/Headers/module.modulemap"
if [ -f "$DUO_SCHNORR_MAP" ]; then
    echo "Found duo_schnorr module.modulemap"
    # Create a unique include directory for duo_schnorr
    mkdir -p "${INCLUDE_DIR}/duo_schnorr"
    cp "$DUO_SCHNORR_MAP" "${INCLUDE_DIR}/duo_schnorr/module.modulemap"
fi

# Handle Ecies specific case
ECIES_MAP="${BUILD_DIR}/Ecies.framework/Headers/module.modulemap"
if [ -f "$ECIES_MAP" ]; then
    echo "Found Ecies module.modulemap"
    # Create a unique include directory for Ecies
    mkdir -p "${INCLUDE_DIR}/ecies"
    cp "$ECIES_MAP" "${INCLUDE_DIR}/ecies/module.modulemap"
fi

echo "Module conflict resolution complete"