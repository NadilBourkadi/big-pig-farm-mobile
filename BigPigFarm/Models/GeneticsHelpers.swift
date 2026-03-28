/// GeneticsHelpers -- Canonical genotype construction and locus constants.
/// Split from Genetics.swift to stay within the file length limit.
import Foundation

// MARK: - Canonical Genotype (Phenotype Recall)

/// Construct the simplest (canonical) genotype that produces the given phenotype traits.
/// Used by the Phenotype Recall Showroom upgrade to override a newborn's genotype.
func canonicalGenotype(
    baseColor: BaseColor, pattern: Pattern,
    intensity: ColorIntensity, roan: RoanType
) -> Genotype {
    let colorLoci = canonicalColorLoci(for: baseColor)
    let sLocus = canonicalSpottingLocus(for: pattern)
    let cLocus = canonicalIntensityLocus(for: intensity)
    let rLocus = canonicalRoanLocus(for: roan)

    return Genotype(
        eLocus: colorLoci.eLocus, bLocus: colorLoci.bLocus, sLocus: sLocus,
        cLocus: cLocus, rLocus: rLocus, dLocus: colorLoci.dLocus
    )
}

/// Parse a phenotype key ("color:pattern:intensity:roan") and construct a canonical genotype.
/// Returns nil if the key cannot be parsed.
func canonicalGenotype(forPhenotypeKey key: String) -> Genotype? {
    let parts = key.split(separator: ":").map(String.init)
    guard parts.count == 4,
          let baseColor = BaseColor(rawValue: parts[0]),
          let pattern = Pattern(rawValue: parts[1]),
          let intensity = ColorIntensity(rawValue: parts[2]),
          let roan = RoanType(rawValue: parts[3]) else {
        return nil
    }
    return canonicalGenotype(baseColor: baseColor, pattern: pattern, intensity: intensity, roan: roan)
}

// MARK: - Canonical Locus Helpers

/// E, B, D loci grouped for a base color.
private struct ColorLoci {
    let eLocus: AllelePair
    let bLocus: AllelePair
    let dLocus: AllelePair
}

/// E, B, D loci for a base color.
private func canonicalColorLoci(for baseColor: BaseColor) -> ColorLoci {
    switch baseColor {
    case .black:
        ColorLoci(eLocus: AllelePair(first: "E", second: "E"),
                  bLocus: AllelePair(first: "B", second: "B"),
                  dLocus: AllelePair(first: "D", second: "D"))
    case .chocolate:
        ColorLoci(eLocus: AllelePair(first: "E", second: "E"),
                  bLocus: AllelePair(first: "b", second: "b"),
                  dLocus: AllelePair(first: "D", second: "D"))
    case .golden:
        ColorLoci(eLocus: AllelePair(first: "e", second: "e"),
                  bLocus: AllelePair(first: "B", second: "B"),
                  dLocus: AllelePair(first: "D", second: "D"))
    case .cream:
        ColorLoci(eLocus: AllelePair(first: "e", second: "e"),
                  bLocus: AllelePair(first: "b", second: "b"),
                  dLocus: AllelePair(first: "D", second: "D"))
    case .blue:
        ColorLoci(eLocus: AllelePair(first: "E", second: "E"),
                  bLocus: AllelePair(first: "B", second: "B"),
                  dLocus: AllelePair(first: "d", second: "d"))
    case .lilac:
        ColorLoci(eLocus: AllelePair(first: "E", second: "E"),
                  bLocus: AllelePair(first: "b", second: "b"),
                  dLocus: AllelePair(first: "d", second: "d"))
    case .saffron:
        ColorLoci(eLocus: AllelePair(first: "e", second: "e"),
                  bLocus: AllelePair(first: "B", second: "B"),
                  dLocus: AllelePair(first: "d", second: "d"))
    case .smoke:
        ColorLoci(eLocus: AllelePair(first: "e", second: "e"),
                  bLocus: AllelePair(first: "b", second: "b"),
                  dLocus: AllelePair(first: "d", second: "d"))
    }
}

/// S locus: SS = solid, Ss = dutch, ss = dalmatian.
private func canonicalSpottingLocus(for pattern: Pattern) -> AllelePair {
    switch pattern {
    case .solid:     AllelePair(first: "S", second: "S")
    case .dutch:     AllelePair(first: "S", second: "s")
    case .dalmatian: AllelePair(first: "s", second: "s")
    }
}

/// C locus: CC = full, C/ch = chinchilla, ch/ch = himalayan.
private func canonicalIntensityLocus(for intensity: ColorIntensity) -> AllelePair {
    switch intensity {
    case .full:        AllelePair(first: "C", second: "C")
    case .chinchilla:  AllelePair(first: "C", second: "ch")
    case .himalayan:   AllelePair(first: "ch", second: "ch")
    }
}

/// R locus: rr = none, Rr = roan (never RR -- lethal).
private func canonicalRoanLocus(for roan: RoanType) -> AllelePair {
    switch roan {
    case .none: AllelePair(first: "r", second: "r")
    case .roan: AllelePair(first: "R", second: "r")
    }
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
