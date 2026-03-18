/// AdoptionTests -- Tests for the Adoption business logic namespace.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Test Helpers

/// Make a pig with a specific rarity and optional bloodline origin tag.
private func makeAdoptionPig(rarity: Rarity = .common, originTag: String? = nil) -> GuineaPig {
    var pig = GuineaPig.create(name: "TestPig", gender: .female, ageDays: 5.0)
    pig.phenotype = Phenotype(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: rarity
    )
    pig.originTag = originTag
    return pig
}

// MARK: - isEligibleForAdoption

@Test @MainActor func isEligibleForAdoptionWhenUnderCapacity() {
    let state = makeGameState()
    // Starter farm capacity is 8; state has 0 pigs — eligible
    #expect(Adoption.isEligibleForAdoption(state: state) == nil)
}

@Test @MainActor func isEligibleForAdoptionWhenAtCapacity() {
    let state = makeGameState()
    // Starter farm capacity is 8 (tier 1, 1 room); fill it up
    for i in 0..<8 {
        let pig = GuineaPig.create(name: "Pig\(i)", gender: .female, ageDays: 5.0)
        state.addGuineaPig(pig)
    }
    #expect(state.isAtCapacity)
    #expect(Adoption.isEligibleForAdoption(state: state) != nil)
}

// MARK: - calculateAdoptionCost

@Test @MainActor func calculateAdoptionCostCommonPig() {
    let state = makeGameState()
    let pig = makeAdoptionPig(rarity: .common)
    // 50 * 1.0 = 50
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 50)
}

@Test @MainActor func calculateAdoptionCostUncommonPig() {
    let state = makeGameState()
    let pig = makeAdoptionPig(rarity: .uncommon)
    // 50 * 1.5 = 75
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 75)
}

@Test @MainActor func calculateAdoptionCostRarePig() {
    let state = makeGameState()
    let pig = makeAdoptionPig(rarity: .rare)
    // 50 * 2.5 = 125
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 125)
}

@Test @MainActor func calculateAdoptionCostVeryRarePig() {
    let state = makeGameState()
    let pig = makeAdoptionPig(rarity: .veryRare)
    // 50 * 4.0 = 200
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 200)
}

@Test @MainActor func calculateAdoptionCostLegendaryPig() {
    let state = makeGameState()
    let pig = makeAdoptionPig(rarity: .legendary)
    // 50 * 10.0 = 500
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 500)
}

@Test @MainActor func calculateAdoptionCostSpottedBloodlinePig() {
    let state = makeGameState()
    // Spotted bloodline: costMultiplier = 1.5
    let pig = makeAdoptionPig(rarity: .common, originTag: "Spotted Bloodline")
    // 50 * 1.0 * 1.5 = 75
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 75)
}

@Test @MainActor func calculateAdoptionCostRoanBloodlinePig() {
    let state = makeGameState()
    // Roan bloodline: costMultiplier = 3.0
    let pig = makeAdoptionPig(rarity: .rare, originTag: "Roan Bloodline")
    // 50 * 2.5 * 3.0 = 375
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 375)
}

@Test @MainActor func calculateAdoptionCostAdoptionDiscountApplied() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("adoption_discount")
    let pig = makeAdoptionPig(rarity: .common)
    // Int(50 * 1.0 * 0.85) = Int(42.5) = 42
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 42)
}

@Test @MainActor func calculateAdoptionCostBloodlineAndDiscount() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("adoption_discount")
    // Spotted bloodline (1.5×) + discount (0.85×)
    let pig = makeAdoptionPig(rarity: .common, originTag: "Spotted Bloodline")
    // Int(50 * 1.0 * 1.5 * 0.85) = Int(63.75) = 63
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 63)
}

@Test @MainActor func calculateAdoptionCostUnknownOriginTagIgnored() {
    let state = makeGameState()
    // A tag that matches no bloodline should not apply any multiplier
    let pig = makeAdoptionPig(rarity: .common, originTag: "Unknown Tag")
    #expect(Adoption.calculateAdoptionCost(pig, state: state) == 50)
}

