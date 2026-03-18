/// CameraController — Pan and zoom camera logic for the farm scene.
/// Maps from: new SpriteKit rendering layer
import SpriteKit

/// Manages camera pan, zoom, and bounds clamping for the farm scene.
/// Inherits NSObject to support @objc gesture handler selectors.
@MainActor
class CameraController: NSObject, UIGestureRecognizerDelegate {
    private let camera: SKCameraNode
    private weak var scene: FarmScene?
    private var farmWidth: Int
    private var farmHeight: Int
    private var pinchStartScale: CGFloat = 1.0

    /// The facility currently being dragged, or nil for normal camera panning.
    private var draggedFacilityID: UUID?

    var currentScale: CGFloat { camera.xScale }

    /// The effective maximum zoom-out scale: whichever is larger of the fixed
    /// constant and the scale needed to fit the entire farm on screen.
    /// This lets the user zoom out to see the whole farm even when it exceeds
    /// the default max.
    var effectiveMaxScale: CGFloat {
        guard let scene = scene, let view = scene.view,
              view.frame.width > 0, view.frame.height > 0 else {
            return SceneConstants.maxCameraScale
        }
        return max(SceneConstants.maxCameraScale, fitCameraScale(for: view))
    }

    init(camera: SKCameraNode, scene: FarmScene, farmWidth: Int, farmHeight: Int) {
        self.camera = camera
        self.scene = scene
        self.farmWidth = farmWidth
        self.farmHeight = farmHeight
        super.init()
    }

