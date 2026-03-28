/// TreatType -- Treat types for the visit feeding mechanic.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

// MARK: - TreatType

/// One of 4 treat types available during farm visits.
enum TreatType: String, Codable, CaseIterable, Sendable {
    case leafyGreens = "leafy_greens"
    case cucumber = "cucumber"
    case strawberries = "strawberries"
    case watermelon = "watermelon"

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

    /// SF Symbol name for menu display.
    var systemImageName: String {
        switch self {
        case .leafyGreens: "leaf.fill"
        case .cucumber: "oval.portrait.fill"
        case .strawberries: "heart.fill"
        case .watermelon: "circle.lefthalf.filled"
        }
    }

    /// Asset catalog name for the SpriteKit treat sprite.
    var spriteAssetName: String {
        "Sprites/Treats/treat_\(rawValue)"
    }

    /// Short summary of the treat's stat effects for the picker menu.
    var effectSummary: String {
        let ti = info
        var parts: [String] = []
        if ti.hungerBoost > 0 { parts.append("+\(Int(ti.hungerBoost)) hunger") }
        if ti.happinessBoost > 0 { parts.append("+\(Int(ti.happinessBoost)) happiness") }
        if ti.healthBoost > 0 { parts.append("+\(Int(ti.healthBoost)) health") }
        if ti.socialBoost > 0 { parts.append("+\(Int(ti.socialBoost)) social") }
        if ti.breedingChanceBoost > 0 { parts.append("+\(Int(ti.breedingChanceBoost * 100))% breeding") }
        if ti.needDecayReduction > 0 { parts.append("-\(Int(ti.needDecayReduction * 100))% decay") }
        return parts.joined(separator: ", ")
    }
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
    .leafyGreens: TreatInfo(
        displayName: "Leafy Greens",
        hungerBoost: 30, happinessBoost: 10, healthBoost: 0, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 1),
    .cucumber: TreatInfo(
        displayName: "Cucumber",
        hungerBoost: 0, happinessBoost: 25, healthBoost: 0, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0.05, breedingBoostDurationHours: 2,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 2),
    .strawberries: TreatInfo(
        displayName: "Strawberries",
        hungerBoost: 0, happinessBoost: 0, healthBoost: 15, socialBoost: 0,
        socialRadius: 0, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0.20, needDecayDurationHours: 2, requiredTier: 3),
    .watermelon: TreatInfo(
        displayName: "Watermelon",
        hungerBoost: 0, happinessBoost: 0, healthBoost: 0, socialBoost: 20,
        socialRadius: 4, breedingChanceBoost: 0, breedingBoostDurationHours: 0,
        needDecayReduction: 0, needDecayDurationHours: 0, requiredTier: 4),
]
