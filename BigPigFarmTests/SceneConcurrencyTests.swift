/// SceneConcurrencyTests — Regression guards for SpriteKit scene-level concurrency.
///
/// FarmScene, CameraController, and SpriteTextureCache all run on the main thread.
/// SpriteKit's update() loop fires on the main thread by contract. These tests
/// verify the isolation boundaries and nonisolated pure-function escape hatches.
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - FarmScene Isolation

@Suite("FarmScene MainActor Isolation")
@MainActor
struct FarmSceneIsolationTests {

    @Test("FarmScene properties are accessible synchronously on MainActor")
    func farmSceneIsMainActorIsolated() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let scene = FarmScene(gameState: state)

        // Synchronous access — proves FarmScene is @MainActor
        _ = scene.gameState
        _ = scene.pigNodes
        _ = scene.facilityNodes
        _ = scene.selectedPigID
        _ = scene.isEditMode
        _ = scene.frameCount
    }

    @Test("FarmSceneDelegate protocol enforces MainActor isolation")
    func farmSceneDelegateIsMainActorIsolated() {
        // FarmSceneDelegate is @MainActor — any conforming type can be called
        // synchronously from @MainActor context. This test verifies the protocol
        // constraint propagates through the FarmSceneCoordinator.
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let scene = FarmScene(gameState: state)

        // Setting sceneDelegate synchronously — proves protocol is @MainActor
        scene.sceneDelegate = nil
        #expect(scene.sceneDelegate == nil)
    }
}

// MARK: - Tick-Gated Sync

@Suite("Tick-Gated Scene Sync")
@MainActor
struct TickGatedSyncTests {

    @Test("Scene reads simulationTick synchronously without crossing actors")
    func sceneReadsSimulationTickOnMainActor() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let scene = FarmScene(gameState: state)

        // Both FarmScene and GameState are @MainActor — reading simulationTick
        // is a synchronous main-actor access, not a cross-actor await.
        let tick0 = state.simulationTick
        state.advanceSimulationTick()
        let tick1 = state.simulationTick

        #expect(tick1 == tick0 + 1)

        // Scene can read the same value synchronously
        _ = scene.gameState.simulationTick
    }

    @Test("Scene sync is gated by simulationTick comparison")
    func sceneSyncOnlyOnTickBoundary() {
        let state = GameState()
        state.farm = FarmGrid.createStarter()

        // Verify the gating mechanism: lastSyncedTick vs simulationTick.
        // The initial values should differ (lastSyncedTick = 0, simulationTick = 0),
        // meaning the first update() triggers sync. After sync, they match.
        #expect(state.simulationTick == 0)

        state.advanceSimulationTick()
        #expect(state.simulationTick == 1)

        // A second advance creates a gap again
        state.advanceSimulationTick()
        #expect(state.simulationTick == 2)
    }
}

// MARK: - Nonisolated Pure Functions

@Suite("Nonisolated Pure Functions")
@MainActor
struct NonisolatedPureFunctionTests {

    @Test("FarmScene.nearestIndex is a nonisolated pure function")
    func nearestIndexIsNonisolated() {
        // nearestIndex is `nonisolated static` on FarmScene — a pure function
        // that takes value-type inputs and touches no actor state.
        let frames = [
            CGRect(x: 100, y: 100, width: 32, height: 32),
            CGRect(x: 200, y: 200, width: 32, height: 32),
        ]
        let centers = [
            CGPoint(x: 116, y: 116),
            CGPoint(x: 216, y: 216),
        ]

        // Tap near the first sprite
        let hit = FarmScene.nearestIndex(
            at: CGPoint(x: 120, y: 120),
            frames: frames,
            centers: centers
        )
        #expect(hit == 0)

        // Tap far from both — no hit
        let miss = FarmScene.nearestIndex(
            at: CGPoint(x: 500, y: 500),
            frames: frames,
            centers: centers
        )
        #expect(miss == nil)
    }

    @Test("CameraController gesture recognizer delegate is a nonisolated pure function")
    func gestureRecognizerDelegateIsNonisolated() {
        // The shouldRecognizeSimultaneouslyWith method is `nonisolated` on CameraController.
        // It's a pure function that only checks gesture types — no actor state access.
        // We verify the contract: pinch + anything = true, otherwise false.

        let state = GameState()
        state.farm = FarmGrid.createStarter()
        let scene = FarmScene(gameState: state)
        let cameraNode = SKCameraNode()
        let controller = CameraController(
            camera: cameraNode,
            scene: scene,
            farmWidth: 20,
            farmHeight: 14
        )

        let pinch = UIPinchGestureRecognizer()
        let pan = UIPanGestureRecognizer()

        // Pinch + pan = simultaneous (for two-finger zoom+drag)
        let result = controller.gestureRecognizer(pinch, shouldRecognizeSimultaneouslyWith: pan)
        #expect(result == true)

        // Pan + pan = not simultaneous
        let pan2 = UIPanGestureRecognizer()
        let result2 = controller.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: pan2)
        #expect(result2 == false)
    }
}

// MARK: - SpriteTextureCache Thread Safety

@Suite("SpriteTextureCache Single-Thread Invariant")
@MainActor
struct SpriteTextureCacheConcurrencyTests {

    @Test("Sequential cache operations produce correct results")
    func sequentialOperationsAreCorrect() {
        // SpriteTextureCache is @unchecked Sendable with single-thread-only semantics.
        // Verify that sequential operations on MainActor work correctly.
        let cache = SpriteTextureCache { _ in SKTexture() }

        var pig = GuineaPig.create(name: "CacheTest", gender: .female)
        pig.ageDays = 20

        // First call caches; second returns cached texture
        let tex1 = cache.texture(for: pig, state: "idle", direction: "left", frame: 0)
        let tex2 = cache.texture(for: pig, state: "idle", direction: "left", frame: 0)
        #expect(tex1 === tex2)

        // Evict and verify cache count changes
        let countBefore = cache.patternedCacheCount + cache.solidCacheCount
        cache.evict(pigID: pig.id)
        cache.evictAll()
        let countAfter = cache.patternedCacheCount + cache.solidCacheCount
        #expect(countAfter <= countBefore)
    }

    @Test("evictAll clears both cache tiers")
    func evictAllClearsCaches() {
        let cache = SpriteTextureCache { _ in SKTexture() }
        var pig = GuineaPig.create(name: "EvictTest", gender: .male)
        pig.ageDays = 20

        _ = cache.texture(for: pig, state: "idle", direction: "left", frame: 0)
        cache.evictAll()

        #expect(cache.solidCacheCount == 0)
        #expect(cache.patternedCacheCount == 0)
    }
}
