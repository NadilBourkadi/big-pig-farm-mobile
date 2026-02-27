/// GeneticsParityTests -- Output parity tests comparing Swift genetics to Python source.
/// Cross-references: big_pig_farm/entities/genetics.py
///
/// These tests verify that the Swift port produces identical results to the Python
/// implementation for specific inputs. Existing unit tests (GeneticsTests.swift,
/// GeneticsBreedingTests.swift) cover mechanics; these cover cross-implementation parity.
import Testing

@testable import BigPigFarm

// MARK: - Helpers

/// Create a genotype from shorthand allele pairs.
private func genotype(
    e: (String, String), b: (String, String), s: (String, String),
    c: (String, String), r: (String, String), d: (String, String)
) -> Genotype {
    Genotype(
        eLocus: AllelePair(first: e.0, second: e.1),
        bLocus: AllelePair(first: b.0, second: b.1),
        sLocus: AllelePair(first: s.0, second: s.1),
        cLocus: AllelePair(first: c.0, second: c.1),
        rLocus: AllelePair(first: r.0, second: r.1),
        dLocus: AllelePair(first: d.0, second: d.1)
    )
}

/// Create a fully homozygous genotype from single allele strings.
private func homozygous(
    e: String, b: String, s: String,
    c: String, r: String, d: String
) -> Genotype {
    genotype(
        e: (e, e), b: (b, b), s: (s, s),
        c: (c, c), r: (r, r), d: (d, d)
    )
}

// MARK: - A. Config Constants Parity
// Cross-ref: genetics.py GeneticsConfig (lines 301-306)

@Test func parityGeneticsConfigValues() {
    // Python: MUTATION_RATE = 0.02
    #expect(GameConfig.Genetics.mutationRate == 0.02)
    // Python: MUTATION_RATE_WITH_LAB = 0.03
    #expect(GameConfig.Genetics.mutationRateWithLab == 0.03)
    // Python: DIRECTIONAL_MUTATION_RATE = 0.06
    #expect(GameConfig.Genetics.directionalMutationRate == 0.06)
    // Python: DIRECTIONAL_MUTATION_RATE_WITH_LAB = 0.09
    #expect(GameConfig.Genetics.directionalMutationRateWithLab == 0.09)
}

// MARK: - B. Heterozygous Dominance Parity
// Cross-ref: genetics.py calculate_phenotype (lines 197-227)
// Heterozygous carriers should produce the same phenotype as homozygous dominant.

@Test func parityHeterozygousDominanceSameAsDominant() {
    // EE/BB/DD (homozygous dominant) and Ee/Bb/Dd (heterozygous) both → black
    let dominant = homozygous(e: "E", b: "B", s: "S", c: "C", r: "r", d: "D")
    let carrier = genotype(
        e: ("E", "e"), b: ("B", "b"), s: ("S", "S"),
        c: ("C", "C"), r: ("r", "r"), d: ("D", "d")
    )

    let phenoDom = calculatePhenotype(dominant)
    let phenoCar = calculatePhenotype(carrier)

    #expect(phenoDom.baseColor == .black)
    #expect(phenoCar.baseColor == .black)
    #expect(phenoDom.baseColor == phenoCar.baseColor)

    // Verify dilution: Dd is NOT diluted (D dominant), dd IS diluted
    let diluted = genotype(
        e: ("E", "e"), b: ("B", "b"), s: ("S", "S"),
        c: ("C", "C"), r: ("r", "r"), d: ("d", "d")
    )
    #expect(calculatePhenotype(diluted).baseColor == .blue)
}

// MARK: - C. Exhaustive Rarity Point Scoring
// Cross-ref: genetics.py calculate_rarity (lines 237-285)
// Point system: pattern (dutch=1, dalmatian=2), intensity (chinchilla=2, himalayan=3),
// roan (2), base color (chocolate/cream=1, blue=2, lilac/saffron=3, smoke=4).
// Tiers: >=6 legendary, >=4 veryRare, >=2 rare, >=1 uncommon, else common.

