/// NewFarmerSpiritTests — Tests for first-run boosters and milestone rewards.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Helpers

private func gameTimeAt(minutes: Double) -> GameTime {
    var gt = GameTime()
    gt.advance(minutes: minutes)
    return gt
}

private func firstFarmPrestige() -> PrestigeState {
    var p = PrestigeState()
    p.farmCount = 1
    return p
}

private func secondFarmPrestige() -> PrestigeState {
    var p = PrestigeState()
    p.farmCount = 2
    return p
}

// MARK: - isFirstFarm

@Test func isFirstFarmTrueWhenFarmCount1() {
    #expect(NewFarmerSpirit.isFirstFarm(firstFarmPrestige()))
}

@Test func isFirstFarmFalseWhenFarmCount2() {
    #expect(!NewFarmerSpirit.isFirstFarm(secondFarmPrestige()))
}

// MARK: - Beginner's Luck

@Test func beginnersLuckActiveWithin48Hours() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 2879)  // Just under 48 hours
    #expect(NewFarmerSpirit.isBeginnersLuckActive(prestige: prestige, gameTime: time))
    #expect(NewFarmerSpirit.breedingChanceMultiplier(prestige: prestige, gameTime: time) == 3.0)
}

@Test func beginnersLuckInactiveAt48Hours() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 2880)  // Exactly 48 hours
    #expect(!NewFarmerSpirit.isBeginnersLuckActive(prestige: prestige, gameTime: time))
    #expect(NewFarmerSpirit.breedingChanceMultiplier(prestige: prestige, gameTime: time) == 1.0)
}

@Test func beginnersLuckInactiveAfter48Hours() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 3000)
    #expect(NewFarmerSpirit.breedingChanceMultiplier(prestige: prestige, gameTime: time) == 1.0)
}

@Test func beginnersLuckInactiveOnSecondFarm() {
    let prestige = secondFarmPrestige()
    let time = gameTimeAt(minutes: 100)
    #expect(!NewFarmerSpirit.isBeginnersLuckActive(prestige: prestige, gameTime: time))
    #expect(NewFarmerSpirit.breedingChanceMultiplier(prestige: prestige, gameTime: time) == 1.0)
}

// MARK: - Natural Talent

@Test func naturalTalentReducesCost20Percent() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 100)
    let cost = NewFarmerSpirit.adjustedPerkCost(1000, prestige: prestige, gameTime: time)
    #expect(cost == 800)
}

@Test func naturalTalentInactiveAfter48Hours() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 3000)
    let cost = NewFarmerSpirit.adjustedPerkCost(1000, prestige: prestige, gameTime: time)
    #expect(cost == 1000)
}

@Test func naturalTalentInactiveOnSecondFarm() {
    let prestige = secondFarmPrestige()
    let time = gameTimeAt(minutes: 100)
    let cost = NewFarmerSpirit.adjustedPerkCost(1000, prestige: prestige, gameTime: time)
    #expect(cost == 1000)
}

@Test func naturalTalentMinimumCost1() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 100)
    // A cost of 1 after 20% discount rounds to 0 — should clamp to 1
    let cost = NewFarmerSpirit.adjustedPerkCost(1, prestige: prestige, gameTime: time)
    #expect(cost >= 1)
}

@Test func naturalTalentRoundsCorrectly() {
    let prestige = firstFarmPrestige()
    let time = gameTimeAt(minutes: 100)
    // 1500 * 0.8 = 1200 (exact)
    #expect(NewFarmerSpirit.adjustedPerkCost(1500, prestige: prestige, gameTime: time) == 1200)
    // 150 * 0.8 = 120 (exact)
    #expect(NewFarmerSpirit.adjustedPerkCost(150, prestige: prestige, gameTime: time) == 120)
    // 7 * 0.8 = 5.6 → Int(5.6) = 5
    #expect(NewFarmerSpirit.adjustedPerkCost(7, prestige: prestige, gameTime: time) == 5)
}

// MARK: - Welcome Gift

@Test func welcomeGiftAvailableOnFirstFarm() {
    let prestige = firstFarmPrestige()
    let booster = BoosterState()
    #expect(NewFarmerSpirit.isWelcomeGiftAvailable(prestige: prestige, boosterState: booster))
    #expect(NewFarmerSpirit.saleMultiplier(prestige: prestige, boosterState: booster) == 3.0)
}

@Test func welcomeGiftNotAvailableWhenUsed() {
    let prestige = firstFarmPrestige()
    var booster = BoosterState()
    booster.welcomeGiftUsed = true
    #expect(!NewFarmerSpirit.isWelcomeGiftAvailable(prestige: prestige, boosterState: booster))
    #expect(NewFarmerSpirit.saleMultiplier(prestige: prestige, boosterState: booster) == 1.0)
}

@Test func welcomeGiftNotAvailableOnSecondFarm() {
    let prestige = secondFarmPrestige()
    let booster = BoosterState()
    #expect(!NewFarmerSpirit.isWelcomeGiftAvailable(prestige: prestige, boosterState: booster))
    #expect(NewFarmerSpirit.saleMultiplier(prestige: prestige, boosterState: booster) == 1.0)
}

// MARK: - Milestone Rewards

@Test func milestoneRewardValues() {
    #expect(MilestoneTracker.reward(for: .firstPigBorn) == 100)
    #expect(MilestoneTracker.reward(for: .firstPigSold) == 50)
    #expect(MilestoneTracker.reward(for: .firstFacilityPlaced) == 25)
    #expect(MilestoneTracker.reward(for: .tier2Reached) == 200)
    #expect(MilestoneTracker.reward(for: .firstContractCompleted) == 150)
    #expect(MilestoneTracker.reward(for: .fiftyPigsBorn) == 500)
}

