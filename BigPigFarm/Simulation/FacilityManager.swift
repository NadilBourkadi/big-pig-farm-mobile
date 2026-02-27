/// FacilityManager — Facility scoring, path caching, and occupancy tracking.
/// Maps from: simulation/facility_manager.py
import Foundation
import GameplayKit

/// Manages facility state, occupancy limits, and scoring for pig AI.
@MainActor
final class FacilityManager {
    private unowned let gameState: GameState
    private unowned let collision: CollisionHandler

    /// Cached pathfinding graph. Rebuilt when farm.gridGeneration changes.
    private var pathfindingCache: Pathfinding?

    init(gameState: GameState, collision: CollisionHandler) {
        self.gameState = gameState
        self.collision = collision
    }

    /// Rebuild per-area pig population counts used by overcrowding logic.
    func updateAreaPopulations() {
        // TODO(facility): Implement area population cache rebuild
    }
}

// MARK: - Path Cache (stub -- caching + invalidation will be implemented in FacilityManager bead)

extension FacilityManager {
    /// Find a path from start to goal using a cached GKGridGraph.
    /// Rebuilds the graph when the farm layout changes (gridGeneration mismatch).
    func findPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition] {
        if pathfindingCache == nil || !(pathfindingCache?.isValid(for: gameState.farm) ?? false) {
            pathfindingCache = Pathfinding(farm: gameState.farm)
        }
        return pathfindingCache?.findPath(from: start, to: goal) ?? []
    }
}

// MARK: - Facility Candidate Ranking (stub)

extension FacilityManager {
    /// Ranked candidates for a given facility type and pig.
    /// Stub returns empty array — full scoring implemented in FacilityManager bead.
    func getCandidateFacilitiesRanked(pig: GuineaPig, facilityType: FacilityType) -> [Facility] {
        // TODO(facility): Score by distance, crowding, biome affinity, bonuses
        []
    }

    /// Find an unoccupied interaction point for a facility and return the path.
    /// Stub returns nil — full occupancy checking implemented in FacilityManager bead.
    func findOpenInteractionPoint(
        pig: GuineaPig,
        facility: Facility
    ) -> (GridPosition, [GridPosition])? {
        // TODO(facility): Check occupancy radius, find best interaction point, pathfind
        nil
    }
}

// MARK: - Facility Failure Tracking (stub)

extension FacilityManager {
    /// Mark a facility as failed for a pig (pig couldn't reach it).
    /// Stub is a no-op — full blacklisting implemented in FacilityManager bead.
    func addFailedFacility(_ pigId: UUID, _ facilityId: UUID) {
        // TODO(facility): Add to per-pig failed facility set with cooldown
    }

    /// Set how many decision cycles before this pig retries failed facilities.
    /// Stub is a no-op — full cooldown tracking implemented in FacilityManager bead.
    func setFailedCooldown(_ pigId: UUID, _ cycles: Int) {
        // TODO(facility): Store cooldown; decrement each decision cycle
    }

    /// Try to find an alternative facility when the pig is blocked.
    /// Stub always returns false — full fallback search implemented in FacilityManager bead.
    func tryAlternativeFacility(pig: inout GuineaPig) -> Bool {
        // TODO(facility): Try other facilities of same type, path to best alternative
        false
    }
}
