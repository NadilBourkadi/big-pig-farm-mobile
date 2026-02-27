/// FacilityManager — Facility scoring, path caching, and occupancy tracking.
/// Maps from: simulation/facility_manager.py
import Foundation

/// Manages facility state, occupancy limits, and scoring for pig AI.
@MainActor
final class FacilityManager {
    private unowned let gameState: GameState
    private unowned let collision: CollisionHandler

    init(gameState: GameState, collision: CollisionHandler) {
        self.gameState = gameState
        self.collision = collision
    }

    /// Rebuild per-area pig population counts used by overcrowding logic.
    func updateAreaPopulations() {
        // TODO(facility): Implement area population cache rebuild
    }
}
