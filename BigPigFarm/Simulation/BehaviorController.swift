/// BehaviorController — Coordinates pig AI behavior evaluation.
/// Maps from: simulation/behavior/controller.py
import Foundation

/// Owns the collision handler and facility manager; drives per-pig AI decisions.
@MainActor
final class BehaviorController {
    private unowned let gameState: GameState
    let collision: CollisionHandler
    let facilityManager: FacilityManager

    /// Courtship pairs completed this tick: (maleID, femaleID).
    /// Drained by SimulationRunner after each tick.
    private var completedCourtships: [(UUID, UUID)] = []

    init(gameState: GameState) {
        self.gameState = gameState
        let col = CollisionHandler(gameState: gameState)
        self.collision = col
        self.facilityManager = FacilityManager(gameState: gameState, collision: col)
    }

    /// Evaluate and apply one AI decision step for a single pig.
    func update(pig: inout GuineaPig, gameMinutes: Double) {
        // TODO(behavior): Implement full decision tree + movement
    }

    /// Remove all per-pig tracking state for a pig that has died or been sold.
    func cleanupDeadPig(_ pigId: UUID) {
        // TODO(behavior): Remove decision timers, block timers, etc.
    }

    /// Resolve all overlapping pig positions by applying separation forces.
    func separateOverlappingPigs() {
        collision.separateOverlappingPigs()
    }

    /// Teleport any pig standing on a non-walkable cell to the nearest walkable cell.
    func rescueNonWalkablePigs(_ pigs: [GuineaPig]) {
        collision.rescueNonWalkablePigs(pigs)
    }

    /// Return and clear all courtships completed this tick.
    func drainCompletedCourtships() -> [(UUID, UUID)] {
        defer { completedCourtships.removeAll() }
        return completedCourtships
    }
}
