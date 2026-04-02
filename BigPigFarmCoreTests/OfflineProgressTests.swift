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
        #expect(GameConfig.Offline.checkpointGameHours == 1.0)
        #expect(GameConfig.Offline.consumptionRateMultiplier == 0.40)
        #expect(GameConfig.Offline.alwaysShowPopupSeconds == 1_800)
    }

    @Test func speedTiersAreConfigured() {
        let tiers = GameConfig.Offline.speedTiers
        #expect(tiers.count == 4)
        #expect(tiers[0].realHoursCeiling == 2)
        #expect(tiers[0].multiplier == 120.0)
        #expect(tiers[1].realHoursCeiling == 6)
        #expect(tiers[1].multiplier == 60.0)
        #expect(tiers[2].realHoursCeiling == 12)
        #expect(tiers[2].multiplier == 30.0)
        #expect(tiers[3].realHoursCeiling == 24)
        #expect(tiers[3].multiplier == 15.0)
    }

    @Test func speedTiersAreOrderedAscending() {
        let tiers = GameConfig.Offline.speedTiers
        for i in 1..<tiers.count {
            #expect(tiers[i].realHoursCeiling > tiers[i - 1].realHoursCeiling)
        }
    }
}

// MARK: - Diminishing Returns Curve Tests

@Suite("Offline Diminishing Returns")
struct OfflineDiminishingReturnsTests {
    @Test func zeroSecondsReturnsZero() {
        #expect(OfflineProgressRunner.computeGameHours(wallClockSeconds: 0) == 0)
    }

    @Test func tier1Only() {
        // 1 real hour at 120x = 120 game-hours
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 3600)
        #expect(result == 120.0)
    }

    @Test func tier1Boundary() {
        // 2 real hours at 120x = 240 game-hours (enough for a full pregnancy)
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 7200)
        #expect(result == 240.0)
    }

    @Test func tier1PlusTier2() {
        // 4h: 2h×120 (240) + 2h×60 (120) = 360 game-hours
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 14_400)
        #expect(result == 360.0)
    }

    @Test func eightRealHoursOvernight() {
        // 8h: 2h×120 (240) + 4h×60 (240) + 2h×30 (60) = 540 game-hours
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 28_800)
        #expect(result == 540.0)
    }

    @Test func twelveRealHours() {
        // 12h: 240 + 240 + 6h×30 (180) = 660 game-hours
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 43_200)
        #expect(result == 660.0)
    }

    @Test func twentyFourRealHours() {
        // 24h: 240 + 240 + 180 + 12h×15 (180) = 840 game-hours = 35 game-days
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 86_400)
        #expect(result == 840.0)
    }

    @Test func beyondLastTierFallsBackToOneX() {
        // 30h: 840 game-hours (tiers 1-4) + 6h at 1x fallback = 846
        let result = OfflineProgressRunner.computeGameHours(wallClockSeconds: 108_000)
        #expect(result == 846.0)
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

    @Test func shouldShowPopupForLongAbsenceWithoutEvents() {
        let summary = OfflineProgressSummary(wallClockElapsed: 7200, gameHoursElapsed: 22)
        #expect(!summary.hasMeaningfulEvents)
        #expect(summary.shouldShowPopup)
    }

    @Test func shouldNotShowPopupForShortAbsenceWithoutEvents() {
        let summary = OfflineProgressSummary(wallClockElapsed: 120, gameHoursElapsed: 0.1)
        #expect(!summary.hasMeaningfulEvents)
        #expect(!summary.shouldShowPopup)
    }

    @Test func shouldShowPopupForShortAbsenceWithEvents() {
        var summary = OfflineProgressSummary(wallClockElapsed: 120, gameHoursElapsed: 0.1)
        summary.pigsBorn.append(.init(name: "Baby", phenotype: "White"))
        #expect(summary.shouldShowPopup)
    }

    @Test func shouldShowPopupAtExactThreshold() {
        let summary = OfflineProgressSummary(
            wallClockElapsed: GameConfig.Offline.alwaysShowPopupSeconds,
            gameHoursElapsed: 5
        )
        #expect(!summary.hasMeaningfulEvents)
        #expect(summary.shouldShowPopup)
    }

    @Test func shouldNotShowPopupJustBelowThreshold() {
        let summary = OfflineProgressSummary(
            wallClockElapsed: GameConfig.Offline.alwaysShowPopupSeconds - 1,
            gameHoursElapsed: 5
        )
        #expect(!summary.hasMeaningfulEvents)
        #expect(!summary.shouldShowPopup)
    }
}

// MARK: - Needs Tests

@Suite("Offline Needs")
struct OfflineNeedsTests {
    @Test @MainActor func needsDecayOverCheckpoints() throws {
        let state = makeOfflineState(pigCount: 1)
        let pig = state.getPigsList()[0]
        let hungerBefore = pig.needs.hunger

        // 5 game-hours via tier 1 (120x): 5/120 real-hours = 150 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 150)
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

        // 1 game-hour via tier 1 (120x): 1/120 real-hour = 30 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 30)

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

        // 1 game-hour via tier 1 (120x) — 10 pigs all consuming at 40% rate
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 30)

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

        // 1 game-hour via tier 1 (120x) = 30 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 30)

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

        // 6 game-hours via tier 1 (120x): 6/120 real-hours = 180 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 180)

        let updated = try #require(state.getGuineaPig(pig.id))
        #expect(updated.needs.health >= GameConfig.Offline.healthMercyFloor)
    }

    @Test @MainActor func needsDoNotRecoverWithoutFacilities() throws {
        let state = makeOfflineState(pigCount: 1, withFacilities: false)
        var pig = state.getPigsList()[0]
        pig.needs.thirst = 30.0
        state.updateGuineaPig(pig)

        // 1 game-hour via tier 1 (120x) = 30 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 30)

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

        // 1 game-hour via tier 1 (120x) = 30 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 30)

        let updated = try #require(state.getGuineaPig(pig.id))
        #expect(updated.needs.hunger >= 0.0 && updated.needs.hunger <= 100.0)
        #expect(updated.needs.thirst >= 0.0 && updated.needs.thirst <= 100.0)
        #expect(updated.needs.energy >= 0.0 && updated.needs.energy <= 100.0)
        #expect(updated.needs.health >= 0.0 && updated.needs.health <= 100.0)
    }
}
