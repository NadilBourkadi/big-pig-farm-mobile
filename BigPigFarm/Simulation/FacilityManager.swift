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

    /// How many decision cycles remain before retrying failed facilities.
    /// Stub always returns 0 — full cooldown tracking implemented in FacilityManager bead.
    func getFailedCooldown(_ pigId: UUID) -> Int {
        // TODO(facility): Return remaining cooldown cycles
        0
    }

    /// Decrement the failure cooldown counter for a pig by one cycle.
    /// Stub is a no-op — implemented in FacilityManager bead.
    func tickFailedCooldown(_ pigId: UUID) {
        // TODO(facility): Decrement cooldown counter
    }

    /// Clear the failed facility blacklist for a pig (called when pig makes a fresh decision).
    /// Stub is a no-op — implemented in FacilityManager bead.
    func clearFailedFacilities(_ pigId: UUID) {
        // TODO(facility): Remove all failed facility entries for this pig
    }

    /// Return the set of facility IDs currently blacklisted for this pig.
    /// Stub returns empty set — implemented in FacilityManager bead.
    func getFailedFacilities(_ pigId: UUID) -> Set<UUID> {
        // TODO(facility): Return per-pig failed facility set
        []
    }

    /// Try to find an alternative facility when the pig is blocked.
    /// Stub always returns false — full fallback search implemented in FacilityManager bead.
    func tryAlternativeFacility(pig: inout GuineaPig) -> Bool {
        // TODO(facility): Try other facilities of same type, path to best alternative
        false
    }
}

// MARK: - Facility Arrival and Consumption (stub)

extension FacilityManager {
    /// Transition a pig's behavior state based on the facility it just reached.
    /// Stub is a no-op — implemented in FacilityManager bead.
    func checkArrivedAtFacility(pig: inout GuineaPig) {
        // TODO(facility): Match facility type to behavior state (.eating, .drinking, etc.)
    }

    /// Consume resources from any facility the pig is currently using.
    /// Stub is a no-op — implemented in FacilityManager bead.
    func consumeFromNearbyFacility(pig: inout GuineaPig, gameMinutes: Double) {
        // TODO(facility): Drain currentAmount from target facility, apply need recovery
    }
}

// MARK: - Lifecycle Helpers (stub)

extension FacilityManager {
    /// Clear all per-pig facility state (occupancy, failed list, cooldown) on pig removal.
    /// Stub is a no-op — implemented in FacilityManager bead.
    func cleanupPig(_ pigId: UUID) {
        // TODO(facility): Remove pig from occupancy tracking and failure blacklist
    }

    /// Reset all per-pig facility state (called on game reset / new game).
    /// Stub is a no-op — implemented in FacilityManager bead.
    func resetAll() {
        // TODO(facility): Clear all tracking dictionaries
    }
}
