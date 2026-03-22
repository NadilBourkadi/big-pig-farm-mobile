/// BehaviorSeeking — Facility scoring and social seeking behavior.
/// Maps from: simulation/behavior/seeking.py
import Foundation

/// Finds facilities, social targets, and courting partners for pig AI.
/// Caseless enum used as a namespace for static functions — cannot be instantiated.
enum BehaviorSeeking {

    // MARK: - Public API

    /// Seek a facility that addresses the given need name.
    ///
    /// Checks unreachable backoff first. If no facility is reachable, sets backoff
    /// (critical: 2 cycles, normal: 5 cycles) and falls back to wandering.
    @MainActor
    static func seekFacilityForNeed(
        controller: BehaviorController,
        pig: inout GuineaPig,
        need: String
    ) {
        let backoff = controller.getUnreachableBackoff(pig.id, need: need)
        if backoff > 0 {
            #if (DEBUG || INTERNAL) && canImport(UIKit)
            logSeekBackoff(pig: pig, need: need, backoff: backoff)
            #endif
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return
        }

        guard let facilityTypes = NeedsSystem.getTargetFacilityForNeed(need) else {
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return
        }

        for facilityType in facilityTypes {
            let candidates = controller.facilityManager.getCandidateFacilitiesRanked(
                pig: pig, facilityType: facilityType
            )
            for facility in candidates.prefix(GameConfig.Behavior.maxFacilityCandidates) {
                guard let (point, path) = controller.facilityManager.findOpenInteractionPoint(
                    pig: pig, facility: facility
                ) else { continue }
                var trimmedPath = path
                if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
                // Dispatch even when trimmedPath is empty (pig is at the interaction point).
                // The arrival handler fires in the same tick when path is empty + targetFacilityId is set.
                pig.path = trimmedPath
                pig.behaviorState = .wandering
                pig.targetFacilityId = facility.id
                pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
                pig.targetDescription = "going to \(facility.name)"
                #if (DEBUG || INTERNAL) && canImport(UIKit)
                logSeekDispatch(pig: pig, need: need, facility: facility)
                #endif
                return
            }
        }

        // No reachable facility — set backoff and wander
        let isCritical = getNeedValue(pig, need: need) < Double(GameConfig.Needs.criticalThreshold)
        let cycles = isCritical
            ? GameConfig.Behavior.unreachableCriticalCycles
            : GameConfig.Behavior.unreachableBackoffCycles
        controller.setUnreachableBackoff(pig.id, need: need, cycles: cycles)
        // Match cooldown to backoff duration so the failed set outlives the backoff
        controller.facilityManager.setFailedCooldown(pig.id, cycles)
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        logSeekFailure(pig: pig, need: need, isCritical: isCritical, cycles: cycles)
        #endif
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
    }

    /// Seek a sleep facility (hideout or hot spring).
    ///
    /// If no facility is reachable, the pig sleeps where it currently stands.
    @MainActor
    static func seekSleep(controller: BehaviorController, pig: inout GuineaPig) {
        for facilityType: FacilityType in [.hideout, .hotSpring] {
            let candidates = controller.facilityManager.getCandidateFacilitiesRanked(
                pig: pig, facilityType: facilityType
            )
            for facility in candidates.prefix(GameConfig.Behavior.maxFacilityCandidates) {
                guard let (point, path) = controller.facilityManager.findOpenInteractionPoint(
                    pig: pig, facility: facility
                ) else { continue }
                var trimmedPath = path
                if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
                pig.path = trimmedPath
                pig.behaviorState = .wandering
                pig.targetFacilityId = facility.id
                pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
                pig.targetDescription = "going to \(facility.name)"
                return
            }
        }

        // No reachable hideout — sleep in place
        pig.path = []
        pig.targetPosition = nil
        pig.targetFacilityId = nil
        pig.targetDescription = "sleeping"
        pig.behaviorState = .sleeping
    }

