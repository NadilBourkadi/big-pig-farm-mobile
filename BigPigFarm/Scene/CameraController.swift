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

    /// When true, pan gestures drive facility movement instead of camera panning.
    var isInFacilityMoveMode: Bool = false

    var currentScale: CGFloat { camera.xScale }

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

    func clampCameraPosition() {
        guard let scene = scene, let view = scene.view else { return }
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize

        // SpriteKit's aspectFill applies a display scale so the scene fills the view.
        // Divide view dimensions by this scale to get the visible area in scene units.
        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let visibleW = (view.frame.width / ds) * camera.xScale
        let visibleH = (view.frame.height / ds) * camera.yScale

        if visibleW >= sceneW {
            camera.position.x = sceneW / 2
        } else {
            let hw = visibleW / 2
            camera.position.x = max(hw, min(sceneW - hw, camera.position.x))
        }

        if visibleH >= sceneH {
            camera.position.y = sceneH / 2
        } else {
            let hh = visibleH / 2
            camera.position.y = max(hh, min(sceneH - hh, camera.position.y))
        }
    }

    /// Returns the scale factor SpriteKit uses to map scene pts to view pts under aspectFill.
    private func displayScale(sceneW: CGFloat, sceneH: CGFloat, view: SKView) -> CGFloat {
        max(view.frame.width / sceneW, view.frame.height / sceneH)
    }

    /// Returns the camera scale needed to fit the entire farm on screen.
    func fitCameraScale(for view: SKView) -> CGFloat {
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize
        let ds = displayScale(sceneW: sceneW, sceneH: sceneH, view: view)
        let visibleW = view.frame.width / ds   // scene units visible at camera scale 1.0
        let visibleH = view.frame.height / ds
        return max(sceneW / visibleW, sceneH / visibleH)
    }

    func zoomTo(scale: CGFloat, duration: TimeInterval) {
        let clamped = max(SceneConstants.minCameraScale, min(SceneConstants.maxCameraScale, scale))
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
        if isInFacilityMoveMode {
            let viewPoint = gesture.location(in: view)
            let scenePoint = scene.convertPoint(fromView: viewPoint)
            scene.moveSelectedFacility(to: scenePoint)
            if gesture.state == .ended || gesture.state == .cancelled {
                scene.confirmFacilityPlacement()
                isInFacilityMoveMode = false
            }
            return
        }
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
        let clamped = max(SceneConstants.minCameraScale, min(SceneConstants.maxCameraScale, newScale))
        camera.setScale(clamped)
        clampCameraPosition()
    }
}
