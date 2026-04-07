/// ShowroomView — Prestige shop for browsing and purchasing Showroom upgrades.
/// Displays Rosette balance, tier-grouped upgrades, and a detail sheet for each.
import SwiftUI

struct ShowroomView: View {
    let gameState: GameState
    @State private var selectedUpgrade: ShowroomUpgrade?
    /// Incremented on each purchase to force SwiftUI re-render.
    /// Needed because `GameState.prestigeState` is `@ObservationIgnored`.
    @State private var purchaseCount = 0
    @Environment(\.dismiss) private var dismiss

    private var prestigeState: PrestigeState { gameState.prestigeState }

    /// Upgrades grouped by tier, in tier order.
    private var upgradesByTier: [(ShowroomTier, [ShowroomUpgrade])] {
        let grouped = Dictionary(grouping: ShowroomUpgrade.allCases, by: \.tier)
        return ShowroomTier.allCases.map { tier in
            (tier, grouped[tier] ?? [])
        }
    }

    private var totalPurchased: Int {
        ShowroomUpgrade.allCases.filter { prestigeState.hasUpgrade($0) }.count
    }

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = purchaseCount // Read to register SwiftUI dependency

        NavigationStack {
            List {
                rosetteHeader
                ForEach(upgradesByTier, id: \.0) { tier, upgrades in
                    ShowroomTierSection(
                        tier: tier,
                        upgrades: upgrades,
                        prestigeState: prestigeState,
                        onUpgradeTapped: { selectedUpgrade = $0 }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("The Showroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Label("\(prestigeState.rosetteBalance)", systemImage: "rosette")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
            .sheet(item: $selectedUpgrade) { upgrade in
                ShowroomUpgradeDetail(
                    upgrade: upgrade,
                    prestigeState: prestigeState,
                    onPurchase: { purchaseUpgrade(upgrade) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Sub-views

private extension ShowroomView {
    var rosetteHeader: some View {
        Section {
            HStack {
                Image(systemName: "rosette")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(prestigeState.rosetteBalance) Rosettes")
                        .font(.title3.bold())
                    Text("\(totalPurchased)/\(ShowroomUpgrade.allCases.count) upgrades owned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Actions

private extension ShowroomView {
    @MainActor
    func purchaseUpgrade(_ upgrade: ShowroomUpgrade) {
        guard gameState.prestigeState.purchaseUpgrade(upgrade) else {
            HapticManager.error()
            AudioManager.error()
            return
        }
        HapticManager.purchase()
        AudioManager.purchase()
        purchaseCount += 1
    }
}

// MARK: - Identifiable

extension ShowroomUpgrade: Identifiable {
    var id: String { rawValue }
}
