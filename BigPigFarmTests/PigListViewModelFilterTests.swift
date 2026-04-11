/// PigListViewModelFilterTests — Tests for search and filter logic in PigListViewModel.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Search

@MainActor
@Suite("PigListViewModel — Search")
struct PigListViewModelSearchTests {

    @Test func searchByNameCaseInsensitive() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Peanut", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "bis"
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Biscuit")
    }

    @Test func searchNoMatch() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "xyz"
        #expect(vm.sortedPigs.isEmpty)
    }

    @Test func searchClearsWhenTextEmpty() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Peanut", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "bis"
        #expect(vm.sortedPigs.count == 1)

        vm.searchText = ""
        #expect(vm.sortedPigs.count == 2)
    }

    @Test func searchPartialMatch() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Peanut", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Wanda", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "an"
        let names = vm.sortedPigs.map(\.name)
        #expect(names.contains("Peanut"))
        #expect(names.contains("Wanda"))
        #expect(!names.contains("Biscuit"))
    }
}

// MARK: - Filter: Gender

@MainActor
@Suite("PigListViewModel — Filter by Gender")
struct PigListViewModelFilterGenderTests {

    @Test func filterByMale() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.gender(.male))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Bob")
    }

    @Test func filterByFemale() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.gender(.female))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Alice")
    }

    @Test func filterBothGendersShowsAll() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.gender(.male))
        vm.toggleFilter(.gender(.female))
        #expect(vm.sortedPigs.count == 2)
    }
}

// MARK: - Filter: Age Group

@MainActor
@Suite("PigListViewModel — Filter by Age Group")
struct PigListViewModelFilterAgeTests {

    @Test func filterByBaby() {
        let state = makeGameState()
        var baby = GuineaPig.create(name: "Baby", gender: .female)
        baby.ageDays = 5.0
        var adult = GuineaPig.create(name: "Adult", gender: .male)
        adult.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(baby)
        state.addGuineaPig(adult)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.ageGroup(.baby))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Baby")
    }

    @Test func filterBySenior() {
        let state = makeGameState()
        var senior = GuineaPig.create(name: "Senior", gender: .female)
        senior.ageDays = Double(GameConfig.Simulation.seniorAgeDays)
        var adult = GuineaPig.create(name: "Adult", gender: .male)
        adult.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(senior)
        state.addGuineaPig(adult)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.ageGroup(.senior))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Senior")
    }
}

// MARK: - Filter: Rarity

@MainActor
@Suite("PigListViewModel — Filter by Rarity")
struct PigListViewModelFilterRarityTests {

    @Test func filterByLegendary() {
        let state = makeGameState()
        var common = GuineaPig.create(name: "Common", gender: .female)
        common.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
        )
        var legendary = GuineaPig.create(name: "Legend", gender: .female)
        legendary.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .legendary
        )
        state.addGuineaPig(common)
        state.addGuineaPig(legendary)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.rarity(.legendary))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Legend")
    }

    @Test func filterMultipleRaritiesIsOR() {
        let state = makeGameState()
        var common = GuineaPig.create(name: "Common", gender: .female)
        common.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
        )
        var rare = GuineaPig.create(name: "Rare", gender: .female)
        rare.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .rare
        )
        var legendary = GuineaPig.create(name: "Legend", gender: .female)
        legendary.phenotype = Phenotype(
            baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .legendary
        )
        state.addGuineaPig(common)
        state.addGuineaPig(rare)
        state.addGuineaPig(legendary)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.rarity(.common))
        vm.toggleFilter(.rarity(.rare))
        #expect(vm.sortedPigs.count == 2)
        let names = vm.sortedPigs.map(\.name)
        #expect(names.contains("Common"))
        #expect(names.contains("Rare"))
    }
}

// MARK: - Filter: Pregnancy

@MainActor
@Suite("PigListViewModel — Filter by Pregnancy")
struct PigListViewModelFilterPregnancyTests {

    @Test func filterPregnant() {
        let state = makeGameState()
        var pregnant = GuineaPig.create(name: "Mama", gender: .female)
        pregnant.isPregnant = true
        state.addGuineaPig(pregnant)
        state.addGuineaPig(GuineaPig.create(name: "NotPregnant", gender: .female))
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.pregnant)
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Mama")
    }

    @Test func filterPregnantNoResults() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "NotPregnant", gender: .female))
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.pregnant)
        #expect(vm.sortedPigs.isEmpty)
    }
}

