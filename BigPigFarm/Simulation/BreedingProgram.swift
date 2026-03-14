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

// MARK: - Breeding Filter

extension BreedingProgram {
    /// Check if a pig passes the breeding program target filter.
    /// Returns true if the pig should be kept (not auto-sold).
    /// Always returns true when the program is disabled.
    /// AND logic across axes: all non-empty axes must match.
    /// OR logic within each axis: any target value within an axis satisfies it.
    func shouldKeepPig(_ pig: GuineaPig, hasGeneticsLab: Bool) -> Bool {
        guard enabled else { return true }
        let carrierAware = keepCarriers && hasGeneticsLab

        if !targetColors.isEmpty {
            guard matchesColor(pig.phenotype, pig.genotype, targetColors, carrierAware) else {
                return false
            }
        }
        if !targetPatterns.isEmpty {
            guard matchesPattern(pig.phenotype, pig.genotype, targetPatterns, carrierAware) else {
                return false
            }
        }
        if !targetIntensities.isEmpty {
            guard matchesIntensity(pig.phenotype, pig.genotype, targetIntensities, carrierAware) else {
                return false
            }
        }
        if !targetRoan.isEmpty {
            guard matchesRoan(pig.phenotype, targetRoan) else { return false }
        }
        return true
    }

    // MARK: - Private Axis Matchers

    // swiftlint:disable:next cyclomatic_complexity
    private func matchesColor(
        _ phenotype: Phenotype,
        _ genotype: Genotype,
        _ targets: Set<BaseColor>,
        _ carrierAware: Bool
    ) -> Bool {
        if targets.contains(phenotype.baseColor) { return true }
        guard carrierAware else { return false }
        for target in targets {
            switch target {
            case .chocolate:
                if genotype.bLocus.contains("b") { return true }
            case .golden:
                if genotype.eLocus.contains("e") { return true }
            case .cream:
                if genotype.eLocus.contains("e") && genotype.bLocus.contains("b") { return true }
            case .blue:
                if genotype.dLocus.contains("d") { return true }
            case .lilac:
                if genotype.bLocus.contains("b") && genotype.dLocus.contains("d") { return true }
            case .saffron:
                if genotype.eLocus.contains("e") && genotype.dLocus.contains("d") { return true }
            case .smoke:
                if genotype.eLocus.contains("e")
                    && genotype.bLocus.contains("b")
                    && genotype.dLocus.contains("d") { return true }
            case .black:
                break // Black is dominant; no meaningful carrier state to rescue
            }
        }
        return false
    }

    private func matchesPattern(
        _ phenotype: Phenotype,
        _ genotype: Genotype,
        _ targets: Set<Pattern>,
        _ carrierAware: Bool
    ) -> Bool {
        if targets.contains(phenotype.pattern) { return true }
        guard carrierAware else { return false }
        for target in targets {
            switch target {
            case .dutch, .dalmatian:
                if genotype.sLocus.contains("s") { return true }
            case .solid:
                break // Solid is dominant (SS/Ss dominance); no carrier rescue applies
            }
        }
        return false
    }

    private func matchesIntensity(
        _ phenotype: Phenotype,
        _ genotype: Genotype,
        _ targets: Set<ColorIntensity>,
        _ carrierAware: Bool
    ) -> Bool {
        if targets.contains(phenotype.intensity) { return true }
        guard carrierAware else { return false }
        for target in targets {
            switch target {
            case .chinchilla, .himalayan:
                if genotype.cLocus.contains("ch") { return true }
            case .full:
                break // Full intensity is dominant (CC/Cch); no carrier rescue applies
            }
        }
        return false
    }

    private func matchesRoan(
        _ phenotype: Phenotype,
        _ targets: Set<RoanType>
    ) -> Bool {
        targets.contains(phenotype.roan)
    }
}
