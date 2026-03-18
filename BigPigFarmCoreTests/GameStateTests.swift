/// GameStateTests -- Unit tests for the GameState observable container.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Guinea Pig Management

@Test @MainActor func addGuineaPig() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Squeaky", gender: .female)
    state.addGuineaPig(pig)
    #expect(state.pigCount == 1)
    #expect(state.getGuineaPig(pig.id) != nil)
}

@Test @MainActor func removeGuineaPig() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Squeaky", gender: .female)
    state.addGuineaPig(pig)
    let removed = state.removeGuineaPig(pig.id)
    #expect(removed != nil)
    #expect(state.pigCount == 0)
    #expect(state.getGuineaPig(pig.id) == nil)
}

@Test @MainActor func removeGuineaPigNonexistent() {
    let state = GameState()
    let result = state.removeGuineaPig(UUID())
    #expect(result == nil)
}

@Test @MainActor func getPigsListReturnsBothPigs() {
    let state = GameState()
    let pig1 = GuineaPig.create(name: "A", gender: .male)
    let pig2 = GuineaPig.create(name: "B", gender: .female)
    state.addGuineaPig(pig1)
    state.addGuineaPig(pig2)
    let list = state.getPigsList()
    #expect(list.count == 2)
}

// MARK: - Facility Management

@Test @MainActor func addAndGetFacility() {
    let state = GameState()
    let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    let added = state.addFacility(bowl)
    #expect(added)
    #expect(state.getFacility(bowl.id) != nil)
}

@Test @MainActor func removeFacility() {
    let state = GameState()
    let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = state.addFacility(bowl)
    let removed = state.removeFacility(bowl.id)
    #expect(removed != nil)
    #expect(state.getFacility(bowl.id) == nil)
}

@Test @MainActor func removeFacilityNonexistent() {
    let state = GameState()
    let result = state.removeFacility(UUID())
    #expect(result == nil)
}

@Test @MainActor func getFacilitiesByType() {
    let state = GameState()
    let bowl1 = Facility.create(type: .foodBowl, x: 5, y: 5)
    let bowl2 = Facility.create(type: .foodBowl, x: 15, y: 5)
    let water = Facility.create(type: .waterBottle, x: 10, y: 5)
    _ = state.addFacility(bowl1)
    _ = state.addFacility(bowl2)
    _ = state.addFacility(water)
    #expect(state.getFacilitiesByType(.foodBowl).count == 2)
    #expect(state.getFacilitiesByType(.waterBottle).count == 1)
    #expect(state.getFacilitiesByType(.hideout).isEmpty)
}

// MARK: - Economy

@Test @MainActor func startingMoney() {
    let state = GameState()
    #expect(state.money == GameConfig.Economy.startingMoney)
}

@Test @MainActor func addMoney() {
    let state = GameState()
    state.addMoney(50)
    #expect(state.money == GameConfig.Economy.startingMoney + 50)
    #expect(state.totalEarnings == 50)
}

@Test @MainActor func addMoneyNegativeDoesNotTrackEarnings() {
    let state = GameState()
    state.addMoney(-10)
    #expect(state.money == GameConfig.Economy.startingMoney - 10)
    #expect(state.totalEarnings == 0)
}

@Test @MainActor func spendMoneySuccess() {
    let state = GameState()
    let success = state.spendMoney(50)
    #expect(success)
    #expect(state.money == GameConfig.Economy.startingMoney - 50)
}

@Test @MainActor func spendMoneyInsufficient() {
    let state = GameState()
    let success = state.spendMoney(GameConfig.Economy.startingMoney + 1)
    #expect(!success)
    #expect(state.money == GameConfig.Economy.startingMoney)
}

// MARK: - Event Log

@Test @MainActor func logEvent() {
    let state = GameState()
    state.logEvent("Test event")
    #expect(state.events.count == 1)
    #expect(state.events[0].message == "Test event")
    #expect(state.events[0].eventType == "info")
    #expect(state.events[0].gameDay == state.gameTime.day)
}

