/// TreatType -- Treat types for the visit feeding mechanic.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

// MARK: - TreatType

/// One of 4 treat types available during farm visits.
enum TreatType: String, Codable, CaseIterable, Sendable {
    case freshVeggies = "fresh_veggies"
    case fruitSlices = "fruit_slices"
    case herbBundle = "herb_bundle"
    case haySampler = "hay_sampler"

    /// Human-readable name for display.
    var displayName: String { info.displayName }

    /// Static metadata for this treat type.
    var info: TreatInfo {
        guard let value = treatInfo[self] else {
            preconditionFailure("Missing treatInfo for \(self)")
        }
        return value
    }

    /// Farm tier required to unlock this treat type.
    var requiredTier: Int { info.requiredTier }
}

// MARK: - TreatInfo

/// Static metadata for a treat type (not Codable -- static lookup data).
struct TreatInfo: Sendable {
    let displayName: String
    let hungerBoost: Double
    let happinessBoost: Double
    let healthBoost: Double
    let socialBoost: Double
    let socialRadius: Double
    let breedingChanceBoost: Double
    let breedingBoostDurationHours: Double
    let needDecayReduction: Double
    let needDecayDurationHours: Double
    let requiredTier: Int
}

// MARK: - Treat Info Lookup Table

/// All 4 treat metadata entries. From design doc Section 6.
let treatInfo: [TreatType: TreatInfo] = [
    .freshVeggies: TreatInfo(
        displayName: "Fresh Veggies",
        hungerBoost: 30, happinessBoost: 10, healthBoost: 0, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 1),
    .fruitSlices: TreatInfo(
        displayName: "Fruit Slices",
        hungerBoost: 0, happinessBoost: 25, healthBoost: 0, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0.05, breedingBoostDurationHours: 2,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 2),
    .herbBundle: TreatInfo(
        displayName: "Herb Bundle",
        hungerBoost: 0, happinessBoost: 0, healthBoost: 15, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0.20, needDecayDurationHours: 2, requiredTier: 3),
    .haySampler: TreatInfo(
        displayName: "Hay Sampler",
        hungerBoost: 0, happinessBoost: 0, healthBoost: 0, socialBoost: 20,
        socialRadius: 4, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 4),
]
