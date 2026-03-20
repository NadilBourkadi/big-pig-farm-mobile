/// AutoResources — Drip systems and area-of-effect facility automation.
/// Maps from: simulation/auto_resources.py
import Foundation

/// Stateless namespace for automatic resource distribution each tick.
enum AutoResources {

    // MARK: - Constants

    /// Facility types affected by drip/auto-feeder/bulk-feeder perks.
    static let foodWaterTypes: Set<FacilityType> = [
        .foodBowl, .hayRack, .waterBottle, .feastTable
    ]

    /// Passive drip refill rate (units per game hour).
    static let dripRatePerHour: Double = 2.0

    /// Auto-feeder triggers when fill percentage drops below this fraction.
    /// 0.25 means 25%.
    static let autoRefillThreshold: Double = 0.25

    /// Stage audience receives passive bonuses within this cell radius.
    static let stageAudienceRadius: Double = 6.0

    /// Happiness bonus per game hour for pigs in stage audience.
    static let stageAudienceHappinessPerHour: Double = 2.0

    /// Social bonus per game hour for pigs in stage audience.
    static let stageAudienceSocialPerHour: Double = 1.5

    // MARK: - Public API

    /// Run drip feeder and auto-feeder logic for all food/water facilities.
    /// Drip applies first; auto-feeder only fires if still below threshold after drip.
    @MainActor
    static func tickAutoResources(state: GameState, gameHours: Double) {
        let hasDrip = state.hasUpgrade("drip_system")
        let hasAuto = state.hasUpgrade("auto_feeders")
        guard hasDrip || hasAuto else { return }

        for facility in state.getFacilitiesList() {
            guard foodWaterTypes.contains(facility.facilityType) else { continue }
            var mutableFacility = facility
            if hasDrip {
                mutableFacility.refill(dripRatePerHour * gameHours)
            }
            if hasAuto && mutableFacility.fillPercentage < autoRefillThreshold * 100 {
                mutableFacility.refill()
            }
            state.updateFacility(mutableFacility)
        }
    }

    /// Double max capacity and current fill of all food/water facilities.
    /// Called once when the Bulk Feeders perk is purchased.
    @MainActor
    static func applyBulkFeeders(state: GameState) {
        for facility in state.getFacilitiesList() {
            guard foodWaterTypes.contains(facility.facilityType) else { continue }
            var mutableFacility = facility
            mutableFacility.maxAmount *= 2
            mutableFacility.currentAmount *= 2
            state.updateFacility(mutableFacility)
        }
    }

    /// Advance veggie garden production and distribute food to nearby bowls/racks.
    /// Re-reads facility values from the dictionary each garden iteration so earlier
    /// garden refills are visible to later ones (matching Python in-place semantics).
    @MainActor
    static func tickVeggieGardens(state: GameState, gameHours: Double) {
        let gardens = state.getFacilitiesByType(.veggieGarden)
        guard !gardens.isEmpty else { return }

        // Collect food facility IDs once; read fresh values from the dict each iteration.
        let foodFacilityIds: [UUID] = (
            state.getFacilitiesByType(.foodBowl)
            + state.getFacilitiesByType(.hayRack)
            + state.getFacilitiesByType(.feastTable)
        ).map(\.id)
        guard !foodFacilityIds.isEmpty else { return }

        for garden in gardens {
            let production = Double(garden.info.foodProduction) * gameHours
            guard production > 0 else { continue }

            // Read current values from dictionary (reflects prior garden refills).
            let targets = foodFacilityIds.compactMap { state.facilities[$0] }
                .filter { $0.currentAmount < $0.maxAmount }
            guard !targets.isEmpty else { continue }

            let perTarget = production / Double(targets.count)
            for var target in targets {
                target.refill(perTarget)
                state.updateFacility(target)
            }
        }
    }

    /// Apply area-of-effect happiness and social bonuses to pigs near an active stage.
    /// A stage is "active" when a pig with behaviorState == .playing is targeting it.
    /// The performing pig is excluded from the audience bonus.
    @MainActor
    static func tickAoEFacilities(state: GameState, gameHours: Double) {
        let pigs = state.getPigsList()
        guard !pigs.isEmpty else { return }

        let stages = state.getFacilitiesByType(.stage)
        guard !stages.isEmpty else { return }

        for stage in stages {
            let hasPerformer = pigs.contains {
                $0.behaviorState == .playing && $0.targetFacilityId == stage.id
            }
            guard hasPerformer else { continue }

            let stageX = Double(stage.positionX) + Double(stage.width) / 2.0
            let stageY = Double(stage.positionY) + Double(stage.height) / 2.0
            let radiusSquared = stageAudienceRadius * stageAudienceRadius

            for var pig in pigs {
                if pig.targetFacilityId == stage.id && pig.behaviorState == .playing { continue }

                let dx = pig.position.x - stageX
                let dy = pig.position.y - stageY
                guard dx * dx + dy * dy <= radiusSquared else { continue }

                pig.needs.happiness = min(
                    100.0,
                    pig.needs.happiness + stageAudienceHappinessPerHour * gameHours
                )
                pig.needs.social = min(
                    100.0,
                    pig.needs.social + stageAudienceSocialPerHour * gameHours
                )
                state.updateGuineaPig(pig)
            }
        }
    }
}
