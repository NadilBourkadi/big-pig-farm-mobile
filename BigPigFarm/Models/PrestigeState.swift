/// PrestigeState -- Cross-farm persistent state for the prestige system ("New Pastures").
/// Maps from: design-prestige-and-progression.md Sections 3-6
import Foundation

// MARK: - LifetimeStats

/// Lifetime statistics that persist across all farms.
struct LifetimeStats: Codable, Sendable {
    var totalPigsBred: Int = 0
    var totalSqueaksEarned: Int = 0
    var totalPigsSold: Int = 0
    var totalContractsCompleted: Int = 0
    var totalFacilitiesBuilt: Int = 0

    enum CodingKeys: String, CodingKey {
        case totalPigsBred = "total_pigs_bred"
        case totalSqueaksEarned = "total_squeaks_earned"
        case totalPigsSold = "total_pigs_sold"
        case totalContractsCompleted = "total_contracts_completed"
        case totalFacilitiesBuilt = "total_facilities_built"
    }
}

// MARK: - AllelePreference

/// Per-locus allele preference for the Selective Advantage upgrade.
enum AllelePreference: String, Codable, CaseIterable, Sendable {
    case dominant
    case recessive
    case noPreference = "no_preference"
}

// MARK: - AllelePreferences

/// Player-configured allele biases for all 6 genetic loci.
/// Part of PrestigeState (cross-farm, survives New Pastures reset).
struct AllelePreferences: Codable, Sendable, Equatable {
    var eLocus: AllelePreference = .noPreference
    var bLocus: AllelePreference = .noPreference
    var sLocus: AllelePreference = .noPreference
    var cLocus: AllelePreference = .noPreference
    var rLocus: AllelePreference = .noPreference
    var dLocus: AllelePreference = .noPreference

    /// Return the preference for a named locus.
    func preference(forLocus name: String) -> AllelePreference {
        switch name {
        case "eLocus": eLocus
        case "bLocus": bLocus
        case "sLocus": sLocus
        case "cLocus": cLocus
        case "rLocus": rLocus
        case "dLocus": dLocus
        default: .noPreference
        }
    }

    /// True if any locus has a non-default preference set.
    var hasAnyPreference: Bool {
        eLocus != .noPreference || bLocus != .noPreference
            || sLocus != .noPreference || cLocus != .noPreference
            || rLocus != .noPreference || dLocus != .noPreference
    }

    enum CodingKeys: String, CodingKey {
        case eLocus = "e_locus"
        case bLocus = "b_locus"
        case sLocus = "s_locus"
        case cLocus = "c_locus"
        case rLocus = "r_locus"
        case dLocus = "d_locus"
    }
}

// MARK: - PrestigeState

/// Top-level prestige state that survives farm resets.
/// Persisted separately from GameState (its own save file).
struct PrestigeState: Codable, Sendable {
    /// Rosette currency balance.
    var rosetteBalance: Int = 0

    /// Permanently purchased Showroom upgrades.
    var purchasedUpgrades: Set<ShowroomUpgrade> = []

    /// Number of farms started (including current).
    var farmCount: Int = 1

    /// Pigdex phenotype keys discovered on previous farms.
    var previousPigdexEntries: Set<String> = []

    /// Cumulative statistics across all farms.
    var lifetimeStats: LifetimeStats = LifetimeStats()

    /// Consecutive visit tracking.
    var visitStreak: VisitStreak = VisitStreak()

    /// Biome mastery progress across all farms.
    var biomeMastery: BiomeMastery = BiomeMastery()

    /// Perk IDs carried across farms via Keepsake Slot upgrade.
    var keepsakePerks: [String] = []

    /// Active reunion boost (nil when expired or not triggered).
    var activeReunionBoost: ReunionBoost?

    /// Per-locus allele preferences for the Selective Advantage upgrade.
    var allelePreferences: AllelePreferences = AllelePreferences()

    // MARK: - Codable

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rosetteBalance = try c.decode(Int.self, forKey: .rosetteBalance)
        purchasedUpgrades = try c.decode(Set<ShowroomUpgrade>.self, forKey: .purchasedUpgrades)
        farmCount = try c.decode(Int.self, forKey: .farmCount)
        previousPigdexEntries = try c.decode(Set<String>.self, forKey: .previousPigdexEntries)
        lifetimeStats = try c.decode(LifetimeStats.self, forKey: .lifetimeStats)
        visitStreak = try c.decode(VisitStreak.self, forKey: .visitStreak)
        biomeMastery = try c.decode(BiomeMastery.self, forKey: .biomeMastery)
        keepsakePerks = try c.decode([String].self, forKey: .keepsakePerks)
        activeReunionBoost = try c.decodeIfPresent(ReunionBoost.self, forKey: .activeReunionBoost)
        allelePreferences = try c.decodeIfPresent(AllelePreferences.self, forKey: .allelePreferences)
            ?? AllelePreferences()
    }

    // MARK: - Upgrade Helpers

    /// Whether a specific upgrade has been purchased.
    func hasUpgrade(_ upgrade: ShowroomUpgrade) -> Bool {
        purchasedUpgrades.contains(upgrade)
    }

    /// Purchase an upgrade if affordable and not already owned. Returns true on success.
    @discardableResult
    mutating func purchaseUpgrade(_ upgrade: ShowroomUpgrade) -> Bool {
        guard !purchasedUpgrades.contains(upgrade) else { return false }
        guard rosetteBalance >= upgrade.cost else { return false }
        rosetteBalance -= upgrade.cost
        purchasedUpgrades.insert(upgrade)
        return true
    }

    /// Add Rosettes earned from a Pig Show.
    mutating func addRosettes(_ amount: Int) {
        rosetteBalance += amount
    }

    // MARK: - Pigdex Carry-Over

    /// Record Pigdex entries from the current farm before reset.
    mutating func carryOverPigdex(_ currentPigdex: Pigdex) {
        for key in currentPigdex.discovered.keys {
            previousPigdexEntries.insert(key)
        }
    }

    // MARK: - Treat Capacity

    /// Treats available per visit (base + streak + upgrades).
    var treatsPerVisit: Int {
        var total = GameConfig.Prestige.baseTreatsPerVisit
        total += visitStreak.bonusTreats
        if hasUpgrade(.treatPouch) {
            total += GameConfig.Prestige.treatPouchBonusTreats
        }
        return total
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case rosetteBalance = "rosette_balance"
        case purchasedUpgrades = "purchased_upgrades"
        case farmCount = "farm_count"
        case previousPigdexEntries = "previous_pigdex_entries"
        case lifetimeStats = "lifetime_stats"
        case visitStreak = "visit_streak"
        case biomeMastery = "biome_mastery"
        case keepsakePerks = "keepsake_perks"
        case activeReunionBoost = "active_reunion_boost"
        case allelePreferences = "allele_preferences"
    }
}