// MARK: - availableBloodlines

@Test func adoptionGetAvailableBloodlinesTier1() {
    let result = Adoption.availableBloodlines(farmTier: 1)
    // Tier 1: Spotted (1) and Chocolate (1)
    #expect(result.count == 2)
    #expect(result.allSatisfy { $0.requiredTier <= 1 })
}

@Test func adoptionGetAvailableBloodlinesTier4() {
    let result = Adoption.availableBloodlines(farmTier: 4)
    // Tier 4: all 7 bloodlines (Spotted, Chocolate, Golden, Silver, Roan, ExoticSpotSilver, ExoticRoanSilver)
    #expect(result.count == 7)
}

@Test func adoptionGetAvailableBloodlinesTier0ReturnsEmpty() {
    let result = Adoption.availableBloodlines(farmTier: 0)
    #expect(result.isEmpty)
}

// MARK: - generateAdoptionPig

@Test func generateAdoptionPigIsAdult() {
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    // Adults have ageDays >= 3 (GameConfig.Simulation.adultAgeDays)
    #expect(pig.ageDays == 5.0)
    #expect(pig.isAdult)
}

@Test func generateAdoptionPigHasUniqueName() {
    let existing: Set<String> = ["Butterscotch", "Peanut", "Nugget"]
    let pig = Adoption.generateAdoptionPig(existingNames: existing, farmTier: 1)
    #expect(!existing.contains(pig.name))
}

@Test func generateAdoptionPigHasValidGender() {
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    #expect(pig.gender == .male || pig.gender == .female)
}

@Test func generateAdoptionPigHasUniqueId() {
    let pig1 = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1)
    let pig2 = Adoption.generateAdoptionPig(existingNames: [pig1.name], farmTier: 1)
    #expect(pig1.id != pig2.id)
}

@Test func generateAdoptionPigTier0HasNoBloodline() {
    // Tier 0: no bloodlines available, so originTag should always be nil
    var allNil = true
    for _ in 0..<20 {
        let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 0)
        if pig.originTag != nil {
            allNil = false
            break
        }
    }
    #expect(allNil)
}

// MARK: - generateAdoptionBatch

@Test func generateAdoptionBatchCorrectCount() {
    let pigs = Adoption.generateAdoptionBatch(existingNames: [], farmTier: 1, count: 4)
    #expect(pigs.count == 4)
}

@Test func generateAdoptionBatchUniqueNames() {
    let pigs = Adoption.generateAdoptionBatch(existingNames: [], farmTier: 1, count: 5)
    let names = Set(pigs.map { $0.name })
    #expect(names.count == 5)
}

@Test func generateAdoptionBatchUniqueIds() {
    let pigs = Adoption.generateAdoptionBatch(existingNames: [], farmTier: 1, count: 5)
    let ids = Set(pigs.map { $0.id })
    #expect(ids.count == 5)
}

@Test func generateAdoptionBatchRespectsExistingNames() {
    let existing: Set<String> = ["Butterscotch", "Peanut", "Nugget"]
    let pigs = Adoption.generateAdoptionBatch(existingNames: existing, farmTier: 1, count: 3)
    for pig in pigs {
        #expect(!existing.contains(pig.name))
    }
}

@Test func generateAdoptionBatchEmptyCountReturnsEmpty() {
    let pigs = Adoption.generateAdoptionBatch(existingNames: [], farmTier: 1, count: 0)
    #expect(pigs.isEmpty)
}

// MARK: - findSpawnPosition

@Test @MainActor func findSpawnPositionReturnsPositionOnStarterGrid() {
    let state = makeGameState()
    let position = Adoption.findSpawnPosition(in: state)
    #expect(position != nil)
}

@Test @MainActor func findSpawnPositionReturnedPositionIsOnGrid() {
    let state = makeGameState()
    if let position = Adoption.findSpawnPosition(in: state) {
        #expect(position.x >= 0)
        #expect(position.y >= 0)
    }
}