@Test @MainActor func logEventTrimming() {
    let state = GameState()
    for i in 0..<150 {
        state.logEvent("Event \(i)")
    }
    #expect(state.events.count == state.maxEvents)
    #expect(state.events.last?.message == "Event 149")
}

// MARK: - Breeding Pair

@Test @MainActor func setAndClearBreedingPair() {
    let state = GameState()
    let maleID = UUID()
    let femaleID = UUID()
    state.setBreedingPair(maleID: maleID, femaleID: femaleID)
    #expect(state.breedingPair != nil)
    #expect(state.breedingPair?.maleId == maleID)
    #expect(state.breedingPair?.femaleId == femaleID)
    state.clearBreedingPair()
    #expect(state.breedingPair == nil)
}

// MARK: - Social Affinity

@Test @MainActor func affinityKeyIsCanonical() {
    let id1 = UUID()
    let id2 = UUID()
    let key1 = GameState.affinityKey(id1, id2)
    let key2 = GameState.affinityKey(id2, id1)
    #expect(key1 == key2)
}

@Test @MainActor func incrementAffinity() {
    let state = GameState()
    let id1 = UUID()
    let id2 = UUID()
    #expect(state.getAffinity(id1, id2) == 0)
    state.incrementAffinity(id1, id2)
    #expect(state.getAffinity(id1, id2) == 1)
}

@Test @MainActor func affinityCapsAtTen() {
    let state = GameState()
    let id1 = UUID()
    let id2 = UUID()
    for _ in 0..<15 {
        state.incrementAffinity(id1, id2)
    }
    #expect(state.getAffinity(id1, id2) == 10)
}

@Test @MainActor func removeGuineaPigPrunesAffinity() {
    let state = GameState()
    let pig1 = GuineaPig.create(name: "A", gender: .male)
    let pig2 = GuineaPig.create(name: "B", gender: .female)
    let pig3 = GuineaPig.create(name: "C", gender: .male)
    state.addGuineaPig(pig1)
    state.addGuineaPig(pig2)
    state.addGuineaPig(pig3)
    state.incrementAffinity(pig1.id, pig2.id)
    state.incrementAffinity(pig1.id, pig3.id)
    state.incrementAffinity(pig2.id, pig3.id)
    #expect(state.socialAffinity.count == 3)
    _ = state.removeGuineaPig(pig1.id)
    #expect(state.socialAffinity.count == 1)
    #expect(state.getAffinity(pig2.id, pig3.id) == 1)
}

// MARK: - Upgrades

@Test @MainActor func hasUpgrade() {
    let state = GameState()
    #expect(!state.hasUpgrade("speed_boost"))
    state.purchasedUpgrades.insert("speed_boost")
    #expect(state.hasUpgrade("speed_boost"))
}

// MARK: - Capacity

@Test @MainActor func isAtCapacity() {
    let state = GameState()
    for i in 0..<8 {
        state.addGuineaPig(GuineaPig.create(name: "Pig\(i)", gender: .male))
    }
    #expect(state.isAtCapacity)
}

@Test @MainActor func belowCapacity() {
    let state = GameState()
    state.addGuineaPig(GuineaPig.create(name: "Solo", gender: .female))
    #expect(!state.isAtCapacity)
    #expect(state.capacity == 8)
}

// MARK: - Default Values

@Test @MainActor func defaultValues() {
    let state = GameState()
    #expect(state.guineaPigs.isEmpty)
    #expect(state.facilities.isEmpty)
    #expect(state.money == GameConfig.Economy.startingMoney)
    #expect(state.speed == .normal)
    #expect(!state.isPaused)
    #expect(state.events.isEmpty)
    #expect(state.pigdex.discoveredCount == 0)
    #expect(state.farmTier == 1)
    #expect(state.purchasedUpgrades.isEmpty)
    #expect(state.totalPigsBorn == 0)
    #expect(state.totalPigsSold == 0)
    #expect(state.totalEarnings == 0)
    #expect(state.breedingPair == nil)
    #expect(state.lastSave == nil)
}

// MARK: - Sendable Conformance

@Test @MainActor func gameStateIsSendable() {
    let state = GameState()
    let _: any Sendable = state
}
