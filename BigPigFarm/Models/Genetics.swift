/// Genetics -- Mendelian genetics system with 6-locus genotype and 144 phenotype combinations.
/// Maps from: entities/genetics.py
import Foundation

// MARK: - Allele

/// A single genetic allele across all 6 loci.
/// Raw values match the Python `Allele(str, Enum)` values exactly.
enum Allele: String, Codable, CaseIterable, Sendable {
    // Extension locus (E) - controls black/color vs red/golden
    case dominantE = "E"
    case recessiveE = "e"

    // Brown locus (B) - modifies black to brown
    case dominantB = "B"
    case recessiveB = "b"

    // Spotting locus (S) - controls white pattern
    case dominantS = "S"
    case recessiveS = "s"

    // Color intensity locus (C)
    case dominantC = "C"
    case chinchilla = "ch"

    // Roan locus (R) - dominant is lethal when homozygous
    case dominantR = "R"
    case recessiveR = "r"

    // Dilution locus (D)
    case dominantD = "D"
    case recessiveD = "d"
}

// MARK: - BaseColor

/// Base coat color derived from E, B, and D loci (8 variants).
enum BaseColor: String, Codable, CaseIterable, Sendable {
    case black
    case chocolate
    case golden
    case cream
    case blue       // Diluted black (dd)
    case lilac      // Diluted chocolate (bb + dd)
    case saffron    // Diluted golden (ee + dd)
    case smoke      // Diluted cream (ee + bb + dd)
}

// MARK: - Pattern

/// Coat pattern derived from S locus.
enum Pattern: String, Codable, CaseIterable, Sendable {
    case solid
    case dutch       // Partial white spotting
    case dalmatian   // Heavy white spotting
}

// MARK: - ColorIntensity

/// Color intensity modifier from C locus.
enum ColorIntensity: String, Codable, CaseIterable, Sendable {
    case full
    case chinchilla  // Diluted
    case himalayan   // Points only
}

// MARK: - RoanType

/// Roan modifier from R locus (white hair intermixing).
enum RoanType: String, Codable, CaseIterable, Sendable {
    case none
    case roan
}

// MARK: - Rarity

/// Phenotype rarity tier based on point scoring.
enum Rarity: String, Codable, CaseIterable, Sendable {
    case common
    case uncommon
    case rare
    case veryRare = "very_rare"
    case legendary

    /// Numeric ordering for sort comparisons. Higher = rarer.
    var sortOrder: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .veryRare: return 3
        case .legendary: return 4
        }
    }
}

// MARK: - AllelePair

/// A pair of alleles at a single locus. Replaces Python's tuple[str, str].
/// Tuples are not Codable in Swift, so this struct provides the same interface.
struct AllelePair: Codable, Sendable, Hashable {
    let first: String
    let second: String

    /// Check if either allele matches the given value.
    func contains(_ allele: String) -> Bool {
        first == allele || second == allele
    }

    /// Count occurrences of the given allele (0, 1, or 2).
    func count(_ allele: String) -> Int {
        var total = 0
        if first == allele { total += 1 }
        if second == allele { total += 1 }
        return total
    }

    /// Check if both alleles are the same value.
    func isHomozygous(_ allele: String) -> Bool {
        first == allele && second == allele
    }

    /// Check if at least one allele matches (dominance check).
    func hasDominant(_ dominant: String) -> Bool {
        contains(dominant)
    }
}

// MARK: - Genotype

/// Complete 6-locus genotype of a guinea pig.
struct Genotype: Codable, Sendable {
    var eLocus: AllelePair   // Extension: E/e
    var bLocus: AllelePair   // Brown: B/b
    var sLocus: AllelePair   // Spotting: S/s
    var cLocus: AllelePair   // Intensity: C/ch
    var rLocus: AllelePair   // Roan: R/r
    var dLocus: AllelePair   // Dilution: D/d

