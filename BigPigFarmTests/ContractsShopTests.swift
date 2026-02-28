/// ContractsShopTests -- Tests for Contracts, ContractGenerator, Upgrades, and Shop.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Contracts: matchesPig

@Test func matchesPigColorMatch() {
    let pig = makeAdultPig(rarity: .common)
    let contract = makeContract(color: .black)
    #expect(contract.matchesPig(pig))
}

@Test func matchesPigColorMismatch() {
    let pig = makeAdultPig(rarity: .common)
    let contract = makeContract(color: .chocolate)
    #expect(!contract.matchesPig(pig))
}

@Test func matchesPigFulfilledReturnsFalse() {
    let pig = makeAdultPig(rarity: .common)
    let contract = makeContract(color: .black, fulfilled: true)
    #expect(!contract.matchesPig(pig))
}

@Test func matchesPigPatternMatch() {
    var pig = makeAdultPig()
    pig.phenotype = Phenotype(baseColor: .black, pattern: .dutch, intensity: .full, roan: .none, rarity: .uncommon)
    let contract = makeContract(color: .black, pattern: .dutch)
    #expect(contract.matchesPig(pig))
}

@Test func matchesPigPatternMismatch() {
    var pig = makeAdultPig()
    pig.phenotype = Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common)
    let contract = makeContract(color: .black, pattern: .dutch)
    #expect(!contract.matchesPig(pig))
}

@Test func matchesPigBiomeRequirementWithNoBirthAreaReturnsFalse() {
    var pig = makeAdultPig()
    pig.birthAreaId = nil
    let contract = makeContract(color: .black, biome: .meadow)
    #expect(!contract.matchesPig(pig))
}

// MARK: - Contracts: checkAndFulfill

@Test @MainActor func checkAndFulfillReturnsFirstMatch() {
    let pig = makeAdultPig(rarity: .common)
    var board = ContractBoard()
    board.activeContracts = [
        makeContract(color: .chocolate), // no match
        makeContract(color: .black, reward: 500), // match
    ]

    let result = board.checkAndFulfill(pig)

    #expect(result?.reward == 500)
    #expect(board.completedContracts == 1)
    // totalContractEarnings is updated by Market.sellPig after applying bonuses,
    // not by checkAndFulfill — so it stays 0 here.
    #expect(board.totalContractEarnings == 0)
}

@Test @MainActor func checkAndFulfillReturnsNilWhenNoMatch() {
    let pig = makeAdultPig(rarity: .common)
    var board = ContractBoard()
    board.activeContracts = [makeContract(color: .chocolate)]

    let result = board.checkAndFulfill(pig)

    #expect(result == nil)
    #expect(board.completedContracts == 0)
}

@Test @MainActor func checkAndFulfillMarksFulfilled() {
    let pig = makeAdultPig(rarity: .common)
    var board = ContractBoard()
    board.activeContracts = [makeContract(color: .black)]

    _ = board.checkAndFulfill(pig)

    #expect(board.activeContracts[0].fulfilled)
}

// MARK: - ContractGenerator

@Test @MainActor func generateContractsReturnsCorrectCountAtTierOne() {
    let state = makeGameState()
    state.farmTier = 1
    let contracts = ContractGenerator.generateContracts(
        farmTier: 1, gameDay: 1, availableBiomes: [.meadow], gameState: state
    )
    // min(4, max(2, 1)) = 2
    #expect(contracts.count == 2)
}

@Test @MainActor func generateContractsTierOneOnlyEasy() {
    let state = makeGameState()
    let contracts = ContractGenerator.generateContracts(
        farmTier: 1, gameDay: 1, availableBiomes: [.meadow], gameState: state
    )
    #expect(contracts.allSatisfy { $0.difficulty == .easy })
}

@Test @MainActor func generateContractsTierTwoIncludesMedium() {
    let state = makeGameState()
    state.farmTier = 2
    // Run many times to confirm medium can appear
    var seenMedium = false
    for _ in 0..<100 {
        let contracts = ContractGenerator.generateContracts(
            farmTier: 2, gameDay: 1, availableBiomes: [.meadow], gameState: state
        )
        if contracts.contains(where: { $0.difficulty == .medium }) {
            seenMedium = true
            break
        }
    }
    #expect(seenMedium)
}

@Test @MainActor func generateContractsLegendaryRequiresUpgrade() {
    let state = makeGameState()
    state.farmTier = 5
    // Without vip_contracts perk, legendary should never appear
    let contracts = ContractGenerator.generateContracts(
        farmTier: 5, gameDay: 1, availableBiomes: [.meadow], gameState: state
    )
    #expect(!contracts.contains(where: { $0.difficulty == .legendary }))
}

@Test @MainActor func generateContractsTierFiveWithVipUnlocksLegendary() {
    let state = makeGameState()
    state.farmTier = 5
    state.purchasedUpgrades.insert("vip_contracts")
    var seenLegendary = false
    for _ in 0..<200 {
        let contracts = ContractGenerator.generateContracts(
            farmTier: 5, gameDay: 1, availableBiomes: [.meadow], gameState: state
        )
        if contracts.contains(where: { $0.difficulty == .legendary }) {
            seenLegendary = true
            break
        }
    }
    #expect(seenLegendary)
}

