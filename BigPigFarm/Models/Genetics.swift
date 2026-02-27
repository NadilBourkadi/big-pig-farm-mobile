/// Genetics — Mendelian genetics system with 6-locus genotype and 144 phenotype combinations.
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
}

// MARK: - Stubs (implemented in later tasks)

/// Full 6-locus genotype.
struct Genotype: Codable, Sendable {
    // TODO: Implement in struct translation task
}

/// Observable phenotype derived from genotype.
struct Phenotype: Codable, Sendable {
    // TODO: Implement in struct translation task
}
