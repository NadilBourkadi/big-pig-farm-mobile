/// ManualRefillTests — Unit tests for GameState.manualRefillAll() and related properties.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Helpers

/// Add a partially-drained food bowl to the state. Returns the facility.
@MainActor
@discardableResult
private func addPartialFoodBowl(to state: GameState, x: Int, y: Int, amount: Double = 50) -> Facility {
    var bowl = Facility.create(type: .foodBowl, x: x, y: y)
    bowl.currentAmount = amount
    _ = state.addFacility(bowl)
    return bowl
}

/// Add a partially-drained water bottle to the state. Returns the facility.
@MainActor
@discardableResult
private func addPartialWaterBottle(to state: GameState, x: Int, y: Int, amount: Double = 50) -> Facility {
    var bottle = Facility.create(type: .waterBottle, x: x, y: y)
    bottle.currentAmount = amount
    _ = state.addFacility(bottle)
    return bottle
}

// MARK: - refillableCount

@Test @MainActor func refillableCountIsZeroWithNoFacilities() {
    let state = GameState()
    #expect(state.refillableCount == 0)
}

@Test @MainActor func refillableCountExcludesNonRefillableFacilities() {
    let state = GameState()
    var hideout = Facility.create(type: .hideout, x: 5, y: 5)
    hideout.currentAmount = 0
    _ = state.addFacility(hideout)
    var wheel = Facility.create(type: .exerciseWheel, x: 10, y: 5)
    wheel.currentAmount = 0
    _ = state.addFacility(wheel)
    #expect(state.refillableCount == 0)
}

@Test @MainActor func refillableCountExcludesFullFacilities() {
    let state = GameState()
    // Facility.create() initializes currentAmount == maxAmount (full)
    let bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = state.addFacility(bowl)
    #expect(state.refillableCount == 0)
    #expect(state.totalRefillCost == 0)
}

@Test @MainActor func refillableCountIncludesPartialFoodBowl() {
    let state = GameState()
    addPartialFoodBowl(to: state, x: 5, y: 5)
    #expect(state.refillableCount == 1)
    #expect(state.totalRefillCost == 5)
}

@Test @MainActor func refillableCountIncludesPartialWaterBottle() {
    let state = GameState()
    addPartialWaterBottle(to: state, x: 5, y: 5)
    #expect(state.refillableCount == 1)
    #expect(state.totalRefillCost == 2)
}

// MARK: - totalRefillCost

@Test @MainActor func totalRefillCostSumsAllEligible() {
    let state = GameState()
    addPartialFoodBowl(to: state, x: 5, y: 5)
    addPartialFoodBowl(to: state, x: 8, y: 5)
    addPartialWaterBottle(to: state, x: 11, y: 5)
    // foodBowl: 5 + 5, waterBottle: 2 → total 12
    #expect(state.totalRefillCost == 12)
    #expect(state.refillableCount == 3)
}

@Test @MainActor func totalRefillCostExcludesHayRack() {
    let state = GameState()
    var rack = Facility.create(type: .hayRack, x: 5, y: 5)
    rack.currentAmount = 0
    _ = state.addFacility(rack)
    // hayRack has refillCost == 0, so even when empty it doesn't contribute
    #expect(state.totalRefillCost == 0)
    #expect(state.refillableCount == 0)
}

// MARK: - manualRefillAll

@Test @MainActor func manualRefillAllSucceedsWithSufficientFunds() {
    let state = GameState()
    state.money = 100
    let bowl = addPartialFoodBowl(to: state, x: 5, y: 5, amount: 50)
    let result = state.manualRefillAll()
    #expect(result)
    #expect(state.money == 95)  // 100 - 5
    let refilled = state.getFacility(bowl.id)
    #expect(refilled?.currentAmount == refilled?.maxAmount)
}

@Test @MainActor func manualRefillAllRefillsToMax() {
    let state = GameState()
    state.money = 100
    let bowl = addPartialFoodBowl(to: state, x: 5, y: 5, amount: 10)
    let max = state.getFacility(bowl.id)?.maxAmount ?? 0
    state.manualRefillAll()
    let after = state.getFacility(bowl.id)?.currentAmount ?? 0
    #expect(after == max)
}

@Test @MainActor func manualRefillAllInsufficientFunds() {
    let state = GameState()
    state.money = 3  // food bowl costs 5 — not enough
    let bowl = addPartialFoodBowl(to: state, x: 5, y: 5, amount: 50)
    let amountBefore = state.getFacility(bowl.id)?.currentAmount ?? 0
    let result = state.manualRefillAll()
    #expect(!result)
    #expect(state.money == 3)  // unchanged
    #expect(state.getFacility(bowl.id)?.currentAmount == amountBefore)  // unchanged
}

@Test @MainActor func manualRefillAllReturnsFalseWhenNoEligibleFacilities() {
    let state = GameState()
    state.money = 100
    // Full food bowl — nothing to refill
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    let result = state.manualRefillAll()
    #expect(!result)
    #expect(state.money == 100)  // no deduction
}

