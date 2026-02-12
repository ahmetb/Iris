# Design: Global Hotkey Toggle

## Overview
Add a global hotkey that allows users to quickly show/hide the Iris window from anywhere in macOS, without needing to click the menu bar icon.

## Goals
- Toggle window visibility with a keyboard shortcut
- Work globally (even when Iris is not the active app)
- No Accessibility permissions required
- Allow users to customize the hotkey
- Persist hotkey preferences across app launches

## Default Hotkey
- **⌥⇧I** (Alt+Shift+I / Option+Shift+I)
- Chosen to avoid conflicts with common system and app shortcuts
- Uses the "I" key as mnemonic for "Iris"

## Architecture

### HotkeyManager
Singleton class responsible for registering and handling global hotkeys.

```swift
class HotkeyManager {
    static let shared = HotkeyManager()

    func setToggleAction(_ action: @escaping () -> Void)
    func startMonitoring()
    func stopMonitoring()
    func restartMonitoring()
    func currentHotkeyDisplayString() -> String
}
```

### Implementation Approach
Uses the Carbon `RegisterEventHotKey` API:
- Works globally without Accessibility permissions
- More reliable than `NSEvent.addGlobalMonitorForEvents`
- Supports modifier key combinations
- Well-established pattern for macOS hotkeys

### Key Components

#### 1. Event Handler Registration
```swift
var eventType = EventTypeSpec(
    eventClass: OSType(kEventClassKeyboard),
    eventKind: UInt32(kEventHotKeyPressed)
)

InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)
RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
```

#### 2. HotKey ID
Unique identifier for the hotkey:
```swift
private static let hotKeyID = EventHotKeyID(
    signature: OSType(0x49524953), // "IRIS" in hex
    id: 1
)
```

#### 3. Modifier Conversion
Convert between NSEvent.ModifierFlags and Carbon modifier flags:
```swift
func carbonModifierFlags(from flags: UInt) -> UInt32 {
    var carbonFlags: UInt32 = 0
    let nsFlags = NSEvent.ModifierFlags(rawValue: flags)
    if nsFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
    if nsFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
    if nsFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
    if nsFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
    return carbonFlags
}
```

## HotkeyRecorderView
Custom NSView for recording user's preferred hotkey combination.

### Features
- Click to start recording
- Visual feedback during recording (highlighted border)
- Shows modifier keys as they're pressed
- Validates that at least one modifier is used
- Displays recorded hotkey in symbol format (⌃⌥⇧⌘)

### Implementation
Uses local event monitors (not global) to capture keystrokes:
```swift
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // Record keyCode and modifiers
}

NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
    // Show modifiers as user presses them
}
```

## Menu Integration

### Toggle Hotkey Submenu
```
┌─────────────────────────┐
│ Toggle Hotkey          ▸│
│   ├ ✓ Enabled (⌥⇧I)    │
│   ├─────────────────────│
│   └   Record Hotkey...  │
└─────────────────────────┘
```

### Menu Items
- **Enabled/Disabled toggle**: Shows current state and hotkey combination
- **Record Hotkey...**: Opens panel to record new hotkey

## Preferences Storage

### UserDefaults Keys
```
com.iris.app.toggleHotkeyEnabled   -> Bool (default: false)
com.iris.app.toggleHotkeyKeyCode   -> Int (default: 34, 'I' key)
com.iris.app.toggleHotkeyModifiers -> Int (default: Option+Shift)
```

### PreferencesManager Properties
```swift
var toggleHotkeyEnabled: Bool
var toggleHotkeyKeyCode: UInt16
var toggleHotkeyModifiers: UInt
```

## Record Hotkey Panel

