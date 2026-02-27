/// GeneticsPrediction -- Offspring prediction via Monte Carlo and analytical Punnett squares.
/// Maps from: entities/genetics.py (lines 473-655)
import Foundation

// MARK: - Offspring Prediction (Monte Carlo)

/// Predict offspring phenotype probabilities using Monte Carlo sampling.
/// Returns a list of (Phenotype, probability) tuples sorted by probability descending.
func predictOffspringPhenotypes(
    _ parent1: Genotype,
    _ parent2: Genotype
) -> [(Phenotype, Double)] {
    var phenotypeCounts: [Phenotype: Int] = [:]
    let totalSamples = 1000

    for _ in 0..<totalSamples {
        let result = breed(parent1, parent2)
        let phenotype = calculatePhenotype(result.genotype)
        phenotypeCounts[phenotype, default: 0] += 1
    }

    var results = phenotypeCounts.map { (phenotype, count) in
        (phenotype, Double(count) / Double(totalSamples))
    }
    results.sort { $0.1 > $1.1 }
    return results
}

// MARK: - Offspring Prediction (Analytical)

/// Compute exact P(offspring matches target) via analytical Punnett squares.
/// Per-locus probabilities are multiplied across independent loci.
/// Empty target set on any axis means probability 1.0 (any value accepted).
func calculateTargetProbability(
    _ parent1: Genotype,
    _ parent2: Genotype,
    targetColors: Set<BaseColor>,
    targetPatterns: Set<Pattern>,
    targetIntensities: Set<ColorIntensity>,
    targetRoan: Set<RoanType>
) -> Double {
    let probabilityColor = targetColors.isEmpty
        ? 1.0 : colorProbability(parent1, parent2, targets: targetColors)
    let probabilityPattern = targetPatterns.isEmpty
        ? 1.0 : patternProbability(parent1, parent2, targets: targetPatterns)
    let probabilityIntensity = targetIntensities.isEmpty
        ? 1.0 : intensityProbability(parent1, parent2, targets: targetIntensities)
    let probabilityRoan = targetRoan.isEmpty
        ? 1.0 : roanProbability(parent1, parent2, targets: targetRoan)

    return probabilityColor * probabilityPattern * probabilityIntensity * probabilityRoan
}

// MARK: - Private Analytical Helpers

/// Compute all possible offspring genotype combinations for a single locus.
/// Each parent passes one allele with 50% chance, giving 4 equally likely combos.
private func locusOutcomeProbs(
    _ parent1Locus: AllelePair,
    _ parent2Locus: AllelePair
) -> [(AllelePair, Double)] {
    var outcomes: [AllelePair: Double] = [:]
    let parent1Alleles = [parent1Locus.first, parent1Locus.second]
    let parent2Alleles = [parent2Locus.first, parent2Locus.second]

    for allele1 in parent1Alleles {
        for allele2 in parent2Alleles {
            let pair = AllelePair(first: allele1, second: allele2)
            outcomes[pair, default: 0.0] += 0.25
        }
    }

    return outcomes.map { ($0.key, $0.value) }
}

/// P(offspring color in targets). Color depends on E+B+D loci jointly.
private func colorProbability(
    _ parent1: Genotype,
    _ parent2: Genotype,
    targets: Set<BaseColor>
) -> Double {
    let eOutcomes = locusOutcomeProbs(parent1.eLocus, parent2.eLocus)
    let bOutcomes = locusOutcomeProbs(parent1.bLocus, parent2.bLocus)
    let dOutcomes = locusOutcomeProbs(parent1.dLocus, parent2.dLocus)

    var probability = 0.0
    for (eAlleles, eProb) in eOutcomes {
        let hasE = eAlleles.hasDominant("E")
        for (bAlleles, bProb) in bOutcomes {
            let hasB = bAlleles.hasDominant("B")
            for (dAlleles, dProb) in dOutcomes {
                let hasD = dAlleles.hasDominant("D")
                let color = determineBaseColor(hasE: hasE, hasB: hasB, hasD: hasD)
                if targets.contains(color) {
                    probability += eProb * bProb * dProb
                }
            }
        }
    }
    return probability
}

/// P(offspring pattern in targets). Pattern depends on S locus.
private func patternProbability(
    _ parent1: Genotype,
    _ parent2: Genotype,
    targets: Set<Pattern>
) -> Double {
    let outcomes = locusOutcomeProbs(parent1.sLocus, parent2.sLocus)
    var probability = 0.0

    for (alleles, prob) in outcomes {
        let pattern: Pattern
        if alleles.isHomozygous("S") {
            pattern = .solid
        } else if alleles.isHomozygous("s") {
            pattern = .dalmatian
        } else {
            pattern = .dutch
        }
        if targets.contains(pattern) {
            probability += prob
        }
    }
    return probability
}

/// P(offspring intensity in targets). Intensity depends on C locus.
private func intensityProbability(
    _ parent1: Genotype,
    _ parent2: Genotype,
    targets: Set<ColorIntensity>
) -> Double {
    let outcomes = locusOutcomeProbs(parent1.cLocus, parent2.cLocus)
    var probability = 0.0

    for (alleles, prob) in outcomes {
        let intensity: ColorIntensity
        if alleles.isHomozygous("ch") {
            intensity = .himalayan
        } else if alleles.contains("ch") {
            intensity = .chinchilla
        } else {
            intensity = .full
        }
        if targets.contains(intensity) {
            probability += prob
        }
    }
    return probability
}

/// P(offspring roan in targets). Roan depends on R locus.
/// RR is lethal and rerolled, so its probability is redistributed
/// proportionally across surviving outcomes.
private func roanProbability(
    _ parent1: Genotype,
    _ parent2: Genotype,
    targets: Set<RoanType>
) -> Double {
    let outcomes = locusOutcomeProbs(parent1.rLocus, parent2.rLocus)

    // Find probability of lethal RR
    let rrLethalProb = outcomes
        .filter { $0.0.isHomozygous("R") }
        .reduce(0.0) { $0 + $1.1 }

    if rrLethalProb >= 1.0 {
        // Both parents RR -- impossible in practice (lethal), but handle gracefully
        return targets.contains(.roan) ? 1.0 : 0.0
    }

    var probability = 0.0
    for (alleles, prob) in outcomes {
        if alleles.isHomozygous("R") { continue }

        // Rescale probability to account for RR elimination
        let adjustedProb = prob / (1.0 - rrLethalProb)
        let roan: RoanType = alleles.hasDominant("R") ? .roan : .none
        if targets.contains(roan) {
            probability += adjustedProb
        }
    }
    return probability
}
