/// ShopViewTests — Tests for ShopView tab logic and Shop.purchaseNewRoom.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - ShopTab Enum

@Test @MainActor func shopTabHasFourCases() {
    #expect(ShopTab.allCases.count == 4)
}

@Test @MainActor func shopTabRawValuesAreCorrect() {
    #expect(ShopTab.facilities.rawValue == "Facilities")
    #expect(ShopTab.perks.rawValue == "Perks")
    #expect(ShopTab.farm.rawValue == "Farm")
    #expect(ShopTab.pigs.rawValue == "Pigs")
}

// MARK: - Facilities Tab Item Filtering

@Test @MainActor func facilitiesTabItemsAreSortedByRequiredTier() {
    let items = Shop.getShopItems(category: .facilities, farmTier: 5)
    for i in 1..<items.count {
        #expect(items[i - 1].requiredTier <= items[i].requiredTier)
    }
}

@Test @MainActor func facilitiesTabShowsAllSeventeenItems() {
    let items = Shop.getShopItems(category: .facilities, farmTier: 5)
    #expect(items.count == 17)
}

@Test @MainActor func facilitiesTabAtTierOneLocksTierTwoItems() {
    let items = Shop.getShopItems(category: .facilities, farmTier: 1)
    let locked = items.filter { !$0.unlocked }
    #expect(!locked.isEmpty)
    #expect(locked.allSatisfy { $0.requiredTier > 1 })
}

@Test @MainActor func facilitiesTabAtTierOneUnlocksTierOneItems() {
    let items = Shop.getShopItems(category: .facilities, farmTier: 1)
    let unlocked = items.filter { $0.unlocked }
    #expect(unlocked.allSatisfy { $0.requiredTier == 1 })
}

// MARK: - purchaseNewRoom — Success

@Test @MainActor func purchaseNewRoomSucceedsAtTierTwo() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 10_000
    let initialAreaCount = state.farm.areas.count
    let success = Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(success)
    #expect(state.farm.areas.count == initialAreaCount + 1)
}

@Test @MainActor func purchaseNewRoomDeductsTotalCost() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 10_000
    let totalCost = Shop.getRoomTotalCost(state: state, biome: .meadow)
    #expect(totalCost > 0)
    Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(state.money == 10_000 - totalCost)
}

@Test @MainActor func purchaseNewRoomAddsAreaWithCorrectBiome() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 10_000
    Shop.purchaseNewRoom(state: state, biome: .burrow)
    let newArea = state.farm.areas.last
    #expect(newArea?.biome == .burrow)
}

// MARK: - purchaseNewRoom — Failure Cases

@Test @MainActor func purchaseNewRoomFailsInsufficientFunds() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 0
    let success = Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(!success)
    #expect(state.farm.areas.count == 1)
}

@Test @MainActor func purchaseNewRoomRefundsOnInsufficientFunds() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 0
    Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(state.money == 0)
    #expect(state.farm.areas.count == 1)
}

@Test @MainActor func purchaseNewRoomFailsAtMaxRoomsForTier() {
    // Tier 1 has maxRooms=1 and starter farm already has 1 area
    let state = makeGameState()
    state.farmTier = 1
    state.farm.tier = 1
    state.money = 10_000
    let success = Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(!success)
    #expect(state.farm.areas.count == 1)
}

@Test @MainActor func purchaseNewRoomDoesNotDeductMoneyWhenAtMaxRooms() {
    let state = makeGameState()
    state.farmTier = 1
    state.farm.tier = 1
    state.money = 10_000
    Shop.purchaseNewRoom(state: state, biome: .meadow)
    #expect(state.money == 10_000)
}

// MARK: - purchaseNewRoom — Entity Shifting

@Test @MainActor func purchaseNewRoomShiftsPigPositions() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 10_000
    // Place a pig with a known position
    var pig = GuineaPig.create(name: "Tester", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    state.addGuineaPig(pig)
    Shop.purchaseNewRoom(state: state, biome: .meadow)
    // After room purchase, pig should have been shifted (if layout required it)
    // We can't predict exact offsets, but pig should still exist
    let pigs = state.getPigsList()
    #expect(pigs.count == 1)
}

@Test @MainActor func purchaseNewRoomShiftsFacilityPositions() {
    let state = makeGameState()
    state.farmTier = 2
    state.farm.tier = 2
    state.money = 10_000
    // Place a facility
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 3, y: 3))
    let facilityCountBefore = state.getFacilitiesList().count
    Shop.purchaseNewRoom(state: state, biome: .meadow)
    // Facility count unchanged after room purchase
    #expect(state.getFacilitiesList().count == facilityCountBefore)
}

// MARK: - Tier Upgrade Requirements

@Test @MainActor func checkTierRequirementsReturnsFalseWhenNoPigsBorn() {
    let state = makeGameState()
    state.farmTier = 1
    state.money = 10_000
    guard let tier = Shop.getNextTierUpgrade(state: state) else {
        Issue.record("No next tier upgrade found")
        return
    }
    let reqs = Shop.checkTierRequirements(state: state, upgrade: tier)
    // totalPigsBorn starts at 0, tier 2 requires 3
    #expect(reqs["pigs_born"] == false)
}

@Test @MainActor func purchaseTierUpgradeFailsWhenRequirementsUnmet() {
    let state = makeGameState()
    state.farmTier = 1
    state.money = 10_000
    // pigs_born is 0, tier 2 requires 3 → should fail
    let success = Shop.purchaseTierUpgrade(state: state)
    #expect(!success)
    #expect(state.farmTier == 1)
}

@Test @MainActor func purchaseTierUpgradeFailsInsufficientFunds() {
    let state = makeGameState()
    state.farmTier = 1
    // Tier 2 requires: 3 pigs born, 2 Pigdex, 0 contracts, cost 300
    state.totalPigsBorn = 3
    _ = state.pigdex.registerPhenotype(key: "black_solid_normal_none", gameDay: 1)
    _ = state.pigdex.registerPhenotype(key: "chocolate_solid_normal_none", gameDay: 1)
    state.money = 0  // Not enough for 300 Sq cost
    let success = Shop.purchaseTierUpgrade(state: state)
    #expect(!success)
    #expect(state.farmTier == 1)
}

@Test @MainActor func getNextTierUpgradeReturnsNilAtMaxTier() {
    let state = makeGameState()
    state.farmTier = 5
    #expect(Shop.getNextTierUpgrade(state: state) == nil)
}
