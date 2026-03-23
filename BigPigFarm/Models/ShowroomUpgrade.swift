/// ShowroomUpgrade -- Permanent upgrades purchasable with Rosettes in the Showroom.
/// Maps from: design-prestige-and-progression.md Section 5
import Foundation

// MARK: - ShowroomTier

/// Tier classification for Showroom upgrades.
enum ShowroomTier: Int, Codable, CaseIterable, Sendable {
    case newcomer = 1
    case apprentice = 2
    case expert = 3
    case master = 4
}

// MARK: - ShowroomUpgrade

/// All 25 Showroom upgrades purchasable with Rosettes.
enum ShowroomUpgrade: String, Codable, CaseIterable, Sendable {
    // Tier 1 — Newcomer (5 upgrades, 2–4 Rosettes each)
    case expandedHutch = "expanded_hutch"
    case rapidRecovery = "rapid_recovery"
    case earlyBloomer = "early_bloomer"
    case pigdexMomentum = "pigdex_momentum"
    case twinSpark = "twin_spark"

    // Tier 2 — Apprentice (7 upgrades, 5–10 Rosettes each)
    case fertileGround = "fertile_ground"
    case mutationCatalyst = "mutation_catalyst"
    case enduringBonds = "enduring_bonds"
    case phenotypeRecall = "phenotype_recall"
    case biomeIntuition = "biome_intuition"
    case treatPouch = "treat_pouch"
    case quickStudy = "quick_study"

    // Tier 3 — Expert (7 upgrades, 12–20 Rosettes each)
    case prolificLine = "prolific_line"
    case geneticImprinting = "genetic_imprinting"
    case premiumGenetics = "premium_genetics"
    case speedGestation = "speed_gestation"
    case establishedFarm = "established_farm"
    case reunionSpirit = "reunion_spirit"
    case autoPilot = "auto_pilot"

    // Tier 4 — Master (6 upgrades, 25–50 Rosettes each)
    case grandFarm = "grand_farm"
    case selectiveAdvantage = "selective_advantage"
    case legendaryLineage = "legendary_lineage"
    case goldenTouch = "golden_touch"
    case heritageHerd = "heritage_herd"
    case keepsakeSlot = "keepsake_slot"

    /// Static metadata for this upgrade.
    var info: ShowroomUpgradeInfo {
        guard let value = showroomUpgradeInfo[self] else {
            preconditionFailure("Missing showroomUpgradeInfo for \(self)")
        }
        return value
    }

    /// Rosette cost.
    var cost: Int { info.cost }

    /// Which tier this upgrade belongs to.
    var tier: ShowroomTier { info.tier }

    /// Human-readable name for display.
    var displayName: String { info.displayName }
}

// MARK: - ShowroomUpgradeInfo

/// Static metadata for a Showroom upgrade (not Codable -- static lookup data).
struct ShowroomUpgradeInfo: Sendable {
    let displayName: String
    let description: String
    let cost: Int
    let tier: ShowroomTier
}

// MARK: - Showroom Upgrade Lookup Table

