/// BehaviorMovement — Movement, wandering, and obstacle avoidance.
/// Maps from: simulation/behavior/movement.py
import Foundation

/// Bundles speed and elapsed game-minutes to avoid 6-parameter functions.
private struct MovementTick {
    let speed: Double
    let gameMinutes: Double
}

/// Handles pig movement along paths and biome-biased wandering.
/// Caseless enum used as a namespace for static functions — cannot be instantiated.
/// Biome wander helpers live in BehaviorMovementBiome.swift.
enum BehaviorMovement {

    // MARK: - Public API

    /// Advance a pig along its current waypoint path this tick.
    ///
    /// Computes a speed-scaled movement budget and consumes waypoints until it runs
    /// out. Skips sleeping pigs. Calls `handleMovementBlocked` on obstruction.
    @MainActor
    static func updateMovement(
        controller: BehaviorController,
        pig: inout GuineaPig,
        gameMinutes: Double
    ) {
        guard pig.behaviorState != .sleeping, !pig.path.isEmpty else { return }
        let tick = MovementTick(speed: computeSpeed(controller: controller, pig: pig), gameMinutes: gameMinutes)
        let moved = advancePath(controller: controller, pig: &pig, tick: tick)
        if moved {
            if let desc = pig.targetDescription, desc.hasSuffix(" (blocked)") {
                pig.targetDescription = String(desc.dropLast(" (blocked)".count))
            }
            controller.resetBlockedState(pig.id)
        }
        if pig.path.isEmpty { pig.targetPosition = nil }
    }

    /// Clamp pig position to the walkable interior (one cell inside walls).
    @MainActor
    static func clampToBounds(controller: BehaviorController, pig: inout GuineaPig) {
        let farm = controller.gameState.farm
        pig.position.x = max(1.0, min(Double(farm.width - 2), pig.position.x))
        pig.position.y = max(1.0, min(Double(farm.height - 2), pig.position.y))
    }

    /// Begin a wandering movement for a pig.
    ///
    /// Priority: (1) A* biome homing when pig has a color-matched area and is outside it,
    /// (2) biome-biased straight-line wander, (3) unbiased wander, (4) rescue to walkable.
    @MainActor
    static func startWandering(controller: BehaviorController, pig: inout GuineaPig) {
        let (targetArea, isColorMatch) = getBiomeWanderTarget(controller: controller, pig: pig)
        let pigGx = Int(pig.position.x)
        let pigGy = Int(pig.position.y)

        if let area = targetArea, isColorMatch,
           !area.containsInterior(x: pigGx, y: pigGy),
           Double.random(in: 0..<1) < GameConfig.Behavior.biomeHomingChance,
           let homeTarget = controller.gameState.farm.findRandomWalkableInArea(area.id) {
            setPathTo(controller: controller, pig: &pig, target: homeTarget)
            if !pig.path.isEmpty {
                pig.behaviorState = .wandering
                pig.targetDescription = nil
                return
            }
        }

        let farm = controller.gameState.farm
        let minSteps = GameConfig.Behavior.simpleWanderMinSteps
        let maxSteps = GameConfig.Behavior.simpleWanderMaxSteps
        for (dx, dy) in wanderDirections(pig: pig, targetArea: targetArea) {
            var path: [GridPosition] = []
            for step in 1...maxSteps {
                let nx = pigGx + dx * step
                let ny = pigGy + dy * step
                guard farm.isWalkable(nx, ny) else { break }
                path.append(GridPosition(x: nx, y: ny))
            }
            if path.count >= minSteps {
                pig.path = path
                // Safe: path.count >= minSteps guarantees non-empty
                // swiftlint:disable:next force_unwrapping
                pig.targetPosition = Position(x: Double(path.last!.x), y: Double(path.last!.y))
                pig.targetDescription = nil
                pig.behaviorState = .wandering
                return
            }
        }

        rescueToWalkable(controller: controller, pig: &pig)
        pig.behaviorState = .wandering
    }

    /// Compute and set an A* path from the pig's current position to `target`.
    ///
    /// Drops the start position from the result (pig is already there).
    /// Leaves `pig.path` empty if no path exists.
    @MainActor
    static func setPathTo(
        controller: BehaviorController,
        pig: inout GuineaPig,
        target: GridPosition
    ) {
        let start = pig.position.gridPosition
        var path = controller.facilityManager.cachedFindPath(from: start, to: target)
        if path.first == start { path.removeFirst() }
        pig.path = path
        if !path.isEmpty { pig.targetPosition = Position(x: Double(target.x), y: Double(target.y)) }
    }

    /// Teleport a pig to a safe walkable cell, resetting all movement state.
    ///
    /// Prefers the pig's current area, then falls back to any walkable cell.
    @MainActor
    static func rescueToWalkable(controller: BehaviorController, pig: inout GuineaPig) {
        pig.path = []
        pig.targetPosition = nil
        pig.targetFacilityId = nil
        pig.targetDescription = nil
        pig.behaviorState = .idle
        if let areaId = pig.currentAreaId,
           let safe = controller.gameState.farm.findRandomWalkableInArea(areaId) {
            pig.position = Position(x: Double(safe.x), y: Double(safe.y))
            return
        }
        if let safe = controller.gameState.farm.findRandomWalkable() {
            pig.position = Position(x: Double(safe.x), y: Double(safe.y))
        }
    }
}

// MARK: - Private Movement Helpers

private extension BehaviorMovement {