### UI Layout
```
┌──────────────────────────────────┐
│ Record Hotkey                  ✕ │
├──────────────────────────────────┤
│ Press a key combination:         │
│                                  │
│ ┌────────────────────────────┐   │
│ │        ⌥⇧I                 │   │
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

### Behavior
1. User clicks the recorder view
2. View highlights and shows "Press hotkey combination..."
3. User presses modifier keys (displayed incrementally: "⌥⇧...")
4. User presses a regular key
5. Full combination shown (e.g., "⌥⇧I")
6. Hotkey saved to preferences
7. Panel closes automatically

### Validation
- Requires at least one modifier key (⌘, ⌥, ⌃, or ⇧)
- Prevents single-key hotkeys that would interfere with typing
- Shows error message if no modifier pressed

## Key Code Mapping
Common key codes for reference:
```swift
let keyMap: [UInt16: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", ...
    34: "I", 35: "P", 31: "O", ...
]
```

## App Integration

### AppDelegate
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing setup ...

    HotkeyManager.shared.setToggleAction { [weak self] in
        self?.menuBarController.toggleWindow()
    }
    HotkeyManager.shared.startMonitoring()
}
```

### Lifecycle Management
- Start monitoring on app launch (if enabled)
- Stop monitoring when disabled
- Restart monitoring when hotkey changed
- Clean up on app termination

## Testing Checklist

### Basic Functionality
- [ ] Default hotkey (⌥⇧I) toggles window
- [ ] Hotkey works when Iris is not focused
- [ ] Hotkey works when other apps are in fullscreen
- [ ] Enable/disable toggle works
- [ ] Preference persists across app restarts

### Recording
- [ ] Recorder view highlights on click
- [ ] Modifier keys show incrementally
- [ ] Full combination recorded correctly
- [ ] Panel closes after recording
- [ ] New hotkey works immediately

### Edge Cases
- [ ] Conflicting hotkey with system shortcuts
- [ ] Conflicting hotkey with other apps
- [ ] Recording cancelled by clicking elsewhere
- [ ] Very fast key presses handled correctly

### Display
- [ ] Menu shows correct hotkey string
- [ ] Symbols render correctly (⌃⌥⇧⌘)
- [ ] Menu updates after hotkey change

## Implementation Checklist

- [x] Create HotkeyManager class
- [x] Implement Carbon RegisterEventHotKey
- [x] Create HotkeyRecorderView
- [x] Add Toggle Hotkey submenu to menu bar
- [x] Add preferences for hotkey storage
- [x] Integrate with AppDelegate
- [x] Connect toggle action to window show/hide
- [ ] Test with various hotkey combinations
- [ ] Test conflict detection
- [ ] Add to app preferences UI (future)

## Common Pitfalls

### 1. Memory Management
**Issue:** Event handler references must be retained
**Solution:** Store eventHandler and hotKeyRef as instance properties

### 2. Thread Safety
**Issue:** Carbon events may not be on main thread
**Solution:** Dispatch toggle action to main queue
```swift
DispatchQueue.main.async {
    manager.toggleAction?()
}
```

### 3. Hotkey Not Working
**Issue:** Hotkey registered but not triggering
**Solution:** Verify keyCode and modifiers match, check if another app claimed it

### 4. Modifier Flags Mismatch
**Issue:** NSEvent flags vs Carbon flags use different values
**Solution:** Use explicit conversion function

### 5. Recording Captures App Shortcuts
**Issue:** Recording might trigger app menu shortcuts
**Solution:** Return nil from event monitor to consume the event

## Dependencies
- Carbon framework (RegisterEventHotKey)
- AppKit (NSEvent, NSPanel)
- PreferencesManager
- MenuBarController

## Future Enhancements
- Multiple hotkeys for different actions
- Conflict detection with system/app shortcuts
- Visual notification when hotkey triggered
- Touch Bar integration
- Shortcuts.app integration (macOS 12+)

## Why Carbon API?

### Alternatives Considered

1. **NSEvent.addGlobalMonitorForEvents**
   - Requires Accessibility permissions
   - Users must enable in System Preferences
   - Poor UX for simple toggle functionality

2. **CGEventTap**
   - Also requires Accessibility permissions
   - More complex implementation
   - Overkill for hotkey registration

3. **Carbon RegisterEventHotKey** (chosen)
   - No permissions required
   - Well-documented pattern
   - Used by many popular apps
   - Simple and reliable

### Trade-offs
- Carbon is deprecated but still fully supported
- Limited to keyboard events (sufficient for our needs)
- Can't intercept events already claimed by system
