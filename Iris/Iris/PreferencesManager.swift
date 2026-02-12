import Foundation
import CoreGraphics
import Cocoa

class PreferencesManager {

    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    // Preference keys
    private enum Keys {
        static let windowSize = "com.iris.app.windowSize"
        static let windowX = "com.iris.app.windowX"
        static let windowY = "com.iris.app.windowY"
        static let windowVisible = "com.iris.app.windowVisible"
        static let selectedCameraID = "com.iris.app.selectedCameraID"
        static let selectedMicrophoneID = "com.iris.app.selectedMicrophoneID"
        static let launchAtLogin = "com.iris.app.launchAtLogin"
        static let mirrorView = "com.iris.app.mirrorView"
        static let firstLaunch = "com.iris.app.firstLaunch"
        static let toggleHotkeyEnabled = "com.iris.app.toggleHotkeyEnabled"
        static let toggleHotkeyKeyCode = "com.iris.app.toggleHotkeyKeyCode"
        static let toggleHotkeyModifiers = "com.iris.app.toggleHotkeyModifiers"
    }

    // MARK: - Window Size
    var windowSize: CGFloat {
        get {
            let size = defaults.double(forKey: Keys.windowSize)
            return size > 0 ? CGFloat(size) : 200.0 // Default 200
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.windowSize)
        }
    }

    // MARK: - Window Position
    var windowPosition: CGPoint {
        get {
            let x = defaults.double(forKey: Keys.windowX)
            let y = defaults.double(forKey: Keys.windowY)
            return CGPoint(x: x, y: y)
        }
        set {
            defaults.set(Double(newValue.x), forKey: Keys.windowX)
            defaults.set(Double(newValue.y), forKey: Keys.windowY)
        }
    }

    // MARK: - Window Visibility
    var windowVisible: Bool {
        get {
            // Default to true on first launch
            if isFirstLaunch {
                return true
            }
            return defaults.bool(forKey: Keys.windowVisible)
        }
        set {
            defaults.set(newValue, forKey: Keys.windowVisible)
        }
    }

    // MARK: - Camera Selection
    var selectedCameraID: String? {
        get {
            defaults.string(forKey: Keys.selectedCameraID)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedCameraID)
        }
    }

    // MARK: - Microphone Selection
    var selectedMicrophoneID: String? {
        get {
            defaults.string(forKey: Keys.selectedMicrophoneID)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedMicrophoneID)
        }
    }

    // MARK: - Launch at Login
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    // MARK: - Mirror View
    var mirrorView: Bool {
        get {
            // Default to true (mirrored, like video call apps)
            if defaults.object(forKey: Keys.mirrorView) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.mirrorView)
        }
        set {
            defaults.set(newValue, forKey: Keys.mirrorView)
        }
    }

    // MARK: - First Launch
    var isFirstLaunch: Bool {
        get {
            !defaults.bool(forKey: Keys.firstLaunch)
        }
        set {
            // Set to true means it's NOT first launch anymore
            defaults.set(!newValue, forKey: Keys.firstLaunch)
        }
    }

    // MARK: - Toggle Hotkey
    var toggleHotkeyEnabled: Bool {
        get {
            defaults.bool(forKey: Keys.toggleHotkeyEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.toggleHotkeyEnabled)
        }
    }

    var toggleHotkeyKeyCode: UInt16 {
        get {
            // Use object(forKey:) to distinguish nil from stored 0
            // keyCode 0 is the 'A' key, which is valid
            if defaults.object(forKey: Keys.toggleHotkeyKeyCode) == nil {
                return 34 // Default to 'I' key
            }
            return UInt16(defaults.integer(forKey: Keys.toggleHotkeyKeyCode))
        }
        set {
            defaults.set(Int(newValue), forKey: Keys.toggleHotkeyKeyCode)
        }
    }

    var toggleHotkeyModifiers: UInt {
        get {
            // Use object(forKey:) to distinguish nil from stored 0
            if defaults.object(forKey: Keys.toggleHotkeyModifiers) == nil {
                // Default to Alt+Shift (NSEvent.ModifierFlags.option | .shift)
                return UInt(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.shift.rawValue)
            }
            return UInt(defaults.integer(forKey: Keys.toggleHotkeyModifiers))
        }
        set {
            defaults.set(Int(newValue), forKey: Keys.toggleHotkeyModifiers)
        }
    }

    // MARK: - Initialization
    private init() {
        // Mark that we've launched
        if isFirstLaunch {
            // Set defaults for first launch
            windowSize = 200.0
            windowVisible = true
            isFirstLaunch = false
        }
    }
}
