/// PerformanceTests — Headless simulation benchmarks with 50–200 pigs.
///
/// These tests measure tick throughput, memory footprint, and spatial grid
/// scaling WITHOUT any SpriteKit dependency. They can run on any simulator.
///
/// Performance budgets are deliberately loose: the goal is to catch catastrophic
/// regressions (> 5 seconds for a handful of ticks) and to log real numbers in
/// test output for humans to trend. Use Instruments for precise profiling.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Simulation Performance

@Suite("Simulation Performance")
@MainActor
struct SimulationPerformanceTests {

    // MARK: - Tick Throughput

    @Test("Tick throughput with 50 pigs: logs timing, asserts no hang")
    func tickThroughput50Pigs() {
        let (state, runner) = makeLargeIntegrationState(pigCount: 50)

        // Warmup: let behavior caches and decision timers settle.
        runTicks(runner, state: state, count: 5)

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<20 {
            let elapsed = clock.measure {
                state.gameTime.advance(minutes: 0.3)
                runner.tick(gameMinutes: 0.3)
            }
            durations.append(elapsed)
        }

        let totalMs = durations.map(\.milliseconds).reduce(0, +)
        let avgMs = totalMs / Double(durations.count)
        let maxMs = durations.map(\.milliseconds).max() ?? 0
        print("[Perf] tickThroughput50: avg=\(format(avgMs))ms max=\(format(maxMs))ms total=\(format(totalMs))ms")

        // Regression guard: 20 ticks must complete in under 30 seconds.
        #expect(totalMs < 30_000, "20 ticks with 50 pigs took \(format(totalMs))ms (budget: 30s)")
    }

    @Test("Tick throughput with 100 pigs: logs timing, asserts no hang")
    func tickThroughput100Pigs() {
        let (state, runner) = makeLargeIntegrationState(pigCount: 100)

        runTicks(runner, state: state, count: 5)

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<20 {
            let elapsed = clock.measure {
                state.gameTime.advance(minutes: 0.3)
                runner.tick(gameMinutes: 0.3)
            }
            durations.append(elapsed)
        }

        let totalMs = durations.map(\.milliseconds).reduce(0, +)
        let avgMs = totalMs / Double(durations.count)
        let maxMs = durations.map(\.milliseconds).max() ?? 0
        print("[Perf] tickThroughput100: avg=\(format(avgMs))ms max=\(format(maxMs))ms total=\(format(totalMs))ms")

        // Regression guard: 20 ticks with 100 pigs under 60 seconds.
        #expect(totalMs < 60_000, "20 ticks with 100 pigs took \(format(totalMs))ms (budget: 60s)")
    }

    @Test("Tick throughput with 200 pigs: logs timing, asserts no hang")
    func tickThroughput200Pigs() {
        let (state, runner) = makeLargeIntegrationState(pigCount: 200)

        runTicks(runner, state: state, count: 3)

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<10 {
            let elapsed = clock.measure {
                state.gameTime.advance(minutes: 0.3)
                runner.tick(gameMinutes: 0.3)
            }
            durations.append(elapsed)
        }

        let totalMs = durations.map(\.milliseconds).reduce(0, +)
        let avgMs = totalMs / Double(durations.count)
        let maxMs = durations.map(\.milliseconds).max() ?? 0
        print("[Perf] tickThroughput200: avg=\(format(avgMs))ms max=\(format(maxMs))ms total=\(format(totalMs))ms")

        // Regression guard: 10 ticks with 200 pigs under 60 seconds.
        #expect(totalMs < 60_000, "10 ticks with 200 pigs took \(format(totalMs))ms (budget: 60s)")
    }

    // MARK: - Sustained TPS

    @Test("Sustained TPS with 50 pigs: logs effective TPS over 100 ticks")
    func sustainedTPS50Pigs() {
        let (state, runner) = makeLargeIntegrationState(pigCount: 50)

        runTicks(runner, state: state, count: 5)

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            runTicks(runner, state: state, count: 100)
        }

        let totalSeconds = elapsed.milliseconds / 1_000.0
        let effectiveTPS = 100.0 / max(totalSeconds, 0.001)
        let totalMs = format(totalSeconds * 1000)
        print("[Perf] sustainedTPS50: \(format(effectiveTPS)) TPS over 100 ticks (\(totalMs)ms total)")

        // Sanity guard: must achieve at least 0.5 TPS (one tick every 2 seconds).
        #expect(effectiveTPS >= 0.5, "Simulation achieved only \(format(effectiveTPS)) TPS with 50 pigs")
    }

    // MARK: - Memory Footprint

    @Test("Memory footprint with 50 pigs: logs resident delta MB")
    func memoryFootprint50Pigs() {
        let baseline = memoryUsageMB()
        guard baseline > 0 else { return } // Skip if mach_task_basic_info unavailable.

        let (state, runner) = makeLargeIntegrationState(pigCount: 50)
        runTicks(runner, state: state, count: 50)

        let peak = memoryUsageMB()
        let deltaMB = peak - baseline
        print("[Perf] memory50: baseline=\(format(baseline))MB peak=\(format(peak))MB delta=\(format(deltaMB))MB")

        // Regression guard: 50 pigs should not cause > 500MB delta.
        #expect(deltaMB < 500, "Memory delta with 50 pigs is \(format(deltaMB))MB (budget: 500MB)")

        // Suppress "unused" warnings.
        _ = state
        _ = runner
    }

    // MARK: - Spatial Grid Scaling

    @Test("Spatial grid rebuild scales sub-quadratically: logs ratios across pig counts")
    func spatialGridScaling() {
        let counts = [25, 50, 100, 200]
        var timesMs: [Double] = []
        let clock = ContinuousClock()

        for count in counts {
            let (state, _) = makeLargeIntegrationState(pigCount: count)
            let controller = BehaviorController(gameState: state)

            // Warm up the grid.
            for _ in 0..<5 { controller.collision.rebuildSpatialGrid() }

            let elapsed = clock.measure {
                for _ in 0..<100 {
                    controller.collision.rebuildSpatialGrid()
                }
            }
            let avgMs = elapsed.milliseconds / 100.0
            timesMs.append(avgMs)
            print("[Perf] spatialGrid(\(count) pigs): avg=\(format(avgMs))ms per rebuild")

            _ = state
        }

        // Print scaling ratios (for humans to interpret).
        guard timesMs[0] > 0 else { return }
        let ratio50to25 = timesMs[1] / timesMs[0]
        let ratio100to25 = timesMs[2] / timesMs[0]
        let ratio200to25 = timesMs[3] / timesMs[0]
        print("[Perf] spatialGrid scaling — ×50/25=\(format(ratio50to25))" +
              " ×100/25=\(format(ratio100to25)) ×200/25=\(format(ratio200to25))")

        // Regression guard: rebuilding for 200 pigs should not be > 50x slower than 25.
        // (Linear = 8x, quadratic = 64x. 50x flags near-quadratic growth.)
        #expect(ratio200to25 < 50.0, "Spatial grid scales worse than O(n^2): 200/25 ratio=\(format(ratio200to25))x")
    }
}

// MARK: - Private Helpers

private func format(_ value: Double) -> String {
    String(format: "%.2f", value)
}
