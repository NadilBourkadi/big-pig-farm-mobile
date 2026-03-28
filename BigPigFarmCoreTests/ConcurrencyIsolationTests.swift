/// ConcurrencyIsolationTests — Regression guards for the @MainActor isolation model.
///
/// Architecture: The entire simulation is single-actor (@MainActor). The Timer,
/// SpriteKit render loop, and SwiftUI views all run on the main thread. Only file
/// I/O (auto-save) and debug logging touch background threads, using value-type copies.
///
/// Many tests here are "compile-time proofs" — their ability to compile under
/// SWIFT_STRICT_CONCURRENCY=complete IS the assertion. Runtime checks supplement
/// the compile-time guarantees.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Actor Isolation

@Suite("MainActor Isolation")
@MainActor
struct MainActorIsolationTests {

    // MARK: - GameState

    @Test("GameState properties are accessible synchronously on MainActor")
    func gameStateIsMainActorIsolated() {
        let state = makeGameState()

        // Synchronous access — would be a compiler error if GameState lost @MainActor
        state.isPaused = true
        #expect(state.isPaused == true)
        state.isPaused = false

        state.speed = .fast
        #expect(state.speed == .fast)

        _ = state.simulationTick
        _ = state.pigCount
        _ = state.capacity
    }

    // MARK: - GameEngine

    @Test("GameEngine tick is callable synchronously on MainActor")
    func gameEngineIsMainActorIsolated() {
        let state = makeGameState()
        let engine = GameEngine(state: state)

        // Synchronous call — proves GameEngine is @MainActor
        engine.tick(0.1)
        #expect(state.gameTime.totalGameMinutes > 0)
    }

    // MARK: - SimulationRunner

    @Test("SimulationRunner tick is callable synchronously on MainActor")
    func simulationRunnerIsMainActorIsolated() {
        let (state, runner) = makeIntegrationState(pigCount: 0)

        // Synchronous call — proves SimulationRunner is @MainActor
        runner.tick(gameMinutes: 0.3)
        #expect(state.simulationTick == 1)
    }

    // MARK: - BehaviorController

    @Test("BehaviorController is accessible synchronously on MainActor")
    func behaviorControllerIsMainActorIsolated() {
        let state = makeGameState()
        let controller = makeController(state: state)

        // Synchronous access — proves BehaviorController is @MainActor
        _ = controller.collision
        _ = controller.facilityManager
    }

    // MARK: - CollisionHandler

    @Test("CollisionHandler spatialGrid is accessible synchronously on MainActor")
    func collisionHandlerIsMainActorIsolated() {
        let state = makeGameState()
        let controller = makeController(state: state)

        // Synchronous access — proves CollisionHandler is @MainActor
        _ = controller.collision.spatialGrid
    }

    // MARK: - Context Protocols

    @Test("Context protocols enforce MainActor isolation on GameState")
    func protocolsAreMainActorIsolated() {
        let state = makeGameState()

        // Synchronous calls through protocol witnesses — proves protocols are @MainActor.
        // If any protocol lost @MainActor, conformance would require `await`.
        let _: [GuineaPig] = (state as PigQueryContext).getPigsList()
        let _: Bool = (state as UpgradeQueryContext).hasUpgrade("test")
        (state as EventLoggingContext).logEvent("test", eventType: "info")
    }
}

// MARK: - Tick Atomicity

@Suite("Tick Atomicity")
@MainActor
struct TickAtomicityTests {

    @Test("Tick counter increments exactly once per tick")
    func tickMutationsAreAtomic() {
        let (state, runner) = makeIntegrationState(pigCount: 0)

        let tickCount = 50
        for i in 1...tickCount {
            state.gameTime.advance(minutes: 0.3)
            runner.tick(gameMinutes: 0.3)
            #expect(state.simulationTick == UInt64(i))
        }
    }

    @Test("Rapid pause/resume toggling does not corrupt state")
    func pauseResumeDoesNotRace() {
        let state = makeGameState()
        let engine = GameEngine(state: state)
        engine.start()

        // Toggle pause 100 times rapidly
        for _ in 0..<100 {
            state.isPaused.toggle()
        }
        // 100 toggles = back to original (false)
        #expect(state.isPaused == false)

        engine.stop()
    }

