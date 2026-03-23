/// ShowroomTierSection — Groups upgrade cards under a tier header.
/// Shows tier name, purchase progress, and a list of upgrade cards.
import SwiftUI

struct ShowroomTierSection: View {
    let tier: ShowroomTier
    let upgrades: [ShowroomUpgrade]
    let prestigeState: PrestigeState
    let onUpgradeTapped: (ShowroomUpgrade) -> Void

    private var purchasedCount: Int {
        upgrades.filter { prestigeState.hasUpgrade($0) }.count
    }

    var body: some View {
        Section {
            ForEach(upgrades, id: \.self) { upgrade in
                ShowroomUpgradeCard(
                    upgrade: upgrade,
                    displayState: UpgradeDisplayState.resolve(
                        upgrade: upgrade,
                        prestigeState: prestigeState
                    ),
                    onTap: { onUpgradeTapped(upgrade) }
                )
            }
        } header: {
            HStack {
                Text("Tier \(tier.rawValue) — \(tier.displayName)")
                    .font(.headline)
                Spacer()
                Text("\(purchasedCount)/\(upgrades.count)")
                    .font(.caption.bold())
                    .foregroundStyle(
                        purchasedCount == upgrades.count ? .green : .secondary
                    )
            }
            .padding(.top, 8)
        }
    }
}
