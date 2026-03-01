/// AlmanacViewTests — Unit tests for AlmanacView data logic.
/// Tests focus on model/data correctness, not SwiftUI rendering.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - AlmanacTab

@Test func almanacTabHasThreeCases() {
    // AlmanacTab is not CaseIterable, so verify raw values exist for all three
    #expect(AlmanacTab.pigdex.rawValue == "Pigdex")
    #expect(AlmanacTab.contracts.rawValue == "Contracts")
    #expect(AlmanacTab.log.rawValue == "Log")
}

// MARK: - Pigdex Grid

@Test func pigdexGridHas144TotalSlots() {
    #expect(getAllPhenotypeKeys().count == 144)
}

@Test func pigdexDiscoveredCountMatchesRegistered() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    _ = pigdex.registerPhenotype(key: "chocolate:solid:full:none", gameDay: 2)
    _ = pigdex.registerPhenotype(key: "golden:solid:full:none", gameDay: 3)
    #expect(pigdex.discoveredCount == 3)
}

@Test func pigdexCompletionPercentIsAccurate() {
    var pigdex = Pigdex()
    // Register 36 of 144 => 25%
    let keys = getAllPhenotypeKeys()
    for key in keys.prefix(36) {
        _ = pigdex.registerPhenotype(key: key, gameDay: 1)
    }
    #expect(abs(pigdex.completionPercent - 25.0) < 0.01)
}

@Test func pigdexUndiscoveredKeyReturnsFalse() {
    let pigdex = Pigdex()
    #expect(!pigdex.isDiscovered("black:solid:full:none"))
}

@Test func pigdexRegisteredKeyReturnsTrue() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    #expect(pigdex.isDiscovered("black:solid:full:none"))
}

@Test func emptyPigdexShowsZeroProgress() {
    let pigdex = Pigdex()
    #expect(pigdex.discoveredCount == 0)
    #expect(pigdex.completionPercent == 0.0)
}

@Test func pigdexDuplicateRegistrationDoesNotIncreaseCount() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    let result = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 2)
    #expect(!result)
    #expect(pigdex.discoveredCount == 1)
}

// MARK: - Milestone Logic

@Test func milestoneNotClaimedBelowThreshold() {
    let pigdex = Pigdex()
    // 0 discovered, threshold 25 not reached
    #expect(!pigdex.milestoneRewardsClaimed.contains(25))
    #expect(pigdex.completionPercent < 25.0)
}

@Test func milestoneClaimedAppearsInList() {
    var pigdex = Pigdex()
    pigdex.claimMilestone(25)
    #expect(pigdex.milestoneRewardsClaimed.contains(25))
}

@Test func milestoneFourThresholdsDefined() {
    #expect(milestoneThresholds == [25, 50, 75, 100])
}

// MARK: - Contracts Tab

@Test func contractDaysLeftCalculation() {
    let contract = BreedingContract(
        requiredColor: .black,
        difficulty: .easy,
        reward: 50,
        deadlineDay: 20,
        createdDay: 1
    )
    let daysLeft = max(0, contract.deadlineDay - 15)
    #expect(daysLeft == 5)
}

@Test func contractDaysLeftNeverNegative() {
    let contract = BreedingContract(
        requiredColor: .black,
        difficulty: .easy,
        reward: 50,
        deadlineDay: 10,
        createdDay: 1
    )
    let daysLeft = max(0, contract.deadlineDay - 15)
    #expect(daysLeft == 0)
}

@Test func contractBreedingHintEmptyForBlackSolid() {
    let contract = BreedingContract(
        requiredColor: .black,
        requiredPattern: .solid,
        difficulty: .medium,
        reward: 100,
        deadlineDay: 30,
        createdDay: 1
    )
    #expect(contract.breedingHint.isEmpty)
}

@Test func contractBreedingHintNonEmptyForCream() {
    let contract = BreedingContract(
        requiredColor: .cream,
        difficulty: .easy,
        reward: 75,
        deadlineDay: 30,
        createdDay: 1
    )
    #expect(!contract.breedingHint.isEmpty)
}

@Test func contractBreedingHintNonEmptyForRoan() {
    let contract = BreedingContract(
        requiredColor: .black,
        requiredRoan: .roan,
        difficulty: .expert,
        reward: 200,
        deadlineDay: 50,
        createdDay: 1
    )
    #expect(!contract.breedingHint.isEmpty)
}

@Test func emptyContractBoardShowsZeroStats() {
    let board = ContractBoard()
    #expect(board.completedContracts == 0)
    #expect(board.totalContractEarnings == 0)
    #expect(board.activeContracts.isEmpty)
}

@Test func contractBoardActiveContractCountMatchesAdded() {
    var board = ContractBoard()
    board.activeContracts.append(
        BreedingContract(requiredColor: .black, difficulty: .easy, reward: 50, deadlineDay: 10, createdDay: 1)
    )
    board.activeContracts.append(
        BreedingContract(requiredColor: .golden, difficulty: .medium, reward: 100, deadlineDay: 20, createdDay: 1)
    )
    #expect(board.activeContracts.count == 2)
}

// MARK: - Event Log

@Test @MainActor func emptyEventLogHasNoEvents() {
    let state = makeGameState()
    #expect(state.events.isEmpty)
}

@Test @MainActor func eventLogEntriesAreIdentifiable() {
    let state = makeGameState()
    state.logEvent("Test event", eventType: "info")
    state.logEvent("Another event", eventType: "birth")
    let ids = state.events.map(\.id)
    #expect(ids[0] != ids[1])
}

@Test @MainActor func eventLogReversedOrderNewestFirst() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 0)
    state.logEvent("Day 1 event", eventType: "info")
    state.gameTime.advance(minutes: 1440) // advance one day
    state.logEvent("Day 2 event", eventType: "info")
    let reversed = state.events.reversed()
    #expect(reversed.first?.gameDay ?? 0 >= reversed.last?.gameDay ?? 0)
}

@Test @MainActor func eventLogCapAt100Entries() {
    let state = makeGameState()
    for i in 0..<110 {
        state.logEvent("Event \(i)", eventType: "info")
    }
    #expect(state.events.count == 100)
}

// MARK: - phenotypeKeyFromParts

@Test func phenotypeKeyFromPartsProducesCorrectFormat() {
    let key = phenotypeKeyFromParts(
        baseColor: .black, pattern: .solid,
        intensity: .full, roan: .none
    )
    #expect(key == "black:solid:full:none")
}

@Test func phenotypeKeyFromPartsAllCombinationsAreUnique() {
    let keys = getAllPhenotypeKeys()
    let uniqueKeys = Set(keys)
    #expect(uniqueKeys.count == keys.count)
}
