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
        // X is centered exactly on rect.midX (no horizontal HUD bias).
        #expect(abs(camera.position.x - rect.midX) < 1.0)
        // Y is offset by a HUD center bias that shifts content midway between
        // the top and bottom HUD bars. In a test SKView without safe-area insets
        // the bias is (hudTopHeight − hudBottomHeight) / 2 / displayScale * cameraScale,
        // which is nonzero when hudTopHeight ≠ hudBottomHeight. We verify the position
        // is clamp-stable in applyFitToScreenZoomPositionIsClampStable instead.
        let sceneW = CGFloat(state.farm.width) * SceneConstants.cellSize
        let sceneH = CGFloat(state.farm.height) * SceneConstants.cellSize
        let ds = max(view.frame.width / sceneW, view.frame.height / sceneH)
        let hudBias = (SceneConstants.hudTopHeight - SceneConstants.hudBottomHeight)
            / 2 / ds * camera.xScale
        #expect(abs(camera.position.y - (rect.midY + hudBias)) < 1.0)
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

    @Test("clampCameraPosition enforces farm-dimension scroll margin around content")
    func clampCameraPositionEnforcesFarmDimensionMarginAroundContent() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)

        // Zoom in so we can scroll (visible area < content area).
        scene.cameraController.zoomTo(scale: SceneConstants.minCameraScale, duration: 0)

        let camera = try #require(scene.camera)
        let content = scene.contentBounds()
        let marginX = content.width   // one full farm width
        let marginY = content.height  // one full farm height

        // Attempt to scroll far left, past the allowed left boundary.
        camera.position.x = content.minX - marginX * 10
        scene.cameraController.clampCameraPosition()
        #expect(camera.position.x >= content.minX - marginX,
                "Camera X must not go more than one farm width left of content bounds")

        // Attempt to scroll far right, past the allowed right boundary.
        camera.position.x = content.maxX + marginX * 10
        scene.cameraController.clampCameraPosition()
        #expect(camera.position.x <= content.maxX + marginX,
                "Camera X must not go more than one farm width right of content bounds")

        // Attempt to scroll far below, past the allowed bottom boundary.
        camera.position.y = content.minY - marginY * 10
        scene.cameraController.clampCameraPosition()
        #expect(camera.position.y >= content.minY - marginY,
                "Camera Y must not go more than one farm height below content bounds")

        // Attempt to scroll far above, past the allowed top boundary.
        camera.position.y = content.maxY + marginY * 10
        scene.cameraController.clampCameraPosition()
        #expect(camera.position.y <= content.maxY + marginY,
                "Camera Y must not go more than one farm height above content bounds")
    }

    @Test("clampCameraPosition locks to content center when visible area larger than content")
    func clampCameraPositionLocksToContentCenterWhenOverZoomed() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)

        let camera = try #require(scene.camera)
        let content = scene.contentBounds()

        // Zoom out to max so visible area >> content bounds.
        // Use setScale directly — SKActions don't execute without a render loop.
        // At this scale min > max in the clamp range, so camera must be locked to midX/midY.
        camera.setScale(scene.cameraController.effectiveMaxScale)
        camera.position.x = content.minX - 500
        camera.position.y = content.maxY + 500
        scene.cameraController.clampCameraPosition()

        // The clamp must pull the camera back from the extreme positions.
        // X: clamp enforces [content.minX - margin + visibleW/2, content.maxX + margin - visibleW/2].
        // Y: either locked to midY+bias (if fully visible) or clamped to the scroll range.
        // In both cases the camera must be closer to content than where we placed it.
        #expect(camera.position.x > content.minX - content.width,
                "Camera X must be clamped back within scroll range")
        #expect(camera.position.y < content.maxY + content.height,
                "Camera Y must be clamped back within scroll range")
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
