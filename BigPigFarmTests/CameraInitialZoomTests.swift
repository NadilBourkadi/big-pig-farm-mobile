/// CameraInitialZoomTests — Tests for deferred camera fit-to-screen zoom on launch.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("Camera Initial Zoom")
@MainActor
struct CameraInitialZoomTests {

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

    @Test("applyFitToScreenZoom centers camera on farm")
    func applyFitToScreenZoomCentersCamera() throws {
        let state = GameState()
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        scene.cameraController.applyFitToScreenZoom(for: view)

        let expectedX = CGFloat(state.farm.width) * SceneConstants.cellSize / 2
        let expectedY = CGFloat(state.farm.height) * SceneConstants.cellSize / 2
        let camera = try #require(scene.camera)
        #expect(abs(camera.position.x - expectedX) < 1.0)
        #expect(abs(camera.position.y - expectedY) < 1.0)
    }

    @Test("applyFitToScreenZoom is no-op for zero-frame view")
    func applyFitToScreenZoomSkipsZeroFrame() throws {
        let scene = FarmScene(gameState: GameState())
        let view = SKView(frame: .zero)
        scene.didMove(to: view)
        let camera = try #require(scene.camera)
        let scaleBefore = camera.xScale
        scene.cameraController.applyFitToScreenZoom(for: view)
        #expect(camera.xScale == scaleBefore)
    }

    @Test("Camera scale stays within min/max bounds after fit zoom")
    func fitZoomRespectsScaleBounds() throws {
        let scene = FarmScene(gameState: GameState())
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scene.didMove(to: view)
        scene.cameraController.applyFitToScreenZoom(for: view)

        let camera = try #require(scene.camera)
        #expect(camera.xScale >= SceneConstants.minCameraScale)
        #expect(camera.xScale <= SceneConstants.maxCameraScale)
    }
}
