/// ShopExtensionsTests -- Tests for the 5 Shop extension methods added for ShopView.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - findPlacementPosition

@Test @MainActor func findPlacementPositionReturnsPositionOnStarterFarm() {
    let state = makeGameState()
    let pos = Shop.findPlacementPosition(for: .foodBowl, in: state)
    #expect(pos != nil)
}

@Test @MainActor func findPlacementPositionReturnedPositionIsInsideArea() {
    let state = makeGameState()
    let pos = Shop.findPlacementPosition(for: .foodBowl, in: state)
    guard let area = state.farm.areas.first, let pos else {
        Issue.record("No area or no position found")
        return
    }
    #expect(pos.x >= area.interiorX1)
    #expect(pos.y >= area.interiorY1)
    #expect(pos.x <= area.interiorX2)
    #expect(pos.y <= area.interiorY2)
}

@Test @MainActor func findPlacementPositionReturnsNilWhenNoAreas() {
    let state = makeGameState()
    state.farm = FarmGrid(width: 10, height: 10)  // A bare grid with no areas
    let pos = Shop.findPlacementPosition(for: .foodBowl, in: state)
    #expect(pos == nil)
}

@Test @MainActor func findPlacementPositionAvoidsOccupiedCells() {
    let state = makeGameState()
    guard let first = Shop.findPlacementPosition(for: .foodBowl, in: state) else {
        Issue.record("No position found for first food bowl")
        return
    }
    _ = state.addFacility(Facility.create(type: .foodBowl, x: first.x, y: first.y))
    let second = Shop.findPlacementPosition(for: .foodBowl, in: state)
    // Second position should be different (or nil if farm is full)
    if let second {
        #expect(second.x != first.x || second.y != first.y)
    }
}

@Test @MainActor func findPlacementPositionForLargeFacilityOnStarterFarm() {
    let state = makeGameState()
    // hotSpring is 6x6 — large but should fit in the default starter farm interior
    let pos = Shop.findPlacementPosition(for: .hotSpring, in: state)
    // A 6x6 facility fits if the interior is >= 6x6; starter farm interior is 60x35 so it fits
    #expect(pos != nil)
}

// MARK: - getAvailablePerks

@Test func shopGetAvailablePerksAtTierOneReturnsEmpty() {
    let result = Shop.getAvailablePerks(farmTier: 1, purchased: [])
    #expect(result.isEmpty)
}

@Test func getAvailablePerksAtTierTwoReturnsNonEmpty() {
    let result = Shop.getAvailablePerks(farmTier: 2, purchased: [])
    #expect(!result.isEmpty)
}

@Test func getAvailablePerksAtTierTwoContainsOnlyEligibleTiers() {
    let result = Shop.getAvailablePerks(farmTier: 2, purchased: [])
    #expect(result.allSatisfy { $0.requiredTier <= 2 })
}

@Test func getAvailablePerksAtTierFiveReturnsAllPerks() {
    let result = Shop.getAvailablePerks(farmTier: 5, purchased: [])
    #expect(result.count == upgrades.count)
}

@Test func getAvailablePerksSortedAscendingByTier() {
    let result = Shop.getAvailablePerks(farmTier: 5, purchased: [])
    for index in 1..<result.count {
        #expect(result[index - 1].requiredTier <= result[index].requiredTier)
    }
}

@Test func getAvailablePerksDoesNotFilterAlreadyPurchased() {
    // The view shows "Owned" badge for purchased perks, so they must remain in the list
    let result = Shop.getAvailablePerks(farmTier: 2, purchased: ["bulk_feeders"])
    #expect(result.contains(where: { $0.id == "bulk_feeders" }))
}

// MARK: - purchasePerk

@Test @MainActor func shopPurchasePerkDeductsCostAndAddsToUpgrades() {
    let state = makeGameState()
    state.farmTier = 2
    let cost = upgrades["bulk_feeders"]!.cost
    state.money = cost + 100

    let success = Shop.purchasePerk(perkID: "bulk_feeders", state: state)

    #expect(success)
    #expect(state.purchasedUpgrades.contains("bulk_feeders"))
    #expect(state.money == 100)
}