/// All 25 upgrade metadata entries. From design doc Section 5.
let showroomUpgradeInfo: [ShowroomUpgrade: ShowroomUpgradeInfo] = [
    // Tier 1 — Newcomer
    .expandedHutch: ShowroomUpgradeInfo(
        displayName: "Expanded Hutch",
        description: "+2 pig capacity per room, permanently",
        cost: 3, tier: .newcomer),
    .rapidRecovery: ShowroomUpgradeInfo(
        displayName: "Rapid Recovery",
        description: "Post-birth recovery halved: 1 day to 12 hours",
        cost: 2, tier: .newcomer),
    .earlyBloomer: ShowroomUpgradeInfo(
        displayName: "Early Bloomer",
        description: "Breeding age minimum reduced from 3 days to 2 days",
        cost: 3, tier: .newcomer),
    .pigdexMomentum: ShowroomUpgradeInfo(
        displayName: "Pigdex Momentum",
        description: "Each Pigdex discovery grants +0.5% breeding chance (caps at +10%)",
        cost: 3, tier: .newcomer),
    .twinSpark: ShowroomUpgradeInfo(
        displayName: "Twin Spark",
        description: "10% chance any birth produces an extra piglet",
        cost: 4, tier: .newcomer),
    // Tier 2 — Apprentice
    .fertileGround: ShowroomUpgradeInfo(
        displayName: "Fertile Ground",
        description: "Base breeding chance 5% to 10% permanently",
        cost: 6, tier: .apprentice),
    .mutationCatalyst: ShowroomUpgradeInfo(
        displayName: "Mutation Catalyst",
        description: "Base mutation rate 2% to 5% permanently",
        cost: 5, tier: .apprentice),
    .enduringBonds: ShowroomUpgradeInfo(
        displayName: "Enduring Bonds",
        description: "Max breeding age 30 to 40 days, lifespan 45 to 60 days",
        cost: 8, tier: .apprentice),
    .phenotypeRecall: ShowroomUpgradeInfo(
        displayName: "Phenotype Recall",
        description: "15% chance a newborn matches a previously-discovered Pigdex phenotype",
        cost: 7, tier: .apprentice),
    .biomeIntuition: ShowroomUpgradeInfo(
        displayName: "Biome Intuition",
        description: "Biome signature color mutations 2x more likely",
        cost: 6, tier: .apprentice),
    .treatPouch: ShowroomUpgradeInfo(
        displayName: "Treat Pouch",
        description: "+2 treats per visit",
        cost: 5, tier: .apprentice),
    .quickStudy: ShowroomUpgradeInfo(
        displayName: "Quick Study",
        description: "Tier advancement requirements reduced by 25%",
        cost: 8, tier: .apprentice),
    // Tier 3 — Expert
    .prolificLine: ShowroomUpgradeInfo(
        displayName: "Prolific Line",
        description: "Base litter size minimum 1 to 2",
        cost: 16, tier: .expert),
    .geneticImprinting: ShowroomUpgradeInfo(
        displayName: "Genetic Imprinting",
        description: "Lock one allele locus on a pig, guaranteeing it passes to all offspring",
        cost: 18, tier: .expert),
    .premiumGenetics: ShowroomUpgradeInfo(
        displayName: "Premium Genetics",
        description: "Rare+ phenotypes 1.5x more likely in all breeding outcomes",
        cost: 15, tier: .expert),
    .speedGestation: ShowroomUpgradeInfo(
        displayName: "Speed Gestation",
        description: "Pregnancy duration 2 to 1.5 days permanently",
        cost: 14, tier: .expert),
    .establishedFarm: ShowroomUpgradeInfo(
        displayName: "Established Farm",
        description: "Start at Tier 2 with 2 rooms",
        cost: 15, tier: .expert),
    .reunionSpirit: ShowroomUpgradeInfo(
        displayName: "Reunion Spirit",
        description: "Visit bonuses last 2x longer and are 50% stronger",
        cost: 12, tier: .expert),
    .autoPilot: ShowroomUpgradeInfo(
        displayName: "Auto-Pilot",
        description: "Start each new farm with Bulk Feeders and Drip System perks",
        cost: 15, tier: .expert),
    // Tier 4 — Master
    .grandFarm: ShowroomUpgradeInfo(
        displayName: "Grand Farm",
        description: "Start at Tier 3 with 3 rooms",
        cost: 35, tier: .master),
    .selectiveAdvantage: ShowroomUpgradeInfo(
        displayName: "Selective Advantage",
        description: "Configure allele preferences per locus in the breeding program",
        cost: 45, tier: .master),
    .legendaryLineage: ShowroomUpgradeInfo(
        displayName: "Legendary Lineage",
        description: "Legendary phenotype chance 2x in all breeding",
        cost: 30, tier: .master),
    .goldenTouch: ShowroomUpgradeInfo(
        displayName: "Golden Touch",
        description: "All pig sale values +25% permanently",
        cost: 30, tier: .master),
    .heritageHerd: ShowroomUpgradeInfo(
        displayName: "Heritage Herd",
        description: "Start with 5 pigs: 2 uncommon+, 1 with a bloodline allele",
        cost: 40, tier: .master),
    .keepsakeSlot: ShowroomUpgradeInfo(
        displayName: "Keepsake Slot",
        description: "Choose 1 regular perk to carry across all future farms (max 3 slots)",
        cost: 50, tier: .master),
]
