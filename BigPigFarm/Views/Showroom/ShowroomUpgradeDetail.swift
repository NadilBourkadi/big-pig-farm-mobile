/// ShowroomUpgradeDetail — Detail sheet for a Showroom upgrade.
/// Shows full description, compound impact text, and purchase button.
import SwiftUI

struct ShowroomUpgradeDetail: View {
    let upgrade: ShowroomUpgrade
    let prestigeState: PrestigeState
    let onPurchase: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var displayState: UpgradeDisplayState {
        UpgradeDisplayState.resolve(upgrade: upgrade, prestigeState: prestigeState)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()
                    descriptionSection
                    Divider()
                    impactSection
                    Spacer(minLength: 20)
                    purchaseSection
                }
                .padding()
            }
            .navigationTitle(upgrade.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sections

private extension ShowroomUpgradeDetail {
    var headerSection: some View {
        HStack {
            Label(
                "Tier \(upgrade.tier.rawValue) — \(upgrade.tier.displayName)",
                systemImage: "star.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
            Label("\(upgrade.cost)", systemImage: "rosette")
                .font(.title3.bold())
                .foregroundStyle(displayState == .purchased ? .green : .orange)
        }
    }

    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effect")
                .font(.headline)
            Text(upgrade.info.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    var impactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            Text(compoundImpactText)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    var purchaseSection: some View {
        Group {
            switch displayState {
            case .purchased:
                Label("Owned", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            case .affordable:
                Button {
                    onPurchase()
                    dismiss()
                } label: {
                    Label(
                        "Purchase for \(upgrade.cost) Rosettes",
                        systemImage: "rosette"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            case .unaffordable:
                VStack(spacing: 4) {
                    Label(
                        "Requires \(upgrade.cost) Rosettes",
                        systemImage: "rosette"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    Text("You have \(prestigeState.rosetteBalance)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Compound Impact Text

extension ShowroomUpgradeDetail {
    // swiftlint:disable:next cyclomatic_complexity
    /// Human-readable compound impact text for each upgrade.
    var compoundImpactText: String {
        let cfg = GameConfig.Prestige.self
        switch upgrade {
        case .expandedHutch:
            return "+\(cfg.expandedHutchCapacityBonus) pig capacity per room, "
                + "permanently. Applies to all existing and future rooms."
        case .rapidRecovery:
            return "Post-birth recovery time multiplied by "
                + "\(cfg.rapidRecoveryMultiplier)x, halving the breeding cooldown."
        case .earlyBloomer:
            return "Breeding eligibility at \(cfg.earlyBloomerMinBreedingAge) "
                + "days old instead of the standard 3 days."
        case .pigdexMomentum:
            let per = formatPercent(cfg.pigdexMomentumPerEntry)
            let cap = formatPercent(cfg.pigdexMomentumCap)
            return "Each Pigdex discovery adds +\(per) breeding chance, "
                + "up to +\(cap) maximum."
        case .twinSpark:
            return "\(formatPercent(cfg.twinSparkChance)) chance any birth "
                + "produces an extra piglet alongside the normal litter."
        case .fertileGround:
            let chance = formatPercent(cfg.fertileGroundBreedingChance)
            return "Base breeding chance: 5% \u{2192} \(chance), "
                + "permanently doubling breeding odds."
        case .mutationCatalyst:
            let rate = formatPercent(cfg.mutationCatalystRate)
            return "Base mutation rate: 2% \u{2192} \(rate). "
                + "Novel phenotypes appear more often."
        case .enduringBonds:
            return "Max breeding age \u{2192} \(cfg.enduringBondsMaxBreedingAge) "
                + "days, lifespan \u{2192} \(cfg.enduringBondsMaxAge) days."
        case .phenotypeRecall:
            let chance = formatPercent(cfg.phenotypeRecallChance)
            return "\(chance) chance a newborn matches a Pigdex phenotype "
                + "from any previous farm."
        case .biomeIntuition:
            let mult = formatMultiplier(cfg.biomeIntuitionMultiplier)
            return "Biome-signature mutations \(mult) more likely "
                + "when breeding in matching biomes."
        case .treatPouch:
            return "+\(cfg.treatPouchBonusTreats) treats per visit, "
                + "increasing your daily interaction budget."
        case .quickStudy:
            let pct = formatPercent(1.0 - cfg.quickStudyThresholdMultiplier)
            return "Tier advancement thresholds reduced by \(pct), "
                + "reaching higher tiers faster."
        case .prolificLine:
            let min = cfg.prolificLineMinLitter
            return "Minimum litter size: 1 \u{2192} \(min). "
                + "Guarantees at least \(min) piglets per birth."
        case .geneticImprinting:
            return "Lock one allele locus on a pig so it passes to all "
                + "offspring with 100% certainty."
        case .premiumGenetics:
            let mult = formatMultiplier(cfg.premiumGeneticsRarityMultiplier)
            return "Rare+ phenotypes \(mult) more likely "
                + "in all breeding outcomes."
        case .speedGestation:
            let days = formatDays(cfg.speedGestationDays)
            return "Pregnancy: 2 days \u{2192} \(days), "
                + "accelerating your breeding cycle."
        case .establishedFarm:
            return "New farms start at Tier 2 with 2 rooms, "
                + "skipping the early grind."
        case .reunionSpirit:
            return "Reunion boosts last longer and are stronger: "
                + "enhanced happiness and breeding bonuses on return."
        case .autoPilot:
            return "New farms start with Bulk Feeders and Drip System "
                + "already purchased."
        case .grandFarm:
            return "New farms start at Tier 3 with 3 rooms and "
                + "immediate access to advanced biomes."
        case .selectiveAdvantage:
            return "Unlocks Allele Preferences in the breeding program "
                + "to configure favored alleles per locus."
        case .legendaryLineage:
            let mult = formatMultiplier(cfg.legendaryLineageMultiplier)
            return "Legendary phenotype chance \(mult) in all breeding, "
                + "making the rarest pigs more attainable."
        case .goldenTouch:
            let pct = formatPercent(cfg.goldenTouchSaleBonus)
            return "All pig sale values permanently +\(pct)."
        case .heritageHerd:
            return "Start with 5 pigs: 2 uncommon or better, "
                + "1 carrying a bloodline allele."
        case .keepsakeSlot:
            return "Carry up to \(cfg.keepsakeMaxSlots) regular perks "
                + "across all future farms permanently."
        }
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }

    private func formatMultiplier(_ value: Double) -> String {
        "\(String(format: "%.1f", value))x"
    }

    private func formatDays(_ value: Double) -> String {
        value == Double(Int(value))
            ? "\(Int(value)) days"
            : "\(String(format: "%.1f", value)) days"
    }
}
