/// NewGameSetupTests — Tests for starter pig creation across farm counts.
/// Regression coverage for bead 9woc: post-prestige pigs must be breedable.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Starter Pig Happiness

@Test @MainActor func starterPigsHaveElevatedHappinessOnFirstFarm() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.prestigeState.farmCount = 1

    setupNewGame(state: state)

    let pigs = Array(state.guineaPigs.values)
    #expect(pigs.count == 2)
    for pig in pigs {
        #expect(
            pig.needs.happiness == GameConfig.NewFarmer.eagerLearnersHappiness,
            "First-farm starter pig should have elevated happiness"
        )
    }
}

@Test @MainActor func starterPigsHaveElevatedHappinessAfterPrestige() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.prestigeState.farmCount = 2

    setupNewGame(state: state)

    let pigs = Array(state.guineaPigs.values)
    #expect(pigs.count == 2)
    for pig in pigs {
        #expect(
            pig.needs.happiness == GameConfig.NewFarmer.eagerLearnersHappiness,
            "Post-prestige starter pig should have elevated happiness"
        )
    }
}

@Test @MainActor func starterPigHappinessAboveBreedingThreshold() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.prestigeState.farmCount = 3

    setupNewGame(state: state)

    let threshold = Double(GameConfig.Breeding.minHappinessToBreed)
    for pig in state.guineaPigs.values {
        #expect(
            pig.needs.happiness >= threshold,
            "Starter pig happiness \(pig.needs.happiness) must be >= breeding threshold \(threshold)"
        )
    }
}

// MARK: - Breeding Eligibility

@Test @MainActor func starterPigsAreBreedableOnDay1AfterPrestige() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.prestigeState.farmCount = 2

    setupNewGame(state: state)

    for pig in state.guineaPigs.values {
        #expect(
            pig.isBreedable(prestige: state.prestigeState),
            """
            Post-prestige starter pig '\(pig.name)' must be breedable: \
            \(pig.checkBreedingBlock(prestige: state.prestigeState) ?? "nil")
            """
        )
    }
}

@Test @MainActor func starterPigsHaveOneMaleAndOneFemale() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.prestigeState.farmCount = 2

    setupNewGame(state: state)

    let males = state.guineaPigs.values.filter { $0.gender == .male }
    let females = state.guineaPigs.values.filter { $0.gender == .female }
    #expect(males.count == 1, "Should have exactly 1 male starter pig")
    #expect(females.count == 1, "Should have exactly 1 female starter pig")
}

// MARK: - Happiness Threshold Edge Cases

@Test @MainActor func pigAtExactBreedingThresholdIsBreedable() {
    var pig = GuineaPig.create(name: "Edge", gender: .female)
    pig.ageDays = Double(GameConfig.Breeding.minAgeDays)
    pig.needs.happiness = Double(GameConfig.Breeding.minHappinessToBreed)

    let prestige = PrestigeState()
    #expect(
        pig.isBreedable(prestige: prestige),
        "Pig at exactly the happiness threshold should be breedable (check is <, not <=)"
    )
}

@Test @MainActor func pigBelowBreedingThresholdIsNotBreedable() {
    var pig = GuineaPig.create(name: "Sad", gender: .female)
    pig.ageDays = Double(GameConfig.Breeding.minAgeDays)
    pig.needs.happiness = Double(GameConfig.Breeding.minHappinessToBreed) - 0.1

    let prestige = PrestigeState()
    #expect(!pig.isBreedable(prestige: prestige))

    let reason = pig.checkBreedingBlock(prestige: prestige)
    #expect(reason?.contains("Unhappy") == true)
}
