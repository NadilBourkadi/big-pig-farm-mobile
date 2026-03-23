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

    /// IDs of emergency bailout pigs (free adoption).
    @State private var emergencyPigIDs: Set<UUID> = []

    /// The selected pig for the detail panel.
    @State private var selectedPig: GuineaPig?

    /// Error alert state.
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            if !emergencyPigIDs.isEmpty {
                emergencyBanners
            }
            List(availablePigs, id: \.id) { pig in
                let isEmergency = emergencyPigIDs.contains(pig.id)
                let cost = isEmergency ? 0 : Adoption.calculateAdoptionCost(pig, state: gameState)
                let canAfford = isEmergency || gameState.money >= cost

                AdoptionPigRow(pig: pig, cost: cost, canAfford: canAfford, isFree: isEmergency)
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
        }
        .sheet(item: $selectedPig) { pig in
            NavigationStack {
                adoptionDetail(pig: pig)
                    .navigationTitle(pig.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedPig = nil }
                        }
                    }
            }
            .presentationDetents([.medium])
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
    var isFree: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(pig.name)
                        .font(.body)
                    Text(pig.gender.displaySymbol)
                        .font(.caption)
                        .foregroundStyle(pig.gender.displayColor)
                    if isFree {
                        StatusBadge(label: "Free", color: .green)
                    }
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

            if isFree {
                Text("Free")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                CurrencyLabel(amount: cost)
                    .foregroundStyle(canAfford ? AnyShapeStyle(.yellow) : AnyShapeStyle(.red))
            }
        }
    }
}

// MARK: - Emergency Banners

extension AdoptionView {
    /// Guidance banners shown when the player is in emergency bailout mode.
    private var emergencyBanners: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Your farm is empty! Adopt the free pigs below to get started again.")
                    .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !gameState.breedingProgram.enabled {
                HStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.pink)
                    Text("Enable the **Breeding Program** in the Breeding tab to grow your herd automatically.")
                        .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.pink.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - AdoptionView Actions

extension AdoptionView {
    /// Detail panel for the selected adoption pig.
    ///
    /// Maps from: shop.py _update_detail() adoption pig branch.
    private func adoptionDetail(pig: GuineaPig) -> some View {
        let isEmergency = emergencyPigIDs.contains(pig.id)
        let cost = isEmergency ? 0 : Adoption.calculateAdoptionCost(pig, state: gameState)
        let canAfford = isEmergency || gameState.money >= cost

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pig.name).font(.headline)
                if isEmergency {
                    StatusBadge(label: "Free", color: .green)
                }
                Spacer()
                if !isEmergency {
                    CurrencyLabel(amount: cost)
                }
            }

            HStack {
                Text("\(pig.gender.displaySymbol) \(pig.gender.displayLabel)")
                    .font(.caption)
                    .foregroundStyle(pig.gender.displayColor)
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

        let isEmergency = emergencyPigIDs.contains(pig.id)
        let cost = isEmergency ? 0 : Adoption.calculateAdoptionCost(pig, state: gameState)

        guard isEmergency || gameState.money >= cost else {
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

        if cost > 0 {
            _ = gameState.spendMoney(cost)
        }
        gameState.addGuineaPig(adoptedPig)

        let costLabel = isEmergency ? "free (emergency)" : "\(cost) Squeaks"
        gameState.logEvent(
            "Adopted \(pig.name) (\(pig.phenotype.displayName)) for \(costLabel)",
            eventType: "adoption"
        )

        emergencyPigIDs.remove(pig.id)
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

        var batch = Adoption.generateAdoptionBatch(
            existingNames: existingNames,
            farmTier: gameState.farmTier,
            count: Int.random(in: 3...5)
        )

        emergencyPigIDs = []
        if EmergencyBailout.isSoftLocked(state: gameState) {
            let batchNames = Set(batch.map(\.name))
            let emergencyPigs = EmergencyBailout.generateEmergencyPigs(
                existingNames: existingNames.union(batchNames),
                farmTier: gameState.farmTier
            )
            emergencyPigIDs = Set(emergencyPigs.map(\.id))
            batch = emergencyPigs + batch
        }

        availablePigs = batch
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
