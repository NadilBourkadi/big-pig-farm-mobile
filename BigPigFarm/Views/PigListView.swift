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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedPigs) { pig in
                    PigRow(pig: pig)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPig = pig }
                        .swipeActions(edge: .trailing) {
                            Button("Sell", role: .destructive) { pigToSell = pig }
                            Button("Follow") { onFollowPig(pig.id); dismiss() }
                                .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button(pig.breedingLocked ? "Unlock" : "Lock") {
                                toggleBreedingLock(pig.id)
                            }
                            .tint(pig.breedingLocked ? .green : .orange)
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Pigs (\(gameState.pigCount))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { sortMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedPig) { pig in
                NavigationStack {
                    PigDetailView(gameState: gameState, pig: pig)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { selectedPig = nil }
                            }
                        }
                }
            }
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
        }
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
        Market.sellPig(state: gameState, pig: pig)
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

// MARK: - PigRow

/// A single row in the pig list displaying key stats at a glance.
private struct PigRow: View {
    let pig: GuineaPig

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pig.name)
                        .font(.body.bold())
                    RarityBadge(rarity: pig.phenotype.rarity)
                    if pig.breedingLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 8) {
                    Text(pig.phenotype.baseColor.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(pig.ageDays))d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pig.gender.displaySymbol)
                        .font(.caption)
                        .foregroundStyle(pig.gender.displayColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                NeedBar(value: pig.needs.happiness / 100.0, label: "")
                    .frame(width: 64)
                BreedingStatusLabel(pig: pig)
            }
        }
        .padding(.vertical, 2)
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
