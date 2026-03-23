/// ShowroomEconomyEffectsTests -- Tests for Showroom upgrade wiring into economy, QoL, and farm reset.
import Testing
@testable import BigPigFarmCore

// MARK: - Golden Touch

@Test @MainActor func goldenTouchIncreasesSaleValueBy25Percent() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .common)

    let baseValue = Market.calculatePigValue(pig: pig, state: state)

    state.prestigeState.purchasedUpgrades = [.goldenTouch]
    let boostedValue = Market.calculatePigValue(pig: pig, state: state)

    // 25 * 1.25 = 31.25 → 31
    #expect(boostedValue == Int(Double(baseValue) * 1.25))
}

@Test @MainActor func goldenTouchStacksWithPerkMultipliers() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("market_connections") // +10%
    state.prestigeState.purchasedUpgrades = [.goldenTouch]

    let pig = makeAdultPig(rarity: .common)
    let value = Market.calculatePigValue(pig: pig, state: state)

    // 25 * 1.1 (perk) * 1.25 (golden touch) = 34.375 → 34
    #expect(value == 34)
}

@Test @MainActor func goldenTouchAppearsInBreakdown() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.goldenTouch]

    let pig = makeAdultPig(rarity: .common)
    let breakdown = Market.calculatePigValueBreakdown(pig: pig, state: state)

    #expect(breakdown.showroomMultiplier == 1.25)
}

@Test @MainActor func noGoldenTouchShowroomMultiplierIsOne() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .common)
    let breakdown = Market.calculatePigValueBreakdown(pig: pig, state: state)

    #expect(breakdown.showroomMultiplier == 1.0)
}

// MARK: - Expanded Hutch

@Test @MainActor func expandedHutchAdds2CapacityPerRoom() {
    let state = makeGameState()
    let baseCapacity = state.capacity

    state.prestigeState.purchasedUpgrades = [.expandedHutch]
    let boostedCapacity = state.capacity

    #expect(boostedCapacity == baseCapacity + GameConfig.Prestige.expandedHutchCapacityBonus)
}

@Test @MainActor func expandedHutchScalesWithRoomCount() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.expandedHutch]
    let capacityWith1Room = state.capacity

    // Add a second room
    _ = GridExpansion.addRoom(&state.farm, biome: .burrow)
    let capacityWith2Rooms = state.capacity

    // Each room adds capacityPerRoom + bonus
    let perRoomTotal = capacityWith1Room
    #expect(capacityWith2Rooms == perRoomTotal * 2)
}

@Test @MainActor func expandedHutchAffectsIsAtCapacity() {
    let state = makeGameState()
    let baseCapacity = state.capacity

    // Fill to base capacity
    for i in 0..<baseCapacity {
        state.addGuineaPig(makeAdultPig(name: "Pig\(i)"))
    }
    #expect(state.isAtCapacity)

    // Enable Expanded Hutch — should no longer be at capacity
    state.prestigeState.purchasedUpgrades = [.expandedHutch]
    #expect(!state.isAtCapacity)
}

// MARK: - Quick Study

@Test @MainActor func quickStudyReducesTierRequirements() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.quickStudy]

    let tier2 = getTierUpgrade(tier: 2)
    let reqs = Shop.checkTierRequirements(state: state, upgrade: tier2)

    // With Quick Study, requirements are floor(original * 0.75)
    // Tier 2: 8 pigs → 6, 5 pigdex → 3, 0 contracts → 0
    // State starts with 0 pigs born, 0 pigdex, 0 contracts
    // All progress checks should fail (except contracts = 0)
    #expect(reqs["contracts"] == true) // floor(0 * 0.75) = 0, state has 0
    #expect(reqs["pigs_born"] == false) // floor(8 * 0.75) = 6, state has 0
    #expect(reqs["pigdex"] == false) // floor(5 * 0.75) = 3, state has 0
}

@Test @MainActor func quickStudyDoesNotReduceMoneyRequirement() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.quickStudy]
    state.totalPigsBorn = 100
    for i in 0..<100 {
        _ = state.pigdex.registerPhenotype(key: "test:\(i)", gameDay: 1)
    }
    state.contractBoard.completedContracts = 50

    let tier2 = getTierUpgrade(tier: 2)

    // Set money to just below the cost
    state.money = tier2.cost - 1
    let reqs = Shop.checkTierRequirements(state: state, upgrade: tier2)
    #expect(reqs["money"] == false) // Money requirement is NOT reduced
}

