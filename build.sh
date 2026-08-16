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

# Signing: use a "Developer ID Application" identity if one is available in the
# keychain (or if IRIS_SIGN_IDENTITY is set), otherwise fall back to ad-hoc
# signing. Ad-hoc signing still lets macOS remember camera permissions between
# launches; a real Developer ID is only required for notarized distribution.
detect_developer_id() {
    security find-identity -v -p codesigning 2>/dev/null \
        | awk -F\" '/Developer ID Application/ {print $2; exit}'
}

SIGN_IDENTITY="${IRIS_SIGN_IDENTITY:-$(detect_developer_id)}"

echo "Building Release configuration..."
if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    # Derive the Team ID from the identity string "... (TEAMID)" unless overridden.
    TEAM_ID="${IRIS_TEAM_ID:-$(echo "$SIGN_IDENTITY" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')}"
    echo "🔏 Signing with Developer ID: $SIGN_IDENTITY (team ${TEAM_ID:-unknown})"
    echo "   Hardened Runtime enabled (required for notarization)."
    xcodebuild \
        -project Iris.xcodeproj \
        -scheme Iris \
        -configuration Release \
        clean build \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        ENABLE_HARDENED_RUNTIME=YES
else
    echo "🔏 No Developer ID found — using ad-hoc signing (Gatekeeper will warn users)."
    xcodebuild \
        -project Iris.xcodeproj \
        -scheme Iris \
        -configuration Release \
        clean build \
        CODE_SIGN_IDENTITY="-"
fi

echo "✅ Build complete!"
echo "Built app location: ~/Library/Developer/Xcode/DerivedData/Iris-*/Build/Products/Release/Iris.app"
