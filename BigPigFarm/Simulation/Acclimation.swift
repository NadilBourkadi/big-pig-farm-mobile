/// Acclimation — Biome preference and acclimation tracking.
/// Maps from: simulation/acclimation.py
import Foundation

/// Stateless namespace for pig biome acclimation logic.
enum Acclimation {
    /// Advance a pig's biome acclimation timer by `hoursPerTick`.
    /// When the timer completes, `preferredBiome` is updated to `currentBiome`.
    static func updateAcclimation(
        pig: inout GuineaPig,
        currentBiome: String?,
        hoursPerTick: Double
    ) {
        // TODO(acclimation): Implement full acclimation timer and biome adoption logic
    }
}
