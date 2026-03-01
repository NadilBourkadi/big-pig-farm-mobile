/// PigListViewTests — Tests for PigListView sort logic, sell/lock actions, and sort enum.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - PigSortCriterion

@Suite("PigSortCriterion")
struct PigSortCriterionTests {

    @Test func allCasesHaveNonEmptyRawValues() {
        for criterion in PigSortCriterion.allCases {
            #expect(!criterion.rawValue.isEmpty)
        }
    }

    @Test func allCasesAreCaseIterable() {
        #expect(PigSortCriterion.allCases.count == 7)
    }
}

// MARK: - Sort: Name

@MainActor
@Suite("PigListView - Sort by Name")
struct PigListSortNameTests {

    @Test func sortByNameAscending() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Charlie", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))

        let sorted = sortPigs(state.getPigsList(), by: .name, ascending: true)
        #expect(sorted.map { $0.name } == ["Alice", "Bob", "Charlie"])
    }

    @Test func sortByNameDescending() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Charlie", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))

        let sorted = sortPigs(state.getPigsList(), by: .name, ascending: false)
        #expect(sorted.first?.name == "Charlie")
        #expect(sorted.last?.name == "Alice")
    }
}

// MARK: - Sort: Age

@MainActor
@Suite("PigListView - Sort by Age")
struct PigListSortAgeTests {

    @Test func sortByAgeAscending() {
        let state = makeGameState()
        var young = GuineaPig.create(name: "Young", gender: .female)
        young.ageDays = 5.0
        var old = GuineaPig.create(name: "Old", gender: .female)
        old.ageDays = 30.0
        state.addGuineaPig(young)
        state.addGuineaPig(old)

        let sorted = sortPigs(state.getPigsList(), by: .age, ascending: true)
        #expect(sorted.first?.name == "Young")
        #expect(sorted.last?.name == "Old")
    }

    @Test func sortByAgeDescending() {
        let state = makeGameState()
        var young = GuineaPig.create(name: "Young", gender: .female)
        young.ageDays = 5.0
        var senior = GuineaPig.create(name: "Senior", gender: .female)
        senior.ageDays = 100.0
        state.addGuineaPig(young)
        state.addGuineaPig(senior)

        let sorted = sortPigs(state.getPigsList(), by: .age, ascending: false)
        #expect(sorted.first?.name == "Senior")
    }
}

// MARK: - Sort: Happiness

@MainActor
@Suite("PigListView - Sort by Happiness")
struct PigListSortHappinessTests {

    @Test func sortByHappinessAscending() {
        let state = makeGameState()
        var sad = GuineaPig.create(name: "Sad", gender: .female)
        sad.needs.happiness = 10.0
        var happy = GuineaPig.create(name: "Happy", gender: .female)
        happy.needs.happiness = 90.0
        state.addGuineaPig(sad)
        state.addGuineaPig(happy)

        let sorted = sortPigs(state.getPigsList(), by: .happiness, ascending: true)
        #expect(sorted.first?.name == "Sad")
        #expect(sorted.last?.name == "Happy")
    }
}

// MARK: - Sort: Rarity

@MainActor
@Suite("PigListView - Sort by Rarity")
struct PigListSortRarityTests {

    @Test func sortByRarityAscending() {
        let state = makeGameState()
        var legendary = GuineaPig.create(name: "Legend", gender: .female)
        legendary.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .legendary
        )
        var common = GuineaPig.create(name: "Common", gender: .female)
        common.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
        )
        state.addGuineaPig(legendary)
        state.addGuineaPig(common)

        let sorted = sortPigs(state.getPigsList(), by: .rarity, ascending: true)
        #expect(sorted.first?.name == "Common")
        #expect(sorted.last?.name == "Legend")
    }

    @Test func sortByRarityDescending() {
        let state = makeGameState()
        var rare = GuineaPig.create(name: "Rare", gender: .male)
        rare.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .rare
        )
        var uncommon = GuineaPig.create(name: "Uncommon", gender: .male)
        uncommon.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .uncommon
        )
        state.addGuineaPig(rare)
        state.addGuineaPig(uncommon)

        let sorted = sortPigs(state.getPigsList(), by: .rarity, ascending: false)
        #expect(sorted.first?.name == "Rare")
    }
}

