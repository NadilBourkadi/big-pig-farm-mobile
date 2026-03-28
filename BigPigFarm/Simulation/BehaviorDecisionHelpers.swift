/// BehaviorDecisionHelpers — Extracted utilities for BehaviorDecision (wander, campfire, social).
/// Split from BehaviorDecision.swift for file length compliance.
import Foundation

// MARK: - Default Wander (Phase 12)

@MainActor
func behaviorHandleDefaultWander(controller: BehaviorController, pig: inout GuineaPig) {
    if Double.random(in: 0..<1) < GameConfig.Behavior.wanderChance {
        pig.logBehavior("Nothing urgent, wandering")
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
        return
    }
    let driftRadius = GameConfig.Behavior.idleDriftRadius
    let nearby = controller.collision.spatialGrid.getNearby(
        x: pig.position.x, y: pig.position.y,
        pigs: controller.gameState.guineaPigs
    )
    let hasNearbyPig = nearby.contains {
        guard $0.id != pig.id else { return false }
        let dx = pig.position.x - $0.position.x
        let dy = pig.position.y - $0.position.y
        return dx * dx + dy * dy <= driftRadius * driftRadius
    }
    if hasNearbyPig {
        pig.logBehavior("Too close to another pig, drifting away")
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
    } else {
        pig.logBehavior("Nothing urgent, idling")
        pig.behaviorState = .idle
        pig.targetPosition = nil; pig.targetFacilityId = nil
        pig.targetDescription = nil; pig.path = []
    }
}

// MARK: - Social Affinity Tracking

/// Increment social affinity between `pig` and any nearby socializing pigs.
@MainActor
func behaviorTrackSocialAffinity(controller: BehaviorController, pig: GuineaPig) {
    let thresholdSq = (GameConfig.Behavior.minPigDistance + 2.0)
        * (GameConfig.Behavior.minPigDistance + 2.0)
    let nearby = controller.collision.spatialGrid.getNearby(
        x: pig.position.x, y: pig.position.y,
        pigs: controller.gameState.guineaPigs
    )
    for other in nearby where other.id != pig.id && other.behaviorState == .socializing {
        let dx = pig.position.x - other.position.x
        let dy = pig.position.y - other.position.y
        if dx * dx + dy * dy <= thresholdSq {
            controller.gameState.incrementAffinity(pig.id, other.id)
        }
    }
}

// MARK: - Campfire Attraction

/// At night, try to route an idle/wandering pig to a nearby campfire.
@MainActor
func behaviorTryCampfireAttraction(controller: BehaviorController, pig: inout GuineaPig) {
    guard pig.targetFacilityId == nil, pig.path.isEmpty else { return }
    let campfires = controller.gameState.getFacilitiesByType(.campfire)
    guard !campfires.isEmpty else { return }
    let attractionRadiusSq = GameConfig.Behavior.campfireAttractionRadius
        * GameConfig.Behavior.campfireAttractionRadius
    for campfire in campfires {
        let centerX = Double(campfire.positionX) + Double(campfire.width) / 2.0
        let centerY = Double(campfire.positionY) + Double(campfire.height) / 2.0
        let dx = pig.position.x - centerX
        let dy = pig.position.y - centerY
        guard dx * dx + dy * dy <= attractionRadiusSq else { continue }
        guard let (point, path) = controller.facilityManager.findOpenInteractionPoint(
            pig: pig, facility: campfire
        ) else { continue }
        var trimmedPath = path
        if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
        pig.logBehavior("Drawn to \(campfire.name) at night")
        pig.path = trimmedPath
        pig.behaviorState = .wandering
        pig.targetFacilityId = campfire.id
        pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
        pig.targetDescription = "going to campfire"
        return
    }
}