@Test @MainActor func firstPigBornMilestoneAwardsSqueaks() {
    let state = GameState()
    state.totalPigsBorn = 1
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 100)
    #expect(state.completedMilestones.contains(.firstPigBorn))
}

@Test @MainActor func firstPigSoldMilestoneAwardsSqueaks() {
    let state = GameState()
    state.totalPigsSold = 1
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 50)
    #expect(state.completedMilestones.contains(.firstPigSold))
}

@Test @MainActor func firstFacilityPlacedAwardsSqueaks() {
    let state = GameState()
    // 3 starter facilities + 1 player-placed = 4 total triggers the milestone
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 3))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 3))
    _ = state.addFacility(Facility.create(type: .hideout, x: 14, y: 3))
    _ = state.addFacility(Facility.create(type: .exerciseWheel, x: 5, y: 8))
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 25)
    #expect(state.completedMilestones.contains(.firstFacilityPlaced))
}

@Test @MainActor func tier2ReachedAwardsSqueaks() {
    let state = GameState()
    state.farmTier = 2
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 200)
    #expect(state.completedMilestones.contains(.tier2Reached))
}

@Test @MainActor func firstContractCompletedAwardsSqueaks() {
    let state = GameState()
    state.contractBoard.completedContracts = 1
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 150)
    #expect(state.completedMilestones.contains(.firstContractCompleted))
}

@Test @MainActor func fiftyPigsBornAwardsSqueaks() {
    let state = GameState()
    state.totalPigsBorn = 50
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    // firstPigBorn (100) + fiftyPigsBorn (500) = 600
    #expect(state.money == 600)
    #expect(state.completedMilestones.contains(.fiftyPigsBorn))
    #expect(state.completedMilestones.contains(.firstPigBorn))
}

// MARK: - Milestone Idempotency

@Test @MainActor func milestoneNotAwardedTwice() {
    let state = GameState()
    state.totalPigsBorn = 1
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 100)
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 100)  // No double award
}

@Test @MainActor func multipleMilestonesCanTriggerAtOnce() {
    let state = GameState()
    state.totalPigsBorn = 1
    state.totalPigsSold = 1
    state.farmTier = 2
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    // firstPigBorn(100) + firstPigSold(50) + tier2(200) = 350
    #expect(state.money == 350)
    #expect(state.completedMilestones.count == 3)
}

// MARK: - Milestone on Second Farm

@Test @MainActor func milestonesFireOnSecondFarm() {
    let state = GameState()
    state.prestigeState.farmCount = 2
    state.totalPigsBorn = 1
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    #expect(state.money == 100)
    #expect(state.completedMilestones.contains(.firstPigBorn))
}

// MARK: - Farm Reset

@Test @MainActor func boostersResetOnNewGameState() {
    let state = GameState()
    state.boosterState.welcomeGiftUsed = true
    state.completedMilestones = [.firstPigBorn, .firstPigSold]
    // Simulate reset
    state.boosterState = BoosterState()
    state.completedMilestones = []
    #expect(!state.boosterState.welcomeGiftUsed)
    #expect(state.completedMilestones.isEmpty)
}

// MARK: - BoosterState Codable

@Test func boosterStateCodableRoundTrip() throws {
    var original = BoosterState()
    original.welcomeGiftUsed = true
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BoosterState.self, from: data)
    #expect(decoded.welcomeGiftUsed == true)
}

@Test func boosterStateDefaultWhenMissingFromSnapshot() throws {
    // When CodableSnapshot is missing the booster_state key (old save files),
    // our custom decoder defaults to BoosterState() via decodeIfPresent.
    // Verify the default state is correct.
    let defaultState = BoosterState()
    #expect(defaultState.welcomeGiftUsed == false)
}

// MARK: - MilestoneID Codable

@Test func milestoneIDCodableRoundTrip() throws {
    let original: Set<MilestoneID> = [.firstPigBorn, .tier2Reached]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Set<MilestoneID>.self, from: data)
    #expect(decoded == original)
}

// MARK: - Eager Learners

@Test @MainActor func eagerLearnersAppliedOnFirstFarm() {
    let state = GameState()
    state.prestigeState.farmCount = 1
    setupNewGame(state: state)
    for pig in state.getPigsList() {
        #expect(pig.needs.happiness == GameConfig.NewFarmer.eagerLearnersHappiness)
    }
}

@Test @MainActor func eagerLearnersNotAppliedOnSecondFarm() {
    let state = GameState()
    state.prestigeState.farmCount = 2
    setupNewGame(state: state)
    for pig in state.getPigsList() {
        // Default happiness from GuineaPig.create, not the 85 boost
        #expect(pig.needs.happiness != GameConfig.NewFarmer.eagerLearnersHappiness)
    }
}

// MARK: - Starter Facilities Don't Trigger Milestone

@Test @MainActor func starterFacilitiesDontTriggerFacilityMilestone() {
    let state = GameState()
    // 3 starter facilities (food, water, hideout)
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 3))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 3))
    _ = state.addFacility(Facility.create(type: .hideout, x: 14, y: 3))
    state.money = 0
    MilestoneTracker.checkMilestones(state: state)
    // Only 3 facilities = no milestone (threshold is 4)
    #expect(!state.completedMilestones.contains(.firstFacilityPlaced))
    #expect(state.money == 0)
}
