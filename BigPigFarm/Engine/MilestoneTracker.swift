/// MilestoneTracker — Awards Squeak breadcrumbs at key progression points.
///
/// Milestones fire on ALL farms (not just Farm #1). Each milestone is awarded
/// once per farm — the completion set resets on prestige.
///
/// Checked once per tick in SimulationRunner (after the economy phase) and once
/// at the end of OfflineProgressRunner.runCatchUp. The check is idempotent:
/// milestones already in `completedMilestones` are skipped.
import Foundation

// MARK: - MilestoneID

enum MilestoneID: String, Codable, CaseIterable, Sendable {
    case firstPigBorn = "first_pig_born"
    case firstPigSold = "first_pig_sold"
    case firstFacilityPlaced = "first_facility_placed"
    case tier2Reached = "tier_2_reached"
    case firstContractCompleted = "first_contract_completed"
    case fiftyPigsBorn = "fifty_pigs_born"
}

// MARK: - MilestoneTracker

enum MilestoneTracker {

    /// Check all milestones and award any that are newly met.
    @MainActor
    static func checkMilestones(state: GameState) {
        for milestone in MilestoneID.allCases {
            guard !state.completedMilestones.contains(milestone) else { continue }
            guard isMet(milestone, state: state) else { continue }
            award(milestone, state: state)
        }
    }

    /// Squeak reward for a given milestone.
    static func reward(for milestone: MilestoneID) -> Int {
        switch milestone {
        case .firstPigBorn: GameConfig.NewFarmer.firstPigBornReward
        case .firstPigSold: GameConfig.NewFarmer.firstPigSoldReward
        case .firstFacilityPlaced: GameConfig.NewFarmer.firstFacilityPlacedReward
        case .tier2Reached: GameConfig.NewFarmer.tier2ReachedReward
        case .firstContractCompleted: GameConfig.NewFarmer.firstContractCompletedReward
        case .fiftyPigsBorn: GameConfig.NewFarmer.fiftyPigsBornReward
        }
    }

    // MARK: - Private

    @MainActor
    private static func isMet(_ milestone: MilestoneID, state: GameState) -> Bool {
        switch milestone {
        case .firstPigBorn: state.totalPigsBorn >= 1
        case .firstPigSold: state.totalPigsSold >= 1
        case .firstFacilityPlaced: facilityCount(state) >= 4  // 3 starter + 1 player-placed
        case .tier2Reached: state.farmTier >= 2
        case .firstContractCompleted: state.contractBoard.completedContracts >= 1
        case .fiftyPigsBorn: state.totalPigsBorn >= 50
        }
    }

    /// Count of player-facing facilities. The starter kit places 3 (food, water, hideout),
    /// so the first player-placed facility triggers at >= 4.
    @MainActor
    private static func facilityCount(_ state: GameState) -> Int {
        state.facilities.count
    }

    @MainActor
    private static func award(_ milestone: MilestoneID, state: GameState) {
        state.completedMilestones.insert(milestone)
        let amount = reward(for: milestone)
        state.addMoney(amount)
        let label = displayName(for: milestone)
        state.logEvent(
            "Milestone: \(label)! +\(amount) Squeaks",
            eventType: "milestone"
        )
    }

    private static func displayName(for milestone: MilestoneID) -> String {
        switch milestone {
        case .firstPigBorn: "First pig born"
        case .firstPigSold: "First pig sold"
        case .firstFacilityPlaced: "First facility placed"
        case .tier2Reached: "Tier 2 reached"
        case .firstContractCompleted: "First contract completed"
        case .fiftyPigsBorn: "50 pigs born"
        }
    }
}
