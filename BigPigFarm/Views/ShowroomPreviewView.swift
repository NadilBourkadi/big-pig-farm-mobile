/// ShowroomPreviewView — Read-only Showroom upgrade preview within the Pig Show flow.
/// Shows what the player could buy with their Rosettes to motivate prestige.
import SwiftUI

struct ShowroomPreviewView: View {
    let prestigeState: PrestigeState
    /// Rosettes about to be earned (not yet awarded).
    let pendingRosettes: Int
    let onContinue: () -> Void

    private var projectedBalance: Int {
        prestigeState.rosetteBalance + pendingRosettes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                balanceHeader
                tierSections
                continueButton
            }
            .padding()
        }
        .navigationTitle("Showroom Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        VStack(spacing: 4) {
            Text("After prestige, you'll have")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "rosette")
                    .foregroundStyle(.pink)
                Text("\(projectedBalance)")
                    .font(.title.bold())
                    .foregroundStyle(.pink)
                Text("Rosettes")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Tier Sections

    @ViewBuilder
    private var tierSections: some View {
        ForEach(ShowroomTier.allCases, id: \.rawValue) { tier in
            let upgrades = ShowroomUpgrade.allCases.filter { $0.tier == tier }
            if !upgrades.isEmpty {
                tierSection(tier: tier, upgrades: upgrades)
            }
        }
    }

    private func tierSection(tier: ShowroomTier, upgrades: [ShowroomUpgrade]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tierDisplayName(tier))
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(upgrades, id: \.rawValue) { upgrade in
                upgradeRow(upgrade)
            }
        }
    }

    // MARK: - Upgrade Row

    private func upgradeRow(_ upgrade: ShowroomUpgrade) -> some View {
        let owned = prestigeState.hasUpgrade(upgrade)
        let affordable = !owned && projectedBalance >= upgrade.cost

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(owned ? .secondary : .primary)
                Text(upgrade.info.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            purchaseStateBadge(owned: owned, affordable: affordable, cost: upgrade.cost)
        }
        .padding(12)
        .background(badgeBackground(owned: owned, affordable: affordable))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(owned ? 0.7 : 1.0)
    }

    // MARK: - Purchase State

    @ViewBuilder
    private func purchaseStateBadge(owned: Bool, affordable: Bool, cost: Int) -> some View {
        if owned {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
        } else if affordable {
            Label("\(cost)", systemImage: "rosette")
                .font(.caption.bold())
                .foregroundStyle(.pink)
        } else {
            Label("\(cost)", systemImage: "rosette")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }

    private func badgeBackground(owned: Bool, affordable: Bool) -> some ShapeStyle {
        if owned {
            return Color.green.opacity(0.08)
        } else if affordable {
            return Color.pink.opacity(0.08)
        } else {
            return Color.secondary.opacity(0.06)
        }
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue to Confirmation")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func tierDisplayName(_ tier: ShowroomTier) -> String {
        switch tier {
        case .newcomer: "Newcomer"
        case .apprentice: "Apprentice"
        case .expert: "Expert"
        case .master: "Master"
        }
    }
}
