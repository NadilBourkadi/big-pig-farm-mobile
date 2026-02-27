/// Upgrades -- Permanent perk upgrade definitions.
/// Maps from: economy/upgrades.py
import Foundation

// MARK: - UpgradeDefinition

/// A permanent one-time upgrade purchasable from the Perks tab.
struct UpgradeDefinition: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let requiredTier: Int
    let category: String
    let implemented: Bool
}

// MARK: - Upgrades Lookup Table

/// All 24 upgrade definitions, keyed by ID.
let upgrades: [String: UpgradeDefinition] = [
    // Automation (3)
    "bulk_feeders": UpgradeDefinition(
        id: "bulk_feeders", name: "Bulk Feeders",
        description: "All food/water facility capacity doubled.",
        cost: 350, requiredTier: 2, category: "Automation", implemented: true),
    "drip_system": UpgradeDefinition(
        id: "drip_system", name: "Drip System",
        description: "Food/water facilities passively regen 2 units per game-hour.",
        cost: 1800, requiredTier: 3, category: "Automation", implemented: true),
    "auto_feeders": UpgradeDefinition(
        id: "auto_feeders", name: "Auto-Feeders",
        description: "Facilities auto-refill to full when below 25% capacity.",
        cost: 6000, requiredTier: 4, category: "Automation", implemented: true),

    // Breeding (4)
    "fertility_herbs": UpgradeDefinition(
        id: "fertility_herbs", name: "Fertility Herbs",
        description: "+5% base breeding chance.",
        cost: 400, requiredTier: 2, category: "Breeding", implemented: true),
    "breeding_insight": UpgradeDefinition(
        id: "breeding_insight", name: "Breeding Insight",
        description: "Pig detail shows offspring phenotype probabilities for selected pairs.",
        cost: 1200, requiredTier: 3, category: "Breeding", implemented: false),
    "litter_boost": UpgradeDefinition(
        id: "litter_boost", name: "Litter Boost",
        description: "Max litter size +1.",
        cost: 7000, requiredTier: 4, category: "Breeding", implemented: true),
    "genetic_accelerator": UpgradeDefinition(
        id: "genetic_accelerator", name: "Genetic Accelerator",
        description: "Mutation rate doubled (stacks with Genetics Lab).",
        cost: 20000, requiredTier: 5, category: "Breeding", implemented: true),

    // Comfort (4)
    "premium_bedding": UpgradeDefinition(
        id: "premium_bedding", name: "Premium Bedding",
        description: "Energy recovery while sleeping +25%.",
        cost: 250, requiredTier: 2, category: "Comfort", implemented: true),
    "enrichment_program": UpgradeDefinition(
        id: "enrichment_program", name: "Enrichment Program",
        description: "Boredom grows 20% slower.",
        cost: 1000, requiredTier: 3, category: "Comfort", implemented: true),
    "climate_control": UpgradeDefinition(
        id: "climate_control", name: "Climate Control",
        description: "All biomes grant +0.3 happiness/hr.",
        cost: 2000, requiredTier: 3, category: "Comfort", implemented: true),
    "pig_spa": UpgradeDefinition(
        id: "pig_spa", name: "Pig Spa Package",
        description: "Passive health recovery doubled.",
        cost: 5000, requiredTier: 4, category: "Comfort", implemented: true),

    // Economy (4)
    "market_connections": UpgradeDefinition(
        id: "market_connections", name: "Market Connections",
        description: "All pig sale values +10%.",
        cost: 500, requiredTier: 2, category: "Economy", implemented: true),
    "premium_branding": UpgradeDefinition(
        id: "premium_branding", name: "Premium Branding",
        description: "Rare+ pigs sell for additional +20%.",
        cost: 2500, requiredTier: 3, category: "Economy", implemented: true),
    "trade_network": UpgradeDefinition(
        id: "trade_network", name: "Trade Network",
        description: "Contract reward payouts +25%.",
        cost: 8000, requiredTier: 4, category: "Economy", implemented: true),
    "influencer_pig": UpgradeDefinition(
        id: "influencer_pig", name: "Influencer Pig",
        description: "Legendary pigs sell for +50%.",
        cost: 25000, requiredTier: 5, category: "Economy", implemented: true),

    // Movement (2)
    "paved_paths": UpgradeDefinition(
        id: "paved_paths", name: "Paved Paths",
        description: "Pig movement speed +20%.",
        cost: 300, requiredTier: 2, category: "Movement", implemented: true),
    "express_lanes": UpgradeDefinition(
        id: "express_lanes", name: "Express Lanes",
        description: "Pig movement speed +50% (replaces Paved Paths).",
        cost: 4000, requiredTier: 4, category: "Movement", implemented: true),

    // Quality of Life (7)
    "farm_bell": UpgradeDefinition(
        id: "farm_bell", name: "Farm Bell",
        description: "Notification when any pig's hunger/thirst drops below critical.",
        cost: 200, requiredTier: 2, category: "Quality of Life", implemented: true),
    "adoption_discount": UpgradeDefinition(
        id: "adoption_discount", name: "Adoption Discount",
        description: "Adoption prices permanently -15%.",
        cost: 300, requiredTier: 2, category: "Quality of Life", implemented: true),
    "speed_breeding": UpgradeDefinition(
        id: "speed_breeding", name: "Speed Breeding License",
        description: "Pregnancy duration -25%.",
        cost: 1500, requiredTier: 3, category: "Quality of Life", implemented: true),
    "contract_negotiator": UpgradeDefinition(
        id: "contract_negotiator", name: "Contract Negotiator",
        description: "+1 max active contract slot.",
        cost: 1200, requiredTier: 3, category: "Quality of Life", implemented: true),
    "lucky_clover": UpgradeDefinition(
        id: "lucky_clover", name: "Lucky Clover",
        description: "Pigdex discoveries award bonus 50-200 Squeaks (10% chance).",
        cost: 5000, requiredTier: 4, category: "Quality of Life", implemented: true),
    "vip_contracts": UpgradeDefinition(
        id: "vip_contracts", name: "VIP Contract Access",
        description: "Unlocks LEGENDARY contract difficulty (all 4 axes + roan, huge reward).",
        cost: 15000, requiredTier: 5, category: "Quality of Life", implemented: true),
    "talent_scout": UpgradeDefinition(
        id: "talent_scout", name: "Talent Scout",
        description: "Enables the Pig Talents system.",
        cost: 1500, requiredTier: 3, category: "Quality of Life", implemented: false),
]
