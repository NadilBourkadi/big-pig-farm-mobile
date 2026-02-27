/// Breeding — Pair selection and courtship behavior.
/// Maps from: simulation/breeding.py
import Foundation

/// Stateless namespace for breeding pair evaluation and pregnancy initiation.
enum Breeding {
    /// Scan all pigs for valid breeding opportunities.
    /// Returns the number of new courtships started.
    /// `runExpensive` enables full O(n²) pair scoring (throttled to every 10 ticks).
    @MainActor
    static func checkBreedingOpportunities(
        gameState: GameState,
        runExpensive: Bool
    ) -> Int {
        // TODO(breeding): Implement pair scoring and courtship initiation
        0
    }

    /// Initiate a pregnancy from a completed courtship.
    /// Applies genetics crossing and resets courtship state.
    @MainActor
    static func startPregnancyFromCourtship(
        male: inout GuineaPig,
        female: inout GuineaPig,
        gameState: GameState
    ) {
        // TODO(breeding): Implement pregnancy initiation with Mendelian genetics
    }

    /// Clear all courtship tracking fields from a pig.
    static func clearCourtship(pig: inout GuineaPig) {
        pig.courtingPartnerId = nil
        pig.courtingInitiator = false
        pig.courtingTimer = 0.0
    }
}