    /// Generate a guaranteed common genotype (solid, full color, no roan, no dilution).
    static func randomCommon() -> Self {
        let eOptions = [AllelePair(first: "E", second: "E"),
                        AllelePair(first: "E", second: "e")]
        let bOptions = [AllelePair(first: "B", second: "B"),
                        AllelePair(first: "B", second: "b")]
        guard let eLocus = eOptions.randomElement(),
              let bLocus = bOptions.randomElement() else {
            preconditionFailure("Allele option arrays must not be empty")
        }
        return Self(
            eLocus: eLocus,
            bLocus: bLocus,
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
    }

    /// Generate a random genotype with more variation.
    static func random() -> Self {
        let eOptions = [AllelePair(first: "E", second: "E"),
                        AllelePair(first: "E", second: "e"),
                        AllelePair(first: "e", second: "e")]
        let bOptions = [AllelePair(first: "B", second: "B"),
                        AllelePair(first: "B", second: "b"),
                        AllelePair(first: "b", second: "b")]
        guard let eLocus = eOptions.randomElement(),
              let bLocus = bOptions.randomElement() else {
            preconditionFailure("Allele option arrays must not be empty")
        }
        return Self(
            eLocus: eLocus,
            bLocus: bLocus,
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
    }

    enum CodingKeys: String, CodingKey {
        case eLocus = "e_locus"
        case bLocus = "b_locus"
        case sLocus = "s_locus"
        case cLocus = "c_locus"
        case rLocus = "r_locus"
        case dLocus = "d_locus"
    }
}

// MARK: - Phenotype

/// Observable traits derived from genotype.
struct Phenotype: Codable, Sendable, Hashable {
    let baseColor: BaseColor
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    let rarity: Rarity

    /// Human-readable name (e.g. "Roan Chinchilla Dutch Black").
    var displayName: String {
        var parts: [String] = []

        if roan == .roan {
            parts.append("Roan")
        }
        if intensity == .chinchilla {
            parts.append("Chinchilla")
        } else if intensity == .himalayan {
            parts.append("Himalayan")
        }
        if pattern == .dutch {
            parts.append("Dutch")
        } else if pattern == .dalmatian {
            parts.append("Dalmatian")
        }

        let colorNames: [BaseColor: String] = [
            .black: "Black", .chocolate: "Chocolate",
            .golden: "Golden", .cream: "Cream",
            .blue: "Blue", .lilac: "Lilac",
            .saffron: "Saffron", .smoke: "Smoke",
        ]
        parts.append(colorNames[baseColor] ?? baseColor.rawValue.capitalized)

        return parts.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case baseColor = "base_color"
        case pattern, intensity, roan, rarity
    }
}

// MARK: - Phenotype Calculation

/// Determine base coat color from E, B, and D locus dominance flags.
/// Internal visibility: used by GeneticsPrediction.swift for analytical probability.
func determineBaseColor(hasE: Bool, hasB: Bool, hasD: Bool) -> BaseColor {
    if hasE && hasB {
        return hasD ? .black : .blue
    } else if hasE && !hasB {
        return hasD ? .chocolate : .lilac
    } else if !hasE && hasB {
        return hasD ? .golden : .saffron
    } else {
        return hasD ? .cream : .smoke
    }
}

/// Calculate the observable phenotype from a genotype.
func calculatePhenotype(_ genotype: Genotype) -> Phenotype {
    let hasE = genotype.eLocus.hasDominant("E")
    let hasB = genotype.bLocus.hasDominant("B")
    let hasD = genotype.dLocus.hasDominant("D")
    let baseColor = determineBaseColor(hasE: hasE, hasB: hasB, hasD: hasD)

    // Pattern from S locus
    let pattern: Pattern
    if genotype.sLocus.isHomozygous("S") {
        pattern = .solid
    } else if genotype.sLocus.isHomozygous("s") {
        pattern = .dalmatian
    } else {
        pattern = .dutch
    }

    // Intensity from C locus
    let intensity: ColorIntensity
    if genotype.cLocus.isHomozygous("ch") {
        intensity = .himalayan
    } else if genotype.cLocus.contains("ch") {
        intensity = .chinchilla
    } else {
        intensity = .full
    }

    // Roan from R locus
    let roan: RoanType = genotype.rLocus.hasDominant("R") ? .roan : .none

    let rarity = calculateRarity(
        baseColor: baseColor, pattern: pattern,
        intensity: intensity, roan: roan
    )

    return Phenotype(
        baseColor: baseColor, pattern: pattern,
        intensity: intensity, roan: roan, rarity: rarity
    )
}

/// Points contributed by a pattern toward rarity scoring.
private func patternRarityPoints(_ pattern: Pattern) -> Int {
    switch pattern {
    case .dalmatian: return 2
    case .dutch: return 1
    case .solid: return 0
    }
}

/// Points contributed by a color intensity toward rarity scoring.
private func intensityRarityPoints(_ intensity: ColorIntensity) -> Int {
    switch intensity {
    case .himalayan: return 3
    case .chinchilla: return 2
    case .full: return 0
    }
}

/// Points contributed by a base color toward rarity scoring.
private func colorRarityPoints(_ baseColor: BaseColor) -> Int {
    switch baseColor {
    case .chocolate, .cream: return 1
    case .blue: return 2
    case .lilac, .saffron: return 3
    case .smoke: return 4
    case .black, .golden: return 0
    }
}

/// Calculate the rarity tier based on trait combination point scoring.
func calculateRarity(
    baseColor: BaseColor, pattern: Pattern,
    intensity: ColorIntensity, roan: RoanType
) -> Rarity {
    var rareCount = 0
    rareCount += patternRarityPoints(pattern)
    rareCount += intensityRarityPoints(intensity)
    rareCount += colorRarityPoints(baseColor)
    if roan == .roan { rareCount += 2 }

    if rareCount >= 6 { return .legendary }
    if rareCount >= 4 { return .veryRare }
    if rareCount >= 2 { return .rare }
    if rareCount >= 1 { return .uncommon }
    return .common
}

// MARK: - Locus Constants

// Locus definitions for mutation/breeding: (locusName, dominant, recessive).
// swiftlint:disable:next large_tuple
let locusDefinitions: [(String, String, String)] = [
    ("eLocus", "E", "e"),
    ("bLocus", "B", "b"),
    ("sLocus", "S", "s"),
    ("cLocus", "C", "ch"),
    ("rLocus", "R", "r"),
    ("dLocus", "D", "d"),
]

/// Human-readable locus names for UI/logging.
let locusDisplayNames: [String: String] = [
    "eLocus": "Extension",
    "bLocus": "Brown",
    "sLocus": "Spotted",
    "cLocus": "Intensity",
    "rLocus": "Roan",
    "dLocus": "Dilution",
]
