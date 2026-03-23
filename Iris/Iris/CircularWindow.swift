import Cocoa
import AVFoundation

class CircularWindow: NSWindow {

    private let circularView: ResizableCircularView
    private var cameraManager: CameraManager

    // Menu provider for right-click context menu
    var menuProvider: (() -> NSMenu?)?

    init(cameraManager: CameraManager, size: CGFloat = 200) {
        self.cameraManager = cameraManager

        let savedPosition = PreferencesManager.shared.windowPosition
        let screenRect = NSScreen.main?.visibleFrame ?? .zero

        let origin: CGPoint
        if savedPosition.x > 0 && savedPosition.y > 0 {
            let savedRect = CGRect(origin: savedPosition, size: CGSize(width: size, height: size))
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(savedRect) }) {
                origin = savedPosition
            } else {
                origin = CGPoint(x: screenRect.midX - size / 2, y: screenRect.midY - size / 2)
            }
        } else {
            origin = CGPoint(x: screenRect.midX - size / 2, y: screenRect.midY - size / 2)
        }

        let rect = CGRect(origin: origin, size: CGSize(width: size, height: size))
        self.circularView = ResizableCircularView(frame: NSRect(origin: .zero, size: rect.size))

        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        setupVideoPreview()
    }

    private func configureWindow() {
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        // NOT using isMovableByWindowBackground - we'll handle dragging manually
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        self.contentView = circularView

        // Set up right-click menu provider
        circularView.menuProvider = { [weak self] in
            self?.menuProvider?()
        }
    }

    private func setupVideoPreview() {
        guard let previewLayer = cameraManager.previewLayer else { return }
        circularView.setPreviewLayer(previewLayer)
    }

    func show() {
        self.orderFrontRegardless()
        cameraManager.startSession()

        // Apply mirror setting
        circularView.setMirrored(PreferencesManager.shared.mirrorView)
    }

    func hide() {
        self.orderOut(nil)
        cameraManager.stopSession()
    }

    func setMirrored(_ mirrored: Bool) {
        circularView.setMirrored(mirrored)
    }
}

// MARK: - ResizableCircularView

class ResizableCircularView: CircularContentView {

    // MARK: - Interaction Mode
    private enum InteractionMode {
        case none
        case dragging
        case resizing
    }

    private var mode: InteractionMode = .none

    // MARK: - Drag State
    private var dragStartMouseLocation: CGPoint = .zero
    private var dragStartWindowOrigin: CGPoint = .zero

    // MARK: - Resize State
    private var anchorCorner: CGPoint = .zero
    private var resizeQuadrant: Quadrant = .bottomRight

    // MARK: - Hover State
    private var isHoveringEdge = false
    private var isHoveringInside = false
    private var cursorPushed = false

    // MARK: - Constants
    private let edgeThreshold: CGFloat = 18
    private let minSize: CGFloat = 100
    
    private var maxSize: CGFloat {
        // Allow up to the smaller dimension of the current screen
        guard let screen = window?.screen ?? NSScreen.main else { return 800 }
        return min(screen.visibleFrame.width, screen.visibleFrame.height)
    }

    private var edgeHighlightLayer: CAShapeLayer?

    // MARK: - Context Menu
    var menuProvider: (() -> NSMenu?)?

    enum Quadrant {
        case topRight, topLeft, bottomRight, bottomLeft
    }

    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupEdgeHighlight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupEdgeHighlight() {
        edgeHighlightLayer = CAShapeLayer()
        edgeHighlightLayer?.fillColor = nil
        edgeHighlightLayer?.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
        edgeHighlightLayer?.lineWidth = 2
        edgeHighlightLayer?.opacity = 0
        layer?.addSublayer(edgeHighlightLayer!)
    }

