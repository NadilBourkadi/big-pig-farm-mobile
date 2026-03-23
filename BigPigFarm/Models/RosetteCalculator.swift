/// RosetteCalculator -- Multi-dimensional Rosette scoring formula for the Pig Show.
/// Maps from: design-prestige-and-progression.md Section 3
import Foundation

// MARK: - RosetteInput

/// Input data for Rosette calculation. Gathered from game state at prestige time.
struct RosetteInput: Sendable {
    let lifetimeSqueaks: Int
    let newPigdexEntries: Int
    let uniquePhenotypesInHerd: Int
    let contractsCompleted: Int
    let hasLegendaryPig: Bool
    let visitStreakBonusRosettes: Int
}

// MARK: - RosetteCalculator

/// Stateless namespace for Rosette calculation.
enum RosetteCalculator {
    /// Calculate total Rosettes earned from a prestige run.
    static func calculate(_ input: RosetteInput) -> Int {
        let b = breakdown(input)
        return b.total
    }

    /// Breakdown of Rosette calculation for display on the Pig Show screen.
    static func breakdown(_ input: RosetteInput) -> RosetteBreakdown {
        let baseDivisor = Double(GameConfig.Prestige.rosetteBaseDivisor)
        return RosetteBreakdown(
            baseRosettes: Int(floor(sqrt(Double(input.lifetimeSqueaks) / baseDivisor))),
            pigdexBonus: input.newPigdexEntries / GameConfig.Prestige.rosettePigdexDivisor,
            diversityBonus: input.uniquePhenotypesInHerd / GameConfig.Prestige.rosetteDiversityDivisor,
            contractBonus: input.contractsCompleted / GameConfig.Prestige.rosetteContractDivisor,
            rarityBonus: input.hasLegendaryPig ? 1 : 0,
            streakBonus: input.visitStreakBonusRosettes
        )
    }
}

// MARK: - RosetteBreakdown

/// Breakdown of each dimension's contribution for UI display.
struct RosetteBreakdown: Sendable {
    let baseRosettes: Int
    let pigdexBonus: Int
    let diversityBonus: Int
    let contractBonus: Int
    let rarityBonus: Int
    let streakBonus: Int

    var total: Int {
        baseRosettes + pigdexBonus + diversityBonus
        + contractBonus + rarityBonus + streakBonus
    }
}
