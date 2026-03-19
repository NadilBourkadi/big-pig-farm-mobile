/// BehaviorDecision — Priority-based decision tree for pig behavior.
/// Maps from: simulation/behavior/decision.py
import Foundation

/// Evaluates need priorities and selects the next behavior state.
/// Caseless enum used as a namespace for static functions — cannot be instantiated.
enum BehaviorDecision {

    // MARK: - Public API

    /// Check if a pig is content (all needs satisfied, idle/wandering, no facility target).
    /// Content pigs use an 8-second decision interval instead of 2 seconds.
    static func isContent(_ pig: GuineaPig) -> Bool {
        guard pig.behaviorState == .idle || pig.behaviorState == .wandering else { return false }
        guard pig.targetFacilityId == nil else { return false }
        let needs = pig.needs
        let high = Double(GameConfig.Needs.highThreshold)
        return needs.hunger >= high
            && needs.thirst >= high
            && needs.energy >= high
            && needs.happiness >= high
            && needs.social >= high
            && needs.boredom < Double(GameConfig.Behavior.boredomPlayThreshold)
    }

    /// Evaluate the 12-phase priority-based decision tree and commit the pig to a behavior.
    /// Called by BehaviorController.update() when the decision timer expires.
    @MainActor
    static func makeDecision(controller: BehaviorController, pig: inout GuineaPig) {
        let oldState = pig.behaviorState
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        defer {
            if pig.behaviorState != oldState {
                DebugLogger.shared.log(
                    category: .behavior, level: .info,
                    message: "\(pig.name): \(oldState.rawValue) -> \(pig.behaviorState.rawValue)",
                    pigId: pig.id, pigName: pig.name,
                    payload: [
                        "fromState": oldState.rawValue,
                        "toState": pig.behaviorState.rawValue,
                        "trigger": pig.targetDescription ?? "decision",
                    ]
                )
            }
        }
        #endif
        if shouldKeepTraveling(controller: controller, pig: &pig) { return }
        cleanupTargetState(controller: controller, pig: &pig)
        if handleSleepGuard(pig: &pig) { return }
        if handleCourtGuard(controller: controller, pig: &pig) { return }
        if handleCommitmentGuard(controller: controller, pig: &pig) { return }
        if handlePlaySocialGuard(controller: controller, pig: &pig) { return }
        controller.tickDownUnreachableBackoffs(pig.id)
        if handleUrgentNeed(controller: controller, pig: &pig) { return }
        if handleLowPriorityBehaviors(controller: controller, pig: &pig) { return }
        if handleNighttimeCampfire(controller: controller, pig: &pig) { return }
        handleDefaultWander(controller: controller, pig: &pig)
    }

    // MARK: - Phase 1 — Travel Validation

    /// Returns true if the pig should keep traveling (facility is still valid).
    /// Returns false to continue re-deciding — either facility was consumed/removed, or pig wasn't traveling.
    @MainActor
    private static func shouldKeepTraveling(controller: BehaviorController, pig: inout GuineaPig) -> Bool {
        guard pig.behaviorState == .wandering, !pig.path.isEmpty,
              let targetId = pig.targetFacilityId else { return false }
        if let facility = controller.gameState.getFacility(targetId) {
            let consumable: Set<FacilityType> = [.foodBowl, .waterBottle, .hayRack, .feastTable]
            if consumable.contains(facility.facilityType), facility.isEmpty {
                controller.facilityManager.addFailedFacility(pig.id, facility.id)
                pig.path = []; pig.targetPosition = nil; pig.targetFacilityId = nil
            } else {
                return true // Non-consumable or still has resources — keep traveling
            }
        } else {
            // Facility was removed
            pig.path = []; pig.targetPosition = nil; pig.targetFacilityId = nil
        }
        return false
    }

    // MARK: - Phase 2 — Target Cleanup

    @MainActor
    private static func cleanupTargetState(controller: BehaviorController, pig: inout GuineaPig) {
        if pig.targetFacilityId != nil, pig.path.isEmpty {
            pig.targetFacilityId = nil
            pig.targetDescription = nil
        } else if controller.facilityManager.getFailedCooldown(pig.id) > 0 {
            controller.facilityManager.tickFailedCooldown(pig.id)
        } else {
            controller.facilityManager.clearFailedFacilities(pig.id)
        }
    }

