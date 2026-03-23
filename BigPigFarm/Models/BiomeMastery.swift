/// BiomeMastery -- Tracks pigs bred per biome across all farms for prestige bonuses.
/// Maps from: design-prestige-and-progression.md Section 11
import Foundation

// MARK: - BiomeMastery

/// Cross-farm biome mastery tracking. Persists across prestige resets.
struct BiomeMastery: Codable, Sendable {
    /// Number of pigs bred in each biome across all farms.
    var pigsBredByBiome: [BiomeType: Int] = [:]

    /// Check if a biome has been mastered (threshold pigs bred).
    func isMastered(_ biome: BiomeType) -> Bool {
        (pigsBredByBiome[biome] ?? 0) >= GameConfig.Prestige.biomeMasteryThreshold
    }

    /// All biomes that have been mastered.
    var masteredBiomes: [BiomeType] {
        BiomeType.allCases.filter { isMastered($0) }
    }

    /// Record a pig bred in a biome.
    mutating func recordBirth(in biome: BiomeType) {
        pigsBredByBiome[biome, default: 0] += 1
    }

    /// Number of pigs bred in a specific biome.
    func pigsBred(in biome: BiomeType) -> Int {
        pigsBredByBiome[biome] ?? 0
    }

    /// Progress toward mastery as a fraction (0.0–1.0).
    func masteryProgress(for biome: BiomeType) -> Double {
        let bred = Double(pigsBred(in: biome))
        let threshold = Double(GameConfig.Prestige.biomeMasteryThreshold)
        return min(1.0, bred / threshold)
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case pigsBredByBiome = "pigs_bred_by_biome"
    }
}
