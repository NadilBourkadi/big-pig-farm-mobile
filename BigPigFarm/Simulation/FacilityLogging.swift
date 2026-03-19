/// FacilityLogging — Debug log helpers and alternative facility search.
/// Split from FacilityConsumption.swift for file length compliance.
import Foundation

// MARK: - Alternative Facility Search

extension FacilityManager {
    /// Try to find an alternative facility when the pig is blocked en route.
    /// Returns true if a new facility was found and the pig's path was updated.
    func tryAlternativeFacility(pig: inout GuineaPig) -> Bool {
        blameTargetFacilityIfNear(pig: pig)

        let facilityTypes = inferNeededFacilityTypes(pig: pig)
        if facilityTypes.isEmpty { return false }

        for facilityType in facilityTypes {
            let candidates = getCandidateFacilitiesRanked(pig: pig, facilityType: facilityType)
            for facility in candidates.prefix(GameConfig.Behavior.maxFacilityCandidates) {
                if let result = findOpenInteractionPoint(pig: pig, facility: facility) {
                    var trimmedPath = result.path
                    if trimmedPath.first == pig.position.gridPosition { trimmedPath.removeFirst() }
                    pig.path = trimmedPath
                    pig.targetPosition = Position(x: Double(result.point.x), y: Double(result.point.y))
                    pig.targetFacilityId = facility.id
                    pig.targetDescription = "going to \(facility.name)"
                    return true
                }
            }
        }

        return false
    }

    private func blameTargetFacilityIfNear(pig: GuineaPig) {
        guard let targetId = pig.targetFacilityId,
              let targetFacility = gameState.getFacility(targetId) else { return }
        let isNear = targetFacility.interactionPoints.contains { point in
            abs(pig.position.x - Double(point.x)) <= 3
                && abs(pig.position.y - Double(point.y)) <= 3
        }
        if isNear { addFailedFacility(pig.id, targetId) }
    }

    private func inferNeededFacilityTypes(pig: GuineaPig) -> [FacilityType] {
        let description = pig.targetDescription ?? ""
        let isPlayDesc = description.contains("Exercise Wheel")
            || description.contains("Tunnel")
            || description.contains("Play Area")
        if isPlayDesc { return [.tunnel, .playArea, .exerciseWheel] }
        let isFoodDesc = description.contains("Food Bowl")
            || description.contains("Hay Rack")
            || description.contains("Feast Table")
        if isFoodDesc { return [.hayRack, .feastTable, .foodBowl] }
        if description.contains("Water Bottle") { return [.waterBottle] }
        if description.contains("Hideout") { return [.hideout] }

        // Fall back to most urgent need
        let urgentNeed = NeedsSystem.getMostUrgentNeed(pig)
        let needToFacilities: [String: [FacilityType]] = [
            "hunger": [.hayRack, .feastTable, .foodBowl],
            "thirst": [.waterBottle],
            "energy": [.hideout, .hotSpring],
            "happiness": [.exerciseWheel, .playArea, .tunnel],
            "social": [.playArea],
        ]
        return needToFacilities[urgentNeed] ?? []
    }
}

// MARK: - Debug Logging Helpers

#if (DEBUG || INTERNAL) && canImport(UIKit)
extension FacilityManager {
    func logFacilityArrival(pig: GuineaPig, facility: Facility) {
        DebugLogger.shared.log(
            category: .facility, level: .info,
            message: "\(pig.name): arrived at \(facility.name)",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "facilityType": facility.facilityType.rawValue,
                "facilityName": facility.name,
                "newState": pig.behaviorState.rawValue,
            ]
        )
    }

    func logArrivalFailed(pig: GuineaPig) {
        DebugLogger.shared.log(
            category: .facility, level: .warning,
            message: "\(pig.name): arrived but no usable facility",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "targetFacilityId": pig.targetFacilityId?.uuidString ?? "none",
            ]
        )
    }

    func logFacilityDepleted(pig: GuineaPig, facility: Facility) {
        DebugLogger.shared.log(
            category: .facility, level: .info,
            message: "\(pig.name): \(facility.name) depleted",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "facilityType": facility.facilityType.rawValue,
                "facilityName": facility.name,
            ]
        )
    }
}
#endif