    // MARK: - Phase 3 — Guard: Sleeping

    /// Returns true if the pig is sleeping (keeps handling in sleep guard, stops further phases).
    private static func handleSleepGuard(pig: inout GuineaPig) -> Bool {
        guard pig.behaviorState == .sleeping else { return false }
        if pig.needs.energy >= Double(GameConfig.Needs.satisfactionThreshold) {
            pig.behaviorState = .idle; pig.targetDescription = nil; return true
        }
        let criticalHunger = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
        let criticalThirst = pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
        if criticalHunger || criticalThirst,
           pig.needs.energy >= Double(GameConfig.Behavior.emergencyWakeEnergy) {
            pig.behaviorState = .idle; pig.targetDescription = nil; return true
        }
        return true // Keep sleeping
    }

    // MARK: - Phase 4 — Guard: Courting

    /// Returns true if the pig is courting (courtship is managed here, stops further phases).
    @MainActor
    private static func handleCourtGuard(controller: BehaviorController, pig: inout GuineaPig) -> Bool {
        guard pig.behaviorState == .courting else { return false }
        guard let partnerId = pig.courtingPartnerId,
              let partner = controller.gameState.getGuineaPig(partnerId),
              partner.behaviorState == .courting else {
            Breeding.clearCourtship(pig: &pig); return true
        }
        let criticalNeed = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
            || pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
        if criticalNeed {
            if var updatedPartner = controller.gameState.getGuineaPig(partnerId) {
                Breeding.clearCourtship(pig: &updatedPartner)
                controller.gameState.updateGuineaPig(updatedPartner)
            }
            Breeding.clearCourtship(pig: &pig); return true
        }
        if pig.courtingInitiator, pig.path.isEmpty {
            BehaviorSeeking.seekCourtingPartner(controller: controller, pig: &pig, partner: partner)
        }
        return true // Stay in courting state
    }

    // MARK: - Phase 5 — Guard: Eating/Drinking Commitment

    /// Returns true if the pig is eating or drinking (commitment handled, stops further phases).
    @MainActor
    private static func handleCommitmentGuard(
        controller: BehaviorController, pig: inout GuineaPig
    ) -> Bool {
        let satisfactionThreshold = Double(GameConfig.Needs.satisfactionThreshold)
        if pig.behaviorState == .eating {
            if pig.needs.hunger < satisfactionThreshold { return true }
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return true
        }
        if pig.behaviorState == .drinking {
            if pig.needs.thirst < satisfactionThreshold { return true }
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return true
        }
        return false
    }

    // MARK: - Phase 6 — Guard: Playing/Socializing Commitment

    /// Returns true if the pig is playing or socializing (commitment managed, stops further phases).
    @MainActor
    private static func handlePlaySocialGuard(
        controller: BehaviorController, pig: inout GuineaPig
    ) -> Bool {
        let criticalNeed = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
            || pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
        let satisfactionThreshold = Double(GameConfig.Needs.satisfactionThreshold)
        if pig.behaviorState == .playing {
            if pig.needs.boredom > Double(GameConfig.Behavior.boredomKeepPlaying) {
                if criticalNeed { pig.behaviorState = .idle; pig.targetDescription = nil } else { return true }
            }
        }
        if pig.behaviorState == .socializing {
            if pig.needs.social < satisfactionThreshold {
                if criticalNeed { pig.behaviorState = .idle; pig.targetDescription = nil } else { return true }
            }
        }
        if pig.behaviorState == .playing || pig.behaviorState == .socializing {
            if pig.behaviorState == .socializing { trackSocialAffinity(controller: controller, pig: pig) }
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return true
        }
        return false
    }

    // MARK: - Phase 8 — Urgent Need Evaluation