@Test @MainActor func purchasePerkReturnsFalseForInsufficientFunds() {
    let state = makeGameState()
    state.farmTier = 2
    state.money = 0

    #expect(!Shop.purchasePerk(perkID: "bulk_feeders", state: state))
}

@Test @MainActor func purchasePerkReturnsFalseForDuplicatePurchase() {
    let state = makeGameState()
    state.farmTier = 2
    state.money = 10_000
    state.purchasedUpgrades.insert("bulk_feeders")

    #expect(!Shop.purchasePerk(perkID: "bulk_feeders", state: state))
}

@Test @MainActor func purchasePerkReturnsFalseForTierGating() {
    let state = makeGameState()
    state.farmTier = 1  // bulk_feeders requires tier 2
    state.money = 10_000

    #expect(!Shop.purchasePerk(perkID: "bulk_feeders", state: state))
}

@Test @MainActor func purchasePerkReturnsFalseForInvalidPerkID() {
    let state = makeGameState()
    state.farmTier = 5
    state.money = 10_000

    #expect(!Shop.purchasePerk(perkID: "nonexistent_perk", state: state))
}

// MARK: - getFarmUpgradeInfo

@Test @MainActor func getFarmUpgradeInfoAtTierOneWithOneRoomReturnsNil() {
    // Tier 1 maxRooms=1, starter farm has 1 area — already at max for this tier
    let state = makeGameState()
    state.farmTier = 1
    #expect(Shop.getFarmUpgradeInfo(state: state) == nil)
}

@Test @MainActor func getFarmUpgradeInfoAtTierTwoWithOneRoomReturnsInfo() {
    let state = makeGameState()
    state.farmTier = 2  // maxRooms=2, farm has 1 area → 1 slot available
    let info = Shop.getFarmUpgradeInfo(state: state)
    #expect(info != nil)
}

@Test @MainActor func getFarmUpgradeInfoCostMatchesRoomCosts() {
    let state = makeGameState()
    state.farmTier = 2
    let info = Shop.getFarmUpgradeInfo(state: state)
    // Starter farm has 1 area, so nextRoomCost is roomCosts[1] = "Cozy Enclosure", cost 500
    #expect(info?.cost == 500)
    #expect(info?.name == "Cozy Enclosure")
}

@Test @MainActor func getFarmUpgradeInfoRoomSizeMatchesTier() {
    let state = makeGameState()
    state.farmTier = 2
    let info = Shop.getFarmUpgradeInfo(state: state)
    let tier = getTierUpgrade(tier: 2)
    #expect(info?.width == tier.roomWidth)
    #expect(info?.height == tier.roomHeight)
    #expect(info?.capacity == tier.capacityPerRoom)
}

@Test @MainActor func getFarmUpgradeInfoReturnsNilWhenAtMaxRoomsForTier() {
    let state = makeGameState()
    state.farmTier = 2  // maxRooms=2
    // Add a second area manually to bring count up to maxRooms
    state.farm.addArea(FarmArea(
        id: UUID(), name: "Room 2", biome: .meadow,
        x1: 70, y1: 0, x2: 137, y2: 39,
        gridCol: 1, gridRow: 0
    ))
    // Now farm.areas.count == 2 == currentTier.maxRooms → should return nil
    #expect(Shop.getFarmUpgradeInfo(state: state) == nil)
}

// MARK: - facilityCost

@Test func facilityCostMatchesGetFacilityCostForFoodBowl() {
    #expect(Shop.facilityCost(.foodBowl) == Shop.getFacilityCost(facilityType: .foodBowl))
}

@Test func facilityCostMatchesGetFacilityCostForHotSpring() {
    #expect(Shop.facilityCost(.hotSpring) == Shop.getFacilityCost(facilityType: .hotSpring))
}

@Test func facilityCostMatchesGetFacilityCostForAllTypes() {
    for type in FacilityType.allCases {
        #expect(Shop.facilityCost(type) == Shop.getFacilityCost(facilityType: type))
    }
}

@Test func facilityCostFoodBowlMatchesConfig() {
    #expect(Shop.facilityCost(.foodBowl) == GameConfig.Economy.foodBowlCost)
}

@Test func facilityCostStageMatchesConfig() {
    #expect(Shop.facilityCost(.stage) == GameConfig.Economy.stageCost)
}