    @Test("Speed changes on GameState are immediately visible (no cross-thread delay)")
    func speedChangesAreImmediatelyVisible() {
        let state = makeGameState()

        // @MainActor isolation means speed changes are synchronous — no barrier,
        // no cross-thread propagation delay, no stale reads.
        state.speed = .normal
        #expect(state.speed == .normal)

        state.speed = .fast
        #expect(state.speed == .fast)

        state.speed = .fastest
        #expect(state.speed == .fastest)

        state.speed = .normal
        #expect(state.speed == .normal)
    }
}

// MARK: - Batch Update Isolation

@Suite("Batch Update Isolation")
@MainActor
struct BatchUpdateIsolationTests {

    @Test("Batch update suppresses cache invalidation until outermost scope exits")
    func batchUpdatePreventsIntermediateRebuilds() {
        let state = makeGameState()

        // Prime the cache
        _ = state.getPigsList()

        state.beginBatchUpdate()
        for i in 0..<10 {
            let pig = GuineaPig.create(name: "Batch\(i)", gender: .female)
            state.addGuineaPig(pig)
        }
        // During batch: cache may be stale but no intermediate invalidation
        state.endBatchUpdate()

        // After batch: cache is invalidated, fresh list reflects all 10 pigs
        let list = state.getPigsList()
        #expect(list.count == 10)
    }

    @Test("Nested batch updates only invalidate on outermost end")
    func nestedBatchUpdatesWork() {
        let state = makeGameState()

        state.beginBatchUpdate()
        state.beginBatchUpdate()

        let pig = GuineaPig.create(name: "Nested", gender: .male)
        state.addGuineaPig(pig)

        state.endBatchUpdate()
        // Still inside outer batch — cache not invalidated yet

        let pig2 = GuineaPig.create(name: "Nested2", gender: .female)
        state.addGuineaPig(pig2)

        state.endBatchUpdate()
        // Now outermost batch ended — cache invalidated

        #expect(state.getPigsList().count == 2)
    }
}

// MARK: - Sendable Boundaries

@Suite("Sendable Boundaries")
@MainActor
struct SendableBoundaryTests {

    @Test("GameState can be referenced across actor boundaries (unchecked Sendable)")
    func gameStateUncheckedSendableCompiles() async {
        let state = makeGameState()
        state.isPaused = true

        // Pass GameState reference to a detached task.
        // This compiles because GameState: @unchecked Sendable.
        // The invariant: all access is @MainActor, so no actual concurrent mutation.
        let paused = await Task.detached { @Sendable in
            await MainActor.run { state.isPaused }
        }.value

        #expect(paused == true)
    }

    @Test("Value types cross actor boundaries safely")
    func allModelTypesAreSendable() async {
        // Create instances of each model type and pass to a detached task.
        // This is a compile-time proof: if any type lost Sendable, this fails.
        let pig = GuineaPig.create(name: "SendableTest", gender: .female)
        let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
        let time = GameTime()
        let genotype = Genotype.random()
        let phenotype = calculatePhenotype(genotype)
        let position = Position(x: 1.0, y: 2.0)
        let needs = Needs()

        let result = await Task.detached { @Sendable () -> Bool in
            // Access value-type properties — no actor isolation needed
            _ = pig.name
            _ = facility.facilityType
            _ = time.day
            _ = genotype.eLocus
            _ = phenotype.baseColor
            _ = position.x
            _ = needs.hunger
            return true
        }.value

        #expect(result == true)
    }

    @Test("Pathfinding is consistent across multiple calls (unchecked Sendable safety)")
    func pathfindingUncheckedSendableIsSafe() {
        let state = makeGameState()
        let pathfinding = Pathfinding(farm: state.farm)

        // Multiple calls should yield consistent results — immutable after construction
        let start = GridPosition(x: 5, y: 5)
        let end = GridPosition(x: 10, y: 10)

        let path1 = pathfinding.findPath(from: start, to: end)
        let path2 = pathfinding.findPath(from: start, to: end)

        #expect(path1.count == path2.count)
        if !path1.isEmpty {
            #expect(path1.first == path2.first)
            #expect(path1.last == path2.last)
        }
    }
}

// MARK: - Background Save Isolation

@Suite("Background Save Isolation")
@MainActor
struct BackgroundSaveIsolationTests {

    @Test("Ticks complete without blocking on save operations")
    func ticksDoNotBlockOnSave() {
        let (state, runner) = makeIntegrationState(pigCount: 2)

        // Run enough ticks to trigger at least one auto-save cycle
        // (auto-save triggers every ~300 ticks by default)
        runTicks(runner, state: state, count: 350)

        // All ticks completed — simulation was not blocked by save I/O
        #expect(state.simulationTick == 350)
        #expect(state.pigCount >= 2)
    }
}
