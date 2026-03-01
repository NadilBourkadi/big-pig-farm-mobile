/// AdoptionViewTests — Integration tests for AdoptionView action logic.
///
/// Tests exercise the same code paths as AdoptionView's private methods
/// against a real GameState to verify correctness without requiring a live view.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Adopt Action Tests

@Test @MainActor func adoptPigDeductsMoney() {
    let state = makeGameState()
    state.money = 200
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let cost = Adoption.calculateAdoptionCost(pig, state: state)
    var adoptedPig = pig
    if let pos = Adoption.findSpawnPosition(in: state) {
        adoptedPig.position = Position(x: Double(pos.x), y: Double(pos.y))
    }
    _ = state.spendMoney(cost)
    state.addGuineaPig(adoptedPig)
    #expect(state.money == 200 - cost)
}

@Test @MainActor func adoptPigAddsToFarm() {
    let state = makeGameState()
    state.money = 500
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let cost = Adoption.calculateAdoptionCost(pig, state: state)
    var adoptedPig = pig
    if let pos = Adoption.findSpawnPosition(in: state) {
        adoptedPig.position = Position(x: Double(pos.x), y: Double(pos.y))
    }
    _ = state.spendMoney(cost)
    state.addGuineaPig(adoptedPig)
    #expect(state.pigCount == 1)
}

@Test @MainActor func adoptPigPositionIsSet() {
    let state = makeGameState()
    state.money = 500
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    var adoptedPig = pig
    if let pos = Adoption.findSpawnPosition(in: state) {
        adoptedPig.position = Position(x: Double(pos.x), y: Double(pos.y))
        state.addGuineaPig(adoptedPig)
        let added = state.getGuineaPig(adoptedPig.id)
        #expect(added?.position.x == Double(pos.x))
        #expect(added?.position.y == Double(pos.y))
    }
}

@Test @MainActor func adoptPigLogsEvent() {
    let state = makeGameState()
    state.money = 500
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let cost = Adoption.calculateAdoptionCost(pig, state: state)
    var adoptedPig = pig
    if let pos = Adoption.findSpawnPosition(in: state) {
        adoptedPig.position = Position(x: Double(pos.x), y: Double(pos.y))
    }
    _ = state.spendMoney(cost)
    state.addGuineaPig(adoptedPig)
    state.logEvent(
        "Adopted \(pig.name) (\(pig.phenotype.displayName)) for \(cost) Squeaks",
        eventType: "adoption"
    )
    #expect(state.events.last?.eventType == "adoption")
    #expect(state.events.last?.message.contains(pig.name) == true)
}

@Test @MainActor func adoptAtCapacityFails() {
    let state = makeGameState()
    // Fill farm to capacity (starter farm = 8 pigs)
    for i in 0..<8 {
        let pig = GuineaPig.create(name: "Pig\(i)", gender: .female, ageDays: 5.0)
        state.addGuineaPig(pig)
    }
    #expect(state.isAtCapacity)
    // Eligibility check should return a non-nil error message
    #expect(Adoption.isEligibleForAdoption(state: state) != nil)
}

@Test @MainActor func adoptWithInsufficientFundsFails() {
    let state = makeGameState()
    state.money = 0
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let cost = Adoption.calculateAdoptionCost(pig, state: state)
    // spendMoney should fail when money < cost
    let succeeded = state.spendMoney(cost)
    #expect(!succeeded)
    #expect(state.money == 0)
    #expect(state.pigCount == 0)
}

// MARK: - Refresh Action Tests

@Test @MainActor func refreshGeneratesBatch() {
    let state = makeGameState()
    let existingNames: Set<String> = []
    // Run multiple refreshes and verify we always get 3–5 pigs
    for _ in 0..<5 {
        let batch = Adoption.generateAdoptionBatch(
            existingNames: existingNames,
            farmTier: state.farmTier,
            count: Int.random(in: 3...5)
        )
        #expect(batch.count >= 3)
        #expect(batch.count <= 5)
    }
}

@Test @MainActor func refreshExcludesExistingNames() {
    let state = makeGameState()
    // Add a pig to the farm
    let farmPig = GuineaPig.create(name: "Butterscotch", gender: .female, ageDays: 5.0)
    state.addGuineaPig(farmPig)

    let existingNames = Set(state.getPigsList().map(\.name))
    let batch = Adoption.generateAdoptionBatch(
        existingNames: existingNames,
        farmTier: state.farmTier,
        count: 5
    )
    for pig in batch {
        #expect(!existingNames.contains(pig.name))
    }
}

// MARK: - Economics Invariant

@Test @MainActor func adoptionCostExceedsSaleValue() {
    let state = makeGameState()
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let adoptionCost = Adoption.calculateAdoptionCost(pig, state: state)
    let saleValue = Market.calculatePigValue(pig: pig, state: state)
    #expect(adoptionCost > saleValue)
}
