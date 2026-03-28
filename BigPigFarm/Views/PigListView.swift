// PigListView — Sortable list of all guinea pigs.
// Maps from: ui/screens/pig_list_screen.py
import SwiftUI

// MARK: - PigSortCriterion

/// Available sort criteria for the pig list.
/// Maps from: pig_list_screen.py column headers.
enum PigSortCriterion: String, CaseIterable, Sendable {
    case name = "Name"
    case age = "Age"
    case gender = "Gender"
    case color = "Color"
    case happiness = "Happiness"
    case value = "Value"
    case rarity = "Rarity"
}

// MARK: - PigListView

/// Displays a sortable list of all pigs on the farm.
struct PigListView: View {
    let gameState: GameState
    var onFollowPig: (UUID) -> Void = { _ in }

    @State private var sortBy: PigSortCriterion = .name
    @State private var sortAscending = true
    @State private var selectedPig: GuineaPig?
    @State private var pigToSell: GuineaPig?
    @State private var isSelecting = false
    @State private var editModeSelection: Set<UUID> = []
    @State private var showBatchSellConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(selection: $editModeSelection) {
                ForEach(sortedPigs) { pig in
                    PigListRow(pig: pig)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isSelecting { selectedPig = pig }
                        }
                        .swipeActions(edge: .trailing) {
                            if !isSelecting {
                                Button(role: .destructive) { pigToSell = pig } label: {
                                    Label("Sell", systemImage: "dollarsign.circle.fill")
                                }
                                Button { onFollowPig(pig.id); dismiss() } label: {
                                    Label("Follow", systemImage: "location.fill")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !isSelecting {
                                Button {
                                    toggleBreedingLock(pig.id)
                                } label: {
                                    Label(
                                        pig.breedingLocked ? "Unlock" : "Lock",
                                        systemImage: pig.breedingLocked ? "lock.open.fill" : "lock.fill"
                                    )
                                }
                                .tint(pig.breedingLocked ? .green : .orange)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, isSelecting ? .constant(.active) : .constant(.inactive))
            .navigationTitle("Pigs (\(gameState.pigCount))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelecting {
                        Button("Cancel") { exitEditMode() }
                    } else {
                        sortMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !isSelecting {
                            Button("Select") { enterEditMode() }
                        }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting && !editModeSelection.isEmpty {
                    batchSellBar
                }
            }
            .pigDetailSheet(pig: $selectedPig, gameState: gameState)
            .confirmationDialog(
                sellConfirmationTitle,
                isPresented: Binding(
                    get: { pigToSell != nil },
                    set: { if !$0 { pigToSell = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Sell", role: .destructive) {
                    if let pig = pigToSell { sellPig(pig) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                batchSellConfirmationTitle,
                isPresented: $showBatchSellConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sell All", role: .destructive) { batchSell() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Batch Sell Bar

    private var batchSellBar: some View {
        let count = editModeSelection.count
        let totalValue = batchSelectionTotalValue
        return HStack {
            Text("Sell \(count) pig\(count == 1 ? "" : "s")")
                .font(.body.bold())
            Spacer()
            Button(role: .destructive) {
                showBatchSellConfirmation = true
            } label: {
                Text(Currency.formatCurrency(totalValue))
                    .font(.body.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Sorted Pigs

    private var sortedPigs: [GuineaPig] {
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

    private func compare(_ lhs: GuineaPig, _ rhs: GuineaPig, by criterion: PigSortCriterion) -> Bool {
        switch criterion {
        case .name: return lhs.name < rhs.name
        case .age: return lhs.ageDays < rhs.ageDays
        case .gender: return lhs.gender.rawValue < rhs.gender.rawValue
        case .color: return lhs.phenotype.displayName < rhs.phenotype.displayName
        case .happiness: return lhs.needs.happiness < rhs.needs.happiness
        case .rarity: return lhs.phenotype.rarity.sortOrder < rhs.phenotype.rarity.sortOrder
        case .value: return false // handled in sortedPigs
        }
    }

    // MARK: - Actions

    private func sellPig(_ pig: GuineaPig) {
        if selectedPig?.id == pig.id { selectedPig = nil }
        pigToSell = nil
        guard gameState.getGuineaPig(pig.id) != nil else { return }
        let result = Market.sellPig(state: gameState, pig: pig)
        HapticManager.pigSold()
        if result.contractBonus > 0 {
            HapticManager.contractCompleted()
        }
    }

    private func batchSell() {
        var anyContractBonus = false
        for pigID in editModeSelection {
            guard let pig = gameState.getGuineaPig(pigID) else { continue }
            let result = Market.sellPig(state: gameState, pig: pig)
            if result.contractBonus > 0 { anyContractBonus = true }
        }
        HapticManager.pigSold()
        if anyContractBonus { HapticManager.contractCompleted() }
        exitEditMode()
    }

    private func enterEditMode() {
        editModeSelection = []
        isSelecting = true
    }

    private func exitEditMode() {
        isSelecting = false
        editModeSelection = []
    }

    private func toggleBreedingLock(_ pigID: UUID) {
        guard var pig = gameState.getGuineaPig(pigID) else { return }
        pig.breedingLocked.toggle()
        gameState.updateGuineaPig(pig)
    }

    // MARK: - Helpers

    private var sellConfirmationTitle: String {
        guard let pig = pigToSell else { return "Sell pig?" }
        let value = Market.calculatePigValue(pig: pig, state: gameState)
        return "Sell \(pig.name) for \(Currency.formatCurrency(value))?"
    }

    private var batchSellConfirmationTitle: String {
        let count = editModeSelection.count
        let totalValue = batchSelectionTotalValue
        return "Sell \(count) pig\(count == 1 ? "" : "s") for \(Currency.formatCurrency(totalValue))?"
    }

    private var batchSelectionTotalValue: Int {
        editModeSelection.reduce(0) { total, pigID in
            guard let pig = gameState.getGuineaPig(pigID) else { return total }
            return total + Market.calculatePigValue(pig: pig, state: gameState)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(PigSortCriterion.allCases, id: \.self) { criterion in
                Button {
                    if sortBy == criterion {
                        sortAscending.toggle()
                    } else {
                        sortBy = criterion
                        sortAscending = true
                    }
                } label: {
                    HStack {
                        Text(criterion.rawValue)
                        if sortBy == criterion {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Label("Sort: \(sortBy.rawValue)", systemImage: "arrow.up.arrow.down")
                .font(.caption)
                .accessibilityLabel("Sort by \(sortBy.rawValue)")
        }
    }
}

// MARK: - Preview

private struct PigListPreview: View {
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        previewState.addGuineaPig(GuineaPig.create(name: "Biscuit", gender: .female))
        previewState.addGuineaPig(GuineaPig.create(name: "Peanut", gender: .male))
        previewState.addGuineaPig(GuineaPig.create(name: "Waffles", gender: .female))
        return previewState
    }()

    var body: some View {
        PigListView(gameState: state)
    }
}

#Preview {
    PigListPreview()
}
