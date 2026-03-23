#!/bin/bash

# Build script for Iris.app
# Builds the project from command line without needing Xcode IDE

set -e  # Exit on error

echo "🔨 Building Iris.app..."

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: xcodebuild not found"
    echo "Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Check if full Xcode is installed (needed for macOS apps)
if xcodebuild -version 2>&1 | grep -q "requires Xcode"; then
    echo "❌ Error: Full Xcode installation required"
    echo "Command Line Tools alone are not sufficient for building macOS apps."
    echo ""
    echo "Please install Xcode from the App Store:"
    echo "  https://apps.apple.com/app/xcode/id497799835"
    echo ""
    echo "After installing, set the command line tools path:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Check if project exists
if [ ! -d "Iris/Iris.xcodeproj" ]; then
    echo "❌ Error: Iris.xcodeproj not found"
    echo "Expected location: Iris/Iris.xcodeproj"
    echo "Please create the Xcode project first (see design/00-project-setup.md)"
    exit 1
fi

# Generate application icons before building
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/generate_icon.sh" ]; then
    echo "🎨 Generating application icons..."
    "$SCRIPT_DIR/generate_icon.sh"
else
    echo "⚠️  Warning: generate_icon.sh not found, skipping icon generation"
fi

# Navigate to project directory
cd Iris

# Build the project with ad-hoc code signing
# This allows macOS to remember camera permissions between launches
echo "Building Release configuration..."
xcodebuild \
    -project Iris.xcodeproj \
    -scheme Iris \
    -configuration Release \
    clean build \
    CODE_SIGN_IDENTITY="-"

echo "✅ Build complete!"
echo "Built app location: ~/Library/Developer/Xcode/DerivedData/Iris-*/Build/Products/Release/Iris.app"
