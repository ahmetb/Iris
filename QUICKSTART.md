# Iris Quick Start Guide

## ✅ Project Status: **COMPLETE**

All features from design documents 00-05 have been implemented and are ready for testing.

## 📋 Requirements

1. **macOS 13.0+**
2. **Swift toolchain** (included with Xcode or Command Line Tools)

## 🚀 Getting Started (Local Development)

The fastest way to build and run locally is with Swift Package Manager:

```bash
cd /path/to/iris
swift run
```

This builds a debug binary and launches the app. No Xcode IDE required.

To build without running:

```bash
swift build
```

### Release Build (Xcode)

For a proper `.app` bundle with icons and code signing, use the Xcode build:

1. Install full Xcode from the Mac App Store
2. Configure it:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
3. Build and run:
   ```bash
   ./build.sh
   ./run.sh
   ```

## 🎯 First Launch

1. **Camera Permission**: macOS will ask for camera access - click "OK"
2. **Menu Bar Icon**: Look for 👁 in your menu bar (top right)
3. **Window Appears**: A circular window with your webcam feed should appear

## 🎮 Using Iris

### Basic Controls

- **Toggle Window**: Click the 👁 menu bar icon
- **Move Window**: Click and drag anywhere in the circle
- **Resize Window**: Click and drag from the edge of the circle
- **Menu**: Right-click the 👁 icon for options

### Menu Options

- **Show/Hide Window** (⌘H) - Toggle visibility
- **Camera** - Select from available cameras
- **Launch at Login** - Start Iris when you log in
- **Quit Iris** (⌘Q) - Exit the application

## 📁 Project Structure

```
iris/
├── AGENTS.md              # Development principles
├── README.md              # Full documentation
├── QUICKSTART.md          # This file
├── IMPLEMENTATION.md      # Implementation details
├── design/                # Design documents (00-05)
├── build.sh               # Build script
├── run.sh                 # Run script
├── clean.sh               # Clean script
└── Iris/                  # Xcode project
    ├── Iris.xcodeproj/
    └── Iris/              # Source code
        ├── AppDelegate.swift
        ├── CameraManager.swift
        ├── CircularWindow.swift
        ├── CircularContentView.swift
        ├── MenuBarController.swift
        ├── PreferencesManager.swift
        ├── Info.plist
        └── Iris.entitlements
```

## 🔧 Troubleshooting

### Build Error: "requires Xcode"

**Problem**: Only Command Line Tools installed, not full Xcode

**Solution**:
```bash
# Install Xcode from App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Camera Not Working

**Problem**: Camera permission denied

**Solution**:
1. Open **System Settings**
2. Go to **Privacy & Security** > **Camera**
3. Enable **Iris**

### Window Not Visible

**Problem**: Window hidden or off-screen

**Solution**: Click the 👁 menu bar icon to show it

### App Not in Menu Bar

**Problem**: Looking in wrong place

**Solution**: The app is menu-bar-only. Look in the top-right corner of your screen, not the Dock

## ✨ Features Implemented

- ✅ Circular always-on-top window
- ✅ Camera feed display
- ✅ Menu bar interface
- ✅ Window dragging
- ✅ Edge-based resizing
- ✅ Multiple camera support
- ✅ Launch at login
- ✅ Persistent preferences (size, position, camera)
- ✅ Permission handling
- ✅ Multi-monitor support

## 📚 More Information

- **Full Documentation**: See [README.md](README.md)
- **Implementation Details**: See [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **Design Specifications**: See [design/](design/) folder
- **Agent Guidelines**: See [AGENTS.md](AGENTS.md)

## 🐛 Known Limitations

- `swift run` builds a bare executable (no `.app` bundle, no app icons). Use `./build.sh` for a full release build.
- Launch at login requires macOS 13+

## 🎉 You're Ready!

The Iris app is fully built and ready to use. Enjoy your circular webcam window!