    /// Seek a play facility. Falls back to socializing (if not shy) then playful wandering.
    @MainActor
    static func seekPlay(controller: BehaviorController, pig: inout GuineaPig) {
        var playTypes: [FacilityType] = [.exerciseWheel, .playArea, .tunnel, .stage]
        // Therapy garden is only sought when the pig is deeply unhappy — it is a
        // last-resort happiness booster, not a normal play destination.
        if pig.needs.happiness < 50 { playTypes.append(.therapyGarden) }

        for facilityType in playTypes {
            let candidates = controller.facilityManager.getCandidateFacilitiesRanked(
                pig: pig, facilityType: facilityType
            )
            for facility in candidates.prefix(GameConfig.Behavior.maxFacilityCandidates) {
                guard let (point, path) = controller.facilityManager.findOpenInteractionPoint(
                    pig: pig, facility: facility
                ) else { continue }
                var trimmedPath = path
                if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
                pig.path = trimmedPath
                pig.behaviorState = .wandering
                pig.targetFacilityId = facility.id
                pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
                pig.targetDescription = "going to \(facility.name)"
                return
            }
        }

        // Fallback: socialize if social need is low and pig is not shy
        if pig.needs.social < Double(GameConfig.Needs.highThreshold), !pig.hasTrait(.shy) {
            seekSocialInteraction(controller: controller, pig: &pig)
            return
        }

        // Last resort: playful wandering
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
        if Double.random(in: 0..<1) < GameConfig.Behavior.noPlayFacilityPlayChance {
            pig.behaviorState = .playing
            pig.targetDescription = "playing around"
        }
    }

    /// Find the nearest pig to socialize with.
    ///
    /// At night, campfires are tried first. Falls back to spatial grid proximity,
    /// then full pig list if nobody is in the nearby grid cells.
    @MainActor
    static func seekSocialInteraction(controller: BehaviorController, pig: inout GuineaPig) {
        if !controller.gameState.gameTime.isDaytime,
           seekCampfire(controller: controller, pig: &pig) { return }

        guard let target = findNearestSocialTarget(controller: controller, pig: pig) else {
            pig.targetFacilityId = nil
            pig.targetDescription = nil
            BehaviorMovement.startWandering(controller: controller, pig: &pig)
            return
        }

        if let adjacentPos = findAdjacentCell(
            controller: controller, target: target.position.gridPosition, pig: pig
        ) {
            BehaviorMovement.setPathTo(controller: controller, pig: &pig, target: adjacentPos)
            if !pig.path.isEmpty {
                pig.behaviorState = .socializing
                pig.targetFacilityId = nil
                pig.targetDescription = "going to \(target.name)"
                return
            }
        }
        pig.targetFacilityId = nil
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
    }

    /// Pathfind the initiating pig toward its courting partner.
    ///
    /// Returns `false` if the partner is unreachable — the caller (BehaviorDecision)
    /// is responsible for cancelling courtship on both pigs.
    @MainActor
    @discardableResult
    static func seekCourtingPartner(
        controller: BehaviorController,
        pig: inout GuineaPig,
        partner: GuineaPig
    ) -> Bool {
        guard let adjacentPos = findAdjacentCell(
            controller: controller,
            target: partner.position.gridPosition,
            pig: pig
        ) else { return false }
        BehaviorMovement.setPathTo(controller: controller, pig: &pig, target: adjacentPos)
        if !pig.path.isEmpty {
            pig.targetDescription = "courting \(partner.name)"
            return true
        }
        return false
    }

