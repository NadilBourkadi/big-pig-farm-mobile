/// BreedingProgram -- Targeted breeding strategies for rare phenotypes.
/// Maps from: simulation/breeding_program.py
import Foundation

// MARK: - BreedingStrategy

/// Breeding program strategy for scoring and pig replacement.
enum BreedingStrategy: String, Codable, CaseIterable, Sendable {
    case target      // Breed toward specific phenotype targets
    case diversity   // Maximize phenotype variety
    case money       // Maximize sale value and contract fulfillment
}

// MARK: - BreedingProgram

/// Goal-oriented breeding autopilot.
/// Set target traits, and the system auto-pairs pigs to maximize
/// offspring probability, auto-sells rejects, and manages stock levels.
struct BreedingProgram: Codable, Sendable {
    var targetColors: Set<BaseColor> = []
    var targetPatterns: Set<Pattern> = []
    var targetIntensities: Set<ColorIntensity> = []
    var targetRoan: Set<RoanType> = []
    var keepCarriers: Bool = true
    var autoPair: Bool = true
    var strategy: BreedingStrategy = .target
    var stockLimit: Int = 6
    var enabled: Bool = false

    /// True if any target axis has selections.
    var hasTarget: Bool {
        !targetColors.isEmpty
            || !targetPatterns.isEmpty
            || !targetIntensities.isEmpty
            || !targetRoan.isEmpty
    }

    /// Check if auto-pairing is active.
    func shouldAutoPair() -> Bool {
        enabled && autoPair
    }

    enum CodingKeys: String, CodingKey {
        case targetColors = "target_colors"
        case targetPatterns = "target_patterns"
        case targetIntensities = "target_intensities"
        case targetRoan = "target_roan"
        case keepCarriers = "keep_carriers"
        case autoPair = "auto_pair"
        case strategy
        case stockLimit = "stock_limit"
        case enabled
    }
}
