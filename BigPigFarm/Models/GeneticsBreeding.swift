/// GeneticsBreeding -- Mendelian breeding, mutations, and carrier analysis.
/// Maps from: entities/genetics.py (lines 288-471)
import Foundation

// MARK: - BreedResult

/// Result of breeding two guinea pigs, containing the child genotype
/// and a list of human-readable mutation descriptions.
struct BreedResult: Sendable {
    let genotype: Genotype
    let mutations: [String]
}

// MARK: - Inheritance

/// Inherit one allele from each parent for a single locus.
func inheritAllele(_ parent1Locus: AllelePair, _ parent2Locus: AllelePair) -> AllelePair {
    let allele1 = Bool.random() ? parent1Locus.first : parent1Locus.second
    let allele2 = Bool.random() ? parent2Locus.first : parent2Locus.second
    return AllelePair(first: allele1, second: allele2)
}

// MARK: - Mutations

/// Attempt to mutate one allele in a locus (random direction).
/// Flips one random allele: dominant -> recessive or recessive -> dominant.
/// Returns (newLocus, didMutate).
func mutateLocus(
    _ locus: AllelePair,
    dominant: String,
    recessive: String,
    rate: Double
) -> (AllelePair, Bool) {
    guard Double.random(in: 0.0..<1.0) < rate else {
        return (locus, false)
    }

    let mutateFirst = Bool.random()
    let currentAllele = mutateFirst ? locus.first : locus.second
    let newAllele = currentAllele == dominant ? recessive : dominant

    let newLocus = mutateFirst
        ? AllelePair(first: newAllele, second: locus.second)
        : AllelePair(first: locus.first, second: newAllele)
    return (newLocus, true)
}

/// Attempt a directional mutation -- push one allele toward the target.
/// Picks a random allele position. If that allele is NOT the target,
/// replace it with the target. If already the target, the roll is wasted.
/// Returns (newLocus, didMutate).
func mutateLocusDirectional(
    _ locus: AllelePair,
    targetAllele: String,
    rate: Double
) -> (AllelePair, Bool) {
    guard Double.random(in: 0.0..<1.0) < rate else {
        return (locus, false)
    }

    let mutateFirst = Bool.random()
    let currentAllele = mutateFirst ? locus.first : locus.second

    guard currentAllele != targetAllele else {
        return (locus, false) // Already matches -- wasted roll
    }

    let newLocus = mutateFirst
        ? AllelePair(first: targetAllele, second: locus.second)
        : AllelePair(first: locus.first, second: targetAllele)
    return (newLocus, true)
}

// MARK: - Breed

