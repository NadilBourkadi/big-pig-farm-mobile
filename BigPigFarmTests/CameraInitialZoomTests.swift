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
        // Camera is centered on rect.midX/Y. No post-clamp is applied inside
        // applyFitToScreenZoom; the midpoint of a full-grid content rect is always
        // within the valid scroll range so no correction is needed.
        // See applyFitToScreenZoomPositionIsClampStable for the regression test.
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
        // presentScene sets scene.view so clampCameraPosition actually runs.
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
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

    @Test("clampCameraPosition preserves valid off-center position when over-zoomed")
    func clampCameraPositionPreservesOffCenterPositionWhenOverZoomed() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        // presentScene sets scene.view so clampCameraPosition actually runs.
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        // Apply fit zoom first so camera.scale is at the fit level (~2.1x),
        // which makes visibleH >> sceneH (the over-zoomed branch).
        let rect = starterContentRect(state)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: rect)

        let camera = try #require(scene.camera)
        // Place camera at 70% of farmH — inside the soft-clamp range [sceneH-hh, hh].
        // The old code would have hard-snapped this to sceneH/2; the new soft
        // clamp must leave any already-valid off-center position untouched.
        let farmH = CGFloat(state.farm.height) * SceneConstants.cellSize
        let offCenter = farmH * 0.7
        camera.position.y = offCenter

        scene.cameraController.clampCameraPosition()

        #expect(abs(camera.position.y - offCenter) < 0.001,
                "clampCameraPosition must not move a valid off-center position when over-zoomed")
    }

    @Test("clampCameraPosition allows viewportPadding scroll leeway at fit-zoom")
    func clampCameraPositionAllowsPaddingLeewayAtFitZoom() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        let rect = starterContentRect(state)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: rect)

        let camera = try #require(scene.camera)
        let farmW = CGFloat(state.farm.width) * SceneConstants.cellSize
        let pad = SceneConstants.viewportPadding

        // At fit-zoom hw ≈ farmW/2. The padded left boundary is farmW/2 - pad.
        // The camera must be allowed to reach that boundary without being clamped.
        let leftBoundary = farmW / 2 - pad
        camera.position.x = leftBoundary
        scene.cameraController.clampCameraPosition()
        #expect(abs(camera.position.x - leftBoundary) < 0.5,
                "Camera must reach the viewportPadding left boundary at fit-zoom")

        // One unit beyond the padded boundary must be clamped back.
        camera.position.x = leftBoundary - 1.0
        scene.cameraController.clampCameraPosition()
        #expect(camera.position.x > leftBoundary - 1.0,
                "Camera must not go past the viewportPadding boundary")
    }

    @Test("isZoomedInForPigTracking returns false at fit-zoom despite FP rounding")
    func isZoomedInForPigTrackingFalseAtFitZoom() {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        // Use presentScene so scene.view is set — isZoomedInForPigTracking reads scene.view.
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        scene.cameraController.applyFitToScreenZoom(for: view, contentRect: starterContentRect(state))
        // At fit-zoom the whole farm is visible — tracking should be suppressed
        // regardless of any floating-point rounding in the geometry chain.
        #expect(!scene.cameraController.isZoomedInForPigTracking,
                "isZoomedInForPigTracking must be false at fit-zoom so pig selection cannot fight panning")
    }

    @Test("isZoomedInForPigTracking returns true when zoomed in past fit level")
    func isZoomedInForPigTrackingTrueWhenZoomedIn() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        // Use presentScene so scene.view is set — isZoomedInForPigTracking reads scene.view.
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        let fitScale = scene.cameraController.fitCameraScale(for: view)
        // Zoom in to half the fit scale — farm is definitely clipped
        let camera = try #require(scene.camera)
        camera.setScale(fitScale * 0.5)
        #expect(scene.cameraController.isZoomedInForPigTracking,
                "isZoomedInForPigTracking must be true when camera is zoomed in past fit level")
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