// MARK: - Sort: Value

@MainActor
@Suite("PigListView - Sort by Value")
struct PigListSortValueTests {

    @Test func sortByValueAscendingPutsLowerValueFirst() {
        let state = makeGameState()
        var cheap = GuineaPig.create(name: "Cheap", gender: .female)
        cheap.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        cheap.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
        )
        var expensive = GuineaPig.create(name: "Expensive", gender: .female)
        expensive.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        expensive.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .legendary
        )
        state.addGuineaPig(cheap)
        state.addGuineaPig(expensive)

        let sorted = valueSortedPigs(state.getPigsList(), state: state, ascending: true)
        #expect(sorted.first?.name == "Cheap")
        #expect(sorted.last?.name == "Expensive")
    }
}

// MARK: - Sell Action

@MainActor
@Suite("PigListView - Sell Action")
struct PigListSellTests {

    @Test func sellPigRemovesItFromState() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        #expect(state.pigCount == 1)

        Market.sellPig(state: state, pig: pig)
        #expect(state.pigCount == 0)
    }

    @Test func sellPigIncreasesMoney() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(pig)
        let moneyBefore = state.money

        Market.sellPig(state: state, pig: pig)
        #expect(state.money > moneyBefore)
    }
}

// MARK: - Lock Toggle Action

@MainActor
@Suite("PigListView - Breeding Lock Toggle")
struct PigListLockToggleTests {

    @Test func toggleBreedingLockLocksUnlockedPig() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Fluffy", gender: .female)
        pig.breedingLocked = false
        state.addGuineaPig(pig)

        pig.breedingLocked.toggle()
        state.updateGuineaPig(pig)

        let updated = state.getGuineaPig(pig.id)
        #expect(updated?.breedingLocked == true)
    }

    @Test func toggleBreedingLockUnlocksLockedPig() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Fluffy", gender: .female)
        pig.breedingLocked = true
        state.addGuineaPig(pig)

        pig.breedingLocked.toggle()
        state.updateGuineaPig(pig)

        let updated = state.getGuineaPig(pig.id)
        #expect(updated?.breedingLocked == false)
    }

    @Test func doubleToggleRestoresOriginalState() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Fluffy", gender: .female)
        pig.breedingLocked = false
        state.addGuineaPig(pig)

        pig.breedingLocked.toggle()
        state.updateGuineaPig(pig)
        pig.breedingLocked.toggle()
        state.updateGuineaPig(pig)

        let updated = state.getGuineaPig(pig.id)
        #expect(updated?.breedingLocked == false)
    }
}

// MARK: - Sort Helpers (mirror view logic for testability)

private func sortPigs(
    _ pigs: [GuineaPig],
    by criterion: PigSortCriterion,
    ascending: Bool
) -> [GuineaPig] {
    pigs.sorted { lhs, rhs in
        let result = comparePigs(lhs, rhs, by: criterion)
        return ascending ? result : !result
    }
}

private func comparePigs(_ lhs: GuineaPig, _ rhs: GuineaPig, by criterion: PigSortCriterion) -> Bool {
    switch criterion {
    case .name: return lhs.name < rhs.name
    case .age: return lhs.ageDays < rhs.ageDays
    case .gender: return lhs.gender.rawValue < rhs.gender.rawValue
    case .color: return lhs.phenotype.displayName < rhs.phenotype.displayName
    case .happiness: return lhs.needs.happiness < rhs.needs.happiness
    case .rarity: return lhs.phenotype.rarity.sortOrder < rhs.phenotype.rarity.sortOrder
    case .value: return false
    }
}

@MainActor
private func valueSortedPigs(
    _ pigs: [GuineaPig],
    state: GameState,
    ascending: Bool
) -> [GuineaPig] {
    let values = Dictionary(uniqueKeysWithValues: pigs.map {
        ($0.id, Market.calculatePigValue(pig: $0, state: state))
    })
    return pigs.sorted {
        let lhsValue = values[$0.id] ?? 0
        let rhsValue = values[$1.id] ?? 0
        return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
    }
}
