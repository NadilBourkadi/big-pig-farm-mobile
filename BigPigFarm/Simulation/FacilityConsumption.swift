/// FacilityConsumption — Arrival handling, resource consumption, and alternative facility search.
/// Maps from: simulation/facility_manager.py (check_arrived_at_facility, consume_from_nearby_facility)
import Foundation

extension FacilityManager {

    // MARK: - Arrival Handling

    /// Transition a pig's behavior state based on the facility it just reached.
    func checkArrivedAtFacility(pig: inout GuineaPig) {
        let gridPos = pig.position.gridPosition

        for facility in getCandidateFacilitiesForArrival(pig: pig) {
            for point in facility.interactionPoints {
                let manhattan = abs(gridPos.x - point.x) + abs(gridPos.y - point.y)
                guard manhattan <= GameConfig.FacilityInteraction.adjacencyDistance else { continue }

                if handleArrival(pig: &pig, facility: facility) {
                    #if (DEBUG || INTERNAL) && canImport(UIKit)
                    logFacilityArrival(pig: pig, facility: facility)
                    #endif
                    return
                }
            }
        }

        // No suitable facility — go idle with cooldown to prevent re-seeking loop
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        logArrivalFailed(pig: pig)
        #endif
        setArrivalFailedCooldown(pig: pig)
        pig.behaviorState = .idle
        pig.targetPosition = nil
        pig.targetFacilityId = nil
        pig.targetDescription = nil
    }

    /// Handle arrival at a specific facility. Returns true if the pig is now using the facility.
    private func handleArrival(pig: inout GuineaPig, facility: Facility) -> Bool {
        switch facility.facilityType {
        case .foodBowl, .hayRack, .feastTable:
            return handleArrivalFood(pig: &pig, facility: facility)
        case .waterBottle:
            return handleArrivalWater(pig: &pig, facility: facility)
        case .hideout:
            return handleArrivalHideout(pig: &pig, facility: facility)
        case .exerciseWheel, .tunnel, .playArea, .therapyGarden, .stage:
            return handleArrivalPlay(pig: &pig, facility: facility)
        case .campfire:
            return handleArrivalCampfire(pig: &pig, facility: facility)
        case .hotSpring:
            return handleArrivalHotSpring(pig: &pig, facility: facility)
        default:
            return false
        }
    }

    private func handleArrivalFood(pig: inout GuineaPig, facility: Facility) -> Bool {
        if !facility.isEmpty && pig.needs.hunger < Double(GameConfig.Needs.satisfactionThreshold) {
            pig.behaviorState = .eating
            pig.targetPosition = nil
            pig.targetDescription = "eating at \(facility.name)"
            clearFailedFacilities(pig.id)
            return true
        } else if facility.isEmpty {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
        }
        return false
    }

    private func handleArrivalWater(pig: inout GuineaPig, facility: Facility) -> Bool {
        if !facility.isEmpty && pig.needs.thirst < Double(GameConfig.Needs.satisfactionThreshold) {
            pig.behaviorState = .drinking
            pig.targetPosition = nil
            pig.targetDescription = "drinking at \(facility.name)"
            clearFailedFacilities(pig.id)
            return true
        } else if facility.isEmpty {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
        }
        return false
    }

    private func handleArrivalHideout(pig: inout GuineaPig, facility: Facility) -> Bool {
        guard pig.needs.energy < Double(GameConfig.Needs.satisfactionThreshold) else { return false }
        let pigsUsing = countPigsUsingFacility(facility, excludePig: pig)
        pig.behaviorState = .sleeping
        pig.targetPosition = nil
        if pigsUsing < facility.info.capacity {
            pig.targetDescription = "sleeping in \(facility.name)"
            clearFailedFacilities(pig.id)
        } else {
            pig.targetDescription = "sleeping near \(facility.name) (full)"
            addFailedFacility(pig.id, facility.id)
        }
        return true
    }

    private func handleArrivalPlay(pig: inout GuineaPig, facility: Facility) -> Bool {
        if facility.facilityType == .therapyGarden && pig.needs.happiness >= 50 {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
            pig.behaviorState = .idle
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
            return true
        }
        let pigsUsing = countPigsUsingFacility(facility, excludePig: pig)
        if pigsUsing < facility.info.capacity {
            pig.behaviorState = .playing
            pig.targetPosition = nil
            pig.targetDescription = "playing at \(facility.name)"
            clearFailedFacilities(pig.id)
        } else {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
            pig.behaviorState = .idle
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
        }
        return true
    }

    private func handleArrivalCampfire(pig: inout GuineaPig, facility: Facility) -> Bool {
        let pigsUsing = countPigsUsingFacility(facility, excludePig: pig)
        if pigsUsing < facility.info.capacity {
            pig.behaviorState = .socializing
            pig.targetPosition = nil
            pig.targetDescription = "socializing at \(facility.name)"
            clearFailedFacilities(pig.id)
        } else {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
            pig.behaviorState = .idle
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
        }
        return true
    }

    private func handleArrivalHotSpring(pig: inout GuineaPig, facility: Facility) -> Bool {
        guard pig.needs.energy < Double(GameConfig.Needs.satisfactionThreshold) else { return false }
        let pigsUsing = countPigsUsingFacility(facility, excludePig: pig)
        if pigsUsing < facility.info.capacity {
            pig.behaviorState = .sleeping
            pig.targetPosition = nil
            pig.targetDescription = "soaking in \(facility.name)"
            clearFailedFacilities(pig.id)
        } else {
            addFailedFacility(pig.id, facility.id)
            setArrivalFailedCooldown(pig: pig)
            pig.behaviorState = .idle
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
        }
        return true
    }

