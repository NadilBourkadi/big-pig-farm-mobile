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

// MARK: - Play/Social Commitment Guard (Phase 6)

/// Returns true if the pig is playing or socializing (commitment managed,
/// caller stops further phases). Honors socializing-commitment counter to
/// prevent rapid partner-flipping; critical needs always override.
@MainActor
func behaviorHandlePlaySocialGuard(
    controller: BehaviorController, pig: inout GuineaPig
) -> Bool {
    let criticalNeed = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
        || pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
    let satisfactionThreshold = Double(GameConfig.Needs.satisfactionThreshold)
    if pig.behaviorState == .playing {
        if pig.needs.boredom > Double(GameConfig.Behavior.boredomKeepPlaying) {
            if criticalNeed {
                pig.logBehavior("Stopped playing (hunger/thirst critical)")
                pig.behaviorState = .idle; pig.targetDescription = nil
            } else { return true }
        }
    }
    if pig.behaviorState == .socializing {
        if criticalNeed {
            pig.logBehavior("Stopped socializing (hunger/thirst critical)")
            controller.clearSocializingCommitment(pig.id)
            pig.behaviorState = .idle; pig.targetDescription = nil
        } else if controller.getSocializingCommitment(pig.id) > 0 {
            // Stay committed regardless of social value or partner distance.
            controller.decrementSocializingCommitment(pig.id)
            return true
        } else if pig.needs.social < satisfactionThreshold {
            return true
        }
    }
    if pig.behaviorState == .playing || pig.behaviorState == .socializing {
        pig.logBehavior("Finished \(pig.behaviorState.rawValue), wandering away")
        if pig.behaviorState == .socializing {
            behaviorTrackSocialAffinity(controller: controller, pig: pig)
            controller.clearSocializingCommitment(pig.id)
        }
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
        return true
    }
    return false
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