    func setupGestureRecognizers(in view: SKView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        // pan.delegate = self so gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)
        // fires when pan and pinch are both active, enabling two-finger zoom+drag.
        pan.delegate = self

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: pan)

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
    }

    func follow(_ position: CGPoint) {
        camera.position = position
        clampCameraPosition()
    }

    func updateFarmDimensions(width: Int, height: Int) {
        farmWidth = width
        farmHeight = height
    }

    /// True when the camera is zoomed in past the fit level, meaning a pig could
    /// be off-screen and tracking is meaningful. At fit-zoom every pig is visible,
    /// so tracking would fight against manual panning.
    ///
    /// Compared directly against `fitCameraScale` (with a small epsilon) rather than
    /// deriving visible geometry: the multi-step FP chain `(viewW / ds) * scale` can
    /// evaluate to sceneW − ε even when scale == fitScale, producing a false positive.
    var isZoomedInForPigTracking: Bool {
        guard let scene = scene, let view = scene.view else { return false }
        // Larger camera scale = more zoomed out (more scene visible).
        // Tracking is needed only when scale < fit (some of the farm is off-screen).
        // The 0.01 epsilon absorbs floating-point rounding between camera.xScale and
        // the freshly-computed fitCameraScale so that fit-zoom reads as "not zoomed in".
        return camera.xScale < fitCameraScale(for: view) - 0.01
    }

    func clampCameraPosition() {
        guard let scene = scene, let view = scene.view else { return }
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize

        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let visibleW = (view.frame.width / ds) * camera.xScale

        // Clamp against farm content bounds (not full grid) with a margin equal to
        // one full farm dimension, so the user can scroll an entire farm-width/-height
        // past the content edge before hitting the limit.
        let content = scene.contentBounds()
        let marginX = content.width
        let marginY = content.height

        // X: no HUD on the sides — use full visible width.
        let minCamX = content.minX - marginX + visibleW / 2
        let maxCamX = content.maxX + marginX - visibleW / 2
        if minCamX > maxCamX {
            camera.position.x = content.midX
        } else {
            camera.position.x = max(minCamX, min(maxCamX, camera.position.x))
        }

        // Y: HUD bars at top and bottom reduce the unobstructed viewport height.
        // Compute scene-unit distances from the view centre to each unobstructed edge
        // so the farm content scrolls flush with the HUD bars, not the screen edges.
        let safeTop = view.safeAreaInsets.top + SceneConstants.hudTopHeight
        let safeBottom = view.safeAreaInsets.bottom + SceneConstants.hudBottomHeight
        let halfHeightTop = max(0, view.frame.height / 2 - safeTop) / ds * camera.yScale
        let halfHeightBottom = max(0, view.frame.height / 2 - safeBottom) / ds * camera.yScale

        let minCamY = content.minY - marginY + halfHeightBottom
        let maxCamY = content.maxY + marginY - halfHeightTop
        if minCamY > maxCamY {
            // Content fits in unobstructed viewport: bias camera so content centres
            // between the two HUD bars, not between the screen edges.
            let centerBias = (safeTop - safeBottom) / 2 / ds * camera.yScale
            camera.position.y = content.midY + centerBias
        } else {
            camera.position.y = max(minCamY, min(maxCamY, camera.position.y))
        }
    }

    /// Returns the scale factor SpriteKit uses to map scene pts to view pts under aspectFill.
    private func displayScale(sceneW: CGFloat, sceneH: CGFloat, view: SKView) -> CGFloat {
        max(view.frame.width / sceneW, view.frame.height / sceneH)
    }

    /// Returns the camera scale needed to fit the entire farm on screen.
    func fitCameraScale(for view: SKView) -> CGFloat {
        guard view.frame.width > 0, view.frame.height > 0 else {
            return SceneConstants.defaultCameraScale
        }
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize
        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let visibleW = view.frame.width / ds   // scene units visible at camera scale 1.0
        let visibleH = view.frame.height / ds
        return max(sceneW / visibleW, sceneH / visibleH)
    }

    /// Zoom and center the camera so that `contentRect` (in scene points)
    /// is fully visible, capped at the fixed max zoom-out.
    ///
    /// - Precondition: `contentRect` must lie within the farm grid bounds.
    ///   The camera position is set to `contentRect.midX/midY` without a
    ///   subsequent clamp — callers must ensure the midpoint is in-range.
    func applyFitToScreenZoom(for view: SKView, contentRect: CGRect) {
        guard view.frame.width > 0, view.frame.height > 0 else { return }

        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize
        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let visibleAtScale1W = view.frame.width / ds
        let visibleAtScale1H = view.frame.height / ds

        // Scale needed to fit the content rect (not the whole grid).
        let contentFitScale = max(
            contentRect.width / visibleAtScale1W,
            contentRect.height / visibleAtScale1H
        )
        let clamped = max(SceneConstants.minCameraScale,
                          min(SceneConstants.maxCameraScale, contentFitScale))
        camera.setScale(clamped)

        // Apply the same HUD bias as clampCameraPosition so the initial position
        // is clamp-stable: content appears centred between the two HUD bars.
        let safeTop = view.safeAreaInsets.top + SceneConstants.hudTopHeight
        let safeBottom = view.safeAreaInsets.bottom + SceneConstants.hudBottomHeight
        let centerBias = (safeTop - safeBottom) / 2 / ds * clamped
        camera.position = CGPoint(x: contentRect.midX, y: contentRect.midY + centerBias)
    }

    func zoomTo(scale: CGFloat, duration: TimeInterval) {
        let clamped = max(SceneConstants.minCameraScale, min(effectiveMaxScale, scale))
        let action = SKAction.scale(to: clamped, duration: duration)
        camera.run(action) { [weak self] in
            self?.clampCameraPosition()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let scene = scene, let view = scene.view else { return }
        let viewPoint = gesture.location(in: view)
        let scenePoint = scene.convertPoint(fromView: viewPoint)
        scene.handleTap(at: scenePoint)
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allow pinch and pan to recognize simultaneously — standard iOS "zoom while dragging" UX.
    /// Tap exclusivity is enforced by tap.require(toFail: pan) in setupGestureRecognizers,
    /// not by this delegate, so we never return true for tap here.
    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer
            || otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let scene = scene, let view = scene.view else { return }

        // In edit mode, check if pan starts on a facility → enter drag mode.
        if gesture.state == .began, scene.isEditMode {
            let viewPoint = gesture.location(in: view)
            let scenePoint = scene.convertPoint(fromView: viewPoint)
            if let facilityID = scene.facilityIDAtPoint(scenePoint) {
                draggedFacilityID = facilityID
                scene.beginDraggingFacility(facilityID)
            }
        }

        // Route drag to facility movement.
        if draggedFacilityID != nil {
            let viewPoint = gesture.location(in: view)
            let scenePoint = scene.convertPoint(fromView: viewPoint)
            scene.moveSelectedFacility(to: scenePoint)
            if gesture.state == .ended || gesture.state == .cancelled {
                scene.confirmFacilityPlacement()
                draggedFacilityID = nil
            }
            return
        }

        // Normal camera pan.
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize
        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let translation = gesture.translation(in: gesture.view)
        camera.position.x -= translation.x * camera.xScale / ds
        camera.position.y += translation.y * camera.yScale / ds
        clampCameraPosition()
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            pinchStartScale = camera.xScale
        }
        let newScale = pinchStartScale / gesture.scale
        let clamped = max(SceneConstants.minCameraScale, min(effectiveMaxScale, newScale))
        camera.setScale(clamped)
        clampCameraPosition()
    }
}
