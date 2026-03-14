/// BreedingProgram+Scoring — Free functions for scoring pigs in breeding decisions.
import Foundation

// MARK: - Breeding Value

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

// MARK: - Diversity Value

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

// MARK: - Money Value

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

// MARK: - Diversity Counters

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

// MARK: - Heterozygosity

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

// MARK: - Contract Allele Hits

// swiftlint:disable cyclomatic_complexity
/// Count how many alleles a pig carries that satisfy a contract's required traits.
func contractAlleleHits(_ genotype: Genotype, _ contract: BreedingContract) -> Int {
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
