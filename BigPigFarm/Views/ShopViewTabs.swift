// ShopViewTabs — Perks, Farm, and Pigs tab content for ShopView.
// Maps from: ui/screens/shop_screen.py
import SwiftUI

// MARK: - PerksTab

/// Displays all available one-time upgrade perks, grouped by category.
struct PerksTab: View {
    let viewModel: ShopViewModel

    var body: some View {
        Group {
            if viewModel.perksByCategory.isEmpty {
                VStack(spacing: 8) {
                    Text("No perks unlocked yet.")
                        .foregroundStyle(.secondary)
                    Text("Reach Tier 2 to unlock perks.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.perksByCategory, id: \.0) { category, perks in
                        Section(category) {
                            ForEach(perks, id: \.id) { perk in
                                PerkRow(perk: perk, viewModel: viewModel)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - PerkRow

private struct PerkRow: View {
    let perk: UpgradeDefinition
    let viewModel: ShopViewModel

    private var isOwned: Bool { viewModel.isPerkOwned(perk.id) }
    private var canAfford: Bool { viewModel.gameState.money >= perk.cost }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(perk.name)
                    .font(.body.bold())
                Text(perk.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: 6) {
                if isOwned {
                    Text("Owned")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    CurrencyLabel(amount: perk.cost)
                        .foregroundStyle(canAfford ? .yellow : .secondary)
                    Button {
                        viewModel.purchasePerk(perk)
                    } label: {
                        Text("Buy")
                            .font(.caption.bold())
                            .frame(width: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAfford)
                    .accessibilityLabel(
                        "Buy \(perk.name) for \(Currency.formatCurrency(perk.cost))"
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FarmTab

/// Displays the tier upgrade section and room expansion section.
struct FarmTab: View {
    let viewModel: ShopViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            tierUpgradeSection
            if viewModel.roomInfo != nil {
                roomExpansionSection
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $viewModel.showingBiomePicker) {
            BiomeSelectView(
                farmTier: viewModel.gameState.farmTier,
                existingBiomes: Set(viewModel.gameState.farm.areas.map(\.biome))
            ) { biome in
                if let biome {
                    viewModel.purchaseRoom(biome: biome)
                }
                viewModel.showingBiomePicker = false
            }
        }
    }

    // MARK: - Tier Upgrade Section

    private var tierUpgradeSection: some View {
        Section("Farm Tier") {
            if let tier = viewModel.nextTier {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tier \(tier.tier): \(tier.name)")
                            .font(.body.bold())
                        Spacer()
                        CurrencyLabel(amount: tier.cost)
                    }
                    Divider()
                    RequirementRow(
                        label: "Pigs Born",
                        current: viewModel.gameState.totalPigsBorn,
                        required: tier.requiredPigsBorn,
                        met: viewModel.tierRequirements["pigs_born"] ?? false
                    )
                    RequirementRow(
                        label: "Pigdex",
                        current: viewModel.gameState.pigdex.discoveredCount,
                        required: tier.requiredPigdex,
                        met: viewModel.tierRequirements["pigdex"] ?? false
                    )
                    if tier.requiredContracts > 0 {
                        RequirementRow(
                            label: "Contracts",
                            current: viewModel.gameState.contractBoard.completedContracts,
                            required: tier.requiredContracts,
                            met: viewModel.tierRequirements["contracts"] ?? false
                        )
                    }
                    RequirementRow(
                        label: "Funds",
                        current: viewModel.gameState.money,
                        required: tier.cost,
                        met: viewModel.tierRequirements["money"] ?? false,
                        formatter: Currency.formatCurrency
                    )
                    Button {
                        viewModel.upgradeTier()
                    } label: {
                        Text("Upgrade to Tier \(tier.tier)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.allRequirementsMet)
                }
                .padding(.vertical, 4)
            } else {
                Label("Maximum tier reached!", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }

    // MARK: - Room Expansion Section

    private var roomExpansionSection: some View {
        Section("Room Expansion") {
            if let info = viewModel.roomInfo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.name)
                                .font(.body.bold())
                            Text(
                                "\(info.width)×\(info.height) cells · Capacity: \(info.capacity) pigs"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        CurrencyLabel(amount: info.cost)
                    }
                    Text("Biome cost added at selection.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button(
                        action: { viewModel.showingBiomePicker = true },
                        label: { Text("Buy New Room").frame(maxWidth: .infinity) }
                    )
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.gameState.money < info.cost)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - RequirementRow

/// A single requirement row for the tier upgrade checklist.
private struct RequirementRow: View {
    let label: String
    let current: Int
    let required: Int
    let met: Bool
    var formatter: ((Int) -> String)?

    private func display(_ value: Int) -> String {
        formatter?(value) ?? "\(value)"
    }

    var body: some View {
        HStack {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .accessibilityLabel(met ? "Requirement met" : "Requirement not met")
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(display(current)) / \(display(required))")
                .font(.caption)
                .foregroundStyle(met ? .green : .secondary)
        }
    }
}

// MARK: - PigsTab

/// Embeds AdoptionView as the Pigs tab content.
struct PigsTab: View {
    let gameState: GameState

    var body: some View {
        AdoptionView(gameState: gameState)
    }
}