    @MainActor
    static func computeSpeed(controller: BehaviorController, pig: GuineaPig) -> Double {
        var speed = GameConfig.Simulation.baseMoveSpeed
        if controller.gameState.hasUpgrade("express_lanes") {
            speed *= 1.5
        } else if controller.gameState.hasUpgrade("paved_paths") {
            speed *= 1.2
        }
        if pig.needs.energy < Double(GameConfig.Behavior.energySleepThreshold) {
            speed *= GameConfig.Behavior.tiredSpeedMult
        }
        if pig.isBaby { speed *= GameConfig.Behavior.babySpeedMult }
        return speed
    }

    /// Consume waypoints until the movement budget runs out. Returns true if pig moved.
    @MainActor
    static func advancePath(
        controller: BehaviorController,
        pig: inout GuineaPig,
        tick: MovementTick
    ) -> Bool {
        var remaining = tick.speed * tick.gameMinutes
        var moved = false
        while !pig.path.isEmpty, remaining > 0 {
            let waypoint = pig.path[0]
            let wx = Double(waypoint.x)
            let wy = Double(waypoint.y)
            let dx = wx - pig.position.x
            let dy = wy - pig.position.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < GameConfig.Behavior.waypointReached {
                if !controller.collision.isPositionBlocked(targetX: wx, targetY: wy, excludePig: pig) {
                    pig.position = Position(x: wx, y: wy)
                    pig.path.removeFirst()
                    moved = true
                }
                break
            }
            if remaining >= dist {
                if !controller.collision.isPositionBlocked(targetX: wx, targetY: wy, excludePig: pig) {
                    pig.position = Position(x: wx, y: wy)
                    pig.path.removeFirst()
                    remaining -= dist
                    moved = true
                } else {
                    handleMovementBlocked(controller: controller, pig: &pig, dx: dx, dy: dy, tick: tick)
                    break
                }
            } else {
                let nx = pig.position.x + (dx / dist) * remaining
                let ny = pig.position.y + (dy / dist) * remaining
                if controller.gameState.farm.isWalkable(Int(nx), Int(ny)) &&
                    !controller.collision.isPositionBlocked(targetX: nx, targetY: ny, excludePig: pig) {
                    pig.position = Position(x: nx, y: ny)
                    moved = true
                } else {
                    handleMovementBlocked(controller: controller, pig: &pig, dx: dx, dy: dy, tick: tick)
                }
                break
            }
        }
        return moved
    }

    @MainActor
    static func tryDodge(
        controller: BehaviorController,
        pig: inout GuineaPig,
        dx: Double, dy: Double,
        tick: MovementTick
    ) -> Bool {
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > GameConfig.Behavior.pathVectorEpsilon else { return false }
        let moveDist = min(tick.speed * tick.gameMinutes, GameConfig.Behavior.dodgeMaxStep)
        for (pdx, pdy) in [(-dy / length, dx / length), (dy / length, -dx / length)] {
            let nx = pig.position.x + pdx * moveDist
            let ny = pig.position.y + pdy * moveDist
            if controller.gameState.farm.isWalkable(Int(nx), Int(ny)) &&
                !controller.collision.isPositionBlocked(targetX: nx, targetY: ny, excludePig: pig) {
                pig.position = Position(x: nx, y: ny)
                return true
            }
        }
        return false
    }

    @MainActor
    static func handleMovementBlocked(
        controller: BehaviorController,
        pig: inout GuineaPig,
        dx: Double, dy: Double,
        tick: MovementTick
    ) {
        if tryDodge(controller: controller, pig: &pig, dx: dx, dy: dy, tick: tick) {
            controller.resetBlockedState(pig.id)
            return
        }
        let newBlockedTime = controller.getBlockedTime(pig.id) + tick.gameMinutes
        controller.setBlockedTime(pig.id, newBlockedTime)
        let currentCell = pig.position.gridPosition
        if let lastStuck = controller.getStuckPosition(pig.id), lastStuck == currentCell {
            controller.setStuckTime(pig.id, controller.getStuckTime(pig.id) + tick.gameMinutes)
        } else {
            controller.setStuckPosition(pig.id, currentCell)
            controller.setStuckTime(pig.id, 0.0)
        }
        if let desc = pig.targetDescription, !desc.hasSuffix(" (blocked)") {
            pig.targetDescription = desc + " (blocked)"
        }
        if newBlockedTime >= GameConfig.Behavior.blockedTimeAlternative, pig.targetPosition != nil {
            if controller.facilityManager.tryAlternativeFacility(pig: &pig) {
                controller.resetBlockedState(pig.id)
                return
            }
        }
        if controller.getStuckTime(pig.id) >= GameConfig.Behavior.blockedTimeGiveUp {
            giveUpAndFallback(controller: controller, pig: &pig)
        }
    }

    @MainActor
    static func giveUpAndFallback(controller: BehaviorController, pig: inout GuineaPig) {
        let description = pig.targetDescription ?? ""
        pig.path = []
        pig.targetPosition = nil
        pig.targetFacilityId = nil
        pig.targetDescription = nil
        controller.resetBlockedState(pig.id)
        controller.clearStuckState(pig.id)
        let isCritical = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
            || pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
        controller.facilityManager.setFailedCooldown(
            pig.id,
            isCritical
                ? GameConfig.Behavior.criticalFailedCooldownCycles
                : GameConfig.Behavior.failedCooldownCycles
        )
        if description.contains("Hideout") || description.localizedCaseInsensitiveContains("sleep") {
            pig.behaviorState = .sleeping
            pig.targetDescription = "sleeping (no hideout available)"
        } else {
            pig.behaviorState = .idle
            startWandering(controller: controller, pig: &pig)
            controller.resetDecisionTimer(pig.id)
        }
    }
}
