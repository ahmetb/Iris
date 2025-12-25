# Release Process

This document describes how to create and publish releases for Iris.app.

## Overview

Releases are fully automated via GitHub Actions. When you push a version tag, the workflow will:
1. Build the app on a macOS runner
2. Create a zip archive
3. Calculate SHA256 checksum
4. Update the Homebrew cask formula
5. Publish a GitHub Release with the zip attached

## Creating a Release

### Step 1: Update Version Numbers

Before creating a release, update the version in `Iris/Iris/Info.plist`:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>  <!-- Update this -->
<key>CFBundleVersion</key>
<string>1</string>  <!-- Increment this for each build -->
```

### Step 2: Commit Changes

```bash
git add Iris/Iris/Info.plist
git commit -m "Bump version to 1.0.0"
git push
```

### Step 3: Create and Push Tag

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

1. **Builds the app** using `xcodebuild` on macOS
2. **Creates zip archive** named `Iris-vX.X.X.zip`
3. **Calculates SHA256** checksum of the zip file
4. **Updates the cask** (`Casks/iris.rb`) with new version and SHA256
5. **Commits the cask update** back to the repo
6. **Creates GitHub Release** with:
   - The zip file attached
   - Auto-generated release notes
   - Installation instructions

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

### 2. Create Zip Archive

```bash
cd Iris/build/Build/Products/Release
zip -r -y "Iris-v1.0.0.zip" Iris.app
```

### 3. Calculate SHA256

```bash
shasum -a 256 Iris-v1.0.0.zip
```

### 4. Update Homebrew Cask

Edit `Casks/iris.rb`:
- Update `version` to match your release
- Update `sha256` with the checksum from step 3

### 5. Create GitHub Release

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
