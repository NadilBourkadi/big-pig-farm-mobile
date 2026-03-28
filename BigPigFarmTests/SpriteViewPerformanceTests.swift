/// SpriteViewPerformanceTests — Measures FarmScene rendering performance with a real SKView.
///
/// Unlike ScenePerformanceTests (which measures syncPigs CPU cost in isolation),
/// these tests present the scene to an SKView via `presentScene()`, triggering
/// `didMove(to:)` and the full node hierarchy: terrain, camera, pig layers, shadows,
/// name labels, and SKAction animations. This exercises the actual rendering pipeline
/// that SpriteView wraps in the app.
import Testing
import SpriteKit
@testable import BigPigFarm

@Suite("SpriteView Rendering Performance")
@MainActor
struct SpriteViewPerformanceTests {

    // MARK: - Frame Update Time

    @Test("Presented scene update with 50 animated pigs: avg frame time under budget")
    func presentedFrameUpdate50Pigs() {
        let (view, scene, state) = makePresentedScene(pigCount: 50)
        _ = view // suppress unused-variable warning — view must stay alive to hold the scene

        let durations = measureUpdateFrames(scene: scene, state: state, frameCount: 60)
        let avgMs = average(durations)
        let maxMs = durations.max() ?? 0

        print("[Perf] Presented update (50 pigs): avg=\(fmt(avgMs))ms max=\(fmt(maxMs))ms")
        #expect(scene.pigNodes.count == 50, "Expected 50 PigNodes, got \(scene.pigNodes.count)")
        #expect(avgMs < 500, "Avg frame time \(fmt(avgMs))ms exceeds regression budget (500ms)")
        #expect(maxMs < 2_000, "Max frame spike \(fmt(maxMs))ms exceeds regression budget (2s)")
    }

    @Test("Presented scene update with 100 animated pigs: avg frame time under budget")
    func presentedFrameUpdate100Pigs() {
        let (view, scene, state) = makePresentedScene(pigCount: 100)
        _ = view // suppress unused-variable warning

        let durations = measureUpdateFrames(scene: scene, state: state, frameCount: 60)
        let avgMs = average(durations)
        let maxMs = durations.max() ?? 0

        print("[Perf] Presented update (100 pigs): avg=\(fmt(avgMs))ms max=\(fmt(maxMs))ms")
        #expect(scene.pigNodes.count == 100, "Expected 100 PigNodes, got \(scene.pigNodes.count)")
        #expect(avgMs < 1_000, "Avg frame time \(fmt(avgMs))ms exceeds regression budget (1s)")
        #expect(maxMs < 3_000, "Max frame spike \(fmt(maxMs))ms exceeds regression budget (3s)")
    }

    // MARK: - Node Hierarchy Count

    @Test("Node hierarchy with 50 pigs: each PigNode has expected child count")
    func nodeHierarchy50Pigs() {
        let (view, scene, _) = makePresentedScene(pigCount: 50)
        _ = view // suppress unused-variable warning

        #expect(scene.pigNodes.count == 50)

        var totalChildren = 0
        var minChildren = Int.max
        var maxChildren = 0
        for node in scene.pigNodes.values {
            let count = node.children.count
            totalChildren += count
            minChildren = min(minChildren, count)
            maxChildren = max(maxChildren, count)
        }

        let avgChildren = Double(totalChildren) / Double(scene.pigNodes.count)
        print("[Perf] Node hierarchy (50 pigs): total children=\(totalChildren) avg=\(fmt(avgChildren)) min=\(minChildren) max=\(maxChildren)")

        // Each PigNode has at least a nameLabel. Shadow is conditional on image loading.
        // Indicator and glow are optional (off by default).
        #expect(minChildren >= 1, "Every PigNode should have at least the nameLabel child")
        #expect(maxChildren <= 4, "PigNode should have at most 4 children (shadow+label+indicator+glow)")
    }

    // MARK: - Mixed Animation States

