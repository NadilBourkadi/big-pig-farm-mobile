/// GeneticsBreedingTests -- Tests for breeding, mutations, carrier analysis, and prediction.
/// Covers: breed(), mutateLocus, carrierSummary, predictOffspringPhenotypes, calculateTargetProbability.
import Testing

@testable import BigPigFarm

// MARK: - Breed Inheritance

@Test func testBreedInheritance() {
    let parent1 = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let parent2 = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "s", second: "s"),
        cLocus: AllelePair(first: "ch", second: "ch"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )

    // Without mutations, all offspring should be heterozygous carriers
    for _ in 0..<100 {
        let result = breed(parent1, parent2)
        let child = result.genotype

        // Parent1 only has E, Parent2 only has e, so child must have E/e
        #expect(child.eLocus.contains("E") && child.eLocus.contains("e"))
        #expect(child.bLocus.contains("B") && child.bLocus.contains("b"))
        #expect(child.sLocus.contains("S") && child.sLocus.contains("s"))
        #expect(child.cLocus.contains("C") && child.cLocus.contains("ch"))
        #expect(child.dLocus.contains("D") && child.dLocus.contains("d"))
        #expect(result.mutations.isEmpty)
    }
}

// MARK: - Lethal RR Reroll

@Test func testLethalRRReroll() {
    // Both parents are Rr -- 25% chance of RR per trial
    let parent = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )

    for _ in 0..<1000 {
        let result = breed(parent, parent)
        // RR should NEVER appear
        #expect(!result.genotype.rLocus.isHomozygous("R"))
    }
}

// MARK: - Mutation Rate

@Test func testMutationRate() {
    let parent = makeBaseGenotype()

    var totalMutations = 0
    let trials = 10_000

    for _ in 0..<trials {
        let result = breed(parent, parent, mutationRate: 0.02)
        totalMutations += result.mutations.count
    }

    // 6 loci * 0.02 rate = ~0.12 mutations per breed on average
    // Over 10,000 trials = ~1200 mutations expected
    // StdDev ≈ sqrt(60000 * 0.02 * 0.98) ≈ 34, so ±5σ ≈ ±170
    // Using ±25% band (~900-1500) to catch implementation errors while
    // remaining tolerant of random variation
    let expectedMin = 900
    let expectedMax = 1500
    #expect(totalMutations >= expectedMin && totalMutations <= expectedMax,
            "Expected \(expectedMin)-\(expectedMax) mutations, got \(totalMutations)")
}

// MARK: - Directional Mutation

@Test func testDirectionalMutation() {
    // Start with all-dominant genotype
    let parent = makeBaseGenotype()

    // Push e_locus toward recessive "e" with 100% rate
    var recessiveECount = 0
    let trials = 1000

    for _ in 0..<trials {
        let result = breed(
            parent, parent,
            directionalTargets: ["eLocus": "e"],
            directionalRate: 1.0
        )
        if result.genotype.eLocus.contains("e") {
            recessiveECount += 1
        }
    }

    // With 100% directional rate targeting "e" and parents being EE,
    // roughly half the time the selected allele will be "E" and get flipped.
    // So we expect a significant fraction to have "e" alleles.
    #expect(recessiveECount > trials / 4,
            "Expected significant recessive e, got \(recessiveECount)/\(trials)")
}

// MARK: - Carrier Summary

@Test func testCarrierSummaryNoCarriers() {
    let homozygous = makeBaseGenotype()
    #expect(carrierSummary(homozygous).isEmpty)
}

@Test func testCarrierSummaryAllCarriers() {
    let heterozygous = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "b"),
        sLocus: AllelePair(first: "S", second: "s"),
        cLocus: AllelePair(first: "C", second: "ch"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "d")
    )
    #expect(carrierSummary(heterozygous) == "E/e, B/b, S/s, C/ch, R/r, D/d")
}

@Test func testCarrierSummaryPartial() {
    let partial = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "d")
    )
    #expect(carrierSummary(partial) == "E/e, D/d")
}

// MARK: - Predict Offspring

@Test func testPredictOffspringProbabilitiesSumToOne() {
    let parent = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "b"),
        sLocus: AllelePair(first: "S", second: "s"),
        cLocus: AllelePair(first: "C", second: "ch"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "d")
    )

    let predictions = predictOffspringPhenotypes(parent, parent)
    let totalProbability = predictions.reduce(0.0) { $0 + $1.1 }

    // Probabilities should sum to approximately 1.0
    #expect(abs(totalProbability - 1.0) < 0.01,
            "Probabilities sum to \(totalProbability), expected ~1.0")
}

// MARK: - Target Probability

@Test func testTargetProbabilityExact() {
    // Two EE BB DD parents should always produce black offspring
    let parent = makeBaseGenotype()

    let probability = calculateTargetProbability(
        parent, parent,
        targetColors: [.black],
        targetPatterns: [.solid],
        targetIntensities: [.full],
        targetRoan: [.none]
    )
    #expect(abs(probability - 1.0) < 0.001, "Expected 1.0, got \(probability)")
}

@Test func testTargetProbabilityHeterozygous() {
    // Two Ee Bb parents: P(black) = P(E_) * P(B_) * P(D_)
    // P(E_) = 3/4, P(B_) = 3/4, P(D_) = 1.0
    // P(black) = 0.75 * 0.75 = 0.5625
    let parent = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )

    let probability = calculateTargetProbability(
        parent, parent,
        targetColors: [.black],
        targetPatterns: [],
        targetIntensities: [],
        targetRoan: []
    )
    #expect(abs(probability - 0.5625) < 0.001,
            "Expected ~0.5625, got \(probability)")
}

@Test func testTargetProbabilityEmptyTargetsMeansAny() {
    let parent = Genotype.randomCommon()
    let probability = calculateTargetProbability(
        parent, parent,
        targetColors: [],
        targetPatterns: [],
        targetIntensities: [],
        targetRoan: []
    )
    #expect(abs(probability - 1.0) < 0.001, "Empty targets should yield 1.0")
}

@Test func testTargetProbabilityRoanWithLethalReroll() {
    // Two Rr parents: 25% RR (lethal), 50% Rr, 25% rr
    // After reroll: P(roan) = 0.50/0.75 = 2/3, P(none) = 0.25/0.75 = 1/3
    let parent = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )

    let roanProb = calculateTargetProbability(
        parent, parent,
        targetColors: [],
        targetPatterns: [],
        targetIntensities: [],
        targetRoan: [.roan]
    )

    let expectedRoanProb = 2.0 / 3.0
    #expect(abs(roanProb - expectedRoanProb) < 0.001,
            "Expected ~\(expectedRoanProb), got \(roanProb)")
}

// MARK: - Test Helpers

/// Create a simple homozygous dominant genotype for testing.
private func makeBaseGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}
