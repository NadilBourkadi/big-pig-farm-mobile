/// AdoptionView — Bloodline adoption interface.
/// Maps from: ui/screens/adoption.py
import SwiftUI

// MARK: - AdoptionView

/// Adoption center showing randomly generated pigs available for purchase.
///
/// Maps from: ui/screens/adoption.py (generate_adoption_pig, calculate_adoption_cost)
/// and shop.py ShopScreen ADOPTION category handling.
///
/// Used as the Adoption tab in ShopView. Can also be presented standalone.
struct AdoptionView: View {
    let gameState: GameState

    /// The current batch of available pigs.
    @State private var availablePigs: [GuineaPig] = []

    /// The selected pig for the detail panel.
    @State private var selectedPig: GuineaPig?

    /// Error alert state.
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            List(availablePigs, id: \.id) { pig in
                let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
                let canAfford = gameState.money >= cost

                AdoptionPigRow(pig: pig, cost: cost, canAfford: canAfford)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPig = pig }
            }
            .listStyle(.plain)
            .overlay {
                if availablePigs.isEmpty {
                    ContentUnavailableView(
                        "No Pigs Available",
                        systemImage: "pawprint",
                        description: Text("Tap Refresh to generate new pigs")
                    )
                }
            }

            if let pig = selectedPig {
                adoptionDetail(pig: pig)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    refreshPigs()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            if availablePigs.isEmpty {
                refreshPigs()
            }
        }
        .alert("Cannot Adopt", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - AdoptionPigRow

/// A single row showing a pig available for adoption.
///
/// Maps from: shop.py AdoptionPigWidget class.
private struct AdoptionPigRow: View {
    let pig: GuineaPig
    let cost: Int
    let canAfford: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(pig.name)
                        .font(.body)
                    Text(pig.gender == .male ? "M" : "F")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(pig.phenotype.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RarityBadge(rarity: pig.phenotype.rarity)
                    if let tag = pig.originTag {
                        StatusBadge(label: tag, color: .purple, style: .tinted)
                    }
                }
            }

            Spacer()

            CurrencyLabel(amount: cost)
                .foregroundStyle(canAfford ? AnyShapeStyle(.yellow) : AnyShapeStyle(.red))
        }
    }
}

// MARK: - AdoptionView Actions

extension AdoptionView {
    /// Detail panel for the selected adoption pig.
    ///
    /// Maps from: shop.py _update_detail() adoption pig branch.
    private func adoptionDetail(pig: GuineaPig) -> some View {
        let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
        let canAfford = gameState.money >= cost

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pig.name).font(.headline)
                Spacer()
                CurrencyLabel(amount: cost)
            }

            HStack {
                Text("Gender: \(pig.gender == .male ? "Male" : "Female")")
                    .font(.caption)
                Text("Color: \(pig.phenotype.displayName)")
                    .font(.caption)
            }

            HStack {
                Text("Rarity: \(pig.phenotype.rarity.rawValue.capitalized)")
                    .font(.caption)
                let traits = pig.personality.map { $0.rawValue.capitalized }
                Text("Traits: \(traits.joined(separator: ", "))")
                    .font(.caption)
            }

            if let tag = pig.originTag {
                Text("Bloodline: \(tag)")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }

            Text("Farm: \(gameState.pigCount)/\(gameState.capacity) pigs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Adopt \(pig.name)") { adoptPig(pig) }
                .buttonStyle(.borderedProminent)
                .disabled(!canAfford || gameState.isAtCapacity)
        }
        .padding()
        .background(.regularMaterial)
    }

    /// Adopt the selected pig.
    ///
    /// Maps from: shop.py _adopt_pig()
    private func adoptPig(_ pig: GuineaPig) {
        guard !gameState.isAtCapacity else {
            errorMessage = "Farm is at capacity! Upgrade or sell pigs."
            showError = true
            HapticManager.error()
            return
        }

        let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
        guard gameState.money >= cost else {
            errorMessage = "Not enough Squeaks!"
            showError = true
            HapticManager.error()
            return
        }

        guard let position = Adoption.findSpawnPosition(in: gameState) else {
            errorMessage = "No space for new pig!"
            showError = true
            HapticManager.error()
            return
        }

        var adoptedPig = pig
        adoptedPig.position = Position(x: Double(position.x), y: Double(position.y))

        _ = gameState.spendMoney(cost)
        gameState.addGuineaPig(adoptedPig)

        gameState.logEvent(
            "Adopted \(pig.name) (\(pig.phenotype.displayName)) for \(cost) Squeaks",
            eventType: "adoption"
        )

        availablePigs.removeAll { $0.id == pig.id }
        selectedPig = nil
        HapticManager.purchase()
    }

    /// Generate a fresh batch of adoption pigs.
    ///
    /// Maps from: shop.py _generate_available_pigs()
    private func refreshPigs() {
        let existingNames = Set(gameState.getPigsList().map(\.name))
            .union(Set(availablePigs.map(\.name)))

        availablePigs = Adoption.generateAdoptionBatch(
            existingNames: existingNames,
            farmTier: gameState.farmTier,
            count: Int.random(in: 3...5)
        )
        selectedPig = nil
    }
}

// MARK: - Preview

private struct AdoptionViewPreview: View {
    @State private var state = GameState()

    var body: some View {
        NavigationStack {
            AdoptionView(gameState: state)
                .navigationTitle("Adoption Center")
        }
    }
}

#Preview {
    AdoptionViewPreview()
}
