/// StatusBarViewTests — Tests for StatusBarView computed properties.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Food Level Tests

@MainActor
@Suite("StatusBarView - Food Level")
struct StatusBarFoodLevelTests {

    @Test func foodLevelIsZeroWithNoFacilities() {
        let state = makeGameState()
        let facilities = state.getFacilitiesByType(.foodBowl)
            + state.getFacilitiesByType(.hayRack)
        #expect(facilities.isEmpty)
        // foodLevel would be 0 when no facilities exist
        let level = computeFoodLevel(state: state)
        #expect(level == 0)
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
