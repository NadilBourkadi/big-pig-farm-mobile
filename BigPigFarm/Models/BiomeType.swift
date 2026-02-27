/// BiomeType -- Environmental biome types affecting pig comfort, mutations, and happiness.
/// Maps from: entities/biomes.py
import Foundation

// MARK: - BiomeType

/// One of 8 environmental biome types for farm areas.
enum BiomeType: String, Codable, CaseIterable, Sendable {
    case meadow
    case burrow
    case garden
    case tropical
    case alpine
    case crystal
    case wildflower
    case sanctuary
}

// MARK: - BiomeInfo

/// Metadata for a biome type. Rendering fields are omitted (SpriteKit uses tile sets).
struct BiomeInfo: Sendable {
    let displayName: String
    let description: String
    let requiredTier: Int
    let cost: Int
    let mutationBoostLoci: [String: Double]
    let signatureColor: BaseColor?
    let directionalAlleles: [String: String]
    let happinessBonus: Double
}

// MARK: - Biome Lookup Table

/// All 8 biome metadata entries. Populated from BIOMES in Python.
let biomes: [BiomeType: BiomeInfo] = [
    .meadow: BiomeInfo(
        displayName: "Meadow",
        description: "Lush green grass -- a natural home for guinea pigs",
        requiredTier: 1, cost: 0,
        mutationBoostLoci: [:],
        signatureColor: .black,
        directionalAlleles: ["eLocus": "E", "bLocus": "B", "dLocus": "D"],
        happinessBonus: 0.5
    ),
    .burrow: BiomeInfo(
        displayName: "Burrow",
        description: "Dark earthy tunnels -- cozy and warm",
        requiredTier: 1, cost: 300,
        mutationBoostLoci: [:],
        signatureColor: .chocolate,
        directionalAlleles: ["eLocus": "E", "bLocus": "b", "dLocus": "D"],
        happinessBonus: 0.5
    ),
    .garden: BiomeInfo(
        displayName: "Garden",
        description: "A lush vegetable garden with rich soil",
        requiredTier: 2, cost: 600,
        mutationBoostLoci: [:],
        signatureColor: .golden,
        directionalAlleles: ["eLocus": "e", "bLocus": "B", "dLocus": "D"],
        happinessBonus: 0.8
    ),
    .tropical: BiomeInfo(
        displayName: "Tropical",
        description: "Warm and exotic -- palm fronds and sandy floors",
        requiredTier: 2, cost: 800,
        mutationBoostLoci: ["sLocus": 0.08],
        signatureColor: .cream,
        directionalAlleles: ["eLocus": "e", "bLocus": "b", "dLocus": "D"],
        happinessBonus: 0.8
    ),
    .alpine: BiomeInfo(
        displayName: "Alpine",
        description: "Cool mountain rocks with grey-blue stone floors",
        requiredTier: 3, cost: 1200,
        mutationBoostLoci: ["cLocus": 0.08],
        signatureColor: .blue,
        directionalAlleles: ["eLocus": "E", "bLocus": "B", "dLocus": "d"],
        happinessBonus: 1.0
    ),
    .crystal: BiomeInfo(
        displayName: "Crystal Cave",
        description: "A mysterious cave with glowing purple crystals",
        requiredTier: 3, cost: 1500,
        mutationBoostLoci: ["rLocus": 0.08],
        signatureColor: .lilac,
        directionalAlleles: ["eLocus": "E", "bLocus": "b", "dLocus": "d"],
        happinessBonus: 1.0
    ),
    .wildflower: BiomeInfo(
        displayName: "Wildflower",
        description: "A colorful field bursting with wildflowers",
        requiredTier: 4, cost: 2000,
        mutationBoostLoci: ["sLocus": 0.05],
        signatureColor: .saffron,
        directionalAlleles: ["eLocus": "e", "bLocus": "B", "dLocus": "d"],
        happinessBonus: 1.2
    ),
    .sanctuary: BiomeInfo(
        displayName: "Sanctuary",
        description: "A golden temple of tranquility -- all mutations enhanced",
        requiredTier: 5, cost: 3500,
        mutationBoostLoci: ["sLocus": 0.03, "cLocus": 0.03, "rLocus": 0.03],
        signatureColor: .smoke,
        directionalAlleles: ["eLocus": "e", "bLocus": "b", "dLocus": "d"],
        happinessBonus: 1.5
    ),
]

// MARK: - Helper Lookups

/// Biome value string to signature BaseColor.
let biomeSignatureColors: [String: BaseColor] = {
    var result: [String: BaseColor] = [:]
    for (biome, info) in biomes {
        if let color = info.signatureColor {
            result[biome.rawValue] = color
        }
    }
    return result
}()

/// BaseColor to biome value string (reverse lookup).
let colorToBiome: [BaseColor: String] = {
    var result: [BaseColor: String] = [:]
    for (biomeValue, color) in biomeSignatureColors {
        result[color] = biomeValue
    }
    return result
}()