@Test func parityRarityExhaustiveBoundaries() {
    // 0 points → common
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .full, roan: .none) == .common)
    #expect(calculateRarity(baseColor: .golden, pattern: .solid, intensity: .full, roan: .none) == .common)

    // 1 point → uncommon
    #expect(calculateRarity(baseColor: .chocolate, pattern: .solid, intensity: .full, roan: .none) == .uncommon)
    #expect(calculateRarity(baseColor: .cream, pattern: .solid, intensity: .full, roan: .none) == .uncommon)
    #expect(calculateRarity(baseColor: .black, pattern: .dutch, intensity: .full, roan: .none) == .uncommon)

    // 2 points → rare (boundary)
    #expect(calculateRarity(baseColor: .blue, pattern: .solid, intensity: .full, roan: .none) == .rare)
    #expect(calculateRarity(baseColor: .black, pattern: .dalmatian, intensity: .full, roan: .none) == .rare)
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .chinchilla, roan: .none) == .rare)
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .full, roan: .roan) == .rare)

    // 3 points → rare
    #expect(calculateRarity(baseColor: .lilac, pattern: .solid, intensity: .full, roan: .none) == .rare)
    #expect(calculateRarity(baseColor: .saffron, pattern: .solid, intensity: .full, roan: .none) == .rare)
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .himalayan, roan: .none) == .rare)

    // 4 points → veryRare (boundary)
    #expect(calculateRarity(baseColor: .smoke, pattern: .solid, intensity: .full, roan: .none) == .veryRare)
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .chinchilla, roan: .roan) == .veryRare)
    #expect(calculateRarity(baseColor: .blue, pattern: .solid, intensity: .full, roan: .roan) == .veryRare)
    #expect(calculateRarity(baseColor: .black, pattern: .dutch, intensity: .himalayan, roan: .none) == .veryRare)

    // 6 points → legendary (boundary)
    #expect(calculateRarity(baseColor: .smoke, pattern: .dalmatian, intensity: .full, roan: .none) == .legendary)
    #expect(calculateRarity(baseColor: .lilac, pattern: .solid, intensity: .himalayan, roan: .none) == .legendary)

    // 11 points → legendary (theoretical maximum)
    // dalmatian(2) + himalayan(3) + roan(2) + smoke(4) = 11
    #expect(calculateRarity(baseColor: .smoke, pattern: .dalmatian, intensity: .himalayan, roan: .roan) == .legendary)
}

// MARK: - D. Mendelian Breeding Ratio Parity
// Cross-ref: genetics.py breed_guinea_pigs (lines 329-393)
// Verifies Mendelian segregation ratios match expected distributions.

@Test func parityMendelianColorRatio3to1() {
    // Ee × Ee: expect ~75% has-E (black), ~25% ee (golden)
    // All other loci homozygous dominant to isolate E locus
    let parent = genotype(
        e: ("E", "e"), b: ("B", "B"), s: ("S", "S"),
        c: ("C", "C"), r: ("r", "r"), d: ("D", "D")
    )

    var goldenCount = 0
    let trials = 10_000

    for _ in 0..<trials {
        let result = breed(parent, parent)
        let phenotype = calculatePhenotype(result.genotype)
        if phenotype.baseColor == .golden {
            goldenCount += 1
        }
    }

    // Expected: 25% ± 5σ band. σ = sqrt(10000 * 0.25 * 0.75) ≈ 43.3, 5σ ≈ 217
    let ratio = Double(goldenCount) / Double(trials)
    #expect(ratio > 0.20 && ratio < 0.30,
            "Expected ~25% golden (3:1 ratio), got \(goldenCount)/\(trials) = \(ratio)")
}

