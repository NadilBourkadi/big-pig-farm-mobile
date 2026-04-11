/// PigListViewModel — Sort, search, filter, sell, and batch sell logic for PigListView.
/// Maps from: ui/screens/pig_list_screen.py
import Foundation

// MARK: - PigListFilter

/// Filter criteria for the pig list. OR within a dimension, AND across dimensions.
enum PigListFilter: Hashable, Sendable {
    case gender(Gender)
    case ageGroup(AgeGroup)
    case biome(BiomeType)
    case pregnant
    case rarity(Rarity)

    var displayName: String {
        switch self {
        case .gender(let gender): gender.displayLabel
        case .ageGroup(let age): age.rawValue.capitalized
        case .biome(let biome): biomes[biome]?.displayName ?? biome.rawValue.capitalized
        case .pregnant: "Pregnant"
        case .rarity(let rarity):
            switch rarity {
            case .veryRare: "Very Rare"
            default: rarity.rawValue.capitalized
            }
        }
    }
}

// MARK: - PigListViewModel

@MainActor @Observable
final class PigListViewModel {

    let gameState: GameState

    var sortBy: PigSortCriterion = .name
    var sortAscending = true
    var selectedPig: GuineaPig?
    var pigToSell: GuineaPig?

    // MARK: - Search & Filter State

    var searchText: String = ""
    var activeFilters: Set<PigListFilter> = []

    // MARK: - Batch Sell State

    var isSelecting = false
    var editModeSelection: Set<UUID> = []
    var showBatchSellConfirmation = false

    init(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Filtered & Sorted Pigs

    var sortedPigs: [GuineaPig] {
        let pigs = gameState.getPigsList()
        let filtered = applyFilters(pigs)
        return applySort(filtered)
    }

    private func applyFilters(_ pigs: [GuineaPig]) -> [GuineaPig] {
        var result = pigs

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        guard !activeFilters.isEmpty else { return result }
        return applyDimensionFilters(result)
    }

    private func applyDimensionFilters(_ pigs: [GuineaPig]) -> [GuineaPig] {
        var result = pigs

        let genderFilters = activeFilters.compactMap {
            if case .gender(let gender) = $0 { gender } else { nil }
        }
        let ageFilters = activeFilters.compactMap {
            if case .ageGroup(let age) = $0 { age } else { nil }
        }
        let biomeFilters = activeFilters.compactMap {
            if case .biome(let biome) = $0 { biome } else { nil }
        }
        let rarityFilters = activeFilters.compactMap {
            if case .rarity(let rarity) = $0 { rarity } else { nil }
        }

        if !genderFilters.isEmpty {
            result = result.filter { genderFilters.contains($0.gender) }
        }
        if !ageFilters.isEmpty {
            result = result.filter { ageFilters.contains($0.ageGroup) }
        }
        if !biomeFilters.isEmpty {
            result = result.filter { pig in
                guard let areaId = pig.currentAreaId,
                      let area = gameState.farm.getAreaByID(areaId) else { return false }
                return biomeFilters.contains(area.biome)
            }
        }
        if !rarityFilters.isEmpty {
            result = result.filter { rarityFilters.contains($0.phenotype.rarity) }
        }
        if activeFilters.contains(.pregnant) {
            result = result.filter { $0.isPregnant }
        }

        return result
    }

    private func applySort(_ pigs: [GuineaPig]) -> [GuineaPig] {
        switch sortBy {
        case .value:
            let values = Dictionary(uniqueKeysWithValues: pigs.map {
                ($0.id, Market.calculatePigValue(pig: $0, state: gameState))
            })
            return pigs.sorted {
                let lhsValue = values[$0.id] ?? 0
                let rhsValue = values[$1.id] ?? 0
                return sortAscending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
        default:
            return pigs.sorted { lhs, rhs in
                let result = compare(lhs, rhs, by: sortBy)
                return sortAscending ? result : !result
            }
        }
    }

    private func compare(
        _ lhs: GuineaPig, _ rhs: GuineaPig, by criterion: PigSortCriterion
    ) -> Bool {
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

    // MARK: - Actions

    func sellPig(_ pig: GuineaPig) {
        if selectedPig?.id == pig.id { selectedPig = nil }
        pigToSell = nil
        guard gameState.getGuineaPig(pig.id) != nil else { return }
        let result = Market.sellPig(state: gameState, pig: pig)
        HapticManager.pigSold()
        AudioManager.pigSold()
        if result.contractBonus > 0 {
            HapticManager.contractCompleted()
            AudioManager.contractCompleted()
        }
    }

    func batchSell() {
        var anyContractBonus = false
        for pigID in editModeSelection {
            guard let pig = gameState.getGuineaPig(pigID) else { continue }
            let result = Market.sellPig(state: gameState, pig: pig)
            if result.contractBonus > 0 { anyContractBonus = true }
        }
        HapticManager.pigSold()
        AudioManager.pigSold()
        if anyContractBonus {
            HapticManager.contractCompleted()
            AudioManager.contractCompleted()
        }
        exitEditMode()
    }

    func enterEditMode() {
        editModeSelection = []
        isSelecting = true
    }

    func exitEditMode() {
        isSelecting = false
        editModeSelection = []
    }

    func toggleBreedingLock(_ pigID: UUID) {
        guard var pig = gameState.getGuineaPig(pigID) else { return }
        pig.breedingLocked.toggle()
        gameState.updateGuineaPig(pig)
    }

    // MARK: - Helpers

    var sellConfirmationTitle: String {
        guard let pig = pigToSell else { return "Sell pig?" }
        let value = Market.calculatePigValue(pig: pig, state: gameState)
        return "Sell \(pig.name) for \(Currency.formatCurrency(value))?"
    }

    var batchSellConfirmationTitle: String {
        let count = editModeSelection.count
        let totalValue = batchSelectionTotalValue
        return "Sell \(count) pig\(count == 1 ? "" : "s") for \(Currency.formatCurrency(totalValue))?"
    }

    var batchSelectionTotalValue: Int {
        editModeSelection.reduce(0) { total, pigID in
            guard let pig = gameState.getGuineaPig(pigID) else { return total }
            return total + Market.calculatePigValue(pig: pig, state: gameState)
        }
    }

    func toggleSort(_ criterion: PigSortCriterion) {
        if sortBy == criterion {
            sortAscending.toggle()
        } else {
            sortBy = criterion
            sortAscending = true
        }
    }

    // MARK: - Filter Actions

    func toggleFilter(_ filter: PigListFilter) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
        searchText = ""
    }

    var isFiltering: Bool {
        !activeFilters.isEmpty || !searchText.isEmpty
    }

    var availableBiomes: [BiomeType] {
        let biomeSet = Set(gameState.farm.areas.map(\.biome))
        return BiomeType.allCases.filter { biomeSet.contains($0) }
    }
}
