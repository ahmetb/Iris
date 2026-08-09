import Cocoa
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {

    private var cameraManager: CameraManager!
    private var circularWindow: CircularWindow?
    private var menuBarController: MenuBarController!

    // Sparkle updater: starts on init, performs scheduled checks, and backs
    // the "Check for Updates…" menu item.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        debugLog("applicationDidFinishLaunching started")

        // Initialize camera manager
        cameraManager = CameraManager()
        debugLog("CameraManager initialized")

        // Initialize menu bar controller immediately (so user sees the icon)
        menuBarController = MenuBarController(cameraManager: cameraManager)
        menuBarController.updaterController = updaterController
        debugLog("MenuBarController initialized")
        menuBarController.setupMenuBar()
        debugLog("Menu bar setup complete")

        HotkeyManager.shared.setToggleAction { [weak self] in
            self?.menuBarController.toggleWindow()
        }
        HotkeyManager.shared.startMonitoring()
        debugLog("HotkeyManager initialized")

        // Request camera permission and setup
        Task {
            do {
                try await cameraManager.setup(with: nil)

                // Initialize window on main thread
                await MainActor.run {
                    // Restore or use default size
                    let size = PreferencesManager.shared.windowSize
                    circularWindow = CircularWindow(
                        cameraManager: cameraManager,
                        size: size
                    )

                    // Set up right-click menu on window
                    circularWindow?.menuProvider = { [weak self] in
                        self?.menuBarController.createMenu()
                    }

                    // Give the window to the menu bar controller
                    menuBarController.setWindow(circularWindow!)

                    // Show window if it was visible last time
                    if PreferencesManager.shared.windowVisible {
                        circularWindow?.show()
                    }
                }
            } catch {
                // Show error on main thread
                await MainActor.run {
                    showPermissionError(error)
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Save window state
        if let window = circularWindow {
            PreferencesManager.shared.windowVisible = window.isVisible
            PreferencesManager.shared.windowPosition = window.frame.origin
        }

        // Cleanup hotkey handler
        HotkeyManager.shared.stopMonitoring()

        // Cleanup camera resources
        cameraManager?.stopSession()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false - app lives in menu bar even when window closed
        return false
    }

    private func showPermissionError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Camera Access Required"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func debugLog(_ message: String) {
        let logMessage = "[\(Date())] Iris: \(message)\n"
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
        print(logMessage, terminator: "")
    }
}
