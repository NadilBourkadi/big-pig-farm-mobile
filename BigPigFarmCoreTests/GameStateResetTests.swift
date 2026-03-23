/// GameStateResetTests -- Unit tests for GameState.resetToNewGame().
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Reset Clears Collections

@Test @MainActor func resetToNewGameClearsPigs() {
    let state = GameState()
    state.addGuineaPig(GuineaPig.create(name: "Squeaky", gender: .female))
    state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .male))
    #expect(state.pigCount == 2)
    state.resetToNewGame()
    #expect(state.pigCount == 0)
    #expect(state.getPigsList().isEmpty)
}

@Test @MainActor func resetToNewGameClearsFacilities() {
    let state = GameState()
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 5))
    #expect(!state.getFacilitiesList().isEmpty)
    state.resetToNewGame()
    #expect(state.getFacilitiesList().isEmpty)
}

// MARK: - Reset Restores Defaults

@Test @MainActor func resetToNewGameResetsMoney() {
    let state = GameState()
    state.money = 99999
    state.resetToNewGame()
    #expect(state.money == GameConfig.Economy.startingMoney)
}

@Test @MainActor func resetToNewGameResetsGameTime() {
    let state = GameState()
    state.gameTime.advance(minutes: 5000)
    #expect(state.gameTime.totalGameMinutes > 0)
    state.resetToNewGame()
    #expect(state.gameTime.totalGameMinutes == 0)
    #expect(state.gameTime.day == 1)
    #expect(state.gameTime.hour == 8)
}

@Test @MainActor func resetToNewGameResetsSpeed() {
    let state = GameState()
    state.speed = .fast
    state.isPaused = true
    state.resetToNewGame()
    #expect(state.speed == .normal)
    #expect(!state.isPaused)
}

@Test @MainActor func resetToNewGameResetsFarm() {
    let state = GameState()
    let starterAreaCount = FarmGrid.createStarter().areas.count
    state.resetToNewGame()
    #expect(state.farm.areas.count == starterAreaCount)
}

// MARK: - Reset Clears Progression

@Test @MainActor func resetToNewGameClearsStatistics() {
    let state = GameState()
    state.totalPigsBorn = 42
    state.totalPigsSold = 10
    state.totalEarnings = 50000
    state.resetToNewGame()
    #expect(state.totalPigsBorn == 0)
    #expect(state.totalPigsSold == 0)
    #expect(state.totalEarnings == 0)
}

@Test @MainActor func resetToNewGameClearsPigdex() {
    let state = GameState()
    let key = phenotypeKeyFromParts(
        baseColor: .black, pattern: .solid,
        intensity: .full, roan: .none
    )
    _ = state.pigdex.registerPhenotype(key: key, gameDay: 1)
    #expect(state.pigdex.discoveredCount == 1)
    state.resetToNewGame()
    #expect(state.pigdex.discoveredCount == 0)
}

@Test @MainActor func resetToNewGameClearsSocialAffinity() {
    let state = GameState()
    let id1 = UUID()
    let id2 = UUID()
    state.incrementAffinity(id1, id2)
    #expect(state.getAffinity(id1, id2) == 1)
    state.resetToNewGame()
    #expect(state.getAffinity(id1, id2) == 0)
}

@Test @MainActor func resetToNewGameClearsUpgrades() {
    let state = GameState()
    state.purchasedUpgrades.insert("auto_feeder")
    #expect(state.hasUpgrade("auto_feeder"))
    state.resetToNewGame()
    #expect(!state.hasUpgrade("auto_feeder"))
}

@Test @MainActor func resetToNewGameResetsBreedingState() {
    let state = GameState()
    state.setBreedingPair(maleID: UUID(), femaleID: UUID())
    #expect(state.breedingPair != nil)
    state.resetToNewGame()
    #expect(state.breedingPair == nil)
}

@Test @MainActor func resetToNewGameResetsFarmTier() {
    let state = GameState()
    state.farmTier = 3
    state.resetToNewGame()
    #expect(state.farmTier == 1)
}

@Test @MainActor func resetToNewGameClearsEvents() {
    let state = GameState()
    state.events.append(EventLog(
        timestamp: Date(), gameDay: 1,
        message: "Test event", eventType: "info"
    ))
    #expect(!state.events.isEmpty)
    state.resetToNewGame()
    #expect(state.events.isEmpty)
}

@Test @MainActor func resetToNewGameResetsSimulationTick() {
    let state = GameState()
    state.advanceSimulationTick()
    state.advanceSimulationTick()
    #expect(state.simulationTick == 2)
    state.resetToNewGame()
    #expect(state.simulationTick == 0)
}

@Test @MainActor func resetToNewGameResetsPrestigeState() {
    let state = GameState()
    state.prestigeState.rosetteBalance = 500
    state.prestigeState.farmCount = 3
    state.prestigeState.previousPigdexEntries.insert("black_solid_full_none")
    state.resetToNewGame()
    #expect(state.prestigeState.rosetteBalance == 0)
    #expect(state.prestigeState.farmCount == 1)
    #expect(state.prestigeState.previousPigdexEntries.isEmpty)
}
