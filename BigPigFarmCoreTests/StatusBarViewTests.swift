/// StatusBarViewTests — Tests for StatusBarView computed properties.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Food Level Tests

@MainActor
@Suite("StatusBarView - Food Level")
struct StatusBarFoodLevelTests {

    @Test func foodLevelIsZeroWithNoFacilities() {
        let state = makeGameState()
        let facilities = state.getFacilitiesByType(.foodBowl)
            + state.getFacilitiesByType(.hayRack)
            + state.getFacilitiesByType(.feastTable)
        #expect(facilities.isEmpty)
        // foodLevel would be 0 when no facilities exist
        let level = computeFoodLevel(state: state)
        #expect(level == 0)
    }

    @Test func foodLevelIncludesFeastTable() {
        let state = makeGameState()
        var table = Facility.create(type: .feastTable, x: 5, y: 5)
        table.currentAmount = table.maxAmount * 0.5   // 50%
        _ = state.addFacility(table)

        let level = computeFoodLevel(state: state)
        #expect(level == 50)
    }

    @Test func foodLevelAveragesAllThreeFoodFacilityTypes() {
        let state = makeGameState()
        let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)   // 100%
        _ = state.addFacility(bowl)
        let rack = Facility.create(type: .hayRack, x: 10, y: 5)   // 100%
        _ = state.addFacility(rack)
        // feastTable is 5×5; place at (5,10) so columns 5–9, rows 10–14 fit within the
        // 18×18 starter farm and don't overlap the bowl (5,5) or rack (10,5).
        var table = Facility.create(type: .feastTable, x: 5, y: 10)
        table.currentAmount = 0                                     // 0%
        _ = state.addFacility(table)

        let level = computeFoodLevel(state: state)
        // Average of 100, 100, 0 = 66.67 → rounds to 67
        #expect(level == 67)
    }

    @Test func foodLevelCapsBelowHundredWhenFeastTableDrained() {
        // Regression: before the fix, feastTable was excluded from the average
        // so a drained table had no effect on the HUD. Now it does.
        let state = makeGameState()
        let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)   // 100%
        _ = state.addFacility(bowl)
        var table = Facility.create(type: .feastTable, x: 10, y: 5)
        table.currentAmount = table.maxAmount * 0.74               // 74%
        _ = state.addFacility(table)

        let level = computeFoodLevel(state: state)
        // Average of 100% and 74% = 87% — the exact symptom the user reported
        #expect(level == 87)
        #expect(level < 100)
    }

    @Test func foodLevelAveragesSingleFoodBowl() {
        let state = makeGameState()
        var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
        bowl.currentAmount = bowl.maxAmount * 0.6   // 60%
        _ = state.addFacility(bowl)

        let level = computeFoodLevel(state: state)
        #expect(level == 60)
    }

    @Test func foodLevelAveragesFoodBowlAndHayRack() {
        let state = makeGameState()
        var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
        bowl.currentAmount = bowl.maxAmount * 0.4   // 40%
        _ = state.addFacility(bowl)

        var rack = Facility.create(type: .hayRack, x: 10, y: 5)
        rack.currentAmount = rack.maxAmount * 0.8   // 80%
        _ = state.addFacility(rack)

        let level = computeFoodLevel(state: state)
        // Average of 40% and 80% = 60%
        #expect(level == 60)
    }

    @Test func foodLevelIsZeroWhenFacilitiesEmpty() {
        let state = makeGameState()
        var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
        bowl.currentAmount = 0
        _ = state.addFacility(bowl)

        let level = computeFoodLevel(state: state)
        #expect(level == 0)
    }

    @Test func foodLevelIsHundredWhenFull() {
        let state = makeGameState()
        let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
        // Default Facility.create sets currentAmount = maxAmount
        _ = state.addFacility(bowl)

        let level = computeFoodLevel(state: state)
        #expect(level == 100)
    }

    @Test func foodLevelRoundsHalfUp() {
        let state = makeGameState()
        // Two bowls at 30% and 31% → average 30.5% → rounds to 31, not truncates to 30
        var bowl1 = Facility.create(type: .foodBowl, x: 5, y: 5)
        bowl1.currentAmount = bowl1.maxAmount * 0.30
        _ = state.addFacility(bowl1)

        var bowl2 = Facility.create(type: .foodBowl, x: 10, y: 5)
        bowl2.currentAmount = bowl2.maxAmount * 0.31
        _ = state.addFacility(bowl2)

        let level = computeFoodLevel(state: state)
        #expect(level == 31)   // 30.5 rounds up, not truncates to 30
    }
}

