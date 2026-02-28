/// Acclimation — Biome preference and acclimation tracking.
/// Maps from: simulation/acclimation.py
import Foundation

/// Stateless namespace for pig biome acclimation logic.
enum Acclimation {
    /// Acclimation threshold in game-hours (3 days × 24 hours/day = 72 hours).
    private static let acclimationHours: Double =
        GameConfig.Biome.acclimationDays * Double(GameConfig.Time.gameHoursPerDay)

    /// Advance a pig's biome acclimation timer by `hoursPerTick`.
    ///
    /// When a pig spends `acclimationDays` continuously in a biome that is not its
    /// `preferredBiome`, it adopts that biome. The timer resets if the pig returns
    /// home or switches to a different foreign biome.
    ///
    /// Pigs whose base color matches the target biome's signature color acclimate
    /// at 2x speed: the threshold is multiplied by `colorMatchAcclimationMultiplier` (0.5),
    /// halving the time required to adopt.
    static func updateAcclimation(
        pig: inout GuineaPig,
        currentBiome: String?,
        hoursPerTick: Double
    ) {
        // Pigs without a preferred biome and pigs outside any area are skipped.
        guard pig.preferredBiome != nil, let currentBiome else { return }

        // Home biome: reset timer, no acclimation needed.
        if currentBiome == pig.preferredBiome {
            pig.acclimationTimer = 0.0
            pig.acclimatingBiome = nil
            return
        }

        // Entered a different foreign biome: restart timer.
        if pig.acclimatingBiome != currentBiome {
            pig.acclimationTimer = 0.0
            pig.acclimatingBiome = currentBiome
        }

        pig.acclimationTimer += hoursPerTick

        // Color-match bonus: pigs whose color matches the biome's signature adopt faster.
        var threshold = acclimationHours
        if let signature = biomeSignatureColors[currentBiome],
           pig.phenotype.baseColor == signature {
            threshold *= GameConfig.Biome.colorMatchAcclimationMultiplier
        }

        if pig.acclimationTimer >= threshold {
            pig.preferredBiome = currentBiome
            pig.acclimationTimer = 0.0
            pig.acclimatingBiome = nil
        }
    }
}
