import Cocoa
import Carbon
import os.log

class HotkeyManager {

    static let shared = HotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var toggleAction: (() -> Void)?
    private var registrationFailedCallback: ((String) -> Void)?

    private static let hotKeyID = EventHotKeyID(signature: OSType(0x49524953), id: 1) // "IRIS"
    private static let logger = Logger(subsystem: "com.iris.app", category: "HotkeyManager")

    private init() {}

    func setToggleAction(_ action: @escaping () -> Void) {
        self.toggleAction = action
    }

    func setRegistrationFailedCallback(_ callback: @escaping (String) -> Void) {
        self.registrationFailedCallback = callback
    }

    /// Attempts to start monitoring for the configured hotkey.
    /// Returns true if successful, false if registration failed.
    @discardableResult
    func startMonitoring() -> Bool {
        guard PreferencesManager.shared.toggleHotkeyEnabled else { return false }
        stopMonitoring()

        let keyCode = PreferencesManager.shared.toggleHotkeyKeyCode
        let modifiers = PreferencesManager.shared.toggleHotkeyModifiers

        let carbonModifiers = carbonModifierFlags(from: modifiers)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let paramStatus = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard paramStatus == noErr else {
                HotkeyManager.logger.error("GetEventParameter failed with status: \(paramStatus)")
                return OSStatus(eventNotHandledErr)
            }

            if hotKeyID.signature == HotkeyManager.hotKeyID.signature && hotKeyID.id == HotkeyManager.hotKeyID.id {
                DispatchQueue.main.async {
                    manager.toggleAction?()
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)

        guard handlerStatus == noErr else {
            Self.logger.error("InstallEventHandler failed with status: \(handlerStatus)")
            let message = "Failed to install hotkey handler (error \(handlerStatus))"
            registrationFailedCallback?(message)
            return false
        }

        var hotKeyIDVar = HotkeyManager.hotKeyID
        let registerStatus = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyIDVar, GetApplicationEventTarget(), 0, &hotKeyRef)

        guard registerStatus == noErr else {
            Self.logger.error("RegisterEventHotKey failed with status: \(registerStatus)")
            // Clean up the event handler since registration failed
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            let message = "Hotkey may be in use by another app (error \(registerStatus))"
            registrationFailedCallback?(message)
            return false
        }

        Self.logger.info("Hotkey registered successfully")
        return true
    }

    func stopMonitoring() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    @discardableResult
    func restartMonitoring() -> Bool {
        stopMonitoring()
        return startMonitoring()
    }

    private func carbonModifierFlags(from flags: UInt) -> UInt32 {
        var carbonFlags: UInt32 = 0
        let nsFlags = NSEvent.ModifierFlags(rawValue: flags)
        if nsFlags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if nsFlags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if nsFlags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if nsFlags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }

    func currentHotkeyDisplayString() -> String {
        let keyCode = PreferencesManager.shared.toggleHotkeyKeyCode
        let modifiers = NSEvent.ModifierFlags(rawValue: PreferencesManager.shared.toggleHotkeyModifiers)
        return modifierString(modifiers) + keyString(keyCode)
    }

    func modifierString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }

    private static let keyMap: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`", 65: ".", 67: "*", 69: "+",
        71: "Clear", 75: "/", 76: "Enter", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6",
        89: "7", 91: "8", 92: "9",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    func keyString(_ keyCode: UInt16) -> String {
        return Self.keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

class HotkeyRecorderView: NSView {
    var onHotkeyRecorded: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onRecordingCancelled: (() -> Void)?

    private var isRecording = false
    private let label = NSTextField(labelWithString: "Click to record hotkey...")
    private var localMonitor: Any?
    private var flagsMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        stopMonitoring()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    private func updateAppearance() {
        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            cancelRecording()
        }
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    private func startRecording() {
        isRecording = true
        label.stringValue = "Press hotkey combination..."
        updateAppearance()
        startMonitoring()
    }

    private func cancelRecording() {
        isRecording = false
        updateAppearance()
        stopMonitoring()
        label.stringValue = "Click to record hotkey..."
        onRecordingCancelled?()
    }

    /// Checks if modifiers include at least one of Command, Option, or Control.
    /// Shift alone is not sufficient as it would conflict with normal typing.
    private func hasRequiredModifier(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        return modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control)
    }

    private func startMonitoring() {
        stopMonitoring()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            // Escape key cancels recording
            if event.keyCode == 53 {
                self.cancelRecording()
                return nil
            }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

            // Require at least Command, Option, or Control (Shift alone is not enough)
            if !self.hasRequiredModifier(modifiers) {
                self.label.stringValue = "Need ⌘, ⌥, or ⌃ modifier"
                return nil
            }

            let keyCode = event.keyCode
            let displayString = HotkeyManager.shared.modifierString(modifiers) + HotkeyManager.shared.keyString(keyCode)
            self.label.stringValue = displayString

            self.isRecording = false
            self.updateAppearance()
            self.stopMonitoring()

            self.onHotkeyRecorded?(keyCode, modifiers)
            return nil
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if !modifiers.isEmpty {
                self.label.stringValue = HotkeyManager.shared.modifierString(modifiers) + "..."
            } else {
                self.label.stringValue = "Press hotkey combination..."
            }
            return event
        }
    }

    private func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    func setDisplayString(_ string: String) {
        label.stringValue = string
    }
}
