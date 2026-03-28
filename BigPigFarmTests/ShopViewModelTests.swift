/// ShopViewModelTests — Tests for ShopViewModel purchase and data logic.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Facilities

@Suite("ShopViewModel — Facilities")
@MainActor
struct ShopViewModelFacilitiesTests {

    @Test("facilityItemsByTier returns items grouped and sorted by tier")
    func facilityItemsByTierGrouped() {
        let state = makeGameState()
        state.farmTier = 5
        let vm = ShopViewModel(gameState: state)
        let groups = vm.facilityItemsByTier
        for i in 1..<groups.count {
            #expect(groups[i - 1].tier <= groups[i].tier)
        }
    }

    @Test("facilityItems returns all 17 items at max tier")
    func facilityItemsCountAtMaxTier() {
        let state = makeGameState()
        state.farmTier = 5
        let vm = ShopViewModel(gameState: state)
        #expect(vm.facilityItems.count == 17)
    }

    @Test("purchaseFacility shows error when no space available")
    func purchaseFacilityNoSpace() {
        let state = makeGameState()
        state.money = 100_000
        let vm = ShopViewModel(gameState: state)
        // Fill the farm until placement fails
        for _ in 0..<50 {
            for item in vm.facilityItems {
                vm.purchaseFacility(item)
            }
        }
        // Reset alert state and try one more — space must be exhausted by now
        vm.showingAlert = false
        vm.purchaseFacility(vm.facilityItems[0])
        #expect(vm.showingAlert == true)
    }
}

// MARK: - Perks

@Suite("ShopViewModel — Perks")
@MainActor
struct ShopViewModelPerksTests {

    @Test("perksByCategory returns empty at tier 1")
    func perksEmptyAtTierOne() {
        let state = makeGameState()
        state.farmTier = 1
        let vm = ShopViewModel(gameState: state)
        #expect(vm.perksByCategory.isEmpty)
    }

    @Test("isPerkOwned returns false for unowned perk")
    func isPerkOwnedFalse() {
        let state = makeGameState()
        let vm = ShopViewModel(gameState: state)
        #expect(vm.isPerkOwned("nonexistent_perk") == false)
    }

    @Test("isPerkOwned returns true for owned perk")
    func isPerkOwnedTrue() {
        let state = makeGameState()
        state.purchasedUpgrades.insert("test_perk")
        let vm = ShopViewModel(gameState: state)
        #expect(vm.isPerkOwned("test_perk") == true)
    }
}

// MARK: - Farm Tier

@Suite("ShopViewModel — Farm Tier")
@MainActor
struct ShopViewModelFarmTierTests {

    @Test("nextTier returns nil at max tier")
    func nextTierNilAtMax() {
        let state = makeGameState()
        state.farmTier = 5
        let vm = ShopViewModel(gameState: state)
        #expect(vm.nextTier == nil)
    }

    @Test("nextTier returns upgrade at tier 1")
    func nextTierExistsAtTierOne() {
        let state = makeGameState()
        state.farmTier = 1
        let vm = ShopViewModel(gameState: state)
        #expect(vm.nextTier != nil)
        #expect(vm.nextTier?.tier == 2)
    }

    @Test("allRequirementsMet is false when no pigs born")
    func allRequirementsNotMet() {
        let state = makeGameState()
        state.farmTier = 1
        state.money = 10_000
        let vm = ShopViewModel(gameState: state)
        #expect(vm.allRequirementsMet == false)
    }

    @Test("upgradeTier fails when requirements unmet")
    func upgradeTierFails() {
        let state = makeGameState()
        state.farmTier = 1
        state.money = 10_000
        let vm = ShopViewModel(gameState: state)
        vm.upgradeTier()
        #expect(state.farmTier == 1)
        #expect(vm.showingAlert == true)
    }

    @Test("roomInfo returns value when room expansion available")
    func roomInfoAvailable() {
        let state = makeGameState()
        state.farmTier = 2
        state.farm.tier = 2
        let vm = ShopViewModel(gameState: state)
        #expect(vm.roomInfo != nil)
    }

    @Test("purchaseRoom succeeds with sufficient funds")
    func purchaseRoomSuccess() {
        let state = makeGameState()
        state.farmTier = 2
        state.farm.tier = 2
        state.money = 10_000
        let vm = ShopViewModel(gameState: state)
        let initialAreas = state.farm.areas.count

        vm.purchaseRoom(biome: .meadow)

        #expect(state.farm.areas.count == initialAreas + 1)
    }

    @Test("purchaseRoom fails with insufficient funds")
    func purchaseRoomFails() {
        let state = makeGameState()
        state.farmTier = 2
        state.farm.tier = 2
        state.money = 0
        let vm = ShopViewModel(gameState: state)

        vm.purchaseRoom(biome: .meadow)

        #expect(vm.showingAlert == true)
        #expect(vm.alertMessage.contains("failed"))
    }
}

// MARK: - Alert

@Suite("ShopViewModel — Alert")
@MainActor
struct ShopViewModelAlertTests {

    @Test("showError sets alertMessage and showingAlert")
    func showErrorSetsState() {
        let vm = ShopViewModel(gameState: makeGameState())
        vm.showError("Test error")
        #expect(vm.alertMessage == "Test error")
        #expect(vm.showingAlert == true)
    }
}
