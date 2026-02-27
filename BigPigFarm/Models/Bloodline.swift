/// Bloodline -- Bloodline tracking for breeding programs and adoption.
/// Maps from: entities/bloodlines.py
import Foundation

// MARK: - BloodlineType

/// Types of bloodlines available for adoption, gated by farm tier.
/// Raw values match the Python `BloodlineType(str, Enum)` values for JSON compatibility.
enum BloodlineType: String, Codable, CaseIterable, Sendable {
    case spotted
    case chocolate
    case golden
    case silver
    case roan
    case exoticSpotSilver = "exotic_spot_silver"
    case exoticRoanSilver = "exotic_roan_silver"
}

// MARK: - Bloodline

/// A bloodline definition with carrier alleles and tier gating.
/// Identity is `bloodlineType` (no UUID).
struct Bloodline: Codable, Sendable {
    let bloodlineType: BloodlineType
    let displayName: String
    let description: String
    let requiredTier: Int
    let costMultiplier: Double
    let locusOverrides: [String: AllelePair]

    /// Apply bloodline carrier alleles on top of a genotype.
    func applyToGenotype(_ genotype: Genotype) -> Genotype {
        var result = genotype
        for (locusName, alleles) in locusOverrides {
            switch locusName {
            case "eLocus": result.eLocus = alleles
            case "bLocus": result.bLocus = alleles
            case "sLocus": result.sLocus = alleles
            case "cLocus": result.cLocus = alleles
            case "rLocus": result.rLocus = alleles
            case "dLocus": result.dLocus = alleles
            default: break
            }
        }
        return result
    }

    enum CodingKeys: String, CodingKey {
        case bloodlineType = "bloodline_type"
        case displayName = "display_name"
        case description
        case requiredTier = "required_tier"
        case costMultiplier = "cost_multiplier"
        case locusOverrides = "locus_overrides"
    }
}

// MARK: - Bloodlines Lookup Table

/// All 7 bloodline definitions. Populated from BLOODLINES in Python.
let bloodlines: [BloodlineType: Bloodline] = [
    .spotted: Bloodline(
        bloodlineType: .spotted,
        displayName: "Spotted Bloodline",
        description: "May produce offspring with unusual patterns",
        requiredTier: 1, costMultiplier: 1.5,
        locusOverrides: ["sLocus": AllelePair(first: "S", second: "s")]
    ),
    .chocolate: Bloodline(
        bloodlineType: .chocolate,
        displayName: "Chocolate Bloodline",
        description: "May produce offspring with rich chocolate coloring",
        requiredTier: 1, costMultiplier: 1.3,
        locusOverrides: ["bLocus": AllelePair(first: "B", second: "b")]
    ),
    .golden: Bloodline(
        bloodlineType: .golden,
        displayName: "Golden Bloodline",
        description: "May produce offspring with golden or cream coloring",
        requiredTier: 2, costMultiplier: 1.8,
        locusOverrides: ["eLocus": AllelePair(first: "E", second: "e")]
    ),
    .silver: Bloodline(
        bloodlineType: .silver,
        displayName: "Silver Bloodline",
        description: "May produce offspring with unusual color intensity",
        requiredTier: 2, costMultiplier: 2.5,
        locusOverrides: ["cLocus": AllelePair(first: "C", second: "ch")]
    ),
    .roan: Bloodline(
        bloodlineType: .roan,
        displayName: "Roan Bloodline",
        description: "Carries the roan gene -- white hairs mixed into coat",
        requiredTier: 3, costMultiplier: 3.0,
        locusOverrides: ["rLocus": AllelePair(first: "R", second: "r")]
    ),
    .exoticSpotSilver: Bloodline(
        bloodlineType: .exoticSpotSilver,
        displayName: "Exotic Bloodline (Spotted+Silver)",
        description: "Carries both spotting and intensity genes -- rare combos possible",
        requiredTier: 4, costMultiplier: 4.0,
        locusOverrides: [
            "sLocus": AllelePair(first: "S", second: "s"),
            "cLocus": AllelePair(first: "C", second: "ch"),
        ]
    ),
    .exoticRoanSilver: Bloodline(
        bloodlineType: .exoticRoanSilver,
        displayName: "Exotic Bloodline (Roan+Silver)",
        description: "Carries both roan and intensity genes -- legendary combos possible",
        requiredTier: 4, costMultiplier: 5.0,
        locusOverrides: [
            "rLocus": AllelePair(first: "R", second: "r"),
            "cLocus": AllelePair(first: "C", second: "ch"),
        ]
    ),
]

// MARK: - Free Functions

/// Get bloodlines available at the given farm tier.
func getAvailableBloodlines(farmTier: Int) -> [Bloodline] {
    bloodlines.values.filter { $0.requiredTier <= farmTier }
}

/// Generate a genotype with bloodline carrier alleles applied.
func generateBloodlinePigGenotype(_ bloodline: Bloodline) -> Genotype {
    let base = Genotype.randomCommon()
    return bloodline.applyToGenotype(base)
}

/// Pick a random available bloodline for the given tier.
func pickRandomBloodline(farmTier: Int) -> Bloodline? {
    let available = getAvailableBloodlines(farmTier: farmTier)
    return available.randomElement()
}
