/// Genetics — Mendelian genetics system with 6-locus genotype and 144 phenotype combinations.
/// Maps from: entities/genetics.py
// TODO: Implement in doc 02
import Foundation

/// Base coat color (8 variants).
enum BaseColor: String, Codable, CaseIterable, Sendable {
    case white, cream, gold, orange, brown, chocolate, gray, black
}

/// Coat pattern type.
enum Pattern: String, Codable, CaseIterable, Sendable {
    case solid, patched, brindle
}

/// Color intensity modifier.
enum ColorIntensity: String, Codable, CaseIterable, Sendable {
    case light, medium, dark
}

/// Roan modifier (white hair intermixing).
enum RoanType: String, Codable, CaseIterable, Sendable {
    case none, roan
}

/// Phenotype rarity tier.
enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare, epic, legendary
}

/// A single genetic allele.
struct Allele: Codable, Sendable, Hashable {
    // TODO: Implement in doc 02
}

/// Full 6-locus genotype.
struct Genotype: Codable, Sendable {
    // TODO: Implement in doc 02
}

/// Observable phenotype derived from genotype.
struct Phenotype: Codable, Sendable {
    // TODO: Implement in doc 02
}