    // MARK: - Tracking
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateEdgeHighlightPath()
        CATransaction.commit()
    }

    private func updateEdgeHighlightPath() {
        let diameter = min(bounds.width, bounds.height)
        let inset: CGFloat = 1
        let rect = CGRect(
            x: (bounds.width - diameter) / 2 + inset,
            y: (bounds.height - diameter) / 2 + inset,
            width: diameter - inset * 2,
            height: diameter - inset * 2
        )
        edgeHighlightLayer?.path = CGPath(ellipseIn: rect, transform: nil)
        edgeHighlightLayer?.frame = bounds
    }

    // MARK: - Hit Testing
    private func isPointNearEdge(_ localPoint: CGPoint) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        let dx = localPoint.x - center.x
        let dy = localPoint.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance >= (radius - edgeThreshold) && distance <= radius
    }

    private func isPointInsideCircle(_ localPoint: CGPoint) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        let dx = localPoint.x - center.x
        let dy = localPoint.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < (radius - edgeThreshold)
    }

    private func quadrant(for localPoint: CGPoint) -> Quadrant {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let isRight = localPoint.x >= center.x
        let isTop = localPoint.y >= center.y

        if isTop && isRight { return .topRight }
        if isTop && !isRight { return .topLeft }
        if !isTop && isRight { return .bottomRight }
        return .bottomLeft
    }

    // MARK: - Mouse Events
    override func mouseMoved(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let nearEdge = isPointNearEdge(localPoint)
        let insideCircle = isPointInsideCircle(localPoint)

        let changed = (nearEdge != isHoveringEdge) || (insideCircle != isHoveringInside)

        isHoveringEdge = nearEdge
        isHoveringInside = insideCircle

        if changed {
            updateCursor()
            updateEdgeHighlight()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if isHoveringEdge || isHoveringInside {
            isHoveringEdge = false
            isHoveringInside = false
            updateCursor()
            updateEdgeHighlight()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // Show context menu on right-click
        if let menu = menuProvider?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        guard let window = window else { return }

        if isPointNearEdge(localPoint) {
            // Start RESIZE
            mode = .resizing
            resizeQuadrant = quadrant(for: localPoint)

            // Anchor the opposite corner
            let windowFrame = window.frame
            switch resizeQuadrant {
            case .topRight:
                anchorCorner = CGPoint(x: windowFrame.minX, y: windowFrame.minY)
            case .topLeft:
                anchorCorner = CGPoint(x: windowFrame.maxX, y: windowFrame.minY)
            case .bottomRight:
                anchorCorner = CGPoint(x: windowFrame.minX, y: windowFrame.maxY)
            case .bottomLeft:
                anchorCorner = CGPoint(x: windowFrame.maxX, y: windowFrame.maxY)
            }
        } else if isPointInsideCircle(localPoint) {
            // Start DRAG
            mode = .dragging
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = window.frame.origin
        }

        updateCursor()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }

        switch mode {
        case .none:
            break

        case .dragging:
            // Simple drag: new position = start position + mouse delta
            let currentMouse = NSEvent.mouseLocation
            let deltaX = currentMouse.x - dragStartMouseLocation.x
            let deltaY = currentMouse.y - dragStartMouseLocation.y

            let newOrigin = CGPoint(
                x: dragStartWindowOrigin.x + deltaX,
                y: dragStartWindowOrigin.y + deltaY
            )

            window.setFrameOrigin(newOrigin)

        case .resizing:
            let currentMouse = NSEvent.mouseLocation

            // Calculate size based on distance from anchor to mouse
            let dx = abs(currentMouse.x - anchorCorner.x)
            let dy = abs(currentMouse.y - anchorCorner.y)
            var newSize = max(dx, dy)

            // Clamp size
            newSize = max(minSize, min(maxSize, newSize))

            // Calculate origin based on anchor position
            var newOrigin: CGPoint
            switch resizeQuadrant {
            case .topRight:
                newOrigin = anchorCorner
            case .topLeft:
                newOrigin = CGPoint(x: anchorCorner.x - newSize, y: anchorCorner.y)
            case .bottomRight:
                newOrigin = CGPoint(x: anchorCorner.x, y: anchorCorner.y - newSize)
            case .bottomLeft:
                newOrigin = CGPoint(x: anchorCorner.x - newSize, y: anchorCorner.y - newSize)
            }

            let newFrame = NSRect(origin: newOrigin, size: NSSize(width: newSize, height: newSize))

            // Set frame without any animation
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            window.setFrame(newFrame, display: false, animate: false)
            CATransaction.commit()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .resizing || mode == .dragging {
            if let window = window {
                PreferencesManager.shared.windowSize = window.frame.width
                PreferencesManager.shared.windowPosition = window.frame.origin
            }
        }

        mode = .none

        // Update hover state after releasing
        let localPoint = convert(event.locationInWindow, from: nil)
        isHoveringEdge = isPointNearEdge(localPoint)
        isHoveringInside = isPointInsideCircle(localPoint)
        updateCursor()
    }

    // MARK: - Cursor & Visual
    private func updateCursor() {
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }

        if mode == .resizing || isHoveringEdge {
            // Horizontal double arrow for resize
            NSCursor.resizeLeftRight.push()
            cursorPushed = true
        } else if mode == .dragging {
            // Closed hand while dragging
            NSCursor.closedHand.push()
            cursorPushed = true
        } else if isHoveringInside {
            // Open hand for drag area
            NSCursor.openHand.push()
            cursorPushed = true
        }
    }

    private func updateEdgeHighlight() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        edgeHighlightLayer?.opacity = isHoveringEdge ? 1.0 : 0.0
        CATransaction.commit()
    }

    deinit {
        if cursorPushed { NSCursor.pop() }
    }
}