/// Create offspring genotype from two parents with optional mutations.
///
/// - Parameters:
///   - parent1: First parent genotype
///   - parent2: Second parent genotype
///   - mutationRate: Per-locus mutation rate (0.0 = no mutations, 0.02 = 2%)
///   - locusRates: Optional per-locus rate overrides (e.g. from biome boosts)
///   - directionalTargets: Optional per-locus target alleles for directional mutations
///   - directionalRate: Rate for directional mutations at targeted loci
func breed(
    _ parent1: Genotype,
    _ parent2: Genotype,
    mutationRate: Double = 0.0,
    locusRates: [String: Double]? = nil,
    directionalTargets: [String: String]? = nil,
    directionalRate: Double = 0.0
) -> BreedResult {
    // Normal Mendelian inheritance
    var eLocus = inheritAllele(parent1.eLocus, parent2.eLocus)
    var bLocus = inheritAllele(parent1.bLocus, parent2.bLocus)
    var sLocus = inheritAllele(parent1.sLocus, parent2.sLocus)
    var cLocus = inheritAllele(parent1.cLocus, parent2.cLocus)
    var rLocus = inheritAllele(parent1.rLocus, parent2.rLocus)
    var dLocus = inheritAllele(parent1.dLocus, parent2.dLocus)

    // Check for lethal roan combination (RR) -- reroll until non-lethal
    while rLocus.isHomozygous("R") {
        rLocus = inheritAllele(parent1.rLocus, parent2.rLocus)
    }

    // Apply mutations
    var mutations: [String] = []
    let hasMutations = mutationRate > 0 || locusRates != nil || directionalTargets != nil

    if hasMutations {
        // Pair each locus variable with its metadata for iteration
        // swiftlint:disable:next large_tuple
        let loci: [(name: String, value: AllelePair, dominant: String, recessive: String)] = [
            ("eLocus", eLocus, "E", "e"),
            ("bLocus", bLocus, "B", "b"),
            ("sLocus", sLocus, "S", "s"),
            ("cLocus", cLocus, "C", "ch"),
            ("rLocus", rLocus, "R", "r"),
            ("dLocus", dLocus, "D", "d"),
        ]

        for (locusName, currentValue, dominant, recessive) in loci {
            let newValue: AllelePair
            let didMutate: Bool

            if let targets = directionalTargets,
               let targetAllele = targets[locusName],
               directionalRate > 0 {
                // Directional mutation for targeted loci
                (newValue, didMutate) = mutateLocusDirectional(
                    currentValue, targetAllele: targetAllele, rate: directionalRate
                )
            } else {
                // Random mutation at per-locus or base rate
                let rate = locusRates?[locusName] ?? mutationRate
                guard rate > 0 else { continue }
                (newValue, didMutate) = mutateLocus(
                    currentValue, dominant: dominant, recessive: recessive, rate: rate
                )
            }

            if didMutate {
                // Suppress mutation if it creates lethal RR
                if locusName == "rLocus" && newValue.isHomozygous("R") {
                    continue
                }
                // Apply mutation to the corresponding locus
                switch locusName {
                case "eLocus": eLocus = newValue
                case "bLocus": bLocus = newValue
                case "sLocus": sLocus = newValue
                case "cLocus": cLocus = newValue
                case "rLocus": rLocus = newValue
                case "dLocus": dLocus = newValue
                default: break
                }
                let displayName = locusDisplayNames[locusName] ?? locusName
                let description = "\(displayName) "
                    + "(\(currentValue.first)/\(currentValue.second)"
                    + " -> \(newValue.first)/\(newValue.second))"
                mutations.append(description)
            }
        }
    }

    let genotype = Genotype(
        eLocus: eLocus,
        bLocus: bLocus,
        sLocus: sLocus,
        cLocus: cLocus,
        rLocus: rLocus,
        dLocus: dLocus
    )

    return BreedResult(genotype: genotype, mutations: mutations)
}

// MARK: - Carrier Summary

/// Get a short summary of hidden carrier alleles in a genotype.
/// Lists heterozygous loci where a recessive allele is masked by a dominant.
func carrierSummary(_ genotype: Genotype) -> String {
    var carriers: [String] = []

    if genotype.eLocus.first != genotype.eLocus.second
        && genotype.eLocus.contains("e") {
        carriers.append("E/e")
    }
    if genotype.bLocus.first != genotype.bLocus.second
        && genotype.bLocus.contains("b") {
        carriers.append("B/b")
    }
    if genotype.sLocus.first != genotype.sLocus.second
        && genotype.sLocus.contains("s") {
        carriers.append("S/s")
    }
    if genotype.cLocus.first != genotype.cLocus.second
        && genotype.cLocus.contains("ch") {
        carriers.append("C/ch")
    }
    if genotype.rLocus.contains("R") && genotype.rLocus.contains("r") {
        carriers.append("R/r")
    }
    if genotype.dLocus.first != genotype.dLocus.second
        && genotype.dLocus.contains("d") {
        carriers.append("D/d")
    }

    return carriers.joined(separator: ", ")
}

// MARK: - Genotype Locus Access

extension Genotype {
    /// Return the allele pair for the named locus.
    /// Supports: "eLocus", "bLocus", "sLocus", "cLocus", "rLocus", "dLocus".
    func allelePair(forLocus name: String) -> AllelePair {
        switch name {
        case "eLocus": eLocus
        case "bLocus": bLocus
        case "sLocus": sLocus
        case "cLocus": cLocus
        case "rLocus": rLocus
        case "dLocus": dLocus
        default: fatalError("Unknown locus name: \(name)")
        }
    }
}
