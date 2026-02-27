/// BiomeType — Environmental biome types affecting pig comfort, mutations, and happiness.
/// Maps from: entities/biomes.py
import Foundation

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
