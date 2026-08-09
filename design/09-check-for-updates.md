# Feature: Check for Updates (Sparkle)

## Overview

Iris updates itself using [Sparkle 2](https://sparkle-project.org/), the de
facto update framework for macOS apps distributed outside the App Store.
Updates are checked automatically (daily) and can be triggered manually via
the menu bar icon → "Check for Updates…". Sparkle downloads the new version,
verifies its EdDSA signature, swaps the app bundle in place, and relaunches.

This is a deliberate exception to the "no third-party frameworks" rule:
update installation (atomic bundle swap, quarantine handling, relaunch) is
easy to get wrong, and Sparkle is the well-tested standard used by Rectangle,
AltTab, Maccy, Ice, and most similar apps. Because Iris is not signed with an
Apple Developer certificate, Sparkle's EdDSA signing is what makes updates
verifiable — and updates installed by Sparkle don't re-trigger Gatekeeper's
unsigned-app warning, unlike manual re-downloads.

## Architecture

```
GitHub Actions (on tag push)
  ├── stamps tag version into Info.plist (CFBundleShortVersionString/CFBundleVersion)
  ├── builds + zips Iris.app
  ├── signs zip with EdDSA private key (SPARKLE_ED_PRIVATE_KEY repo secret)
  ├── writes appcast.xml (single <item> describing the newest release)
  └── commits appcast.xml + Casks/iris.rb to main

Iris.app (Sparkle framework, embedded)
  ├── SUFeedURL → https://raw.githubusercontent.com/ahmetb/Iris/main/appcast.xml
  ├── SUPublicEDKey → verifies the enclosure signature
  └── SUEnableAutomaticChecks → daily scheduled checks, no consent prompt
```

## Key Components

- **AppDelegate**: owns `SPUStandardUpdaterController` (started at launch;
  performs scheduled checks and provides the standard Sparkle UI).
- **MenuBarController**: adds "Check for Updates…" menu item targeting the
  updater controller. Sparkle's `validateMenuItem` disables it while a check
  is in flight.
- **Info.plist**: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`.
- **.github/workflows/release.yml**: version stamping, `sign_update`,
  appcast generation.

## Design Decisions

- **Appcast lists only the newest version.** Sparkle only offers the latest
  entry anyway; keeping one `<item>` avoids maintaining archive state in CI.
  Delta updates are not used (the app is ~1 MB zipped).
- **Appcast served from raw.githubusercontent.com on main.** The release
  workflow already commits back to main for the Homebrew cask; the appcast
  rides the same commit. Raw CDN caching (~5 min) is acceptable lag.
- **CFBundleVersion = CFBundleShortVersionString = tag version.** Sparkle
  compares `sparkle:version` against the installed `CFBundleVersion`; using
  the semver string for both keeps everything in one namespace. Pre-Sparkle
  installs (≤0.2.1, CFBundleVersion "1") never see the appcast, so the
  discontinuity is harmless.
- **`SUEnableAutomaticChecks = true`** skips Sparkle's second-launch consent
  prompt. Appropriate for a small utility; the check is a single HTTPS fetch.
- **Homebrew cask sets `auto_updates true`** so `brew upgrade` defers to the
  in-app updater unless `--greedy` is passed.

## Key Management

- Private key: generated as a 32-byte ed25519 seed (base64). Stored in the
  developer's login keychain ("Private key for signing Sparkle updates") and
  as the `SPARKLE_ED_PRIVATE_KEY` GitHub Actions secret.
- Public key: `SUPublicEDKey` in Info.plist. Rotating the key requires
  shipping an update signed with the old key that contains the new key.

## Edge Cases

- **Secret missing in CI**: the sign step fails the release loudly rather
  than shipping an unsigned appcast entry.
- **User on ≤0.2.1**: no Sparkle in the app; must update manually once.
- **LSUIElement app**: Sparkle activates the app to show its windows even
  though Iris has no Dock presence.
- **Ad-hoc code signing**: Sparkle validates updates purely via EdDSA since
  there is no Developer ID identity to match.

## Testing

- CI `build.yml` verifies the app builds and Sparkle.framework is embedded.
- End-to-end: install release N, publish release N+1, launch N and verify
  the update is offered, installs, and relaunches as N+1.