    /// Returns true if an urgent need was addressed (stops further phases).
    @MainActor
    private static func handleUrgentNeed(controller: BehaviorController, pig: inout GuineaPig) -> Bool {
        let criticalThreshold = Double(GameConfig.Needs.criticalThreshold)
        let sleepThreshold = Double(GameConfig.Behavior.energySleepThreshold)
        let urgentNeed = NeedsSystem.getMostUrgentNeed(pig)
        switch urgentNeed {
        case "energy" where pig.needs.energy < sleepThreshold:
            if pig.needs.happiness < criticalThreshold, pig.needs.energy >= criticalThreshold {
                BehaviorSeeking.seekPlay(controller: controller, pig: &pig)
            } else {
                BehaviorSeeking.seekSleep(controller: controller, pig: &pig)
            }
            return true
        case "hunger", "thirst":
            BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: urgentNeed)
            return true
        case "happiness":
            BehaviorSeeking.seekPlay(controller: controller, pig: &pig); return true
        case "social" where !pig.hasTrait(.shy):
            BehaviorSeeking.seekSocialInteraction(controller: controller, pig: &pig); return true
        default:
            return false
        }
    }

    // MARK: - Phases 9 + 10 — Boredom and Personality Defaults

    /// Returns true if boredom or personality trait triggered a behavior (stops further phases).
    @MainActor
    private static func handleLowPriorityBehaviors(
        controller: BehaviorController, pig: inout GuineaPig
    ) -> Bool {
        if pig.needs.boredom > Double(GameConfig.Behavior.boredomPlayThreshold) {
            BehaviorSeeking.seekPlay(controller: controller, pig: &pig); return true
        }
        if pig.hasTrait(.lazy), Double.random(in: 0..<1) < GameConfig.Behavior.lazySleepChance {
            BehaviorSeeking.seekSleep(controller: controller, pig: &pig); return true
        }
        if pig.hasTrait(.playful), Double.random(in: 0..<1) < GameConfig.Behavior.playfulPlayChance {
            BehaviorSeeking.seekPlay(controller: controller, pig: &pig); return true
        }
        if pig.hasTrait(.social), Double.random(in: 0..<1) < GameConfig.Behavior.socialSocializeChance {
            BehaviorSeeking.seekSocialInteraction(controller: controller, pig: &pig); return true
        }
        return false
    }

    // MARK: - Phase 11 — Nighttime Campfire Attraction

    /// Returns true if the pig was routed to a campfire (stops further phases).
    @MainActor
    private static func handleNighttimeCampfire(
        controller: BehaviorController, pig: inout GuineaPig
    ) -> Bool {
        guard !controller.gameState.gameTime.isDaytime else { return false }
        tryCampfireAttraction(controller: controller, pig: &pig)
        return pig.targetFacilityId != nil
    }

    // MARK: - Phase 12 — Random Wandering or Idle

    @MainActor
    private static func handleDefaultWander(controller: BehaviorController, pig: inout GuineaPig) {
        if Double.random(in: 0..<1) < GameConfig.Behavior.wanderChance {
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
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
        } else {
            pig.behaviorState = .idle
            pig.targetPosition = nil; pig.targetFacilityId = nil
            pig.targetDescription = nil; pig.path = []
        }
    }

    // MARK: - Private Phase Helpers (call file-private utilities below)

    @MainActor
    private static func trackSocialAffinity(controller: BehaviorController, pig: GuineaPig) {
        behaviorTrackSocialAffinity(controller: controller, pig: pig)
    }

    @MainActor
    private static func tryCampfireAttraction(controller: BehaviorController, pig: inout GuineaPig) {
        behaviorTryCampfireAttraction(controller: controller, pig: &pig)
    }
}

// MARK: - File-Private Utility Functions

/// Increment social affinity between `pig` and any nearby socializing pigs.
@MainActor
private func behaviorTrackSocialAffinity(controller: BehaviorController, pig: GuineaPig) {
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

/// At night, try to route an idle/wandering pig to a nearby campfire.
@MainActor
private func behaviorTryCampfireAttraction(controller: BehaviorController, pig: inout GuineaPig) {
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
        pig.path = trimmedPath
        pig.behaviorState = .wandering
        pig.targetFacilityId = campfire.id
        pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
        pig.targetDescription = "going to campfire"
        return
    }
}
