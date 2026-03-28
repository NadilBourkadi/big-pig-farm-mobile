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

/// All 26 upgrade definitions, keyed by ID — retuned for prestige pacing (Section 7C).
let upgrades: [String: UpgradeDefinition] = [
    // Automation (3)
    "bulk_feeders": UpgradeDefinition(
        id: "bulk_feeders", name: "Bulk Feeders",
        description: "All food/water facility capacity doubled.",
        cost: 1_000, requiredTier: 2, category: "Automation", implemented: true),
    "drip_system": UpgradeDefinition(
        id: "drip_system", name: "Drip System",
        description: "Food/water facilities passively regen 2 units per game-hour.",
        cost: 9_000, requiredTier: 3, category: "Automation", implemented: true),
    "auto_feeders": UpgradeDefinition(
        id: "auto_feeders", name: "Auto-Feeders",
        description: "Facilities auto-refill to full when below 25% capacity.",
        cost: 40_000, requiredTier: 4, category: "Automation", implemented: true),

    // Breeding (4)
    "fertility_herbs": UpgradeDefinition(
        id: "fertility_herbs", name: "Fertility Herbs",
        description: "+5% base breeding chance.",
        cost: 1_500, requiredTier: 2, category: "Breeding", implemented: true),
    "breeding_insight": UpgradeDefinition(
        id: "breeding_insight", name: "Breeding Insight",
        description: "Pig detail shows offspring phenotype probabilities for selected pairs.",
        cost: 5_000, requiredTier: 3, category: "Breeding", implemented: false),
    "litter_boost": UpgradeDefinition(
        id: "litter_boost", name: "Litter Boost",
        description: "Max litter size +1.",
        cost: 50_000, requiredTier: 4, category: "Breeding", implemented: true),
    "genetic_accelerator": UpgradeDefinition(
        id: "genetic_accelerator", name: "Genetic Accelerator",
        description: "Mutation rate doubled (stacks with Genetics Lab).",
        cost: 150_000, requiredTier: 5, category: "Breeding", implemented: true),

    // Comfort (4)
    "premium_bedding": UpgradeDefinition(
        id: "premium_bedding", name: "Premium Bedding",
        description: "Energy recovery while sleeping +25%.",
        cost: 800, requiredTier: 2, category: "Comfort", implemented: true),
    "enrichment_program": UpgradeDefinition(
        id: "enrichment_program", name: "Enrichment Program",
        description: "Boredom grows 20% slower.",
        cost: 4_000, requiredTier: 3, category: "Comfort", implemented: true),
    "climate_control": UpgradeDefinition(
        id: "climate_control", name: "Climate Control",
        description: "All biomes grant +0.3 happiness/hr.",
        cost: 10_000, requiredTier: 3, category: "Comfort", implemented: true),
    "pig_spa": UpgradeDefinition(
        id: "pig_spa", name: "Pig Spa Package",
        description: "Passive health recovery doubled.",
        cost: 30_000, requiredTier: 4, category: "Comfort", implemented: true),

    // Economy (4)
    "market_connections": UpgradeDefinition(
        id: "market_connections", name: "Market Connections",
        description: "All pig sale values +10%.",
        cost: 1_500, requiredTier: 2, category: "Economy", implemented: true),
    "premium_branding": UpgradeDefinition(
        id: "premium_branding", name: "Premium Branding",
        description: "Rare+ pigs sell for additional +20%.",
        cost: 12_000, requiredTier: 3, category: "Economy", implemented: true),
    "trade_network": UpgradeDefinition(
        id: "trade_network", name: "Trade Network",
        description: "Contract reward payouts +25%.",
        cost: 50_000, requiredTier: 4, category: "Economy", implemented: true),
    "influencer_pig": UpgradeDefinition(
        id: "influencer_pig", name: "Influencer Pig",
        description: "Legendary pigs sell for +50%.",
        cost: 200_000, requiredTier: 5, category: "Economy", implemented: true),

    // Movement (2)
    "paved_paths": UpgradeDefinition(
        id: "paved_paths", name: "Paved Paths",
        description: "Pig movement speed +20%.",
        cost: 1_000, requiredTier: 2, category: "Movement", implemented: true),
    "express_lanes": UpgradeDefinition(
        id: "express_lanes", name: "Express Lanes",
        description: "Pig movement speed +50% (replaces Paved Paths).",
        cost: 25_000, requiredTier: 4, category: "Movement", implemented: true),

    // Quality of Life (7)
    "farm_bell": UpgradeDefinition(
        id: "farm_bell", name: "Farm Bell",
        description: "Notification when any pig's hunger/thirst drops below critical.",
        cost: 500, requiredTier: 2, category: "Quality of Life", implemented: true),
    "adoption_discount": UpgradeDefinition(
        id: "adoption_discount", name: "Adoption Discount",
        description: "Adoption prices permanently -15%.",
        cost: 1_000, requiredTier: 2, category: "Quality of Life", implemented: true),
    "speed_breeding": UpgradeDefinition(
        id: "speed_breeding", name: "Speed Breeding License",
        description: "Pregnancy duration -25%.",
        cost: 8_000, requiredTier: 3, category: "Quality of Life", implemented: true),
    "contract_negotiator": UpgradeDefinition(
        id: "contract_negotiator", name: "Contract Negotiator",
        description: "+1 max active contract slot.",
        cost: 5_000, requiredTier: 3, category: "Quality of Life", implemented: true),
    "lucky_clover": UpgradeDefinition(
        id: "lucky_clover", name: "Lucky Clover",
        description: "Pigdex discoveries award bonus 50-200 Squeaks (10% chance).",
        cost: 30_000, requiredTier: 4, category: "Quality of Life", implemented: true),
    "vip_contracts": UpgradeDefinition(
        id: "vip_contracts", name: "VIP Contract Access",
        description: "Unlocks LEGENDARY contract difficulty (all 4 axes + roan, huge reward).",
        cost: 100_000, requiredTier: 5, category: "Quality of Life", implemented: true),
    "talent_scout": UpgradeDefinition(
        id: "talent_scout", name: "Talent Scout",
        description: "Enables the Pig Talents system.",
        cost: 8_000, requiredTier: 3, category: "Quality of Life", implemented: false),

    // Treats (2)
    "treat_basket": UpgradeDefinition(
        id: "treat_basket", name: "Treat Basket",
        description: "+1 treat per visit.",
        cost: 800, requiredTier: 3, category: "Treats", implemented: false),
    "treat_wagon": UpgradeDefinition(
        id: "treat_wagon", name: "Treat Wagon",
        description: "+2 treats per visit.",
        cost: 3_000, requiredTier: 4, category: "Treats", implemented: false),
]

