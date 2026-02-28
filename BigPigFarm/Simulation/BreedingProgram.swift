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

// MARK: - Scoring Free Functions

// swiftlint:disable cyclomatic_complexity function_body_length
/// Score how useful a pig is for hitting the breeding program's target alleles.
/// Range: roughly 0–10+ for target hits + 0–5 age bonus – 20 senior penalty.
func breedingValue(
    pig: GuineaPig,
    program: BreedingProgram,
    hasLab: Bool
) -> Double {
    if pig.isSenior { return -20.0 }

    var score = 0.0

    for color in program.targetColors {
        switch color {
        case .golden:
            score += Double(pig.genotype.eLocus.count("e"))
        case .chocolate:
            score += Double(pig.genotype.bLocus.count("b"))
        case .cream:
            score += Double(pig.genotype.eLocus.count("e")) + Double(pig.genotype.bLocus.count("b"))
        case .blue:
            score += Double(pig.genotype.dLocus.count("d"))
        case .lilac:
            score += Double(pig.genotype.bLocus.count("b")) + Double(pig.genotype.dLocus.count("d"))
        case .saffron:
            score += Double(pig.genotype.eLocus.count("e")) + Double(pig.genotype.dLocus.count("d"))
        case .smoke:
            score += Double(pig.genotype.eLocus.count("e"))
                + Double(pig.genotype.bLocus.count("b"))
                + Double(pig.genotype.dLocus.count("d"))
        case .black:
            score += Double(pig.genotype.eLocus.count("E")) + Double(pig.genotype.bLocus.count("B"))
        }
    }
    for pattern in program.targetPatterns {
        switch pattern {
        case .dutch, .dalmatian:
            score += Double(pig.genotype.sLocus.count("s"))
        case .solid:
            score += Double(pig.genotype.sLocus.count("S"))
        }
    }
    for intensity in program.targetIntensities {
        switch intensity {
        case .chinchilla, .himalayan:
            score += Double(pig.genotype.cLocus.count("ch"))
        case .full:
            score += Double(pig.genotype.cLocus.count("C"))
        }
    }
    for roan in program.targetRoan {
        switch roan {
        case .roan:
            score += Double(pig.genotype.rLocus.count("R"))
        case .none:
            score += Double(pig.genotype.rLocus.count("r"))
        }
    }

    let ageTiebreaker = (max(0.0, Double(GameConfig.Breeding.maxAgeDays) - pig.ageDays)
        / Double(GameConfig.Breeding.maxAgeDays)) * 5.0
    return score + ageTiebreaker
}
// swiftlint:enable cyclomatic_complexity function_body_length

/// Score a pig's contribution to phenotype diversity.
/// Rewards uniqueness, heterozygosity, and youth.
func diversityValue(
    pig: GuineaPig,
    allPigs: [GuineaPig],
    phenotypeCounts: [String: Int]?,
    colorCounts: [BaseColor: Int]?
) -> Double {
    if pig.isSenior { return -20.0 }

    let key = phenotypeKey(pig.phenotype)
    let phenoCount = phenotypeCounts?[key] ?? 1
    let colorCount = colorCounts?[pig.phenotype.baseColor] ?? 1

    let phenoUniqueness = 10.0 / Double(max(phenoCount, 1))
    let colorUniqueness = 10.0 / Double(max(colorCount, 1))
    let hetBonus = Double(heterozygosityCount(pig.genotype))

    let ageTiebreaker = (max(0.0, Double(GameConfig.Breeding.maxAgeDays) - pig.ageDays)
        / Double(GameConfig.Breeding.maxAgeDays)) * 3.0

    return phenoUniqueness + colorUniqueness + hetBonus + ageTiebreaker
}