    // MARK: - Resource Consumption

    /// Consume resources from a nearby facility and apply need recovery bonuses.
    func consumeFromNearbyFacility(pig: inout GuineaPig, gameMinutes: Double) {
        let gridPos = pig.position.gridPosition

        for facility in getCandidateFacilitiesForArrival(pig: pig) {
            let point = facility.interactionPoint
            let dx = abs(gridPos.x - point.x)
            let dy = abs(gridPos.y - point.y)
            guard dx <= GameConfig.FacilityInteraction.adjacencyDistance
                && dy <= GameConfig.FacilityInteraction.adjacencyDistance else { continue }

            switch pig.behaviorState {
            case .eating:
                consumeFromFood(pig: &pig, facility: facility, gameMinutes: gameMinutes)
                return
            case .drinking:
                consumeFromWater(pig: &pig, facility: facility, gameMinutes: gameMinutes)
                return
            case .sleeping:
                consumeFromSleep(pig: &pig, facility: facility, gameMinutes: gameMinutes)
                return
            case .playing:
                consumeFromPlay(pig: &pig, facility: facility, gameMinutes: gameMinutes)
                return
            case .socializing:
                consumeFromSocial(pig: &pig, facility: facility, gameMinutes: gameMinutes)
                return
            default:
                continue
            }
        }
    }

    private func consumeFromFood(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        guard [FacilityType.foodBowl, .hayRack, .feastTable].contains(facility.facilityType) else { return }

        var mutableFacility = facility
        let consumed = mutableFacility.consume(gameMinutes * GameConfig.Behavior.resourceConsumeRate)
        gameState.updateFacility(mutableFacility)

        if consumed <= 0 {
            #if (DEBUG || INTERNAL) && canImport(UIKit)
            logFacilityDepleted(pig: pig, facility: facility)
            #endif
            pig.behaviorState = .idle
            return
        }
        if facility.facilityType == .hayRack {
            pig.needs.health = min(100, pig.needs.health
                + facility.info.healthBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        } else if facility.facilityType == .feastTable {
            let coDiners = countCoDiners(pig: pig, facility: facility)
            if coDiners > 0 {
                let socialBoost = Double(min(coDiners, 3)) * 5.0 * (gameMinutes / 60.0)
                pig.needs.social = min(100, pig.needs.social + socialBoost)
            }
            if facility.info.happinessBonus > 0 {
                pig.needs.happiness = min(100, pig.needs.happiness
                    + facility.info.happinessBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
            }
        }
    }

    private func consumeFromWater(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        guard facility.facilityType == .waterBottle else { return }
        var mutableFacility = facility
        let consumed = mutableFacility.consume(gameMinutes * GameConfig.Behavior.resourceConsumeRate)
        gameState.updateFacility(mutableFacility)
        if consumed <= 0 {
            #if (DEBUG || INTERNAL) && canImport(UIKit)
            logFacilityDepleted(pig: pig, facility: facility)
            #endif
            pig.behaviorState = .idle
        }
    }

    private func consumeFromSleep(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        if facility.facilityType == .hideout {
            if facility.info.happinessBonus > 0 {
                pig.needs.happiness = min(100, pig.needs.happiness
                    + facility.info.happinessBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
            }
        } else if facility.facilityType == .hotSpring {
            applyHotSpringBonuses(pig: &pig, facility: facility, gameMinutes: gameMinutes)
        }
    }

    private func applyHotSpringBonuses(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        let info = facility.info
        let gameHours = gameMinutes / 60.0
        // Hot spring trades 25% of energy recovery for multi-need bonuses
        pig.needs.energy -= GameConfig.Needs.sleepRecoveryPerHour * 0.25 * gameHours
        if info.happinessBonus > 0 {
            pig.needs.happiness = min(100, pig.needs.happiness
                + info.happinessBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
        if info.healthBonus > 0 {
            pig.needs.health = min(100, pig.needs.health
                + info.healthBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
        if info.socialBonus > 0 {
            let coOccupants = countPigsUsingFacility(facility, excludePig: pig)
            let socialScale = 1.0 + 0.5 * Double(coOccupants)
            pig.needs.social = min(100, pig.needs.social
                + info.socialBonus * socialScale * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
    }

    private func consumeFromPlay(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        let playTypes: Set<FacilityType> = [.exerciseWheel, .tunnel, .playArea, .therapyGarden, .stage]
        guard playTypes.contains(facility.facilityType) else { return }
        let info = facility.info
        if info.healthBonus > 0 {
            pig.needs.health = min(100, pig.needs.health
                + info.healthBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
        if info.happinessBonus > 0 {
            pig.needs.happiness = min(100, pig.needs.happiness
                + info.happinessBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
        if info.socialBonus > 0 {
            pig.needs.social = min(100, pig.needs.social
                + info.socialBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
    }

    private func consumeFromSocial(pig: inout GuineaPig, facility: Facility, gameMinutes: Double) {
        guard facility.facilityType == .campfire else { return }
        let info = facility.info
        if info.socialBonus > 0 {
            pig.needs.social = min(100, pig.needs.social
                + info.socialBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
        if info.happinessBonus > 0 {
            pig.needs.happiness = min(100, pig.needs.happiness
                + info.happinessBonus * gameMinutes * GameConfig.Behavior.facilityBonusScale)
        }
    }

}