    @Test("Mixed animation states (idle/walking/eating/sleeping) vs uniform idle: no performance cliff")
    func mixedAnimationStates() {
        // Baseline: all idle
        let (viewUniform, sceneUniform, stateUniform) = makePresentedScene(pigCount: 50)
        _ = viewUniform // suppress unused-variable warning
        let uniformDurations = measureUpdateFrames(scene: sceneUniform, state: stateUniform, frameCount: 60)
        let uniformAvg = average(uniformDurations)

        // Mixed: distribute across 4 animation states
        let (viewMixed, sceneMixed, stateMixed) = makePresentedScene(pigCount: 50, mixedStates: true)
        _ = viewMixed // suppress unused-variable warning
        let mixedDurations = measureUpdateFrames(scene: sceneMixed, state: stateMixed, frameCount: 60)
        let mixedAvg = average(mixedDurations)

        print("[Perf] Uniform idle (50 pigs): avg=\(fmt(uniformAvg))ms")
        print("[Perf] Mixed states (50 pigs): avg=\(fmt(mixedAvg))ms")

        // Mixed states cause more texture swaps per frame (3 animated states
        // plus idle), but should not be dramatically worse.
        #expect(uniformAvg > 0, "Baseline (uniform idle) measured as 0ms — cannot compute ratio")
        guard uniformAvg > 0 else { return }
        let ratio = mixedAvg / uniformAvg
        print("[Perf] Mixed/Uniform ratio: \(fmt(ratio))x")
        #expect(ratio < 5.0, "Mixed animation states \(fmt(ratio))x slower than uniform — possible performance cliff")
        #expect(mixedAvg < 1_000, "Mixed states avg \(fmt(mixedAvg))ms exceeds regression budget (1s)")
    }

    // MARK: - Scene Presentation Cost

    @Test("Full scene presentation cost with 50 pigs: didMove(to:) completes within budget")
    func scenePresentationCost50() {
        let (state, _) = makeLargeIntegrationState(pigCount: 50)
        let scene = FarmScene(gameState: state)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        let clock = ContinuousClock()
        let elapsed = clock.measure { view.presentScene(scene) }

        let ms = elapsed.milliseconds
        withExtendedLifetime(view) {}
        print("[Perf] Scene presentation (50 pigs): \(fmt(ms))ms (includes terrain, camera, syncPigs)")
        #expect(ms < 3_000, "Scene presentation took \(fmt(ms))ms (budget: 3s)")
        #expect(scene.pigNodes.count == 50)
    }
}

// MARK: - Private Helpers

@MainActor
private func makePresentedScene(
    pigCount: Int,
    mixedStates: Bool = false
) -> (SKView, FarmScene, GameState) {
    let (state, _) = makeLargeIntegrationState(pigCount: pigCount)

    if mixedStates {
        let states: [BehaviorState] = [.idle, .wandering, .eating, .sleeping]
        for (index, id) in state.guineaPigs.keys.enumerated() {
            guard var pig = state.guineaPigs[id] else { continue }
            pig.behaviorState = states[index % states.count]
            if pig.behaviorState == .wandering {
                pig.path = [
                    GridPosition(x: Int(pig.position.x), y: Int(pig.position.y)),
                    GridPosition(x: Int(pig.position.x) + 3, y: Int(pig.position.y))
                ]
            }
            state.guineaPigs[id] = pig
        }
    }

    let scene = FarmScene(gameState: state)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    view.presentScene(scene)

    return (view, scene, state)
}

@MainActor
private func measureUpdateFrames(
    scene: FarmScene,
    state: GameState,
    frameCount: Int
) -> [Double] {
    let clock = ContinuousClock()
    var durations: [Double] = []
    durations.reserveCapacity(frameCount)

    for i in 0..<frameCount {
        // Increment tick so update() triggers syncPigs/syncFacilities.
        state.simulationTick &+= 1
        let elapsed = clock.measure {
            scene.update(TimeInterval(i) / 60.0)
        }
        durations.append(elapsed.milliseconds)
    }
    return durations
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func fmt(_ value: Double) -> String {
    String(format: "%.2f", value)
}
