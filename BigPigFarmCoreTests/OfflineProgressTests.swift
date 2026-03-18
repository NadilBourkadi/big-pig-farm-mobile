/// Tests for OfflineProgressRunner and OfflineProgressSummary.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Test Helpers

@MainActor
func makeOfflineState(pigCount: Int = 2, withFacilities: Bool = true) -> GameState {
    let state = GameState()
    // Add adult pigs (1 male, rest alternating)
    for i in 0..<pigCount {
        let gender: Gender = i % 2 == 0 ? .male : .female
        var pig = GuineaPig.create(name: "Pig\(i)", gender: gender)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        pig.position = Position(x: Double(5 + i * 2), y: 5.0)
        state.addGuineaPig(pig)
    }
    if withFacilities {
        _ = state.addFacility(Facility.create(type: .foodBowl, x: 3, y: 3))
        _ = state.addFacility(Facility.create(type: .waterBottle, x: 8, y: 3))
        _ = state.addFacility(Facility.create(type: .hideout, x: 13, y: 3))
    }
    return state
}

// MARK: - Config Tests

@Suite("Offline Config")
struct OfflineConfigTests {
    @Test func constantsAreCorrect() {
        #expect(GameConfig.Offline.minThresholdSeconds == 60)
        #expect(GameConfig.Offline.maxDurationSeconds == 86_400)
        #expect(GameConfig.Offline.speedMultiplier == 3)
        #expect(GameConfig.Offline.checkpointGameHours == 1.0)
    }
}

// MARK: - Summary Tests

@Suite("OfflineProgressSummary")
struct OfflineProgressSummaryTests {
    @Test func hasMeaningfulEventsWhenEmpty() {
        let summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        #expect(!summary.hasMeaningfulEvents)
    }

    @Test func hasMeaningfulEventsWithBirths() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.pigsBorn.append(.init(name: "Baby", phenotype: "White"))
        #expect(summary.hasMeaningfulEvents)
    }

    @Test func hasMeaningfulEventsWithMoney() {
        var summary = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        summary.totalMoneyEarned = 50
        #expect(summary.hasMeaningfulEvents)
    }
}

// MARK: - Needs Tests

@Suite("Offline Needs")
struct OfflineNeedsTests {
    @Test @MainActor func needsDecayOverCheckpoints() throws {
        let state = makeOfflineState(pigCount: 1)
        let pig = state.getPigsList()[0]
        let hungerBefore = pig.needs.hunger

        // 5 checkpoints = 5 game-hours. wallClock = 5*60/3 = 100 seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)
        #expect(summary.gameHoursElapsed == 5.0)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Hunger decays at 0.6/hr but also recovers via equilibration if below threshold.
        // Starting at 100, after 5 hours: 100 - (0.6 * 5) = 97.0 (stays above threshold, no recovery)
        #expect(updated.needs.hunger < hungerBefore)
        #expect(updated.needs.hunger > 90.0)
    }

    @Test @MainActor func needsEquilibrateWithFacilities() throws {
        let state = makeOfflineState(pigCount: 1)
        var pig = state.getPigsList()[0]
        pig.needs.thirst = 20.0  // Below lowThreshold (40)
        state.updateGuineaPig(pig)

        // 1 checkpoint = 1 game-hour
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Thirst should have recovered (consumes from water bottle)
        #expect(updated.needs.thirst > 20.0)
    }

    @Test @MainActor func facilitiesDepleteDuringRecovery() throws {
        let state = makeOfflineState(pigCount: 10)
        // Set all pigs to low hunger so they all need food
        for var pig in state.getPigsList() {
            pig.needs.hunger = 10.0
            state.updateGuineaPig(pig)
        }
        let foodBowl = state.getFacilitiesByType(.foodBowl).first
        let stockBefore = foodBowl?.currentAmount ?? 0

        // 1 checkpoint — 10 pigs all consuming at 25% rate
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updatedBowl = foodBowl.flatMap { state.getFacility($0.id) }
        let stockAfter = updatedBowl?.currentAmount ?? 0
        #expect(stockAfter < stockBefore)
    }

    @Test @MainActor func recoveryStopsWhenFacilitiesEmpty() throws {
        let state = makeOfflineState(pigCount: 1)
        // Drain the water bottle completely
        for facility in state.getFacilitiesByType(.waterBottle) {
            var mutable = facility
            _ = mutable.consume(mutable.currentAmount)
            state.updateFacility(mutable)
        }
        var pig = state.getPigsList()[0]
        pig.needs.thirst = 20.0
        state.updateGuineaPig(pig)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Thirst should only decay — empty water bottle provides no recovery
        #expect(updated.needs.thirst < 20.0)
    }

    @Test @MainActor func healthMercyFloorPreventsDeathSpiral() throws {
        let state = makeOfflineState(pigCount: 1, withFacilities: false)
        var pig = state.getPigsList()[0]
        pig.needs.hunger = 5.0   // Critical — will drain health
        pig.needs.thirst = 5.0   // Critical — will drain health
        pig.needs.health = 30.0
        state.updateGuineaPig(pig)

        // Long offline — health would drain well past 0 without mercy floor
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 2000)

        let updated = try #require(state.getGuineaPig(pig.id))
        #expect(updated.needs.health >= GameConfig.Offline.healthMercyFloor)
    }

    @Test @MainActor func needsDoNotRecoverWithoutFacilities() throws {
        let state = makeOfflineState(pigCount: 1, withFacilities: false)
        var pig = state.getPigsList()[0]
        pig.needs.thirst = 30.0
        state.updateGuineaPig(pig)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Thirst only decays, no recovery without water bottle
        #expect(updated.needs.thirst < 30.0)
    }

    @Test @MainActor func needsClampedToRange() throws {
        let state = makeOfflineState(pigCount: 1)
        var pig = state.getPigsList()[0]
        pig.needs.hunger = 100.0
        pig.needs.thirst = 100.0
        pig.needs.energy = 100.0
        pig.needs.happiness = 100.0
        pig.needs.health = 100.0
        state.updateGuineaPig(pig)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updated = try #require(state.getGuineaPig(pig.id))
        #expect(updated.needs.hunger >= 0.0 && updated.needs.hunger <= 100.0)
        #expect(updated.needs.thirst >= 0.0 && updated.needs.thirst <= 100.0)
        #expect(updated.needs.energy >= 0.0 && updated.needs.energy <= 100.0)
        #expect(updated.needs.health >= 0.0 && updated.needs.health <= 100.0)
    }
}
