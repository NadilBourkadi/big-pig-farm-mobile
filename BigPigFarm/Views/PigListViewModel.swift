/// PigListViewModel — Sort, sell, batch sell, and breeding lock logic for PigListView.
/// Maps from: ui/screens/pig_list_screen.py
import Foundation

@MainActor @Observable
final class PigListViewModel {

    let gameState: GameState

    var sortBy: PigSortCriterion = .name
    var sortAscending = true
    var selectedPig: GuineaPig?
    var pigToSell: GuineaPig?

    // MARK: - Batch Sell State

    var isSelecting = false
    var editModeSelection: Set<UUID> = []
    var showBatchSellConfirmation = false

    init(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Sorted Pigs

    var sortedPigs: [GuineaPig] {
        let pigs = gameState.getPigsList()
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
}
