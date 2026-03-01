// ShopViewTabs — Perks, Farm, and Pigs tab content for ShopView.
// Maps from: ui/screens/shop_screen.py
import SwiftUI

// MARK: - PerksTab

/// Displays all available one-time upgrade perks, grouped by category.
struct PerksTab: View {
    let gameState: GameState
    @State private var alertMessage: String = ""
    @State private var showingAlert = false

    private var perksByCategory: [(String, [UpgradeDefinition])] {
        let available = Shop.getAvailablePerks(farmTier: gameState.farmTier)
        let grouped = Dictionary(grouping: available, by: \.category)
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        Group {
            if perksByCategory.isEmpty {
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
                    ForEach(perksByCategory, id: \.0) { category, perks in
                        Section(category) {
                            ForEach(perks, id: \.id) { perk in
                                PerkRow(perk: perk, gameState: gameState, onError: showError)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .alert("Purchase Failed", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - PerkRow

private struct PerkRow: View {
    let perk: UpgradeDefinition
    let gameState: GameState
    let onError: (String) -> Void

    private var isOwned: Bool { gameState.purchasedUpgrades.contains(perk.id) }
    private var canAfford: Bool { gameState.money >= perk.cost }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(perk.name)
                    .font(.body.bold())
                    .foregroundStyle(perk.implemented ? .primary : .secondary)
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
                } else if !perk.implemented {
                    Text("Soon")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else {
                    CurrencyLabel(amount: perk.cost)
                        .foregroundStyle(canAfford ? .yellow : .secondary)
                    Button(action: purchase) {
                        Text("Buy")
                            .font(.caption.bold())
                            .frame(width: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAfford)
                    .accessibilityLabel("Buy \(perk.name) for \(Currency.formatCurrency(perk.cost))")
                }
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func purchase() {
        if Shop.purchasePerk(perkID: perk.id, state: gameState) {
            HapticManager.purchase()
        } else {
            onError("Could not purchase \(perk.name).")
            HapticManager.error()
        }
    }
}

// MARK: - FarmTab

/// Displays the tier upgrade section and room expansion section.
struct FarmTab: View {
    let gameState: GameState
    @State private var showingBiomePicker = false
    @State private var alertMessage: String = ""
    @State private var showingAlert = false

    private var nextTier: TierUpgrade? { Shop.getNextTierUpgrade(state: gameState) }
    private var tierRequirements: [String: Bool] {
        guard let tier = nextTier else { return [:] }
        return Shop.checkTierRequirements(state: gameState, upgrade: tier)
    }
    private var allRequirementsMet: Bool { tierRequirements.values.allSatisfy { $0 } }
    private var roomInfo: RoomUpgradeInfo? { Shop.getFarmUpgradeInfo(state: gameState) }

    var body: some View {
        List {
            tierUpgradeSection
            if roomInfo != nil {
                roomExpansionSection
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingBiomePicker) {
            BiomeSelectView(
                farmTier: gameState.farmTier,
                existingBiomes: Set(gameState.farm.areas.map(\.biome))
            ) { biome in
                if let biome {
                    purchaseRoom(biome: biome)
                }
                showingBiomePicker = false
            }
        }
        .alert("Purchase Failed", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Tier Upgrade Section

    private var tierUpgradeSection: some View {
        Section("Farm Tier") {
            if let tier = nextTier {
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
                        current: gameState.totalPigsBorn,
                        required: tier.requiredPigsBorn,
                        met: tierRequirements["pigs_born"] ?? false
                    )
                    RequirementRow(
                        label: "Pigdex",
                        current: gameState.pigdex.discoveredCount,
                        required: tier.requiredPigdex,
                        met: tierRequirements["pigdex"] ?? false
                    )
                    if tier.requiredContracts > 0 {
                        RequirementRow(
                            label: "Contracts",
                            current: gameState.contractBoard.completedContracts,
                            required: tier.requiredContracts,
                            met: tierRequirements["contracts"] ?? false
                        )
                    }
                    RequirementRow(
                        label: "Funds",
                        current: gameState.money,
                        required: tier.cost,
                        met: tierRequirements["money"] ?? false,
                        formatter: Currency.formatCurrency
                    )
                    Button(action: upgradeTier) {
                        Text("Upgrade to Tier \(tier.tier)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allRequirementsMet)
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
            if let info = roomInfo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.name)
                                .font(.body.bold())
                            Text("\(info.width)×\(info.height) cells · Capacity: \(info.capacity) pigs")
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
                        action: { showingBiomePicker = true },
                        label: { Text("Buy New Room").frame(maxWidth: .infinity) }
                    )
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(gameState.money < info.cost)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func upgradeTier() {
        if Shop.purchaseTierUpgrade(state: gameState) {
            HapticManager.purchase()
        } else {
            alertMessage = "Farm tier upgrade failed. Check requirements."
            showingAlert = true
            HapticManager.error()
        }
    }

    @MainActor
    private func purchaseRoom(biome: BiomeType) {
        if Shop.purchaseNewRoom(state: gameState, biome: biome) {
            HapticManager.purchase()
        } else {
            alertMessage = "Room purchase failed. Check your funds."
            showingAlert = true
            HapticManager.error()
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
