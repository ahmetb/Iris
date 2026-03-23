import Cocoa
import AVFoundation

class CircularContentView: NSView {
    // MARK: - Properties
    private var maskLayer: CAShapeLayer?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layer Configuration
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = self.layer else { return }

        // Background color (visible inside circle)
        layer.backgroundColor = NSColor.black.cgColor

        // Update mask without animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateMask()
        CATransaction.commit()
    }

    override func layout() {
        super.layout()

        // Disable animations during layout
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Update preview layer frame
        if let previewLayer = previewLayer {
            previewLayer.frame = bounds
        }

        // Update circular mask
        updateMask()

        CATransaction.commit()
    }

    func updateMask() {
        guard let layer = self.layer else { return }

        // Create circular mask
        let diameter = min(bounds.width, bounds.height)
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        // Reuse existing mask layer or create new one
        if maskLayer == nil {
            maskLayer = CAShapeLayer()
        }

        maskLayer?.path = CGPath(ellipseIn: rect, transform: nil)
        layer.mask = maskLayer

        // Update shadow to circular shape
        layer.shadowPath = maskLayer?.path
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: -5)
    }

    // MARK: - Preview Layer Management
    func setPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        // Remove old preview layer if exists
        self.previewLayer?.removeFromSuperlayer()

        // Disable implicit animations on preview layer
        previewLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "transform": NSNull()
        ]

        // Configure and add new preview layer
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill

        if let layer = self.layer {
            layer.insertSublayer(previewLayer, at: 0)
        }

        self.previewLayer = previewLayer
    }

    // MARK: - Mirror View
    func setMirrored(_ mirrored: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if mirrored {
            // Flip horizontally (like looking in a mirror)
            previewLayer?.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            // Normal view (how others see you)
            previewLayer?.transform = CATransform3DIdentity
        }

        CATransaction.commit()
    }
}