@Test @MainActor func manualRefillAllReturnsFalseWithEmptyState() {
    let state = GameState()
    state.money = 100
    let result = state.manualRefillAll()
    #expect(!result)
}

@Test @MainActor func manualRefillAllSkipsFullFacilitiesInMixedSet() {
    let state = GameState()
    state.money = 100
    // Full food bowl — excluded
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    // Partial water bottle — eligible
    let bottle = addPartialWaterBottle(to: state, x: 8, y: 5, amount: 50)
    let result = state.manualRefillAll()
    #expect(result)
    #expect(state.money == 98)  // only water bottle cost (2)
    let refilled = state.getFacility(bottle.id)
    #expect(refilled?.currentAmount == refilled?.maxAmount)
}

@Test @MainActor func manualRefillAllLogsEvent() {
    let state = GameState()
    state.money = 100
    addPartialFoodBowl(to: state, x: 5, y: 5)
    let countBefore = state.events.count
    state.manualRefillAll()
    #expect(state.events.count == countBefore + 1)
    #expect(state.events.last?.eventType == "purchase")
}

@Test @MainActor func refillableCountIsZeroAfterSuccessfulRefill() {
    let state = GameState()
    state.money = 100
    addPartialFoodBowl(to: state, x: 5, y: 5)
    addPartialWaterBottle(to: state, x: 8, y: 5)
    #expect(state.refillableCount == 2)
    state.manualRefillAll()
    #expect(state.refillableCount == 0)
}

// MARK: - hasFacilitiesToRefill

@Test @MainActor func hasFacilitiesToRefillIsFalseWithNoFacilities() {
    let state = GameState()
    #expect(!state.hasFacilitiesToRefill)
}

@Test @MainActor func hasFacilitiesToRefillIsFalseWhenAllFull() {
    let state = GameState()
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    #expect(!state.hasFacilitiesToRefill)
}

@Test @MainActor func hasFacilitiesToRefillIsTrueWhenPartiallyDrained() {
    let state = GameState()
    addPartialFoodBowl(to: state, x: 5, y: 5)
    #expect(state.hasFacilitiesToRefill)
}

// MARK: - canAffordRefill

@Test @MainActor func canAffordRefillIsFalseWithNoFacilities() {
    let state = GameState()
    state.money = 1000
    #expect(!state.canAffordRefill)
}

@Test @MainActor func canAffordRefillIsFalseWhenInsufficientFunds() {
    let state = GameState()
    state.money = 1  // food bowl costs 5
    addPartialFoodBowl(to: state, x: 5, y: 5)
    #expect(state.hasFacilitiesToRefill)
    #expect(!state.canAffordRefill)
}

@Test @MainActor func canAffordRefillIsTrueWhenExactFunds() {
    let state = GameState()
    addPartialFoodBowl(to: state, x: 5, y: 5)
    state.money = state.totalRefillCost  // exactly enough
    #expect(state.canAffordRefill)
}

@Test @MainActor func canAffordRefillIsTrueWhenSufficientFunds() {
    let state = GameState()
    state.money = 100
    addPartialFoodBowl(to: state, x: 5, y: 5)
    #expect(state.hasFacilitiesToRefill)
    #expect(state.canAffordRefill)
}

// MARK: - Three-state distinction

@Test @MainActor func threeStateDistinction() {
    let state = GameState()

    // State 1: No facilities to refill
    #expect(!state.hasFacilitiesToRefill)
    #expect(!state.canAffordRefill)
    #expect(!state.isRefillEnabled)

    // State 2: Facilities need refilling but can't afford
    addPartialFoodBowl(to: state, x: 5, y: 5)
    state.money = 1  // food bowl costs 5
    #expect(state.hasFacilitiesToRefill)
    #expect(!state.canAffordRefill)
    #expect(!state.isRefillEnabled)

    // State 3: Facilities need refilling and can afford
    state.money = 100
    #expect(state.hasFacilitiesToRefill)
    #expect(state.canAffordRefill)
    #expect(state.isRefillEnabled)
}

@Test @MainActor func manualRefillAllRefillsMultipleFacilities() {
    let state = GameState()
    state.money = 100
    let bowl = addPartialFoodBowl(to: state, x: 5, y: 5, amount: 20)
    let bottle = addPartialWaterBottle(to: state, x: 8, y: 5, amount: 30)
    let result = state.manualRefillAll()
    #expect(result)
    #expect(state.money == 93)  // 100 - 5 - 2
    let refilledBowl = state.getFacility(bowl.id)
    let refilledBottle = state.getFacility(bottle.id)
    #expect(refilledBowl?.currentAmount == refilledBowl?.maxAmount)
    #expect(refilledBottle?.currentAmount == refilledBottle?.maxAmount)
}
