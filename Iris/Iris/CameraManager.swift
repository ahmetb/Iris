import Foundation
@preconcurrency import AVFoundation
import AppKit

enum CameraError: Error, LocalizedError {
    case noDeviceAvailable
    case permissionDenied
    case cannotAddInput
    case sessionConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .noDeviceAvailable:
            return "No camera device found. Please connect a camera."
        case .permissionDenied:
            return "Iris needs camera access. Enable it in System Settings > Privacy & Security > Camera."
        case .cannotAddInput:
            return "Cannot configure camera."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        }
    }
}

// Mutable session state (captureSession, videoDevice, videoInput) is confined
// to `sessionQueue`, so cross-thread access from the @Sendable dispatch
// closures is safe by construction.
final class CameraManager: NSObject, @unchecked Sendable {

    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?

    // All session configuration (setup, start/stop, input rebuilds) runs on
    // this serial queue. Wake, hot-plug, and user-driven camera switches can
    // otherwise fire concurrently and interleave beginConfiguration/
    // removeInput/addInput on the same session, corrupting it. Serializing
    // guarantees one reconfiguration completes before the next begins.
    private let sessionQueue = DispatchQueue(label: "com.iris.app.camera.session")

    var previewLayer: AVCaptureVideoPreviewLayer?
    var isSessionRunning: Bool { captureSession?.isRunning ?? false }
    var currentDevice: AVCaptureDevice? { videoDevice }

    // MARK: - Init
    override init() {
        super.init()
        // After system sleep the AVCaptureDeviceInput is left in a dead state —
        // session may still report running, but no frames flow. Rebuild the
        // input on wake so the camera recovers without the user having to
        // reselect it from the menu.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        // If the user's preferred camera comes back at runtime (e.g. plugging
        // in an external camera), switch back to it from the fallback.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasConnected(_:)),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        // If the currently active device is unplugged, fall back to whatever
        // is still available so the window doesn't go permanently black.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasDisconnected(_:)),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func systemDidWake() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDevice else { return }
            try? self.rebuildInputSync(for: device)
        }
    }

    @objc private func deviceWasConnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice,
              let savedID = PreferencesManager.shared.selectedCameraID,
              device.uniqueID == savedID else { return }
        // Always rebuild when our preferred camera (re)connects: covers both
        // "we were on a fallback" and "we're nominally on it but the input
        // is stale because the device was just plugged in".
        sessionQueue.async { [weak self] in
            try? self?.rebuildInputSync(for: device)
        }
    }

    @objc private func deviceWasDisconnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice else { return }

        sessionQueue.async { [weak self] in
            // Only react if the device that vanished is the one we're using.
            // Checked on the session queue so it can't race a concurrent switch.
            guard let self, self.videoDevice?.uniqueID == device.uniqueID else { return }

            // Pick a still-available fallback. Don't touch the saved preference —
            // we want to switch back automatically if the original camera returns.
            let fallback: AVCaptureDevice? = {
                if let defaultDev = AVCaptureDevice.default(for: .video),
                   defaultDev.uniqueID != device.uniqueID {
                    return defaultDev
                }
                return Self.availableCameras().first { $0.uniqueID != device.uniqueID }
            }()

            guard let fallback else { return }
            try? self.rebuildInputSync(for: fallback)
        }
    }

    // MARK: - Setup
    func setup(with device: AVCaptureDevice?) async throws {
        // Check permissions first
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }

        // Build the session on the serial queue so it can't interleave with a
        // wake/hot-plug rebuild that arrives while we're still configuring.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                do {
                    try self.configureInitialSession(with: device)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Don't persist here: if the saved camera was unavailable and we fell
        // back to the default, we want to keep the user's original choice so
        // it can be restored when that camera reconnects. The preference is
        // only updated when the user explicitly picks a camera via
        // switchToCamera().

        // Defensive: if the device was hot-replugged shortly before launch,
        // a freshly created AVCaptureDeviceInput sometimes attaches but
        // produces no frames until the input is cycled. Rebuild once after
        // setup so the user doesn't have to re-pick the same camera from
        // the menu to get video. Serialized on the same queue.
        sessionQueue.async { [weak self] in
            guard let self,
                  let savedID = PreferencesManager.shared.selectedCameraID,
                  let device = self.videoDevice,
                  device.uniqueID == savedID else { return }
            try? self.rebuildInputSync(for: device)
        }
    }

    /// Creates and configures the initial capture session. Must run on
    /// `sessionQueue`.
    private func configureInitialSession(with device: AVCaptureDevice?) throws {
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Get video device
        let selectedDevice: AVCaptureDevice?
        if let device = device {
            selectedDevice = device
        } else if let savedDeviceID = PreferencesManager.shared.selectedCameraID {
            // Try to restore saved camera
            selectedDevice = Self.availableCameras().first { $0.uniqueID == savedDeviceID }
                ?? AVCaptureDevice.default(for: .video)
        } else {
            selectedDevice = AVCaptureDevice.default(for: .video)
        }

        guard let videoDevice = selectedDevice else {
            session.commitConfiguration()
            throw CameraError.noDeviceAvailable
        }

        // Create input
        let input = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        // Set session preset
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        session.commitConfiguration()

        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        // Store references
        self.captureSession = session
        self.videoDevice = videoDevice
        self.videoInput = input
        self.previewLayer = previewLayer
    }

    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let session = self?.captureSession, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let session = self?.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }

    // MARK: - Device Enumeration
    static func availableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    // MARK: - Device Switching

    /// User-driven camera switch. Persists the choice as the preferred camera.
    func switchToCamera(_ device: AVCaptureDevice) async throws {
        try await rebuildInput(for: device)
        PreferencesManager.shared.selectedCameraID = device.uniqueID
    }

    /// Async bridge to `rebuildInputSync` for callers that need to await the
    /// result (and surface errors), while still serializing on `sessionQueue`.
    private func rebuildInput(for device: AVCaptureDevice) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                do {
                    try self.rebuildInputSync(for: device)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Rebuilds the capture input for `device` without touching the saved
    /// preference. Used for non-user-initiated switches (wake recovery,
    /// preferred-camera reconnect) so a transient fallback never overwrites
    /// the user's actual choice. Must run on `sessionQueue`.
    private func rebuildInputSync(for device: AVCaptureDevice) throws {
        guard let session = captureSession else { return }

        let wasRunning = session.isRunning
        if wasRunning {
            session.stopRunning()
        }

        session.beginConfiguration()

        // Remove old input
        if let oldInput = videoInput {
            session.removeInput(oldInput)
        }

        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(newInput) else {
                // Try to restore old input
                if let oldInput = videoInput, session.canAddInput(oldInput) {
                    session.addInput(oldInput)
                }
                session.commitConfiguration()
                if wasRunning { session.startRunning() }
                throw CameraError.cannotAddInput
            }
            session.addInput(newInput)
            session.commitConfiguration()

            // Update references
            self.videoDevice = device
            self.videoInput = newInput
        } catch {
            // Couldn't create the input at all — restore the old one if possible.
            if let oldInput = videoInput, session.canAddInput(oldInput) {
                session.addInput(oldInput)
            }
            session.commitConfiguration()
            if wasRunning { session.startRunning() }
            throw error
        }

        if wasRunning {
            session.startRunning()
        }
    }
}
