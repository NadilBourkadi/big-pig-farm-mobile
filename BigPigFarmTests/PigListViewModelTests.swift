/// PigListViewModelTests — Tests for PigListViewModel sort, sell, and lock actions.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Sort: Name

@MainActor
@Suite("PigListViewModel — Sort by Name")
struct PigListViewModelSortNameTests {

    @Test func sortByNameAscending() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Charlie", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .name
        vm.sortAscending = true

        #expect(vm.sortedPigs.map(\.name) == ["Alice", "Bob", "Charlie"])
    }

    @Test func sortByNameDescending() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Charlie", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .name
        vm.sortAscending = false

        #expect(vm.sortedPigs.first?.name == "Charlie")
        #expect(vm.sortedPigs.last?.name == "Alice")
    }
}

// MARK: - Sort: Age

@MainActor
@Suite("PigListViewModel — Sort by Age")
struct PigListViewModelSortAgeTests {

    @Test func sortByAgeAscending() {
        let state = makeGameState()
        var young = GuineaPig.create(name: "Young", gender: .female)
        young.ageDays = 25.0
        var old = GuineaPig.create(name: "Old", gender: .female)
        old.ageDays = 150.0
        state.addGuineaPig(young)
        state.addGuineaPig(old)
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .age
        vm.sortAscending = true

        #expect(vm.sortedPigs.first?.name == "Young")
        #expect(vm.sortedPigs.last?.name == "Old")
    }
}

// MARK: - Sort: Happiness

@MainActor
@Suite("PigListViewModel — Sort by Happiness")
struct PigListViewModelSortHappinessTests {

    @Test func sortByHappinessAscending() {
        let state = makeGameState()
        var sad = GuineaPig.create(name: "Sad", gender: .female)
        sad.needs.happiness = 10.0
        var happy = GuineaPig.create(name: "Happy", gender: .female)
        happy.needs.happiness = 90.0
        state.addGuineaPig(sad)
        state.addGuineaPig(happy)
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .happiness
        vm.sortAscending = true

        #expect(vm.sortedPigs.first?.name == "Sad")
        #expect(vm.sortedPigs.last?.name == "Happy")
    }
}

// MARK: - Sort: Rarity

@MainActor
@Suite("PigListViewModel — Sort by Rarity")
struct PigListViewModelSortRarityTests {

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
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .rarity
        vm.sortAscending = true

        #expect(vm.sortedPigs.first?.name == "Common")
        #expect(vm.sortedPigs.last?.name == "Legend")
    }
}

// MARK: - Sort: Value

@MainActor
@Suite("PigListViewModel — Sort by Value")
struct PigListViewModelSortValueTests {

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
        let vm = PigListViewModel(gameState: state)
        vm.sortBy = .value
        vm.sortAscending = true

        #expect(vm.sortedPigs.first?.name == "Cheap")
        #expect(vm.sortedPigs.last?.name == "Expensive")
    }
}

// MARK: - Sell Action

@MainActor
@Suite("PigListViewModel — Sell Action")
struct PigListViewModelSellTests {

    @Test func sellPigRemovesItFromState() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)
        #expect(state.pigCount == 1)

        vm.sellPig(pig)
        #expect(state.pigCount == 0)
    }

    @Test func sellPigIncreasesMoney() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Biscuit", gender: .female)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)
        let moneyBefore = state.money

        vm.sellPig(pig)
        #expect(state.money > moneyBefore)
    }

    @Test func sellPigClearsSelectedPigIfMatch() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)
        vm.selectedPig = pig

        vm.sellPig(pig)
        #expect(vm.selectedPig == nil)
    }

    @Test func sellPigClearsPigToSell() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)
        vm.pigToSell = pig

        vm.sellPig(pig)
        #expect(vm.pigToSell == nil)
    }
}

// MARK: - Lock Toggle Action

@MainActor
@Suite("PigListViewModel — Breeding Lock Toggle")
struct PigListViewModelLockToggleTests {

    @Test func toggleBreedingLockLocksUnlockedPig() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Fluffy", gender: .female)
        pig.breedingLocked = false
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)

        vm.toggleBreedingLock(pig.id)
        #expect(state.getGuineaPig(pig.id)?.breedingLocked == true)
    }

    @Test func toggleBreedingLockUnlocksLockedPig() {
        let state = makeGameState()
        var pig = GuineaPig.create(name: "Fluffy", gender: .female)
        pig.breedingLocked = true
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)

        vm.toggleBreedingLock(pig.id)
        #expect(state.getGuineaPig(pig.id)?.breedingLocked == false)
    }
}

// MARK: - Sell Confirmation Title

@MainActor
@Suite("PigListViewModel — Sell Confirmation Title")
struct PigListViewModelSellConfirmationTests {

    @Test func sellConfirmationTitleIncludesPigNameAndValue() {
        let state = makeGameState()
        let pig = GuineaPig.create(name: "Biscuit", gender: .female)
        state.addGuineaPig(pig)
        let vm = PigListViewModel(gameState: state)
        vm.pigToSell = pig

        #expect(vm.sellConfirmationTitle.contains("Biscuit"))
    }

    @Test func sellConfirmationTitleDefaultsWhenNoPigToSell() {
        let vm = PigListViewModel(gameState: makeGameState())
        #expect(vm.sellConfirmationTitle == "Sell pig?")
    }
}

// MARK: - Toggle Sort

@MainActor
@Suite("PigListViewModel — Toggle Sort")
struct PigListViewModelToggleSortTests {

    @Test func toggleSortToNewCriterionSetsAscending() {
        let vm = PigListViewModel(gameState: makeGameState())
        vm.sortBy = .name
        vm.sortAscending = false

        vm.toggleSort(.age)
        #expect(vm.sortBy == .age)
        #expect(vm.sortAscending == true)
    }

    @Test func toggleSortSameCriterionFlipsDirection() {
        let vm = PigListViewModel(gameState: makeGameState())
        vm.sortBy = .name
        vm.sortAscending = true

        vm.toggleSort(.name)
        #expect(vm.sortBy == .name)
        #expect(vm.sortAscending == false)
    }
}
