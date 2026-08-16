# Release Process

This document describes how to create and publish releases for Iris.app.

## Overview

Releases are fully automated via GitHub Actions. When you push a version tag, the workflow will:
1. Stamp the tag version into `Info.plist` (`CFBundleShortVersionString` and `CFBundleVersion`)
2. Build the app on a macOS runner
3. Create a zip archive
4. Calculate SHA256 checksum
5. Sign the zip with the Sparkle EdDSA key and regenerate `appcast.xml` (for in-app updates)
6. Update the Homebrew cask formula
7. Publish a GitHub Release with the zip attached

## Creating a Release

There is no manual version bump: the version in `Iris/Iris/Info.plist` is a
placeholder that CI overwrites from the tag name.

### Create and Push Tag

```bash
# Create the tag (use semantic versioning: vMAJOR.MINOR.PATCH)
git tag v1.0.0

# Push the tag to GitHub
git push origin v1.0.0
```

**That's it!** GitHub Actions will automatically:
- Build the app
- Create the release
- Update the Homebrew cask

## What Happens Automatically

### GitHub Actions Workflow

The `.github/workflows/release.yml` workflow:

1. **Stamps the version** from the tag into `Iris/Iris/Info.plist`
2. **Builds the app** using `xcodebuild` on macOS
3. **Creates zip archive** named `Iris-vX.X.X.zip`
4. **Calculates SHA256** checksum of the zip file
5. **Signs the zip** with the Sparkle EdDSA private key (`SPARKLE_ED_PRIVATE_KEY`
   repo secret) and **generates `appcast.xml`** so existing installs are offered
   the update in-app
6. **Updates the cask** (`Casks/iris.rb`) with new version and SHA256
7. **Commits the cask + appcast update** back to the repo
8. **Creates GitHub Release** with:
   - The zip file attached
   - Auto-generated release notes
   - Installation instructions

### Sparkle Update Signing

In-app updates are delivered by [Sparkle](https://sparkle-project.org/) (see
`design/09-check-for-updates.md`). Signing key facts:

- The private key is a base64 ed25519 seed stored in two places: the
  `SPARKLE_ED_PRIVATE_KEY` GitHub Actions secret, and the maintainer's login
  keychain as "Private key for signing Sparkle updates" (export with
  `generate_keys -x <file>` from the Sparkle distribution).
- The matching public key is `SUPublicEDKey` in `Iris/Iris/Info.plist`.
- If the secret is missing, the release workflow fails on purpose — a release
  without a signed appcast entry would strand in-app updaters.

### Homebrew Cask Update

The workflow automatically updates `Casks/iris.rb` with:
- New version number
- SHA256 checksum of the release zip
- Commits the change back to the repository

## Manual Release (If Needed)

If you need to create a release manually (without GitHub Actions):

### 1. Build the App

```bash
./build.sh
```

`build.sh` signs the app automatically:

- If a **"Developer ID Application"** identity is present in your keychain, the
  app is signed with it and built with Hardened Runtime (required for
  notarization). The Team ID is derived from the identity automatically.
- Otherwise it falls back to **ad-hoc** signing, which still works locally but
  makes Gatekeeper warn end users.

Overrides (optional):

```bash
IRIS_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
IRIS_TEAM_ID=TEAMID ./build.sh
```

### 2. Notarize (optional but recommended)

Notarization lets macOS launch the app without a Gatekeeper warning. It
requires a Developer ID signed build (step 1) and a one-time notarytool
credential profile.

One-time setup (App Store Connect API key, recommended):

```bash
xcrun notarytool store-credentials iris-notarization \
  --key    /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer <ISSUER_UUID>
```

Then, after each build:

```bash
./notarize.sh
```

This zips the app, submits it to Apple, waits for the result, and staples the
ticket to `Iris.app`. See the header of `notarize.sh` for Apple ID / app-specific
password setup as an alternative to the API key.

### 3. Create Zip Archive

```bash
cd Iris/build/Build/Products/Release
zip -r -y "Iris-v1.0.0.zip" Iris.app
```

### 4. Calculate SHA256

```bash
shasum -a 256 Iris-v1.0.0.zip
```

### 5. Update Homebrew Cask

Edit `Casks/iris.rb`:
- Update `version` to match your release
- Update `sha256` with the checksum from step 4

### 6. Create GitHub Release

1. Go to https://github.com/ahmetb/Iris/releases/new
2. Create a new tag: `v1.0.0`
3. Upload `Iris-v1.0.0.zip`
4. Add release notes
5. Publish

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0): Incompatible API changes
- **MINOR** (0.1.0): Backward-compatible functionality
- **PATCH** (0.0.1): Backward-compatible bug fixes

## Testing a Release

Before pushing a tag, you can test the build locally:

```bash
# Build release version
cd Iris
xcodebuild \
  -project Iris.xcodeproj \
  -scheme Iris \
  -configuration Release \
  -derivedDataPath build \
  clean build \
  CODE_SIGN_IDENTITY="-"

# Test the built app
open build/Build/Products/Release/Iris.app
```

## Troubleshooting

### Workflow Fails to Build

- Check that Xcode is available on the runner (it should be)
- Verify the project builds locally first
- Check workflow logs in GitHub Actions tab

### Cask Update Fails

- Ensure the workflow has `contents: write` permission (it does)
- Check that the SHA256 calculation is correct
- Verify the cask file syntax is valid Ruby

### Release Created but No Zip

- Check the workflow logs for errors
- Verify the zip file was created in the build step
- Ensure the file path in the release step is correct

## Distribution Methods

### GitHub Releases

Users can download directly from:
https://github.com/ahmetb/Iris/releases

### Homebrew Cask

Users can install via Homebrew:

```bash
brew tap ahmetb/iris https://github.com/ahmetb/Iris
brew install --cask ahmetb/iris/iris
```

⚠️ **macOS will show a warning about the unsigned application binary**. Users will need to:
1. Right-click (or Control-click) on Iris.app and select "Open" on first launch
2. Click "Open" in the security dialog
3. If needed, go to System Settings > Privacy & Security > Gatekeeper to allow the app

Or if submitted to `homebrew/cask` (future):

```bash
brew install --cask iris
```

## Post-Release Checklist

- [ ] Verify the release appears on GitHub
- [ ] Download and test the zip file
- [ ] Verify Homebrew cask was updated
- [ ] Test Homebrew installation: `brew install --cask iris`
- [ ] Update any documentation if needed
- [ ] Announce the release (if desired)