// MARK: - Water Level Tests

@MainActor
@Suite("StatusBarView - Water Level")
struct StatusBarWaterLevelTests {

    @Test func waterLevelIsZeroWithNoFacilities() {
        let state = makeGameState()
        let level = computeWaterLevel(state: state)
        #expect(level == 0)
    }

    @Test func waterLevelAveragesSingleBottle() {
        let state = makeGameState()
        var bottle = Facility.create(type: .waterBottle, x: 5, y: 5)
        bottle.currentAmount = bottle.maxAmount * 0.75   // 75%
        _ = state.addFacility(bottle)

        let level = computeWaterLevel(state: state)
        #expect(level == 75)
    }

    @Test func waterLevelAveragesMultipleBottles() {
        let state = makeGameState()
        var b1 = Facility.create(type: .waterBottle, x: 5, y: 5)
        b1.currentAmount = b1.maxAmount * 0.2   // 20%
        _ = state.addFacility(b1)

        var b2 = Facility.create(type: .waterBottle, x: 10, y: 5)
        b2.currentAmount = b2.maxAmount * 0.8   // 80%
        _ = state.addFacility(b2)

        let level = computeWaterLevel(state: state)
        // Average of 20% and 80% = 50%
        #expect(level == 50)
    }
}

// MARK: - Low Population Warning Tests

@MainActor
@Suite("StatusBarView - Low Population Warning")
struct StatusBarLowPopWarningTests {

    @Test func noWarningWhenBreedingDisabled() {
        let state = makeGameState()
        state.breedingProgram.enabled = false
        #expect(!computeLowPopWarning(state: state))
    }

    @Test func warningWhenBreedingEnabledAndNoPigs() {
        let state = makeGameState()
        state.breedingProgram.enabled = true
        // 0 adults <= minBreedingPopulation (2) -> warning
        #expect(computeLowPopWarning(state: state))
    }

    @Test func warningWhenBreedingEnabledAndAtThreshold() {
        let state = makeGameState()
        state.breedingProgram.enabled = true
        for i in 0..<GameConfig.Breeding.minBreedingPopulation {
            var pig = GuineaPig.create(name: "Pig\(i)", gender: i == 0 ? .male : .female)
            pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
            state.addGuineaPig(pig)
        }
        let adultCount = state.getPigsList().filter { !$0.isBaby }.count
        #expect(adultCount == GameConfig.Breeding.minBreedingPopulation)
        #expect(computeLowPopWarning(state: state))
    }

    @Test func noWarningWhenEnoughAdults() {
        let state = makeGameState()
        state.breedingProgram.enabled = true
        let targetCount = GameConfig.Breeding.minBreedingPopulation + 2
        for i in 0..<targetCount {
            var pig = GuineaPig.create(name: "Pig\(i)", gender: i.isMultiple(of: 2) ? .male : .female)
            pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
            state.addGuineaPig(pig)
        }
        let adultCount = state.getPigsList().filter { !$0.isBaby }.count
        #expect(adultCount > GameConfig.Breeding.minBreedingPopulation)
        #expect(!computeLowPopWarning(state: state))
    }

    @Test func warningTextReferencesThresholdFromConfig() {
        let text = computeLowPopWarningText()
        // With minBreedingPopulation == 2, this resolves to "Need 3+ adults"
        let needed = GameConfig.Breeding.minBreedingPopulation + 1
        #expect(text == "Need \(needed)+ adults")
    }

    @Test func accessibilityLabelIncludesThreshold() {
        let label = computeLowPopAccessibilityLabel()
        let needed = GameConfig.Breeding.minBreedingPopulation + 1
        #expect(label.contains("at least \(needed)"))
        #expect(label.contains("breeding"))
    }

    @Test func babiesDoNotCountTowardPopulation() {
        let state = makeGameState()
        state.breedingProgram.enabled = true
        // Add 5 baby pigs — they should not satisfy the population requirement
        for i in 0..<5 {
            var pig = GuineaPig.create(name: "Baby\(i)", gender: .female)
            pig.ageDays = 0.0   // Baby
            state.addGuineaPig(pig)
        }
        let adultCount = state.getPigsList().filter { !$0.isBaby }.count
        #expect(adultCount == 0)
        #expect(computeLowPopWarning(state: state))
    }
}