@Test func parityMendelianPatternRatio1to2to1() {
    // Ss × Ss: expect ~25% SS (solid), ~50% Ss (dutch), ~25% ss (dalmatian)
    let parent = genotype(
        e: ("E", "E"), b: ("B", "B"), s: ("S", "s"),
        c: ("C", "C"), r: ("r", "r"), d: ("D", "D")
    )

    var solidCount = 0
    var dutchCount = 0
    var dalmatianCount = 0
    let trials = 10_000

    for _ in 0..<trials {
        let result = breed(parent, parent)
        let phenotype = calculatePhenotype(result.genotype)
        switch phenotype.pattern {
        case .solid: solidCount += 1
        case .dutch: dutchCount += 1
        case .dalmatian: dalmatianCount += 1
        }
    }

    // Expected: 25/50/25 ± 5σ band
    let solidRatio = Double(solidCount) / Double(trials)
    let dutchRatio = Double(dutchCount) / Double(trials)
    let dalmatianRatio = Double(dalmatianCount) / Double(trials)

    #expect(solidRatio > 0.20 && solidRatio < 0.30,
            "Expected ~25% solid, got \(solidRatio)")
    #expect(dutchRatio > 0.43 && dutchRatio < 0.57,
            "Expected ~50% dutch, got \(dutchRatio)")
    #expect(dalmatianRatio > 0.20 && dalmatianRatio < 0.30,
            "Expected ~25% dalmatian, got \(dalmatianRatio)")
}

// MARK: - E. Mutation Description Format Parity
// Cross-ref: genetics.py _apply_mutations (lines 395-440)
// Python format: f"{LOCUS_DISPLAY_NAMES[name]} ({old_a}/{old_b} -> {new_a}/{new_b})"
// Display names: Extension, Brown, Spotted, Intensity, Roan, Dilution

@Test func parityMutationDescriptionFormat() {
    // Use 100% mutation rate on a homozygous genotype to guarantee mutations
    let parent = homozygous(e: "E", b: "B", s: "S", c: "C", r: "r", d: "D")

    // Collect mutation descriptions over many trials
    var descriptions: Set<String> = []
    for _ in 0..<200 {
        let result = breed(parent, parent, mutationRate: 1.0)
        for desc in result.mutations {
            descriptions.insert(desc)
        }
    }

    // Verify format: "<DisplayName> (<old> -> <new>)"
    let expectedDisplayNames = ["Extension", "Brown", "Spotted", "Intensity", "Roan", "Dilution"]
    for desc in descriptions {
        let startsWithKnownName = expectedDisplayNames.contains { desc.hasPrefix($0) }
        #expect(startsWithKnownName,
                "Mutation description '\(desc)' should start with a known locus display name")

        #expect(desc.contains("(") && desc.contains("->") && desc.contains(")"),
                "Mutation description '\(desc)' should match format 'Name (old -> new)'")
    }

    // Should see at least a few distinct locus names mutated
    #expect(descriptions.count >= 3,
            "Expected mutations across multiple loci, got \(descriptions.count) distinct descriptions")
}

// MARK: - F. Analytical Probability Parity
// Cross-ref: genetics.py _pattern_probability, _intensity_probability (lines 560-625)

@Test func parityAnalyticalPatternProbabilitySsxSs() {
    // Ss × Ss: P(solid)=0.25, P(dutch)=0.50, P(dalmatian)=0.25
    let parent = genotype(
        e: ("E", "E"), b: ("B", "B"), s: ("S", "s"),
        c: ("C", "C"), r: ("r", "r"), d: ("D", "D")
    )

    let solidProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [.solid],
        targetIntensities: [], targetRoan: []
    )
    #expect(abs(solidProb - 0.25) < 0.001, "P(solid) should be 0.25, got \(solidProb)")

    let dutchProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [.dutch],
        targetIntensities: [], targetRoan: []
    )
    #expect(abs(dutchProb - 0.50) < 0.001, "P(dutch) should be 0.50, got \(dutchProb)")

    let dalmatianProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [.dalmatian],
        targetIntensities: [], targetRoan: []
    )
    #expect(abs(dalmatianProb - 0.25) < 0.001, "P(dalmatian) should be 0.25, got \(dalmatianProb)")
}

