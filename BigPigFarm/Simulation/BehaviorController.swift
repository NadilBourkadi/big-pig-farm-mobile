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

    private var lastGridGeneration: Int = 0
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
        // Invalidate unreachable caches when the farm layout changes
        let gridGen = gameState.farm.gridGeneration
        if gridGen != lastGridGeneration {
            unreachableNeeds.removeAll()
            lastGridGeneration = gridGen
        }

        // Decision timer — stagger initial evaluation with a random offset to spread CPU load
        let timer = decisionTimers[pig.id] ?? Double.random(in: 0..<1)
        let newTimer = timer + gameMinutes

        let criticalThreshold = Double(GameConfig.Needs.criticalThreshold)
        let interval: Double
        if pig.needs.hunger < criticalThreshold || pig.needs.thirst < criticalThreshold {
            interval = 0.0 // Emergency: evaluate every tick
        } else if BehaviorDecision.isContent(pig) {
            interval = GameConfig.Behavior.contentDecisionInterval
        } else {
            interval = GameConfig.Simulation.decisionIntervalSeconds
        }

        var adjustedTimer = newTimer
        if newTimer >= interval {
            BehaviorDecision.makeDecision(controller: self, pig: &pig)
            // Emergency pigs (interval=0) re-fire on the very next tick regardless of this jitter
            adjustedTimer = Double.random(in: 0..<GameConfig.Simulation.decisionIntervalSeconds / 4)
        }
        decisionTimers[pig.id] = adjustedTimer

        BehaviorMovement.updateMovement(controller: self, pig: &pig, gameMinutes: gameMinutes)
        BehaviorMovement.clampToBounds(controller: self, pig: &pig)

        if !gameState.farm.isWalkable(Int(pig.position.x), Int(pig.position.y)) {
            BehaviorMovement.rescueToWalkable(controller: self, pig: &pig)
        }

        // Clear unreachable backoff when the pig moves to a new farm area
        let newAreaId = gameState.farm.getAreaAt(Int(pig.position.x), Int(pig.position.y))?.id
        if newAreaId != pig.currentAreaId {
            clearUnreachableBackoff(pig.id)
        }
        pig.currentAreaId = newAreaId

        updateCurrentBehavior(pig: &pig, gameMinutes: gameMinutes)
    }

    /// Remove all per-pig tracking state for a pig that has died or been sold.
    /// Also cancels courtship on any pig that was paired with the removed pig.
    func cleanupDeadPig(_ pigId: UUID) {
        decisionTimers.removeValue(forKey: pigId)
        blockedTimers.removeValue(forKey: pigId)
        stuckPositions.removeValue(forKey: pigId)
        stuckTimers.removeValue(forKey: pigId)
        unreachableNeeds.removeValue(forKey: pigId)
        facilityManager.cleanupPig(pigId)
        for var pig in gameState.getPigsList() where pig.courtingPartnerId == pigId {
            Breeding.clearCourtship(pig: &pig)
            gameState.updateGuineaPig(pig)
        }
    }

    /// Reset all tracking state — call on new game or game reset.
    func resetAllTracking() {
        decisionTimers.removeAll()
        blockedTimers.removeAll()
        stuckPositions.removeAll()
        stuckTimers.removeAll()
        unreachableNeeds.removeAll()
        facilityManager.resetAll()
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

// MARK: - Per-tick Behavior Update

extension BehaviorController {
    /// Apply state transitions for a pig that has just arrived at a facility,
    /// advance the courtship timer when adjacent to a partner, and consume
    /// resources from any facility the pig is currently using.
    private func updateCurrentBehavior(pig: inout GuineaPig, gameMinutes: Double) {
        // Arrived at targeted facility (wandering, path consumed, facility target set)
        if pig.behaviorState == .wandering, pig.path.isEmpty, pig.targetFacilityId != nil {
            blockedTimers.removeValue(forKey: pig.id)
            stuckPositions.removeValue(forKey: pig.id)
            stuckTimers.removeValue(forKey: pig.id)
            facilityManager.checkArrivedAtFacility(pig: &pig)
        }

        // Courting: advance together-timer when the initiator is adjacent to partner
        if pig.behaviorState == .courting, pig.path.isEmpty, pig.courtingInitiator,
           let partnerId = pig.courtingPartnerId,
           let partner = gameState.getGuineaPig(partnerId),
           partner.behaviorState == .courting {
            let dist = pig.position.distanceTo(partner.position)
            if dist <= GameConfig.Behavior.minPigDistance + 2.0 {
                let prevTimer = pig.courtingTimer
                pig.courtingTimer += gameMinutes
                var updatedPartner = partner
                updatedPartner.courtingTimer = pig.courtingTimer
                let boostPerMinute = GameConfig.Behavior.courtshipHappinessBoost * (gameMinutes / 60.0)
                pig.needs.happiness = min(100.0, pig.needs.happiness + boostPerMinute)
                updatedPartner.needs.happiness = min(100.0, updatedPartner.needs.happiness + boostPerMinute)
                gameState.updateGuineaPig(updatedPartner)
                if pig.courtingTimer >= GameConfig.Behavior.courtshipTogetherSeconds
                    && prevTimer < GameConfig.Behavior.courtshipTogetherSeconds {
                    completedCourtships.append((pig.id, partnerId))
                }
            }
        }

        // Consuming resources at a facility (eating, drinking, sleeping, playing)
        let isConsuming = pig.behaviorState == .eating || pig.behaviorState == .drinking
            || pig.behaviorState == .sleeping || pig.behaviorState == .playing
        if isConsuming, pig.path.isEmpty {
            facilityManager.consumeFromNearbyFacility(pig: &pig, gameMinutes: gameMinutes)
        }
    }
}