// MARK: - Speed Display Tests

@Suite("StatusBarView - Speed Display")
struct StatusBarSpeedTests {

    @Test func allGameSpeedsHaveNonEmptyDisplayLabel() {
        for speed in GameSpeed.allCases {
            #expect(!speed.displayLabel.isEmpty)
        }
    }

    @Test func displayLabelMatchesExpectedValuesForAllSpeeds() {
        #expect(GameSpeed.paused.displayLabel == "0x")
        #expect(GameSpeed.normal.displayLabel == "1x")
        #expect(GameSpeed.fast.displayLabel == "2x")
        #expect(GameSpeed.faster.displayLabel == "5x")
        #expect(GameSpeed.fastest.displayLabel == "20x")
        #expect(GameSpeed.debug.displayLabel == "100x")
        #expect(GameSpeed.debugFast.displayLabel == "300x")
    }

    @Test @MainActor func speedLabelReflectsCurrentGameStateSpeedForAllCases() {
        let expected: [GameSpeed: String] = [
            .paused: "0x", .normal: "1x", .fast: "2x",
            .faster: "5x", .fastest: "20x", .debug: "100x", .debugFast: "300x"
        ]
        let state = makeGameState()
        for speed in GameSpeed.allCases {
            state.speed = speed
            #expect(state.speed.displayLabel == expected[speed])
        }
    }

    @Test @MainActor func speedLabelRemainsCorrectWhilePaused() {
        let state = makeGameState()
        // Pausing the game does NOT change the speed property —
        // the speed button should still show the last active speed.
        state.speed = .faster
        state.isPaused = true
        #expect(state.speed.displayLabel == "5x")
    }
}

// MARK: - GameState Property Tests

@MainActor
@Suite("StatusBarView - GameState Properties")
struct StatusBarGameStateTests {

    @Test func dayCounterReflectsGameTime() {
        let state = makeGameState()
        state.gameTime.day = 42
        #expect(state.gameTime.day == 42)
    }

    @Test func pigCountReflectsAddedPigs() {
        let state = makeGameState()
        #expect(state.pigCount == 0)
        let pig = GuineaPig.create(name: "Oink", gender: .male)
        state.addGuineaPig(pig)
        #expect(state.pigCount == 1)
    }

    @Test func capacityIsPositive() {
        let state = makeGameState()
        #expect(state.capacity > 0)
    }

    @Test func farmTierDefaultsToOne() {
        let state = makeGameState()
        #expect(state.farmTier == 1)
    }

    @Test func isPausedDefaultsFalse() {
        let state = makeGameState()
        #expect(!state.isPaused)
    }
}

// MARK: - Test Helpers
// Mirror the computed property logic so tests verify the same computation
// that StatusBarView uses, without requiring SwiftUI view rendering.

@MainActor
private func computeFoodLevel(state: GameState) -> Int {
    let facilities = state.getFacilitiesByType(.foodBowl)
        + state.getFacilitiesByType(.hayRack)
        + state.getFacilitiesByType(.feastTable)
    guard !facilities.isEmpty else { return 0 }
    let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
        / Double(facilities.count)
    return Int(average.rounded())
}

@MainActor
private func computeWaterLevel(state: GameState) -> Int {
    let facilities = state.getFacilitiesByType(.waterBottle)
    guard !facilities.isEmpty else { return 0 }
    let average = facilities.reduce(0.0) { $0 + $1.fillPercentage }
        / Double(facilities.count)
    return Int(average.rounded())
}

@MainActor
private func computeLowPopWarning(state: GameState) -> Bool {
    guard state.breedingProgram.enabled else { return false }
    let adultCount = state.getPigsList().filter { !$0.isBaby }.count
    return adultCount <= GameConfig.Breeding.minBreedingPopulation
}

private func computeLowPopWarningText() -> String {
    let needed = GameConfig.Breeding.minBreedingPopulation + 1
    return "Need \(needed)+ adults"
}

private func computeLowPopAccessibilityLabel() -> String {
    let needed = GameConfig.Breeding.minBreedingPopulation + 1
    return "Low population warning: you need at least \(needed) adult pigs for breeding"
}
