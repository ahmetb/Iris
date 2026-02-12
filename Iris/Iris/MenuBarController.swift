import Cocoa
import AVFoundation
import ServiceManagement

// MARK: - Menu Bar Icon Styles
enum MenuBarIconStyle: Int, CaseIterable {
    case sfSymbolEye = 0      // Option A: SF Symbol eye.circle
    case neuralWeb = 1        // Option B: Neural web pattern
    case concentricRings = 2  // Option C: Concentric rings
    case almondEye = 3        // Option D: Stylized almond eye
    case eyeOfHorus = 4       // Option E: Eye of Horus

    var displayName: String {
        switch self {
        case .sfSymbolEye: return "Eye Circle (SF Symbol)"
        case .neuralWeb: return "Neural Web"
        case .concentricRings: return "Concentric Rings"
        case .almondEye: return "Almond Eye"
        case .eyeOfHorus: return "Eye of Horus"
        }
    }

    var next: MenuBarIconStyle {
        let allCases = MenuBarIconStyle.allCases
        let currentIndex = allCases.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

class MenuBarController: NSObject {

    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private weak var circularWindow: CircularWindow?
    private var cameraManager: CameraManager
    private var audioManager: AudioManager?
    private var currentIconStyle: MenuBarIconStyle = .almondEye
    private var hotkeyRecorderPanel: NSPanel?

    // MARK: - Initialization
    init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        super.init()

        // Observe camera device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    func setAudioManager(_ audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    func setupMenuBar() {
        debugLog("setupMenuBar() called")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        debugLog("statusItem created: \(statusItem != nil)")

        guard let statusItem = statusItem else {
            debugLog("ERROR - statusItem is nil!")
            return
        }
        guard let button = statusItem.button else {
            debugLog("ERROR - button is nil!")
            return
        }
        debugLog("button obtained")

        // Set icon based on current style
        updateMenuBarIcon()

        // Set tooltip
        button.toolTip = "Iris - Click to toggle, right-click for menu"

        // Handle clicks manually (not setting menu allows us to differentiate click types)
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Don't set menu directly - we'll show it programmatically on right-click
        // statusItem.menu = nil
    }

    func setWindow(_ window: CircularWindow) {
        self.circularWindow = window
    }

    // MARK: - Icon Creation

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let image = createMenuBarIcon(style: currentIconStyle)
        image.isTemplate = true
        button.image = image
    }

    private func createMenuBarIcon(style: MenuBarIconStyle) -> NSImage {
        switch style {
        case .sfSymbolEye:
            return createSFSymbolEyeIcon()
        case .neuralWeb:
            return createNeuralWebIcon()
        case .concentricRings:
            return createConcentricRingsIcon()
        case .almondEye:
            return createAlmondEyeIcon()
        case .eyeOfHorus:
            return createEyeOfHorusIcon()
        }
    }