// MARK: - Filter: Biome

@MainActor
@Suite("PigListViewModel — Filter by Biome")
struct PigListViewModelFilterBiomeTests {

    @Test func filterByBiome() throws {
        let state = makeGameState()
        let meadowAreaId = try #require(state.farm.areas.first).id
        var inMeadow = GuineaPig.create(name: "Meadow", gender: .female)
        inMeadow.currentAreaId = meadowAreaId
        var noArea = GuineaPig.create(name: "NoArea", gender: .male)
        noArea.currentAreaId = nil
        state.addGuineaPig(inMeadow)
        state.addGuineaPig(noArea)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.biome(.meadow))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Meadow")
    }

    @Test func filterByBiomeExcludesNilArea() {
        let state = makeGameState()
        var noArea = GuineaPig.create(name: "NoArea", gender: .female)
        noArea.currentAreaId = nil
        state.addGuineaPig(noArea)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.biome(.meadow))
        #expect(vm.sortedPigs.isEmpty)
    }
}

// MARK: - Combined Filters

@MainActor
@Suite("PigListViewModel — Combined Filters")
struct PigListViewModelCombinedFilterTests {

    @Test func searchPlusGenderFilter() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        state.addGuineaPig(GuineaPig.create(name: "Charlie", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "b"
        vm.toggleFilter(.gender(.male))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "Bob")
    }

    @Test func genderPlusAgeIsAND() {
        let state = makeGameState()
        var maleBaby = GuineaPig.create(name: "MaleBaby", gender: .male)
        maleBaby.ageDays = 5.0
        var maleAdult = GuineaPig.create(name: "MaleAdult", gender: .male)
        maleAdult.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        var femaleBaby = GuineaPig.create(name: "FemaleBaby", gender: .female)
        femaleBaby.ageDays = 5.0
        state.addGuineaPig(maleBaby)
        state.addGuineaPig(maleAdult)
        state.addGuineaPig(femaleBaby)
        let vm = PigListViewModel(gameState: state)

        vm.toggleFilter(.gender(.male))
        vm.toggleFilter(.ageGroup(.baby))
        #expect(vm.sortedPigs.count == 1)
        #expect(vm.sortedPigs.first?.name == "MaleBaby")
    }

    @Test func clearFiltersResetsAll() {
        let state = makeGameState()
        state.addGuineaPig(GuineaPig.create(name: "Alice", gender: .female))
        state.addGuineaPig(GuineaPig.create(name: "Bob", gender: .male))
        let vm = PigListViewModel(gameState: state)

        vm.searchText = "alice"
        vm.toggleFilter(.gender(.female))
        #expect(vm.sortedPigs.count == 1)

        vm.clearFilters()
        #expect(vm.sortedPigs.count == 2)
        #expect(vm.searchText.isEmpty)
        #expect(vm.activeFilters.isEmpty)
    }
}

// MARK: - Filter Helpers

@MainActor
@Suite("PigListViewModel — Filter Helpers")
struct PigListViewModelFilterHelperTests {

    @Test func availableBiomesReturnsOnlyFarmBiomes() {
        let state = makeGameState()
        let vm = PigListViewModel(gameState: state)
        #expect(vm.availableBiomes == [.meadow])
    }

    @Test func isFilteringTrueWhenFiltersActive() {
        let vm = PigListViewModel(gameState: makeGameState())
        #expect(!vm.isFiltering)

        vm.toggleFilter(.gender(.male))
        #expect(vm.isFiltering)
    }

    @Test func isFilteringTrueWhenSearchActive() {
        let vm = PigListViewModel(gameState: makeGameState())
        vm.searchText = "test"
        #expect(vm.isFiltering)
    }

    @Test func toggleFilterAddsAndRemoves() {
        let vm = PigListViewModel(gameState: makeGameState())
        vm.toggleFilter(.gender(.male))
        #expect(vm.activeFilters.contains(.gender(.male)))

        vm.toggleFilter(.gender(.male))
        #expect(!vm.activeFilters.contains(.gender(.male)))
    }

    @Test func filterEmptyPigListDoesNotCrash() {
        let vm = PigListViewModel(gameState: makeGameState())
        vm.toggleFilter(.gender(.male))
        vm.searchText = "test"
        #expect(vm.sortedPigs.isEmpty)
    }
}