@Test @MainActor func quickStudyAllowsEarlierTierPurchase() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.quickStudy]

    let tier2 = getTierUpgrade(tier: 2)
    // Tier 2 requires 8 pigs born → reduced to 6
    state.totalPigsBorn = 6
    // Tier 2 requires 5 pigdex → reduced to 3
    for i in 0..<3 {
        _ = state.pigdex.registerPhenotype(key: "test:\(i)", gameDay: 1)
    }
    // Tier 2 requires 0 contracts → still 0
    state.money = tier2.cost

    let reqs = Shop.checkTierRequirements(state: state, upgrade: tier2)
    #expect(reqs.values.allSatisfy { $0 })
}

// MARK: - Auto-Pilot

@Test @MainActor func autoPilotGrantsBulkFeedersAndDripOnReset() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.autoPilot]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.purchasedUpgrades.contains("bulk_feeders"))
    #expect(state.purchasedUpgrades.contains("drip_system"))
}

@Test @MainActor func autoPilotDoublesFacilityCapacity() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.autoPilot]

    let engine = GameEngine(state: state)
    engine.farmReset()

    // setupNewGame creates foodBowl and waterBottle — bulk_feeders should have doubled them
    let foodFacilities = state.getFacilitiesByType(.foodBowl)
    let waterFacilities = state.getFacilitiesByType(.waterBottle)

    for facility in foodFacilities + waterFacilities {
        let defaultCapacity = Double(facility.info.capacity)
        #expect(facility.maxAmount == defaultCapacity * 2)
    }
}

@Test @MainActor func autoPilotWithoutResetDoesNotAffectPerks() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.autoPilot]
    // Without farmReset, purchasedUpgrades should be unaffected
    #expect(!state.purchasedUpgrades.contains("bulk_feeders"))
}

// MARK: - Keepsake Slot

@Test @MainActor func keepsakePerksAppliedOnReset() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.keepsakeSlot]
    state.prestigeState.keepsakePerks = ["market_connections", "paved_paths"]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.purchasedUpgrades.contains("market_connections"))
    #expect(state.purchasedUpgrades.contains("paved_paths"))
}

@Test @MainActor func keepsakeSlotWithBulkFeedersAppliesImmediateEffect() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.keepsakeSlot]
    state.prestigeState.keepsakePerks = ["bulk_feeders"]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.purchasedUpgrades.contains("bulk_feeders"))

    // bulk_feeders should have doubled food/water facilities
    let foodFacilities = state.getFacilitiesByType(.foodBowl)
    for facility in foodFacilities {
        let defaultCapacity = Double(facility.info.capacity)
        #expect(facility.maxAmount == defaultCapacity * 2)
    }
}

@Test @MainActor func keepsakeSlotWithoutUpgradeDoesNotApplyPerks() {
    let state = makeGameState()
    // keepsakeSlot NOT purchased, but keepsakePerks has entries
    state.prestigeState.keepsakePerks = ["market_connections"]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(!state.purchasedUpgrades.contains("market_connections"))
}

@Test @MainActor func keepsakeMaxThreePerks() {
    #expect(GameConfig.Prestige.keepsakeMaxSlots == 3)
}

// MARK: - Treat Basket / Treat Wagon (Regular Perks)

@Test @MainActor func treatBasketPerkExists() {
    let def = upgrades["treat_basket"]
    #expect(def != nil)
    #expect(def?.name == "Treat Basket")
    #expect(def?.category == "Treats")
    #expect(def?.implemented == true)
}

@Test @MainActor func treatWagonPerkExists() {
    let def = upgrades["treat_wagon"]
    #expect(def != nil)
    #expect(def?.name == "Treat Wagon")
    #expect(def?.category == "Treats")
    #expect(def?.implemented == true)
}

@Test @MainActor func treatCapacityConstants() {
    #expect(GameConfig.Prestige.treatBasketBonusTreats == 1)
    #expect(GameConfig.Prestige.treatWagonBonusTreats == 2)
}

// MARK: - hasShowroomUpgrade Protocol

@Test @MainActor func hasShowroomUpgradeForwardsToPrestigeState() {
    let state = makeGameState()

    #expect(!state.hasShowroomUpgrade(.goldenTouch))

    state.prestigeState.purchasedUpgrades = [.goldenTouch]
    #expect(state.hasShowroomUpgrade(.goldenTouch))
}

// MARK: - ShowroomUpgrade Enum

@Test func showroomUpgradeCountIs25() {
    #expect(ShowroomUpgrade.allCases.count == 25)
}

@Test func autoPilotAndQuickStudyExist() {
    #expect(ShowroomUpgrade.autoPilot.rawValue == "auto_pilot")
    #expect(ShowroomUpgrade.quickStudy.rawValue == "quick_study")
}

@Test func autoPilotIsExpertTier() {
    #expect(ShowroomUpgrade.autoPilot.tier == .expert)
}

@Test func quickStudyIsApprenticeTier() {
    #expect(ShowroomUpgrade.quickStudy.tier == .apprentice)
}
