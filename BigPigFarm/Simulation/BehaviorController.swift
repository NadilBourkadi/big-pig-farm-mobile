/// BehaviorController — Coordinates pig AI behavior evaluation.
/// Maps from: simulation/behavior/controller.py
import Foundation

/// Owns the collision handler and facility manager; drives per-pig AI decisions.
@MainActor
final class BehaviorController {
    unowned let gameState: GameState
    let collision: CollisionHandler
    let facilityManager: FacilityManager

    /// Courtship pairs completed this tick: (maleID, femaleID).
    /// Drained by SimulationRunner after each tick.
    private var completedCourtships: [(UUID, UUID)] = []

    // MARK: - Per-pig tracking state

    private var decisionTimers: [UUID: Double] = [:]
    private var blockedTimers: [UUID: Double] = [:]
    private var stuckPositions: [UUID: GridPosition] = [:]
    private var stuckTimers: [UUID: Double] = [:]
    private var unreachableNeeds: [UUID: [String: Int]] = [:]

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
        decisionTimers.removeValue(forKey: pigId)
        blockedTimers.removeValue(forKey: pigId)
        stuckPositions.removeValue(forKey: pigId)
        stuckTimers.removeValue(forKey: pigId)
        unreachableNeeds.removeValue(forKey: pigId)
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

// MARK: - Blocked timer access

extension BehaviorController {
    func getBlockedTime(_ pigId: UUID) -> Double {
        blockedTimers[pigId] ?? 0.0
    }

    func setBlockedTime(_ pigId: UUID, _ time: Double) {
        blockedTimers[pigId] = time
    }

    /// Clear blocked time and any "(blocked)" annotations — call on successful movement.
    func resetBlockedState(_ pigId: UUID) {
        blockedTimers.removeValue(forKey: pigId)
    }
}

// MARK: - Stuck position tracking

extension BehaviorController {
    func getStuckPosition(_ pigId: UUID) -> GridPosition? {
        stuckPositions[pigId]
    }

    func setStuckPosition(_ pigId: UUID, _ position: GridPosition) {
        stuckPositions[pigId] = position
    }

    func getStuckTime(_ pigId: UUID) -> Double {
        stuckTimers[pigId] ?? 0.0
    }

    func setStuckTime(_ pigId: UUID, _ time: Double) {
        stuckTimers[pigId] = time
    }

    func clearStuckState(_ pigId: UUID) {
        stuckPositions.removeValue(forKey: pigId)
        stuckTimers.removeValue(forKey: pigId)
    }
}

// MARK: - Decision timer

extension BehaviorController {
    /// Reset a pig's decision timer so it re-evaluates on the next tick.
    func resetDecisionTimer(_ pigId: UUID) {
        decisionTimers.removeValue(forKey: pigId)
    }

    func getDecisionTimer(_ pigId: UUID) -> Double {
        decisionTimers[pigId] ?? 0.0
    }

    func setDecisionTimer(_ pigId: UUID, _ time: Double) {
        decisionTimers[pigId] = time
    }
}

// MARK: - Unreachable backoff

extension BehaviorController {
    /// How many decision cycles before this pig retries seeking this need.
    func getUnreachableBackoff(_ pigId: UUID, need: String) -> Int {
        unreachableNeeds[pigId]?[need] ?? 0
    }

    func setUnreachableBackoff(_ pigId: UUID, need: String, cycles: Int) {
        unreachableNeeds[pigId, default: [:]][need] = cycles
    }

    /// Decrement all backoff counters for a pig by 1, removing zeroed entries.
    func tickDownUnreachableBackoffs(_ pigId: UUID) {
        guard var needs = unreachableNeeds[pigId] else { return }
        for key in needs.keys {
            needs[key] = max(0, (needs[key] ?? 0) - 1)
            if needs[key] == 0 { needs.removeValue(forKey: key) }
        }
        unreachableNeeds[pigId] = needs.isEmpty ? nil : needs
    }

    func clearUnreachableBackoff(_ pigId: UUID) {
        unreachableNeeds.removeValue(forKey: pigId)
    }
}
