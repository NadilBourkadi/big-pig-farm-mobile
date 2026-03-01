/// ScenePerformanceTests — SpriteKit scene sync benchmarks with 50–100 pigs.
///
/// Measures `FarmScene.syncPigs()` cost (PigNode creation and per-frame update)
/// without needing a running app. The scene is created directly without calling
/// `didMove(to:)`, so `farmHeight = 0` — pig scene-coordinates are wrong but
/// the timing measurement is valid.
///
/// `PigNode` creation calls `SpriteAssets.pigTexture(...)`. The test target
/// uses the app as TEST_HOST, so the asset catalog is available; textures load
/// normally. Timing includes texture lookup cost, which is realistic.
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - Scene Sync Performance

@Suite("Scene Sync Performance")
@MainActor
struct ScenePerformanceTests {

    // MARK: - syncPigs Creation Cost

    @Test("syncPigs with 50 pigs: logs PigNode creation cost on first call")
    func syncPigsCreation50() {
        let (state, _) = makeLargeIntegrationState(pigCount: 50)
        let scene = FarmScene(gameState: state)

        let clock = ContinuousClock()
        let elapsed = clock.measure { scene.syncPigs() }

        print("[Perf] syncPigs creation (50 pigs): \(sceneFormat(elapsed.milliseconds))ms")
        let ms50 = sceneFormat(elapsed.milliseconds)
        #expect(elapsed.milliseconds < 10_000, "Creating 50 PigNodes took \(ms50)ms (budget: 10s)")
        #expect(scene.pigNodes.count == 50, "Expected 50 PigNodes, got \(scene.pigNodes.count)")
    }

    @Test("syncPigs with 100 pigs: logs PigNode creation cost on first call")
    func syncPigsCreation100() {
        let (state, _) = makeLargeIntegrationState(pigCount: 100)
        let scene = FarmScene(gameState: state)

        let clock = ContinuousClock()
        let elapsed = clock.measure { scene.syncPigs() }

        print("[Perf] syncPigs creation (100 pigs): \(sceneFormat(elapsed.milliseconds))ms")
        let ms100 = sceneFormat(elapsed.milliseconds)
        #expect(elapsed.milliseconds < 20_000, "Creating 100 PigNodes took \(ms100)ms (budget: 20s)")
        #expect(scene.pigNodes.count == 100, "Expected 100 PigNodes, got \(scene.pigNodes.count)")
    }

    // MARK: - syncPigs Update Cost (steady-state)

    @Test("syncPigs with 50 pigs: logs per-frame update cost after nodes are created")
    func syncPigsUpdate50() {
        let (state, _) = makeLargeIntegrationState(pigCount: 50)
        let scene = FarmScene(gameState: state)

        // First call creates all nodes.
        scene.syncPigs()
        #expect(scene.pigNodes.count == 50)

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<30 {
            durations.append(clock.measure { scene.syncPigs() })
        }

        let avgMs = durations.map(\.milliseconds).reduce(0, +) / Double(durations.count)
        let maxMs = durations.map(\.milliseconds).max() ?? 0
        print("[Perf] syncPigs update (50 pigs): avg=\(sceneFormat(avgMs))ms max=\(sceneFormat(maxMs))ms")

        // Regression guard: update pass for 50 pigs under 5 seconds each.
        #expect(avgMs < 5_000, "syncPigs update avg \(sceneFormat(avgMs))ms > 5s for 50 pigs")
    }

    @Test("syncPigs with 100 pigs: logs per-frame update cost after nodes are created")
    func syncPigsUpdate100() {
        let (state, _) = makeLargeIntegrationState(pigCount: 100)
        let scene = FarmScene(gameState: state)

        scene.syncPigs()
        #expect(scene.pigNodes.count == 100)

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<30 {
            durations.append(clock.measure { scene.syncPigs() })
        }

        let avgMs = durations.map(\.milliseconds).reduce(0, +) / Double(durations.count)
        let maxMs = durations.map(\.milliseconds).max() ?? 0
        print("[Perf] syncPigs update (100 pigs): avg=\(sceneFormat(avgMs))ms max=\(sceneFormat(maxMs))ms")

        #expect(avgMs < 10_000, "syncPigs update avg \(sceneFormat(avgMs))ms > 10s for 100 pigs")
    }

    // MARK: - Pig Removal Throughput

    @Test("syncPigs removes stale nodes when pigs are deleted from state")
    func syncPigsDeletion50() {
        let (state, _) = makeLargeIntegrationState(pigCount: 50)
        let scene = FarmScene(gameState: state)

        scene.syncPigs()
        #expect(scene.pigNodes.count == 50)

        // Remove half the pigs from state.
        let idsToRemove = Array(state.guineaPigs.keys.prefix(25))
        for id in idsToRemove { _ = state.removeGuineaPig(id) }
        #expect(state.guineaPigs.count == 25)

        let clock = ContinuousClock()
        let elapsed = clock.measure { scene.syncPigs() }

        print("[Perf] syncPigs deletion (25 of 50 pigs): \(sceneFormat(elapsed.milliseconds))ms")
        #expect(scene.pigNodes.count == 25, "Expected 25 PigNodes after deletion, got \(scene.pigNodes.count)")
    }
}

// MARK: - Private Helpers

private func sceneFormat(_ value: Double) -> String {
    String(format: "%.2f", value)
}
