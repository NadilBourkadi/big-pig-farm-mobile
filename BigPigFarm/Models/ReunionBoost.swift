/// ReunionBoost -- Active reunion boost state after returning from offline.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

// MARK: - ReunionBoost

/// Represents an active reunion boost triggered when the player returns after >= 1 hour offline.
struct ReunionBoost: Codable, Sendable {
    /// When the boost was activated.
    var activatedAt: Date

    /// Duration of the boost in real seconds.
    var durationSeconds: TimeInterval

    /// Happiness boost applied to all pigs on activation.
    var happinessBoost: Double

    /// Breeding chance bonus during boost.
    var breedingChanceBonus: Double

    /// Sale value bonus during boost.
    var saleValueBonus: Double

    // MARK: - Computed Properties

    /// Whether the boost is still active.
    func isActive(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(activatedAt) < durationSeconds
    }

    /// Time remaining in seconds. Returns 0 if expired.
    func timeRemainingSeconds(at now: Date = Date()) -> TimeInterval {
        max(0, durationSeconds - now.timeIntervalSince(activatedAt))
    }

    // MARK: - Factories

    /// Create a standard reunion boost (no Showroom upgrades).
    static func standard(at now: Date = Date()) -> Self {
        Self(
            activatedAt: now,
            durationSeconds: GameConfig.Prestige.reunionDurationSeconds,
            happinessBoost: GameConfig.Prestige.reunionHappinessBoost,
            breedingChanceBonus: GameConfig.Prestige.reunionBreedingBonus,
            saleValueBonus: GameConfig.Prestige.reunionSaleBonus
        )
    }

    /// Create an enhanced reunion boost (with Reunion Spirit upgrade).
    static func enhanced(at now: Date = Date()) -> Self {
        Self(
            activatedAt: now,
            durationSeconds: GameConfig.Prestige.reunionEnhancedDurationSeconds,
            happinessBoost: GameConfig.Prestige.reunionEnhancedHappinessBoost,
            breedingChanceBonus: GameConfig.Prestige.reunionEnhancedBreedingBonus,
            saleValueBonus: GameConfig.Prestige.reunionEnhancedSaleBonus
        )
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case activatedAt = "activated_at"
        case durationSeconds = "duration_seconds"
        case happinessBoost = "happiness_boost"
        case breedingChanceBonus = "breeding_chance_bonus"
        case saleValueBonus = "sale_value_bonus"
    }
}
