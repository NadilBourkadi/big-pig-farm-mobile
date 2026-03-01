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
        guard let scene = scene else { return }
        let sceneW = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneH = CGFloat(farmHeight) * SceneConstants.cellSize
        let viewW = scene.view?.frame.width ?? sceneW
        let viewH = scene.view?.frame.height ?? sceneH

        let halfViewW = (viewW / 2) * camera.xScale
        let halfViewH = (viewH / 2) * camera.yScale

        let minX = halfViewW
        let maxX = max(halfViewW, sceneW - halfViewW)
        let minY = halfViewH
        let maxY = max(halfViewH, sceneH - halfViewH)

        camera.position = CGPoint(
            x: max(minX, min(maxX, camera.position.x)),
            y: max(minY, min(maxY, camera.position.y))
        )
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

    /// Allow pinch and pan to recognize simultaneously (two-finger zoom + drag).
    /// Tap is exclusive — it only fires after pan fails.
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
        guard let scene = scene else { return }
        let translation = gesture.translation(in: gesture.view)
        camera.position.x -= translation.x * camera.xScale
        camera.position.y += translation.y * camera.yScale
        clampCameraPosition()
        gesture.setTranslation(.zero, in: gesture.view)
        _ = scene  // suppress unused warning
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
