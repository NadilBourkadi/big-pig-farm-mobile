/// OfflineProgressRepositionTests — Tests for overlap-aware repositioning and
/// post-offline deadlock prevention (bead 1dyx).
import Testing
import Foundation
@testable import BigPigFarmCore

@MainActor
struct OfflineProgressRepositionTests {

    // MARK: - Overlap-Aware Repositioning

    @Test("repositionPigs places all pigs at distinct grid cells")
    func repositionPigsPlacesAtDistinctCells() {
        let state = makeOfflineState(pigCount: 20)
        state.lastSave = Date(timeIntervalSinceNow: -300)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 300)

        var positions = Set<GridPosition>()
        for pig in state.getPigsList() {
            let gridPos = pig.position.gridPosition
            positions.insert(gridPos)
        }
        #expect(positions.count == state.pigCount)
    }

    @Test("repositionPigs handles more pigs than area cells with fallback")
    func repositionPigsOverflowFallback() {
        // Create a tiny grid where the area has fewer walkable cells than pigs.
        // Area is 3x3 (x1=1..x2=3, y1=1..y2=3) = 9 walkable cells.
        // Grid is 12x12 so cells outside the area provide fallback space.
        let state = GameState()
        var grid = FarmGrid(width: 12, height: 12)
        let area = FarmArea(
            id: UUID(), name: "Tiny", biome: .meadow,
            x1: 1, y1: 1, x2: 3, y2: 3,
            gridCol: 0, gridRow: 0
        )
        grid.addArea(area)
        state.farm = grid

        // Add 15 pigs — more than the 9 area cells, forcing global fallback
        for i in 0..<15 {
            let gender: Gender = i % 2 == 0 ? .male : .female
            var pig = GuineaPig.create(name: "Pig\(i)", gender: gender)
            pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
            pig.position = Position(x: 2.0, y: 2.0) // All start at same position
            pig.currentAreaId = area.id
            state.addGuineaPig(pig)
        }

        state.lastSave = Date(timeIntervalSinceNow: -300)
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 300)

        // All pigs should be at distinct positions
        var positions = Set<GridPosition>()
        for pig in state.getPigsList() {
            positions.insert(pig.position.gridPosition)
        }
        #expect(positions.count == state.pigCount)

        // At least one pig must have been placed outside the area (fallback exercised)
        let outsideArea = state.getPigsList().contains { pig in
            let gp = pig.position.gridPosition
            return gp.x < area.x1 || gp.x > area.x2 || gp.y < area.y1 || gp.y > area.y2
        }
        #expect(outsideArea, "Expected at least one pig placed outside the tiny area via fallback")
    }

    @Test("repositionPigs places all pigs on walkable cells")
    func repositionPigsAllOnWalkableCells() {
        let state = makeOfflineState(pigCount: 15)
        state.lastSave = Date(timeIntervalSinceNow: -300)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 300)

        for pig in state.getPigsList() {
            let gp = pig.position.gridPosition
            #expect(
                state.farm.isWalkable(gp.x, gp.y),
                "Pig \(pig.name) at (\(gp.x), \(gp.y)) is not on a walkable cell"
            )
        }
    }

    // MARK: - Decision Timer Staggering

    @Test("resetAfterOffline staggers decision timers across full interval")
    func resetAfterOfflineStaggersTimers() {
        let state = makeOfflineState(pigCount: 30)
        let controller = makeController(state: state)
        let runner = SimulationRunner(
            state: state, behaviorController: controller, saveManager: makeTempSaveManager()
        )

        runner.resetAfterOffline()

        // Decision timers should be spread across [0, decisionIntervalSeconds).
        // With 30 pigs, at least some should be in the upper half of the interval.
        let interval = GameConfig.Simulation.decisionIntervalSeconds
        var upperHalfCount = 0
        for pigId in state.guineaPigs.keys {
            let timer = controller.getDecisionTimer(pigId)
            #expect(timer >= 0.0)
            #expect(timer < interval)
            if timer >= interval / 2 { upperHalfCount += 1 }
        }
        // With 30 pigs uniformly distributed, expect ~15 in upper half.
        // Use a loose bound to avoid flaky tests.
        #expect(upperHalfCount >= 5, "Expected some timers in upper half of interval")
    }

    @Test("staggered timers prevent all pigs deciding on first tick")
    func staggeredTimersPreventMassFirstDecision() {
        let state = makeOfflineState(pigCount: 20)
        let controller = makeController(state: state)
        let runner = SimulationRunner(
            state: state, behaviorController: controller, saveManager: makeTempSaveManager()
        )

        // Set all pigs to idle with low hunger so they'd seek food
        for var pig in state.getPigsList() {
            pig.behaviorState = .idle
            pig.needs.hunger = 40.0
            state.updateGuineaPig(pig)
        }

        runner.resetAfterOffline()

        // Run 1 tick at normal speed (0.3 game-minutes)
        state.gameTime.advance(minutes: 0.3)
        runner.tick(gameMinutes: 0.3)

        // With timers spread across [0, 2.0) and a tick of 0.3 game-minutes,
        // only pigs seeded in [1.7, 2.0) fire on tick 1 (~15% of 20 = ~3 pigs).
        var changedCount = 0
        for pig in state.getPigsList() where pig.behaviorState != .idle {
            changedCount += 1
        }
        #expect(changedCount <= 8, "Expected at most ~40% of pigs to decide on first tick, got \(changedCount)")
    }

    // MARK: - Post-Offline Movement Integration

    @Test("pigs can move within a few ticks after offline catch-up")
    func postOfflinePigsCanMove() {
        let state = makeOfflineState(pigCount: 20)
        state.lastSave = Date(timeIntervalSinceNow: -300)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 300)

        let controller = makeController(state: state)
        let runner = SimulationRunner(
            state: state, behaviorController: controller, saveManager: makeTempSaveManager()
        )
        runner.rebuildAndSeparateAfterOffline()
        runner.resetAfterOffline()

        // Record post-catch-up positions
        var initialPositions: [UUID: Position] = [:]
        for pig in state.getPigsList() {
            initialPositions[pig.id] = pig.position
        }

        // Run 30 ticks (~3 seconds of gameplay at normal speed)
        runTicks(runner, state: state, count: 30)

        // At least half the pigs should have moved
        var movedCount = 0
        for pig in state.getPigsList() {
            guard let initial = initialPositions[pig.id] else { continue }
            if pig.position.x != initial.x || pig.position.y != initial.y {
                movedCount += 1
            }
        }
        #expect(movedCount >= 10, "Expected at least half of 20 pigs to move, got \(movedCount)")
    }
}
