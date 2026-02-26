/// BiomeType — Environmental biome types affecting pig comfort and behavior.
/// Maps from: entities/biome.py
// TODO: Implement in doc 02
import Foundation

/// One of 8 environmental biome types.
enum BiomeType: String, Codable, CaseIterable, Sendable {
    case meadow
    case forest
    case desert
    case tundra
    case tropical
    case mountain
    case swamp
    case volcanic
}