    /// Find a walkable, unoccupied cell adjacent to `target` at pig-spacing distance.
    ///
    /// Checks 8 offset cells (4 cardinal + 4 diagonal) sorted by proximity to `pig`.
    /// Returns nil if no suitable cell exists.
    @MainActor
    static func findAdjacentCell(
        controller: BehaviorController,
        target: GridPosition,
        pig: GuineaPig
    ) -> GridPosition? {
        let spacing = Int(GameConfig.Behavior.minPigDistance)
        let offsets: [(Int, Int)] = [
            (-spacing, 0), (spacing, 0), (0, -spacing), (0, spacing),
            (-spacing, -spacing), (spacing, spacing), (-spacing, spacing), (spacing, -spacing),
        ]
        let pigPos = pig.position.gridPosition
        let sorted = offsets.sorted { lhs, rhs in
            abs(target.x + lhs.0 - pigPos.x) + abs(target.y + lhs.1 - pigPos.y) <
            abs(target.x + rhs.0 - pigPos.x) + abs(target.y + rhs.1 - pigPos.y)
        }
        let farm = controller.gameState.farm
        for (ox, oy) in sorted {
            let ax = target.x + ox
            let ay = target.y + oy
            if farm.isWalkable(ax, ay) &&
                !controller.collision.isCellOccupiedByPig(x: ax, y: ay, excludePig: pig) {
                return GridPosition(x: ax, y: ay)
            }
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Try to path to a campfire for nighttime socializing. Returns true on success.
    @MainActor
    private static func seekCampfire(controller: BehaviorController, pig: inout GuineaPig) -> Bool {
        let campfires = controller.facilityManager.getCandidateFacilitiesRanked(
            pig: pig, facilityType: .campfire
        )
        for campfire in campfires.prefix(GameConfig.Behavior.maxFacilityCandidates) {
            guard let (point, path) = controller.facilityManager.findOpenInteractionPoint(
                pig: pig, facility: campfire
            ) else { continue }
            var trimmedPath = path
            if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
            pig.path = trimmedPath
            pig.behaviorState = .socializing
            pig.targetFacilityId = campfire.id
            pig.targetPosition = Position(x: Double(point.x), y: Double(point.y))
            pig.targetDescription = "going to campfire"
            return true
        }
        return false
    }

    /// Find the closest other pig using a wide spatial grid search.
    ///
    /// Uses a 30-cell radius (covering most of the map) instead of the fixed
    /// 3×3 neighborhood, eliminating the O(n) full-list fallback in nearly all
    /// cases. The fallback only fires for extremely isolated pigs (>30 cells
    /// from any other pig).
    @MainActor
    private static func findNearestSocialTarget(
        controller: BehaviorController,
        pig: GuineaPig
    ) -> GuineaPig? {
        var nearest: GuineaPig?
        var bestDistSq = Double.infinity
        let nearby = controller.collision.spatialGrid.getNearby(
            x: pig.position.x, y: pig.position.y,
            radius: GameConfig.Behavior.socialSeekRadius,
            pigs: controller.gameState.guineaPigs
        )
        for other in nearby where other.id != pig.id {
            let distSq = (pig.position.x - other.position.x) * (pig.position.x - other.position.x)
                + (pig.position.y - other.position.y) * (pig.position.y - other.position.y)
            if distSq < bestDistSq { bestDistSq = distSq; nearest = other }
        }
        if nearest == nil {
            // Fallback for extremely isolated pigs (rare with 100+ pigs).
            for other in controller.gameState.getPigsList() where other.id != pig.id {
                let distSq = (pig.position.x - other.position.x) * (pig.position.x - other.position.x)
                    + (pig.position.y - other.position.y) * (pig.position.y - other.position.y)
                if distSq < bestDistSq { bestDistSq = distSq; nearest = other }
            }
        }
        return nearest
    }

    static func getNeedValue(_ pig: GuineaPig, need: String) -> Double {
        switch need {
        case "hunger":    return pig.needs.hunger
        case "thirst":    return pig.needs.thirst
        case "energy":    return pig.needs.energy
        case "happiness": return pig.needs.happiness
        case "social":    return pig.needs.social
        default:          return 100.0
        }
    }
}

// MARK: - Debug Logging Helpers

#if (DEBUG || INTERNAL) && canImport(UIKit)
extension BehaviorSeeking {
    @MainActor private static func logSeekBackoff(pig: GuineaPig, need: String, backoff: Int) {
        DebugLogger.shared.log(
            category: .behavior, level: .info,
            message: "\(pig.name): seek \(need) blocked by backoff",
            pigId: pig.id, pigName: pig.name,
            payload: ["need": need, "backoffCycles": String(backoff)]
        )
    }

    @MainActor private static func logSeekDispatch(pig: GuineaPig, need: String, facility: Facility) {
        DebugLogger.shared.log(
            category: .behavior, level: .info,
            message: "\(pig.name): seeking \(need) -> \(facility.name)",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "need": need,
                "facilityType": facility.facilityType.rawValue,
                "facilityName": facility.name,
                "needValue": String(Int(getNeedValue(pig, need: need))),
            ]
        )
    }

    @MainActor private static func logSeekFailure(pig: GuineaPig, need: String, isCritical: Bool, cycles: Int) {
        DebugLogger.shared.log(
            category: .behavior, level: .warning,
            message: "\(pig.name): no reachable \(need) facility",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "need": need,
                "isCritical": String(isCritical),
                "backoffCycles": String(cycles),
                "needValue": String(Int(getNeedValue(pig, need: need))),
            ]
        )
    }
}
#endif
