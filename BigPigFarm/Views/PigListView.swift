// PigListView — Sortable list of all guinea pigs with batch sell.
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
    @State var viewModel: PigListViewModel
    var onFollowPig: (UUID) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    init(gameState: GameState, onFollowPig: @escaping (UUID) -> Void = { _ in }) {
        _viewModel = State(initialValue: PigListViewModel(gameState: gameState))
        self.onFollowPig = onFollowPig
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List(selection: $viewModel.editModeSelection) {
                ForEach(viewModel.sortedPigs) { pig in
                    PigListRow(pig: pig)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !viewModel.isSelecting { viewModel.selectedPig = pig }
                        }
                        .swipeActions(edge: .trailing) {
                            if !viewModel.isSelecting {
                                Button(role: .destructive) {
                                    viewModel.pigToSell = pig
                                } label: {
                                    Label("Sell", systemImage: "dollarsign.circle.fill")
                                }
                                Button { onFollowPig(pig.id); dismiss() } label: {
                                    Label("Follow", systemImage: "location.fill")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !viewModel.isSelecting {
                                Button {
                                    viewModel.toggleBreedingLock(pig.id)
                                } label: {
                                    Label(
                                        pig.breedingLocked ? "Unlock" : "Lock",
                                        systemImage: pig.breedingLocked
                                            ? "lock.open.fill" : "lock.fill"
                                    )
                                }
                                .tint(pig.breedingLocked ? .green : .orange)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .environment(
                \.editMode,
                viewModel.isSelecting ? .constant(.active) : .constant(.inactive)
            )
            .navigationTitle("Pigs (\(viewModel.gameState.pigCount))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isSelecting {
                        Button("Cancel") { viewModel.exitEditMode() }
                    } else {
                        sortMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !viewModel.isSelecting {
                            Button("Select") { viewModel.enterEditMode() }
                        }
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelecting && !viewModel.editModeSelection.isEmpty {
                    batchSellBar
                }
            }
            .pigDetailSheet(pig: $viewModel.selectedPig, gameState: viewModel.gameState)
            .confirmationDialog(
                viewModel.sellConfirmationTitle,
                isPresented: Binding(
                    get: { viewModel.pigToSell != nil },
                    set: { if !$0 { viewModel.pigToSell = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Sell", role: .destructive) {
                    if let pig = viewModel.pigToSell { viewModel.sellPig(pig) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                viewModel.batchSellConfirmationTitle,
                isPresented: $viewModel.showBatchSellConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sell All", role: .destructive) { viewModel.batchSell() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Batch Sell Bar

    private var batchSellBar: some View {
        let count = viewModel.editModeSelection.count
        let totalValue = viewModel.batchSelectionTotalValue
        return HStack {
            Text("Sell \(count) pig\(count == 1 ? "" : "s")")
                .font(.body.bold())
            Spacer()
            Button(role: .destructive) {
                viewModel.showBatchSellConfirmation = true
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

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(PigSortCriterion.allCases, id: \.self) { criterion in
                Button {
                    viewModel.toggleSort(criterion)
                } label: {
                    HStack {
                        Text(criterion.rawValue)
                        if viewModel.sortBy == criterion {
                            Image(systemName: viewModel.sortAscending
                                ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Label("Sort: \(viewModel.sortBy.rawValue)", systemImage: "arrow.up.arrow.down")
                .font(.caption)
                .accessibilityLabel("Sort by \(viewModel.sortBy.rawValue)")
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
