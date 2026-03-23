/// PigShowTests — Tests for Pig Show visibility threshold and prestige trigger logic.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Pig Show Visibility Threshold

@Test @MainActor func pigShowHiddenBelowThreshold() {
    let state = makeGameState()
    state.totalEarnings = GameConfig.Prestige.pigShowLifetimeSqueaksThreshold - 1

    let lifetime = state.prestigeState.lifetimeStats.totalSqueaksEarned
    let current = state.totalEarnings
    let eligible = lifetime + current >= GameConfig.Prestige.pigShowLifetimeSqueaksThreshold
    #expect(!eligible)
}

@Test @MainActor func pigShowVisibleAtExactThreshold() {
    let state = makeGameState()
    state.totalEarnings = GameConfig.Prestige.pigShowLifetimeSqueaksThreshold

    let lifetime = state.prestigeState.lifetimeStats.totalSqueaksEarned
    let current = state.totalEarnings
    let eligible = lifetime + current >= GameConfig.Prestige.pigShowLifetimeSqueaksThreshold
    #expect(eligible)
}

@Test @MainActor func pigShowVisibleWithCombinedLifetimeAndCurrent() {
    let state = makeGameState()
    state.prestigeState.lifetimeStats.totalSqueaksEarned = 40_000
    state.totalEarnings = 10_000

    let lifetime = state.prestigeState.lifetimeStats.totalSqueaksEarned
    let current = state.totalEarnings
    let eligible = lifetime + current >= GameConfig.Prestige.pigShowLifetimeSqueaksThreshold
    #expect(eligible)
}

@Test @MainActor func pigShowVisibleFromLifetimeAlone() {
    let state = makeGameState()
    state.prestigeState.lifetimeStats.totalSqueaksEarned = 60_000
    state.totalEarnings = 0

    let lifetime = state.prestigeState.lifetimeStats.totalSqueaksEarned
    let current = state.totalEarnings
    let eligible = lifetime + current >= GameConfig.Prestige.pigShowLifetimeSqueaksThreshold
    #expect(eligible)
}

// MARK: - triggerPrestige()

@Test @MainActor func triggerPrestigeAwardsRosettes() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    state.prestigeState.rosetteBalance = 0
    let engine = GameEngine(state: state)

    let breakdown = engine.triggerPrestige()

    #expect(breakdown.total > 0)
    #expect(state.prestigeState.rosetteBalance == breakdown.total)
}

@Test @MainActor func triggerPrestigePreservesExistingRosettes() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    state.prestigeState.rosetteBalance = 5
    let engine = GameEngine(state: state)

    let breakdown = engine.triggerPrestige()

    #expect(state.prestigeState.rosetteBalance == 5 + breakdown.total)
}

@Test @MainActor func triggerPrestigeIncrementsFarmCount() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    let initialFarmCount = state.prestigeState.farmCount
    let engine = GameEngine(state: state)

    _ = engine.triggerPrestige()

    #expect(state.prestigeState.farmCount == initialFarmCount + 1)
}

@Test @MainActor func triggerPrestigeCarriesOverPigdex() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    state.pigdex.discovered["agouti:solid:normal:none"] = 1
    state.pigdex.discovered["black:spotted:dark:none"] = 2
    let engine = GameEngine(state: state)

    _ = engine.triggerPrestige()

    #expect(state.prestigeState.previousPigdexEntries.contains("agouti:solid:normal:none"))
    #expect(state.prestigeState.previousPigdexEntries.contains("black:spotted:dark:none"))
}

@Test @MainActor func triggerPrestigeAccumulatesLifetimeStats() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    state.totalPigsBorn = 25
    state.totalPigsSold = 10
    state.prestigeState.lifetimeStats.totalPigsBred = 50
    state.prestigeState.lifetimeStats.totalSqueaksEarned = 40_000
    let engine = GameEngine(state: state)

    _ = engine.triggerPrestige()

    #expect(state.prestigeState.lifetimeStats.totalPigsBred == 75)
    #expect(state.prestigeState.lifetimeStats.totalSqueaksEarned == 120_000)
    #expect(state.prestigeState.lifetimeStats.totalPigsSold == 10)
}

@Test @MainActor func triggerPrestigeClearsPerFarmState() {
    let state = makeGameState()
    state.totalEarnings = 80_000
    state.money = 5000
    let engine = GameEngine(state: state)

    _ = engine.triggerPrestige()

    // Per-farm stats should be reset
    #expect(state.totalEarnings == 0)
    #expect(state.totalPigsBorn == 0)
    #expect(state.money == GameConfig.Economy.startingMoney)
}

@Test @MainActor func triggerPrestigeWithZeroStatsDoesNotCrash() {
    let state = makeGameState()
    state.totalEarnings = 0
    state.prestigeState.rosetteBalance = 0
    let engine = GameEngine(state: state)

    let breakdown = engine.triggerPrestige()

    // Zero stats means zero rosettes earned — that's fine
    #expect(breakdown.total == 0)
    #expect(state.prestigeState.rosetteBalance == 0)
}

// MARK: - RosetteBreakdown Scoring Dimensions

@Test @MainActor func rosetteBreakdownContainsAllDimensions() {
    let state = makeGameState()
    state.totalEarnings = 100_000
    // Add some Pigdex entries
    state.pigdex.discovered["agouti:solid:normal:none"] = 1
    // Add pigs for diversity
    var pig = GuineaPig.create(name: "ShowPig", gender: .female)
    pig.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig)
    // Complete a contract
    state.contractBoard.completedContracts = 6

    let breakdown = PigShowCalculator.evaluate(
        gameState: state,
        prestigeState: state.prestigeState
    )

    // Base rosettes from sqrt(100_000 / baseDivisor) should be > 0
    #expect(breakdown.baseRosettes > 0)
    // 1 new pigdex entry / pigdexDivisor
    #expect(breakdown.pigdexBonus >= 0)
    // 1 unique phenotype / diversityDivisor
    #expect(breakdown.diversityBonus >= 0)
    // 6 contracts / contractDivisor
    #expect(breakdown.contractBonus >= 0)
    // Total is sum of all dimensions
    let expectedTotal = breakdown.baseRosettes + breakdown.pigdexBonus
        + breakdown.diversityBonus + breakdown.contractBonus
        + breakdown.rarityBonus + breakdown.streakBonus
    #expect(breakdown.total == expectedTotal)
}