/// Score a pig's breeding potential for producing high-value offspring.
/// Accounts for rarity alleles and active contract alignment.
@MainActor
func moneyValue(
    pig: GuineaPig,
    program: BreedingProgram,
    hasLab: Bool,
    gameState: GameState
) -> Double {
    if pig.isSenior { return -20.0 }

    var score = 0.0

    // Rarity allele bonuses
    score += Double(pig.genotype.cLocus.count("ch")) * 3.0  // Chinchilla/himalayan
    score += Double(pig.genotype.sLocus.count("s")) * 2.0   // Spotting
    score += Double(pig.genotype.rLocus.count("R")) * 2.0   // Roan
    score += Double(pig.genotype.bLocus.count("b")) * 1.0   // Chocolate
    score += Double(pig.genotype.eLocus.count("e")) * 0.5   // Golden

    // Active contract alignment bonus
    for contract in gameState.contractBoard.activeContracts where !contract.fulfilled {
        let hits = contractAlleleHits(pig.genotype, contract)
        score += Double(hits) * (Double(contract.reward) / 100.0)
    }

    let ageTiebreaker = (max(0.0, Double(GameConfig.Breeding.maxAgeDays) - pig.ageDays)
        / Double(GameConfig.Breeding.maxAgeDays)) * 5.0

    return score + ageTiebreaker
}

/// Pre-compute phenotype and base-color frequency counters over all pigs. O(n).
func buildDiversityCounters(
    pigs: [GuineaPig]
) -> ([String: Int], [BaseColor: Int]) {
    var phenotypeCounts: [String: Int] = [:]
    var colorCounts: [BaseColor: Int] = [:]
    for pig in pigs {
        let key = phenotypeKey(pig.phenotype)
        phenotypeCounts[key, default: 0] += 1
        colorCounts[pig.phenotype.baseColor, default: 0] += 1
    }
    return (phenotypeCounts, colorCounts)
}

/// Count how many of the 6 loci are heterozygous (0–6).
func heterozygosityCount(_ genotype: Genotype) -> Int {
    let lociNames = ["eLocus", "bLocus", "sLocus", "cLocus", "rLocus", "dLocus"]
    var count = 0
    for name in lociNames {
        let pair = genotype.allelePair(forLocus: name)
        if pair.first != pair.second { count += 1 }
    }
    return count
}

// MARK: - Private Helper

// swiftlint:disable cyclomatic_complexity
/// Count how many alleles a pig carries that satisfy a contract's required traits.
private func contractAlleleHits(_ genotype: Genotype, _ contract: BreedingContract) -> Int {
    var hits = 0
    if let requiredColor = contract.requiredColor {
        switch requiredColor {
        case .golden: hits += genotype.eLocus.count("e")
        case .chocolate: hits += genotype.bLocus.count("b")
        case .cream: hits += genotype.eLocus.count("e") + genotype.bLocus.count("b")
        case .blue: hits += genotype.dLocus.count("d")
        case .lilac: hits += genotype.bLocus.count("b") + genotype.dLocus.count("d")
        case .saffron: hits += genotype.eLocus.count("e") + genotype.dLocus.count("d")
        case .smoke:
            hits += genotype.eLocus.count("e")
                + genotype.bLocus.count("b")
                + genotype.dLocus.count("d")
        case .black: hits += genotype.eLocus.count("E") + genotype.bLocus.count("B")
        }
    }
    if let requiredPattern = contract.requiredPattern {
        switch requiredPattern {
        case .dutch, .dalmatian: hits += genotype.sLocus.count("s")
        case .solid: hits += genotype.sLocus.count("S")
        }
    }
    if let requiredIntensity = contract.requiredIntensity {
        switch requiredIntensity {
        case .chinchilla, .himalayan: hits += genotype.cLocus.count("ch")
        case .full: hits += genotype.cLocus.count("C")
        }
    }
    if let requiredRoan = contract.requiredRoan {
        switch requiredRoan {
        case .roan: hits += genotype.rLocus.count("R")
        case .none: hits += genotype.rLocus.count("r")
        }
    }
    return hits
}
// swiftlint:enable cyclomatic_complexity