@Test @MainActor func generateContractsTierOneNoSmokeColor() {
    let state = makeGameState()
    // smoke is tier-4 color; should never appear at tier 1
    for _ in 0..<100 {
        let contracts = ContractGenerator.generateContracts(
            farmTier: 1, gameDay: 1, availableBiomes: [.meadow], gameState: state
        )
        #expect(!contracts.contains(where: { $0.requiredColor == .smoke }))
    }
}

// MARK: - Upgrades

@Test @MainActor func getAvailablePerksAtTierOneReturnsEmpty() {
    // All upgrades require tier 2+, so tier 1 has no available perks.
    let state = makeGameState()
    state.farmTier = 1
    let perks = Upgrades.getAvailablePerks(state: state)
    #expect(perks.isEmpty)
}

@Test @MainActor func getAvailablePerksAtTierTwoReturnsTierTwoUpgrades() {
    let state = makeGameState()
    state.farmTier = 2
    let perks = Upgrades.getAvailablePerks(state: state)
    #expect(!perks.isEmpty)
    #expect(perks.allSatisfy { $0.requiredTier <= 2 })
}

@Test @MainActor func getAvailablePerksExcludesHigherTier() {
    let state = makeGameState()
    state.farmTier = 2
    let perks = Upgrades.getAvailablePerks(state: state)
    #expect(!perks.contains(where: { $0.requiredTier > 2 }))
}

@Test @MainActor func purchasePerkDeductsCostAndAddsToUpgrades() {
    let state = makeGameState()
    state.farmTier = 2
    let def = upgrades["bulk_feeders"]!
    state.money = def.cost + 100

    let success = Upgrades.purchasePerk(state: state, upgradeId: "bulk_feeders")

    #expect(success)
    #expect(state.purchasedUpgrades.contains("bulk_feeders"))
    #expect(state.money == 100)
}

@Test @MainActor func purchasePerkReturnsFalseForDuplicate() {
    let state = makeGameState()
    state.farmTier = 2
    state.purchasedUpgrades.insert("bulk_feeders")
    state.money = 10_000

    #expect(!Upgrades.purchasePerk(state: state, upgradeId: "bulk_feeders"))
}

@Test @MainActor func purchasePerkReturnsFalseForWrongTier() {
    let state = makeGameState()
    state.farmTier = 1
    state.money = 10_000
    // bulk_feeders requires tier 2
    #expect(!Upgrades.purchasePerk(state: state, upgradeId: "bulk_feeders"))
}

@Test @MainActor func purchasePerkReturnsFalseForInsufficientMoney() {
    let state = makeGameState()
    state.farmTier = 2
    state.money = 0
    #expect(!Upgrades.purchasePerk(state: state, upgradeId: "bulk_feeders"))
}

@Test @MainActor func bulkFeederDoublesExistingFoodWaterCapacity() {
    let state = makeGameState()
    state.farmTier = 2
    state.money = 10_000

    let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
    let initialMax = facility.maxAmount
    _ = state.addFacility(facility)

    Upgrades.purchasePerk(state: state, upgradeId: "bulk_feeders")

    let updated = state.getFacilitiesByType(.foodBowl).first
    #expect(updated?.maxAmount == initialMax * 2)
}

// MARK: - Shop

@Test func getShopItemsReturnsSortedByTier() {
    let items = Shop.getShopItems()
    for index in 1..<items.count {
        #expect(items[index - 1].requiredTier <= items[index].requiredTier)
    }
}

@Test func getShopItemsFacilitiesCategoryFilterReturnsCorrectCount() {
    let items = Shop.getShopItems(category: .facilities)
    #expect(!items.isEmpty)
    #expect(items.allSatisfy { $0.category == .facilities })
}

@Test func getShopItemsMarksLockedAtTierOne() {
    let items = Shop.getShopItems(farmTier: 1)
    // Tier-2 items should be locked
    let tier2Items = items.filter { $0.requiredTier == 2 }
    #expect(tier2Items.allSatisfy { !$0.unlocked })
}

@Test func getShopItemsMarksUnlockedAtCurrentTier() {
    let items = Shop.getShopItems(farmTier: 1)
    let tier1Items = items.filter { $0.requiredTier == 1 }
    #expect(tier1Items.allSatisfy { $0.unlocked })
}

@Test @MainActor func getNextTierUpgradeAtTierOneReturnsTierTwo() {
    let state = makeGameState()
    state.farmTier = 1
    let upgrade = Shop.getNextTierUpgrade(state: state)
    #expect(upgrade?.tier == 2)
}

@Test @MainActor func getNextTierUpgradeAtMaxTierReturnsNil() {
    let state = makeGameState()
    state.farmTier = 5
    #expect(Shop.getNextTierUpgrade(state: state) == nil)
}

@Test @MainActor func checkTierRequirementsCorrectFlags() {
    let state = makeGameState()
    state.farmTier = 1
    state.money = 0
    state.totalPigsBorn = 0
    let upgrade = tierUpgrades.first { $0.tier == 2 }!

    let reqs = Shop.checkTierRequirements(state: state, upgrade: upgrade)

    #expect(reqs["money"] == false)
}

@Test @MainActor func purchaseTierUpgradeReturnsFalseAtMaxTier() {
    let state = makeGameState()
    state.farmTier = 5
    #expect(!Shop.purchaseTierUpgrade(state: state))
}