// MARK: - Upgrades Logic

/// Stateless namespace for upgrade purchase and effect logic.
enum Upgrades {
    /// Facility types whose capacity is doubled by the `bulk_feeders` upgrade.
    static let foodWaterTypes: Set<FacilityType> = [.foodBowl, .waterBottle, .hayRack]

    static func isFoodWaterType(_ type: FacilityType) -> Bool {
        foodWaterTypes.contains(type)
    }

    /// All upgrade definitions available at or below the current farm tier.
    @MainActor
    static func getAvailablePerks(state: any UpgradesContext) -> [UpgradeDefinition] {
        upgrades.values
            .filter { $0.requiredTier <= state.farmTier }
            .sorted { $0.requiredTier < $1.requiredTier }
    }

    /// Purchase a perk upgrade. Returns false if ineligible or insufficient funds.
    @discardableResult
    @MainActor
    static func purchasePerk(state: any UpgradesContext, upgradeId: String) -> Bool {
        guard let def = upgrades[upgradeId] else { return false }
        guard def.requiredTier <= state.farmTier else { return false }
        guard !state.purchasedUpgrades.contains(upgradeId) else { return false }
        // Natural Talent: -20% perk costs on Farm #1 for first 48 game hours
        let cost = NewFarmerSpirit.adjustedPerkCost(
            def.cost, prestige: state.prestigeState, gameTime: state.gameTime
        )
        guard state.spendMoney(cost) else { return false }
        state.purchasedUpgrades.insert(upgradeId)
        applyImmediateEffect(state: state, upgradeId: upgradeId)
        state.logEvent("Purchased upgrade: \(def.name)", eventType: "purchase")
        return true
    }

    // MARK: - Immediate Effects

    /// Apply the one-time side-effect of granting `upgradeId` (e.g. bulk_feeders doubles capacity).
    /// Precondition: caller has already inserted the upgrade into `purchasedUpgrades` and verified
    /// eligibility. Do NOT call before the duplicate/tier/currency checks in `purchasePerk`.
    @MainActor
    static func applyImmediateEffect(state: any UpgradesContext, upgradeId: String) {
        if upgradeId == "bulk_feeders" {
            applyBulkFeeders(state: state)
        }
    }

    @MainActor
    private static func applyBulkFeeders(state: any UpgradesContext) {
        for facility in state.getFacilitiesList() where isFoodWaterType(facility.facilityType) {
            var updated = facility
            updated.maxAmount *= 2
            updated.currentAmount = min(updated.currentAmount * 2, updated.maxAmount)
            state.updateFacility(updated)
        }
    }
}