@Test func parityAnalyticalIntensitySelfConsistent() {
    // C/ch × C/ch: four outcomes CC (0.25), C/ch (0.25), ch/C (0.25), ch/ch (0.25)
    // Correct classification (matching calculatePhenotype):
    //   CC → full (0.25), C/ch + ch/C → chinchilla (0.50), ch/ch → himalayan (0.25)
    //
    // NOTE: Python _intensity_probability (genetics.py line 604) has a bug:
    // it checks has_dominant("C") first, which classifies C/ch as FULL instead of
    // CHINCHILLA. Python's calculate_phenotype correctly classifies C/ch as CHINCHILLA.
    // The Swift port uses the calculatePhenotype ordering in both calculatePhenotype
    // AND intensityProbability, making the analytical prediction self-consistent.
    let parent = genotype(
        e: ("E", "E"), b: ("B", "B"), s: ("S", "S"),
        c: ("C", "ch"), r: ("r", "r"), d: ("D", "D")
    )

    let fullProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [],
        targetIntensities: [.full], targetRoan: []
    )
    #expect(abs(fullProb - 0.25) < 0.001, "P(full) should be 0.25, got \(fullProb)")

    let chinchillaProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [],
        targetIntensities: [.chinchilla], targetRoan: []
    )
    #expect(abs(chinchillaProb - 0.50) < 0.001, "P(chinchilla) should be 0.50, got \(chinchillaProb)")

    let himalayanProb = calculateTargetProbability(
        parent, parent,
        targetColors: [], targetPatterns: [],
        targetIntensities: [.himalayan], targetRoan: []
    )
    #expect(abs(himalayanProb - 0.25) < 0.001, "P(himalayan) should be 0.25, got \(himalayanProb)")

    // Verify analytical prediction matches Monte Carlo phenotype distribution
    // (proves intensityProbability agrees with calculatePhenotype)
    var fullCount = 0
    var chinchillaCount = 0
    var himalayanCount = 0
    let trials = 10_000
    for _ in 0..<trials {
        let result = breed(parent, parent)
        switch calculatePhenotype(result.genotype).intensity {
        case .full: fullCount += 1
        case .chinchilla: chinchillaCount += 1
        case .himalayan: himalayanCount += 1
        }
    }

    let mcFull = Double(fullCount) / Double(trials)
    let mcChinchilla = Double(chinchillaCount) / Double(trials)
    let mcHimalayan = Double(himalayanCount) / Double(trials)

    // Monte Carlo should agree with analytical within ±5%
    #expect(abs(mcFull - fullProb) < 0.05,
            "MC full (\(mcFull)) should match analytical (\(fullProb))")
    #expect(abs(mcChinchilla - chinchillaProb) < 0.05,
            "MC chinchilla (\(mcChinchilla)) should match analytical (\(chinchillaProb))")
    #expect(abs(mcHimalayan - himalayanProb) < 0.05,
            "MC himalayan (\(mcHimalayan)) should match analytical (\(himalayanProb))")
}

// MARK: - G. Display Name Full Combo Parity
// Cross-ref: genetics.py Phenotype.display_name (lines 161-185)
// Order: [Roan] [Intensity] [Pattern] <Color>

@Test func parityDisplayNameFullCombos() {
    // Minimal: solid/full/black/none → "Black"
    let minimal = Phenotype(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
    )
    #expect(minimal.displayName == "Black")

    // Maximum rarity: roan/himalayan/dalmatian/lilac → "Roan Himalayan Dalmatian Lilac"
    let maximal = Phenotype(
        baseColor: .lilac, pattern: .dalmatian, intensity: .himalayan, roan: .roan, rarity: .legendary
    )
    #expect(maximal.displayName == "Roan Himalayan Dalmatian Lilac")

    // All 8 base colors in minimal form
    let colorNames: [(BaseColor, String)] = [
        (.black, "Black"), (.chocolate, "Chocolate"), (.golden, "Golden"),
        (.cream, "Cream"), (.blue, "Blue"), (.lilac, "Lilac"),
        (.saffron, "Saffron"), (.smoke, "Smoke"),
    ]
    for (color, expected) in colorNames {
        let phenotype = Phenotype(
            baseColor: color, pattern: .solid, intensity: .full, roan: .none, rarity: .common
        )
        #expect(phenotype.displayName == expected,
                "Expected '\(expected)' for \(color), got '\(phenotype.displayName)'")
    }
}
