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

// MARK: - Biased Inheritance (Selective Advantage)

/// Inherit one allele from each parent with optional preference bias.
/// When a preference is set and the parent carries the target allele,
/// there is an 80% chance the inherited allele matches the preferred direction.
func inheritAlleleWithPreference(
    _ parent1Locus: AllelePair,
    _ parent2Locus: AllelePair,
    preference: AllelePreference,
    dominant: String,
    recessive: String
) -> AllelePair {
    guard preference != .noPreference else {
        return inheritAllele(parent1Locus, parent2Locus)
    }
    let target = preference == .dominant ? dominant : recessive
    let allele1 = biasedAlleleChoice(parent1Locus, target: target)
    let allele2 = biasedAlleleChoice(parent2Locus, target: target)
    return AllelePair(first: allele1, second: allele2)
}

/// Pick one allele from a parent pair, biased toward the target allele.
/// If the parent does not carry the target allele, falls back to random (50/50).
private func biasedAlleleChoice(_ parentPair: AllelePair, target: String) -> String {
    guard parentPair.contains(target) else {
        return Bool.random() ? parentPair.first : parentPair.second
    }
    if Double.random(in: 0.0..<1.0) < GameConfig.Prestige.selectiveAdvantageBias {
        return target
    }
    return Bool.random() ? parentPair.first : parentPair.second
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
    directionalRate: Double = 0.0,
    lockedLoci: [(locusName: String, parentGenotype: Genotype)]? = nil,
    allelePreferences: AllelePreferences? = nil
) -> BreedResult {
    // Mendelian inheritance with optional Selective Advantage bias
    let prefs = allelePreferences ?? AllelePreferences()
    var eLocus = inheritAlleleWithPreference(parent1.eLocus, parent2.eLocus,
        preference: prefs.eLocus, dominant: "E", recessive: "e")
    var bLocus = inheritAlleleWithPreference(parent1.bLocus, parent2.bLocus,
        preference: prefs.bLocus, dominant: "B", recessive: "b")
    var sLocus = inheritAlleleWithPreference(parent1.sLocus, parent2.sLocus,
        preference: prefs.sLocus, dominant: "S", recessive: "s")
    var cLocus = inheritAlleleWithPreference(parent1.cLocus, parent2.cLocus,
        preference: prefs.cLocus, dominant: "C", recessive: "ch")
    var rLocus = inheritAlleleWithPreference(parent1.rLocus, parent2.rLocus,
        preference: prefs.rLocus, dominant: "R", recessive: "r")
    var dLocus = inheritAlleleWithPreference(parent1.dLocus, parent2.dLocus,
        preference: prefs.dLocus, dominant: "D", recessive: "d")

    // Check for lethal roan combination (RR) -- reroll until non-lethal
    while rLocus.isHomozygous("R") {
        rLocus = inheritAllele(parent1.rLocus, parent2.rLocus)
    }

    // Genetic Imprinting: force one allele from the locked parent's genotype
    if let locked = lockedLoci {
        for (locusName, parentGeno) in locked {
            let parentPair = parentGeno.allelePair(forLocus: locusName)
            let forcedAllele = Bool.random() ? parentPair.first : parentPair.second
            switch locusName {
            case "eLocus": eLocus = AllelePair(first: forcedAllele, second: eLocus.second)
            case "bLocus": bLocus = AllelePair(first: forcedAllele, second: bLocus.second)
            case "sLocus": sLocus = AllelePair(first: forcedAllele, second: sLocus.second)
            case "cLocus": cLocus = AllelePair(first: forcedAllele, second: cLocus.second)
            case "rLocus":
                let candidate = AllelePair(first: forcedAllele, second: rLocus.second)
                if !candidate.isHomozygous("R") { rLocus = candidate }
            case "dLocus": dLocus = AllelePair(first: forcedAllele, second: dLocus.second)
            default: break
            }
        }
    }

    // Apply mutations
    var mutations: [String] = []
    let hasMutations = mutationRate > 0 || locusRates != nil || directionalTargets != nil

    if hasMutations {
        applyMutations(
            to: &eLocus, bLocus: &bLocus, sLocus: &sLocus,
            cLocus: &cLocus, rLocus: &rLocus, dLocus: &dLocus,
            mutations: &mutations,
            mutationRate: mutationRate,
            locusRates: locusRates,
            directionalTargets: directionalTargets,
            directionalRate: directionalRate
        )
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

// Apply per-locus mutations to the inherited loci and record descriptions.
// swiftlint:disable:next function_parameter_count
private func applyMutations(
    to eLocus: inout AllelePair,
    bLocus: inout AllelePair,
    sLocus: inout AllelePair,
    cLocus: inout AllelePair,
    rLocus: inout AllelePair,
    dLocus: inout AllelePair,
    mutations: inout [String],
    mutationRate: Double,
    locusRates: [String: Double]?,
    directionalTargets: [String: String]?,
    directionalRate: Double
) {
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
        let (newValue, didMutate) = resolveMutation(
            locusName: locusName,
            currentValue: currentValue,
            dominant: dominant,
            recessive: recessive,
            mutationRate: mutationRate,
            locusRates: locusRates,
            directionalTargets: directionalTargets,
            directionalRate: directionalRate
        )

        guard didMutate else { continue }
        // Suppress mutation if it creates lethal RR
        if locusName == "rLocus" && newValue.isHomozygous("R") { continue }

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
        mutations.append(
            "\(displayName) (\(currentValue.first)/\(currentValue.second)"
            + " -> \(newValue.first)/\(newValue.second))"
        )
    }
}

/// Compute the mutation result for a single locus, choosing directional or random.
private func resolveMutation(
    locusName: String,
    currentValue: AllelePair,
    dominant: String,
    recessive: String,
    mutationRate: Double,
    locusRates: [String: Double]?,
    directionalTargets: [String: String]?,
    directionalRate: Double
) -> (AllelePair, Bool) {
    if let targets = directionalTargets,
       let targetAllele = targets[locusName],
       directionalRate > 0 {
        return mutateLocusDirectional(currentValue, targetAllele: targetAllele, rate: directionalRate)
    }
    let rate = locusRates?[locusName] ?? mutationRate
    guard rate > 0 else { return (currentValue, false) }
    return mutateLocus(currentValue, dominant: dominant, recessive: recessive, rate: rate)
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