    // Option A: SF Symbol eye.circle
    private func createSFSymbolEyeIcon() -> NSImage {
        if let image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Iris") {
            return image
        }
        // Fallback to custom drawn icon
        return createNeuralWebIcon()
    }

    // Option B: Neural web pattern (no outer circle, randomized branches)
    private func createNeuralWebIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let maxRadius: CGFloat = 8.0
            let pupilRadius: CGFloat = 3.5  // Bigger pupil

            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Seeded pseudo-random values for consistent but organic look
            // These create a deterministic "random" pattern
            let branchData: [(angle: CGFloat, length: CGFloat, curve: CGFloat, hasSecondary: Bool)] = [
                (0.0, 0.95, 0.2, true),
                (0.9, 0.75, -0.15, false),
                (1.7, 0.85, 0.25, true),
                (2.4, 0.65, -0.1, true),
                (3.3, 0.90, 0.18, false),
                (4.0, 0.70, -0.22, true),
                (4.9, 0.80, 0.12, false),
                (5.6, 0.88, -0.2, true),
            ]

            let nodeRadius: CGFloat = 0.9

            for branch in branchData {
                let baseAngle = branch.angle
                let lengthFactor = branch.length
                let curveOffset = branch.curve

                // Main branch from pupil outward
                let startPoint = NSPoint(
                    x: center.x + cos(baseAngle) * (pupilRadius + 0.3),
                    y: center.y + sin(baseAngle) * (pupilRadius + 0.3)
                )

                // End point with varied length
                let endRadius = maxRadius * lengthFactor
                let endPoint = NSPoint(
                    x: center.x + cos(baseAngle) * endRadius,
                    y: center.y + sin(baseAngle) * endRadius
                )

                // Control point for organic curve
                let midRadius = (pupilRadius + endRadius) / 2
                let controlAngle = baseAngle + curveOffset
                let controlPoint = NSPoint(
                    x: center.x + cos(controlAngle) * midRadius,
                    y: center.y + sin(controlAngle) * midRadius
                )

                // Draw curved branch
                let branchPath = NSBezierPath()
                branchPath.move(to: startPoint)
                branchPath.curve(to: endPoint, controlPoint1: controlPoint, controlPoint2: controlPoint)
                branchPath.lineWidth = 0.7
                branchPath.stroke()

                // Draw node at end of branch
                let nodeCircle = NSBezierPath(
                    ovalIn: NSRect(
                        x: endPoint.x - nodeRadius,
                        y: endPoint.y - nodeRadius,
                        width: nodeRadius * 2,
                        height: nodeRadius * 2
                    )
                )
                nodeCircle.fill()

                // Draw secondary branch for some
                if branch.hasSecondary {
                    let secondaryAngle = baseAngle + (curveOffset > 0 ? 0.5 : -0.5)
                    let secondaryStart = NSPoint(
                        x: center.x + cos(baseAngle) * (midRadius * 0.8),
                        y: center.y + sin(baseAngle) * (midRadius * 0.8)
                    )
                    let secondaryEnd = NSPoint(
                        x: center.x + cos(secondaryAngle) * (endRadius * 0.85),
                        y: center.y + sin(secondaryAngle) * (endRadius * 0.85)
                    )

                    let secondaryBranch = NSBezierPath()
                    secondaryBranch.move(to: secondaryStart)
                    secondaryBranch.line(to: secondaryEnd)
                    secondaryBranch.lineWidth = 0.5
                    secondaryBranch.stroke()

                    // Small node at secondary branch end
                    let smallNodeRadius: CGFloat = 0.6
                    let smallNode = NSBezierPath(
                        ovalIn: NSRect(
                            x: secondaryEnd.x - smallNodeRadius,
                            y: secondaryEnd.y - smallNodeRadius,
                            width: smallNodeRadius * 2,
                            height: smallNodeRadius * 2
                        )
                    )
                    smallNode.fill()
                }
            }

            // Draw pupil (filled circle) on top
            let pupilCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - pupilRadius,
                    y: center.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
            )
            pupilCircle.fill()

            // Draw light reflection highlights (two for realistic eye look)
            NSColor.white.setFill()

            // Main highlight (upper right)
            let highlightRadius: CGFloat = 1.2
            let highlightCenter = NSPoint(x: center.x + 1.0, y: center.y + 1.0)
            let highlightCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: highlightCenter.x - highlightRadius,
                    y: highlightCenter.y - highlightRadius,
                    width: highlightRadius * 2,
                    height: highlightRadius * 2
                )
            )
            highlightCircle.fill()

            // Secondary smaller highlight (lower left)
            let smallHighlightRadius: CGFloat = 0.6
            let smallHighlightCenter = NSPoint(x: center.x - 1.2, y: center.y - 0.8)
            let smallHighlightCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: smallHighlightCenter.x - smallHighlightRadius,
                    y: smallHighlightCenter.y - smallHighlightRadius,
                    width: smallHighlightRadius * 2,
                    height: smallHighlightRadius * 2
                )
            )
            smallHighlightCircle.fill()

            return true
        }
        return image
    }

    // Option C: Concentric rings
    private func createConcentricRingsIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let outerRadius: CGFloat = 8.0
            let middleRadius: CGFloat = 5.0
            let innerRadius: CGFloat = 2.0

            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Draw outer circle
            let outerCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                )
            )
            outerCircle.lineWidth = 1.2
            outerCircle.stroke()

            // Draw middle circle (iris)
            let middleCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - middleRadius,
                    y: center.y - middleRadius,
                    width: middleRadius * 2,
                    height: middleRadius * 2
                )
            )
            middleCircle.lineWidth = 1.0
            middleCircle.stroke()

            // Draw inner circle (pupil) - filled
            let innerCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - innerRadius,
                    y: center.y - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                )
            )
            innerCircle.fill()

            return true
        }
        return image
    }

    // Option D: Stylized almond-shaped eye
    private func createAlmondEyeIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let eyeWidth: CGFloat = 16.0
            let eyeHeight: CGFloat = 8.0
            let irisRadius: CGFloat = 3.0
            let pupilRadius: CGFloat = 1.5

            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Draw almond shape using bezier curves
            let almondPath = NSBezierPath()

            // Left point
            let leftPoint = NSPoint(x: center.x - eyeWidth / 2, y: center.y)
            // Right point
            let rightPoint = NSPoint(x: center.x + eyeWidth / 2, y: center.y)

            // Control points for top curve
            let topControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y + eyeHeight / 2)
            let topControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y + eyeHeight / 2)

            // Control points for bottom curve
            let bottomControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y - eyeHeight / 2)
            let bottomControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y - eyeHeight / 2)

            // Draw top half of almond
            almondPath.move(to: leftPoint)
            almondPath.curve(to: rightPoint, controlPoint1: topControlLeft, controlPoint2: topControlRight)

            // Draw bottom half of almond
            almondPath.curve(to: leftPoint, controlPoint1: bottomControlRight, controlPoint2: bottomControlLeft)

            almondPath.lineWidth = 1.2
            almondPath.stroke()

            // Draw iris circle
            let irisCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - irisRadius,
                    y: center.y - irisRadius,
                    width: irisRadius * 2,
                    height: irisRadius * 2
                )
            )
            irisCircle.lineWidth = 1.0
            irisCircle.stroke()

            // Draw pupil (filled)
            let pupilCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - pupilRadius,
                    y: center.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
            )
            pupilCircle.fill()

            return true
        }
        return image
    }

    // Option E: Eye of Horus (ancient Egyptian symbol)
    private func createEyeOfHorusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let eyeWidth: CGFloat = 12.0
            let eyeHeight: CGFloat = 6.5
            let irisRadius: CGFloat = 2.5

            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Draw almond-shaped eye outline (thick lines)
            let eyePath = NSBezierPath()

            // Inner corner (left) and outer corner (right)
            let innerCorner = NSPoint(x: center.x - eyeWidth / 2, y: center.y)
            let outerCorner = NSPoint(x: center.x + eyeWidth / 2, y: center.y)

            // Control points for top curve
            let topControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y + eyeHeight / 2)
            let topControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y + eyeHeight / 2)

            // Control points for bottom curve
            let bottomControlLeft = NSPoint(x: center.x - eyeWidth / 4, y: center.y - eyeHeight / 2)
            let bottomControlRight = NSPoint(x: center.x + eyeWidth / 4, y: center.y - eyeHeight / 2)

            // Draw top eyelid
            eyePath.move(to: innerCorner)
            eyePath.curve(to: outerCorner, controlPoint1: topControlLeft, controlPoint2: topControlRight)

            // Draw bottom eyelid
            eyePath.curve(to: innerCorner, controlPoint1: bottomControlRight, controlPoint2: bottomControlLeft)

            eyePath.lineWidth = 1.5
            eyePath.stroke()

            // Draw curved eyebrow above - starts from inner corner, arches up prominently
            let eyebrowPath = NSBezierPath()
            let eyebrowStart = NSPoint(x: innerCorner.x, y: innerCorner.y + eyeHeight / 2)
            let eyebrowEnd = NSPoint(x: outerCorner.x - 1.0, y: outerCorner.y + eyeHeight / 2 + 0.5)
            let eyebrowControl = NSPoint(x: center.x, y: center.y + eyeHeight / 2 + 3.0)
            eyebrowPath.move(to: eyebrowStart)
            eyebrowPath.curve(to: eyebrowEnd, controlPoint1: eyebrowControl, controlPoint2: eyebrowControl)
            eyebrowPath.lineWidth = 1.5
            eyebrowPath.stroke()

            // Draw teardrop marking below inner corner (left side)
            // Vertical line descending from inner corner
            let teardropPath = NSBezierPath()
            let teardropTop = NSPoint(x: innerCorner.x, y: innerCorner.y - eyeHeight / 2)
            let teardropBottom = NSPoint(x: innerCorner.x, y: innerCorner.y - eyeHeight / 2 - 2.5)
            teardropPath.move(to: teardropTop)
            teardropPath.line(to: teardropBottom)
            teardropPath.lineWidth = 1.5
            teardropPath.stroke()

            // Small circle attached at bottom, slightly offset to the right
            let teardropCircleRadius: CGFloat = 1.0
            let teardropCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: teardropBottom.x + 0.5 - teardropCircleRadius,
                    y: teardropBottom.y - teardropCircleRadius,
                    width: teardropCircleRadius * 2,
                    height: teardropCircleRadius * 2
                )
            )
            teardropCircle.fill()

            // Draw spiral marking below outer corner (right side)
            // Extends down and curls inward to form tight spiral
            let spiralPath = NSBezierPath()
            let spiralStart = NSPoint(x: outerCorner.x, y: outerCorner.y - eyeHeight / 2)
            let spiralMid = NSPoint(x: outerCorner.x + 0.5, y: outerCorner.y - eyeHeight / 2 - 1.5)
            let spiralEnd = NSPoint(x: outerCorner.x - 0.5, y: outerCorner.y - eyeHeight / 2 - 2.5)

            // Draw the spiral: down, then curl inward
            spiralPath.move(to: spiralStart)
            spiralPath.line(to: spiralMid)

            // Create tight spiral/volute by drawing curved path that curls inward
            let spiralControl1 = NSPoint(x: outerCorner.x + 1.0, y: outerCorner.y - eyeHeight / 2 - 2.0)
            let spiralControl2 = NSPoint(x: outerCorner.x, y: outerCorner.y - eyeHeight / 2 - 2.5)
            spiralPath.curve(to: spiralEnd, controlPoint1: spiralControl1, controlPoint2: spiralControl2)

            // Continue the spiral inward
            let spiralInner = NSPoint(x: outerCorner.x - 1.2, y: outerCorner.y - eyeHeight / 2 - 2.0)
            let spiralInnerControl = NSPoint(x: outerCorner.x - 0.8, y: outerCorner.y - eyeHeight / 2 - 2.3)
            spiralPath.curve(to: spiralInner, controlPoint1: spiralInnerControl, controlPoint2: spiralInnerControl)

            spiralPath.lineWidth = 1.5
            spiralPath.stroke()

            // Draw filled iris circle (no separate pupil - just filled black circle)
            let irisCircle = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - irisRadius,
                    y: center.y - irisRadius,
                    width: irisRadius * 2,
                    height: irisRadius * 2
                )
            )
            irisCircle.fill()

            return true
        }
        return image
    }

    @objc func cycleIconStyle() {
        currentIconStyle = currentIconStyle.next
        updateMenuBarIcon()
        debugLog("Icon style changed to: \(currentIconStyle.displayName)")
    }

    // MARK: - Menu Creation
    func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Toggle window item
        let toggleTitle: String
        if circularWindow == nil {
            toggleTitle = "Show Window (Loading...)"
        } else if circularWindow?.isVisible == true {
            toggleTitle = "Hide Window"
        } else {
            toggleTitle = "Show Window"
        }

        let toggleItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.isEnabled = circularWindow != nil
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Camera selection submenu
        let cameraMenuItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        let cameraSubmenu = createCameraSubmenu()
        cameraMenuItem.submenu = cameraSubmenu
        menu.addItem(cameraMenuItem)

        // Sound indicator submenu
        let microphoneMenuItem = NSMenuItem(title: "Sound Indicator", action: nil, keyEquivalent: "")
        let microphoneSubmenu = createMicrophoneSubmenu()
        microphoneMenuItem.submenu = microphoneSubmenu
        menu.addItem(microphoneMenuItem)

        // Mirror View toggle
        let mirrorItem = NSMenuItem(
            title: "Mirror View",
            action: #selector(toggleMirrorView),
            keyEquivalent: ""
        )
        mirrorItem.target = self
        mirrorItem.state = PreferencesManager.shared.mirrorView ? .on : .off
        menu.addItem(mirrorItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        // Icon Style submenu (for testing different icon designs)
        let iconMenuItem = NSMenuItem(title: "Icon Style", action: nil, keyEquivalent: "")
        let iconSubmenu = createIconStyleSubmenu()
        iconMenuItem.submenu = iconSubmenu
        menu.addItem(iconMenuItem)

        let hotkeyMenuItem = NSMenuItem(title: "Toggle Hotkey", action: nil, keyEquivalent: "")
        let hotkeySubmenu = createHotkeySubmenu()
        hotkeyMenuItem.submenu = hotkeySubmenu
        menu.addItem(hotkeyMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Iris",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func createCameraSubmenu() -> NSMenu {
        let menu = NSMenu()

        let cameras = CameraManager.availableCameras()

        if cameras.isEmpty {
            let noCamera = NSMenuItem(title: "No Camera Available", action: nil, keyEquivalent: "")
            noCamera.isEnabled = false
            menu.addItem(noCamera)
            return menu
        }

        let currentDevice = cameraManager.currentDevice

        for camera in cameras {
            let item = NSMenuItem(
                title: camera.localizedName,
                action: #selector(selectCamera(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = camera

            // Checkmark for current camera
            if camera.uniqueID == currentDevice?.uniqueID {
                item.state = .on
            }

            menu.addItem(item)
        }

        return menu
    }

    private func createMicrophoneSubmenu() -> NSMenu {
        let menu = NSMenu()

        let currentDevice = audioManager?.currentDevice

        // Disable indicator option
        let disabledItem = NSMenuItem(
            title: "Disable Indicator",
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        disabledItem.target = self
        disabledItem.representedObject = AudioDevice.disabled
        if currentDevice?.uid == "disabled" {
            disabledItem.state = .on
        }
        menu.addItem(disabledItem)

        menu.addItem(NSMenuItem.separator())

        // System Default option
        let defaultItem = NSMenuItem(
            title: "System Default",
            action: #selector(selectMicrophone(_:)),
            keyEquivalent: ""
        )
        defaultItem.target = self
        defaultItem.representedObject = AudioDevice.systemDefault
        if currentDevice?.uid == "system-default" {
            defaultItem.state = .on
        }
        menu.addItem(defaultItem)

        let microphones = AudioManager.availableMicrophones()

        if !microphones.isEmpty {
            menu.addItem(NSMenuItem.separator())

            for mic in microphones {
                let item = NSMenuItem(
                    title: mic.name,
                    action: #selector(selectMicrophone(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = mic

                // Checkmark for current microphone (only if not using system default or disabled)
                if currentDevice?.uid != "system-default" &&
                   currentDevice?.uid != "disabled" &&
                   mic.id == currentDevice?.id {
                    item.state = .on
                }

                menu.addItem(item)
            }
        }

        return menu
    }

    private func createIconStyleSubmenu() -> NSMenu {
        let menu = NSMenu()

        for style in MenuBarIconStyle.allCases {
            let item = NSMenuItem(
                title: style.displayName,
                action: #selector(selectIconStyle(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = style.rawValue

            // Checkmark for current style
            if style == currentIconStyle {
                item.state = .on
            }

            menu.addItem(item)
        }

        return menu
    }

    private func createHotkeySubmenu() -> NSMenu {
        let menu = NSMenu()

        let isEnabled = PreferencesManager.shared.toggleHotkeyEnabled
        let currentHotkey = HotkeyManager.shared.currentHotkeyDisplayString()

        let enabledItem = NSMenuItem(
            title: isEnabled ? "Enabled (\(currentHotkey))" : "Disabled",
            action: #selector(toggleHotkeyEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        let recordItem = NSMenuItem(
            title: "Record Hotkey...",
            action: #selector(showHotkeyRecorderPanel),
            keyEquivalent: ""
        )
        recordItem.target = self
        menu.addItem(recordItem)

        return menu
    }

    // MARK: - Actions
    @objc func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggleWindow()
            return
        }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            showMenu()
        } else {
            // Left-click: toggle window
            toggleWindow()
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = createMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    @objc func toggleWindow() {
        guard let window = circularWindow else {
            // Window not ready yet
            return
        }

        if window.isVisible {
            window.hide()
        } else {
            window.show()
        }
    }

    @objc func selectCamera(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AVCaptureDevice else { return }

        Task {
            do {
                try await cameraManager.switchToCamera(device)
            } catch {
                // Show error alert on main thread
                await MainActor.run {
                    self.showError("Failed to switch camera: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func selectMicrophone(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        guard let audioManager = audioManager else { return }

        Task {
            do {
                try await audioManager.switchToMicrophone(device)
            } catch {
                // Show error alert on main thread
                await MainActor.run {
                    self.showError("Failed to switch microphone: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func toggleMirrorView() {
        let newValue = !PreferencesManager.shared.mirrorView
        PreferencesManager.shared.mirrorView = newValue

        // Update the window
        circularWindow?.setMirrored(newValue)
    }

    @objc func selectIconStyle(_ sender: NSMenuItem) {
        guard let style = MenuBarIconStyle(rawValue: sender.tag) else { return }
        currentIconStyle = style
        updateMenuBarIcon()
        debugLog("Icon style changed to: \(style.displayName)")
    }

    @objc func toggleHotkeyEnabled() {
        let newValue = !PreferencesManager.shared.toggleHotkeyEnabled
        PreferencesManager.shared.toggleHotkeyEnabled = newValue
        if newValue {
            HotkeyManager.shared.startMonitoring()
        } else {
            HotkeyManager.shared.stopMonitoring()
        }
    }

    @objc func showHotkeyRecorderPanel() {
        // Close existing panel if any
        hotkeyRecorderPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Record Hotkey"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.center()

        // Retain the panel
        hotkeyRecorderPanel = panel

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))

        let label = NSTextField(labelWithString: "Press a key combination:")
        label.frame = NSRect(x: 20, y: 80, width: 280, height: 20)
        contentView.addSubview(label)

        let recorderView = HotkeyRecorderView(frame: NSRect(x: 20, y: 35, width: 280, height: 35))
        recorderView.setDisplayString(HotkeyManager.shared.currentHotkeyDisplayString())
        recorderView.onHotkeyRecorded = { [weak self, weak panel] keyCode, modifiers in
            // Temporarily save the new hotkey settings
            let oldKeyCode = PreferencesManager.shared.toggleHotkeyKeyCode
            let oldModifiers = PreferencesManager.shared.toggleHotkeyModifiers
            let wasEnabled = PreferencesManager.shared.toggleHotkeyEnabled

            PreferencesManager.shared.toggleHotkeyKeyCode = keyCode
            PreferencesManager.shared.toggleHotkeyModifiers = modifiers.rawValue
            PreferencesManager.shared.toggleHotkeyEnabled = true

            // Attempt to register the hotkey
            let success = HotkeyManager.shared.restartMonitoring()

            if success {
                // Registration succeeded, close panel after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    panel?.close()
                    self?.hotkeyRecorderPanel = nil
                }
            } else {
                // Registration failed, revert to old settings
                PreferencesManager.shared.toggleHotkeyKeyCode = oldKeyCode
                PreferencesManager.shared.toggleHotkeyModifiers = oldModifiers
                PreferencesManager.shared.toggleHotkeyEnabled = wasEnabled
                if wasEnabled {
                    HotkeyManager.shared.restartMonitoring()
                }

                // Show error to user
                self?.showError("Could not register hotkey. It may be in use by another application.")
                recorderView.setDisplayString(HotkeyManager.shared.currentHotkeyDisplayString())
            }
        }
        recorderView.onRecordingCancelled = { [weak self, weak panel] in
            panel?.close()
            self?.hotkeyRecorderPanel = nil
        }
        contentView.addSubview(recorderView)

        panel.contentView = contentView
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(recorderView)
    }

    @objc func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
    }

    @objc func quit() {
        // Clean up camera resources
        cameraManager.stopSession()

        // Clean up audio resources
        audioManager?.stopMonitoring()

        // Quit app
        NSApplication.shared.terminate(nil)
    }

    @objc func devicesDidChange() {
        // Menu will be refreshed on next right-click
    }

    // MARK: - Launch at Login
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return PreferencesManager.shared.launchAtLogin
        }
    }

    private func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                PreferencesManager.shared.launchAtLogin = true
            } catch {
                showError("Failed to enable launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for older macOS versions
            PreferencesManager.shared.launchAtLogin = true
            showError("Launch at login requires macOS 13 or later.")
        }
    }

    private func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                PreferencesManager.shared.launchAtLogin = false
            } catch {
                showError("Failed to disable launch at login: \(error.localizedDescription)")
            }
        } else {
            PreferencesManager.shared.launchAtLogin = false
        }
    }

    // MARK: - Error Handling
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func debugLog(_ message: String) {
        let logMessage = "[\(Date())] MenuBar: \(message)\n"
        let logPath = "/tmp/iris_debug.log"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
            }
        }
    }
}
