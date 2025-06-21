#!/bin/bash

# Interspace iOS Setup Script
# This script helps set up the development environment

set -e

echo "🚀 Interspace iOS Setup Script"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if running from correct directory
if [ ! -f "Podfile" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

echo "📋 Checking prerequisites..."
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed. Please install Xcode from the App Store."
    exit 1
else
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    print_status "Xcode installed: $XCODE_VERSION"
fi

# Check for CocoaPods
if ! command -v pod &> /dev/null; then
    print_warning "CocoaPods not found. Installing..."
    sudo gem install cocoapods
    print_status "CocoaPods installed"
else
    POD_VERSION=$(pod --version)
    print_status "CocoaPods installed: $POD_VERSION"
fi

echo ""
echo "📦 Setting up configuration files..."
echo ""

# Function to setup config file
setup_config_file() {
    local template=$1
    local target=$2
    local description=$3
    
    if [ -f "$target" ]; then
        print_warning "$description already exists. Skipping..."
    elif [ -f "$template" ]; then
        cp "$template" "$target"
        print_status "$description created from template"
        echo "   📝 Please edit $target with your values"
    else
        print_error "Template not found: $template"
    fi
}

# Setup configuration files
setup_config_file "Interspace/Supporting/BuildConfiguration.xcconfig.template" \
                  "Interspace/Supporting/BuildConfiguration.xcconfig" \
                  "Build configuration"

setup_config_file "Interspace/GoogleService-Info.plist.template" \
                  "Interspace/GoogleService-Info.plist" \
                  "Google Service configuration"

setup_config_file ".env.example" \
                  ".env" \
                  "Environment variables"

setup_config_file ".xcode.env.local.template" \
                  ".xcode.env.local" \
                  "Xcode environment"

echo ""
echo "🔧 Installing dependencies..."
echo ""

# Install pods
pod install
print_status "CocoaPods dependencies installed"

echo ""
echo "🔑 Configuration checklist:"
echo ""
echo "Please configure the following API keys:"
echo ""
echo "1. Google OAuth:"
echo "   - Visit: https://console.cloud.google.com/"
echo "   - Update: GoogleService-Info.plist"
echo "   - Update: BuildConfiguration.xcconfig (GOOGLE_CLIENT_ID)"
echo ""
echo "2. Infura:"
echo "   - Visit: https://infura.io/"
echo "   - Update: BuildConfiguration.xcconfig (INFURA_API_KEY)"
echo ""
echo "3. WalletConnect:"
echo "   - Visit: https://cloud.walletconnect.com/"
echo "   - Update: BuildConfiguration.xcconfig (WALLETCONNECT_PROJECT_ID)"
echo ""

# Create .gitignore entries if needed
if ! grep -q "BuildConfiguration.xcconfig" .gitignore 2>/dev/null; then
    print_warning "Adding sensitive files to .gitignore..."
    echo "" >> .gitignore
    echo "# Local configuration" >> .gitignore
    echo "BuildConfiguration.xcconfig" >> .gitignore
    echo "GoogleService-Info.plist" >> .gitignore
    echo ".env" >> .gitignore
    echo ".xcode.env.local" >> .gitignore
    print_status "Updated .gitignore"
fi

echo ""
echo "📱 Next steps:"
echo ""
echo "1. Open Interspace.xcworkspace in Xcode"
echo "2. Configure your development team in project settings"
echo "3. Add your API keys to the configuration files"
echo "4. Build and run the project (Cmd+R)"
echo ""
echo "✅ Setup complete!"
echo ""
echo "For more information, see:"
echo "- README.md for general information"
echo "- docs/DEVELOPMENT.md for development guide"
echo "- docs/API.md for API documentation"
echo ""

# Check if workspace can be opened
read -p "Would you like to open the project in Xcode now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open Interspace.xcworkspace
    print_status "Opening Xcode..."
fi

echo ""
echo "Happy coding! 🎉"