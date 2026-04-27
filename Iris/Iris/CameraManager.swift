import Foundation
import AVFoundation
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

class CameraManager: NSObject {

    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?

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
        guard let device = videoDevice else { return }
        Task { [weak self] in
            try? await self?.rebuildInput(for: device)
        }
    }

    @objc private func deviceWasConnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice,
              let savedID = PreferencesManager.shared.selectedCameraID,
              device.uniqueID == savedID else { return }
        // Always rebuild when our preferred camera (re)connects: covers both
        // "we were on a fallback" and "we're nominally on it but the input
        // is stale because the device was just plugged in".
        Task { [weak self] in
            try? await self?.rebuildInput(for: device)
        }
    }

    @objc private func deviceWasDisconnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice,
              videoDevice?.uniqueID == device.uniqueID else { return }

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

        Task { [weak self] in
            try? await self?.rebuildInput(for: fallback)
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

        // Create session
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

        // Don't persist here: if the saved camera was unavailable and we fell
        // back to the default, we want to keep the user's original choice so
        // it can be restored when that camera reconnects. The preference is
        // only updated when the user explicitly picks a camera via
        // switchToCamera().

        // Defensive: if the device was hot-replugged shortly before launch,
        // a freshly created AVCaptureDeviceInput sometimes attaches but
        // produces no frames until the input is cycled. Rebuild once after
        // setup so the user doesn't have to re-pick the same camera from
        // the menu to get video.
        if let savedID = PreferencesManager.shared.selectedCameraID,
           videoDevice.uniqueID == savedID {
            Task { [weak self] in
                try? await self?.rebuildInput(for: videoDevice)
            }
        }
    }

    // MARK: - Session Control
    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
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

    /// Rebuilds the capture input for `device` without touching the saved
    /// preference. Used for non-user-initiated switches (wake recovery,
    /// preferred-camera reconnect) so a transient fallback never overwrites
    /// the user's actual choice.
    private func rebuildInput(for device: AVCaptureDevice) async throws {
        guard let session = captureSession else { return }

        let wasRunning = session.isRunning
        if wasRunning {
            stopSession()
            // Wait a bit for session to stop
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        session.beginConfiguration()

        // Remove old input
        if let oldInput = videoInput {
            session.removeInput(oldInput)
        }

        // Add new input
        let newInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(newInput) else {
            // Try to restore old input
            if let oldInput = videoInput, session.canAddInput(oldInput) {
                session.addInput(oldInput)
            }
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(newInput)

        session.commitConfiguration()

        // Update references
        self.videoDevice = device
        self.videoInput = newInput

        if wasRunning {
            startSession()
        }
    }
}
