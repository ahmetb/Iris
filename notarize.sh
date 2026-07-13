#!/bin/bash

# Notarize a signed Iris.app with Apple and staple the ticket, so macOS
# Gatekeeper launches it without warnings.
#
# Requirements:
#   - The app must already be signed with a "Developer ID Application" identity
#     and built with Hardened Runtime. ./build.sh does both automatically when
#     a Developer ID is present in your keychain.
#   - A notarytool keychain profile (see one-time setup below).
#
# One-time setup (creates a keychain profile named "iris-notarization").
#
#   Using an App Store Connect API key (recommended):
#     xcrun notarytool store-credentials iris-notarization \
#       --key    /path/to/AuthKey_XXXXXXXXXX.p8 \
#       --key-id XXXXXXXXXX \
#       --issuer <ISSUER_UUID>
#
#   Or using an Apple ID + app-specific password:
#     xcrun notarytool store-credentials iris-notarization \
#       --apple-id "you@example.com" \
#       --team-id  <YOUR_TEAM_ID> \
#       --password "app-specific-password"
#
#   API keys live under App Store Connect > Users and Access > Integrations.
#   App-specific passwords are created at https://appleid.apple.com.
#
# Env vars (optional):
#   NOTARIZE_PROFILE  notarytool keychain profile. Default: iris-notarization
#   APP_PATH          path to Iris.app. Default: the Release build output.

set -euo pipefail

PROFILE="${NOTARIZE_PROFILE:-iris-notarization}"
DEFAULT_APP="Iris/build/Build/Products/Release/Iris.app"
APP_PATH="${APP_PATH:-$DEFAULT_APP}"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    echo "   Run ./build.sh first, or set APP_PATH=/path/to/Iris.app"
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "❌ Notary profile '$PROFILE' is missing or not usable."
    echo "   See the setup instructions at the top of this script."
    exit 1
fi

# Confirm the app is signed with Developer ID + Hardened Runtime (both are
# required for notarization to succeed).
echo "🔍 Checking signature..."
codesign --verify --strict --verbose=2 "$APP_PATH"
if ! codesign -dvv "$APP_PATH" 2>&1 | grep -q "flags=.*runtime"; then
    echo "❌ Hardened Runtime is not enabled on this build."
    echo "   Rebuild with ./build.sh using a Developer ID identity."
    exit 1
fi

WORK_ZIP="$(dirname "$APP_PATH")/Iris-notarize.zip"
echo "📦 Zipping app for submission..."
rm -f "$WORK_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$WORK_ZIP"

echo "☁️  Submitting to Apple (this can take a few minutes)..."
xcrun notarytool submit "$WORK_ZIP" --keychain-profile "$PROFILE" --wait

echo "📎 Stapling ticket to the app..."
xcrun stapler staple "$APP_PATH"

rm -f "$WORK_ZIP"

echo "✅ Notarized and stapled: $APP_PATH"
echo "🔎 Gatekeeper assessment:"
spctl --assess --type execute --verbose "$APP_PATH" || true
