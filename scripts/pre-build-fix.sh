#!/bin/bash

# Pre-build script to handle module.modulemap conflicts
# This runs before the build to prevent conflicts

set -e

echo "Pre-build: Handling module.modulemap conflicts..."

# Find package checkout directories
PACKAGES_DIR="${BUILD_DIR%Build/*}SourcePackages/checkouts"

# Handle duo_schnorr modulemap
DUO_SCHNORR_ARM64="${PACKAGES_DIR}/silentshard-artifacts/frameworks/duo_schnorr.xcframework/ios-arm64/Headers/module.modulemap"
DUO_SCHNORR_SIM="${PACKAGES_DIR}/silentshard-artifacts/frameworks/duo_schnorr.xcframework/ios-arm64_x86_64-simulator/Headers/module.modulemap"

if [ -f "$DUO_SCHNORR_ARM64" ]; then
    echo "Renaming duo_schnorr module.modulemap (arm64)"
    mv "$DUO_SCHNORR_ARM64" "${DUO_SCHNORR_ARM64}.backup" || true
fi

if [ -f "$DUO_SCHNORR_SIM" ]; then
    echo "Renaming duo_schnorr module.modulemap (simulator)"
    mv "$DUO_SCHNORR_SIM" "${DUO_SCHNORR_SIM}.backup" || true
fi

# Handle Ecies modulemap
ECIES_ARM64="${PACKAGES_DIR}/metamask-ios-sdk/Sources/metamask-ios-sdk/Frameworks/Ecies.xcframework/ios-arm64/Headers/module.modulemap"
ECIES_SIM="${PACKAGES_DIR}/metamask-ios-sdk/Sources/metamask-ios-sdk/Frameworks/Ecies.xcframework/ios-arm64-simulator/Headers/module.modulemap"

if [ -f "$ECIES_ARM64" ]; then
    echo "Renaming Ecies module.modulemap (arm64)"
    mv "$ECIES_ARM64" "${ECIES_ARM64}.backup" || true
fi

if [ -f "$ECIES_SIM" ]; then
    echo "Renaming Ecies module.modulemap (simulator)"
    mv "$ECIES_SIM" "${ECIES_SIM}.backup" || true
fi

echo "Pre-build: Module conflict handling complete"