/// CameraInitialZoomTests — Tests for deferred camera fit-to-screen zoom on launch.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("Camera Initial Zoom")
@MainActor
struct CameraInitialZoomTests {

    /// Helper: full-grid content rect for a starter farm.
    private func starterContentRect(_ state: GameState) -> CGRect {
        let width = CGFloat(state.farm.width) * SceneConstants.cellSize
        let height = CGFloat(state.farm.height) * SceneConstants.cellSize
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    @Test("fitCameraScale returns default for zero-frame view")
    func fitCameraScaleReturnsDefaultForZeroFrame() {
        let scene = FarmScene(gameState: GameState())
        let view = SKView(frame: .zero)
        scene.didMove(to: view)
        let scale = scene.cameraController.fitCameraScale(for: view)
        #expect(scale == SceneConstants.defaultCameraScale)
    }

    @Test("fitCameraScale returns positive for valid view dimensions")
    func fitCameraScalePositiveForValidView() {
        let scene = FarmScene(gameState: GameState())
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        let scale = scene.cameraController.fitCameraScale(for: view)
        #expect(scale > 0)
        #expect(scale != SceneConstants.defaultCameraScale,
                "Valid view should compute a real scale, not the zero-frame fallback")
    }

    @Test("applyFitToScreenZoom centers camera on content rect")
    func applyFitToScreenZoomCentersCamera() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        let rect = starterContentRect(state)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: rect)

        let camera = try #require(scene.camera)
        // Camera is centered on rect.midX/Y then clamped to the full-grid scroll range.
        // For a full-grid content rect the midpoint is always in-range, so centering
        // survives the clamp. See applyFitToScreenZoomPositionIsClampStable for the
        // authoritative regression test.
        #expect(abs(camera.position.x - rect.midX) < 1.0)
        #expect(abs(camera.position.y - rect.midY) < 1.0)
    }

    @Test("applyFitToScreenZoom is no-op for zero-frame view")
    func applyFitToScreenZoomSkipsZeroFrame() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: .zero)
        scene.didMove(to: view)
        let camera = try #require(scene.camera)
        let scaleBefore = camera.xScale
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: starterContentRect(state))
        #expect(camera.xScale == scaleBefore)
    }

    @Test("Camera scale stays within min/max bounds after fit zoom")
    func fitZoomRespectsScaleBounds() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: starterContentRect(state))

        let camera = try #require(scene.camera)
        #expect(camera.xScale >= SceneConstants.minCameraScale)
        #expect(camera.xScale <= SceneConstants.maxCameraScale)
    }

    @Test("effectiveMaxScale grows for large farms that exceed the fixed max")
    func effectiveMaxScaleGrowsForLargeFarm() {
        let state = GameState()
        state.farm = FarmGrid(width: 62, height: 37)
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        #expect(scene.cameraController.effectiveMaxScale > SceneConstants.maxCameraScale,
                "Large farm should push effectiveMaxScale beyond the fixed constant")
    }

    @Test("applyFitToScreenZoom leaves camera in a clamp-stable position")
    func applyFitToScreenZoomPositionIsClampStable() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        let rect = starterContentRect(state)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: rect)

        let camera = try #require(scene.camera)
        let positionAfterFit = camera.position

        // A second clamp call must be a no-op: if applyFitToScreenZoom left
        // the camera outside the valid scroll range, this would move it and
        // the assertions below would fail — reproducing the original snap bug.
        scene.cameraController.clampCameraPosition()
        #expect(abs(camera.position.x - positionAfterFit.x) < 0.001)
        #expect(abs(camera.position.y - positionAfterFit.y) < 0.001)
    }

    @Test("contentBounds returns area bounds, not full grid")
    func contentBoundsMatchesAreas() {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        let bounds = scene.contentBounds()
        // Starter farm has one area covering the full grid, so bounds ≈ grid size.
        let gridW = CGFloat(state.farm.width) * SceneConstants.cellSize
        let gridH = CGFloat(state.farm.height) * SceneConstants.cellSize
        #expect(abs(bounds.width - gridW) < 1.0)
        #expect(abs(bounds.height - gridH) < 1.0)
    }
}
