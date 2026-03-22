/// FacilityArrivalFailTests — Tests for the seek-arrive-fail loop fix (bead k4zu).
///
/// Verifies that pigs set a failed cooldown on arrival failure, that
/// cleanupTargetState handles the safety net branch, and that backoff
/// prevents the tight re-seeking loop.
import Foundation
import Testing
@testable import BigPigFarmCore

@MainActor
struct FacilityArrivalFailTests {

    // MARK: - Helpers

    // swiftlint:disable:next large_tuple
    func makeManager() -> (FacilityManager, GameState, BehaviorController) {
        let state = makeGameState()
        let controller = makeController(state: state)
        return (controller.facilityManager, state, controller)
    }

    func placeFacility(type: FacilityType, x: Int, y: Int, state: GameState) -> Facility {
        let facility = Facility.create(type: type, x: x, y: y)
        let success = state.addFacility(facility)
        precondition(success, "Failed to place \(type) at (\(x), \(y))")
        guard let placed = state.getFacility(facility.id) else {
            preconditionFailure("Facility missing after placement")
        }
        return placed
    }

    func pigAt(x: Double, y: Double, state: BehaviorState = .idle) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.position = Position(x: x, y: y)
        pig.behaviorState = state
        return pig
    }

    // MARK: - Arrival Failure Sets Cooldown

    @Test("Arrival at empty food bowl sets failed cooldown")
    func arrivalAtEmptyFoodSetsFailedCooldown() {
        let (manager, state, _) = makeManager()
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.hunger = 30.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
        #expect(manager.getFailedFacilities(pig.id).contains(facility.id))
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    @Test("Arrival at empty water bottle sets failed cooldown")
    func arrivalAtEmptyWaterSetsFailedCooldown() {
        let (manager, state, _) = makeManager()
        var facility = placeFacility(type: .waterBottle, x: 5, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.thirst = 30.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
        #expect(manager.getFailedFacilities(pig.id).contains(facility.id))
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    @Test("Arrival at full play facility sets failed cooldown")
    func arrivalAtFullPlayFacilitySetsFailedCooldown() {
        let (manager, state, controller) = makeManager()
        let facility = placeFacility(type: .exerciseWheel, x: 4, y: 9, state: state)

        // Fill the facility to capacity with pigs at the interaction point
        let interactionPoint = facility.interactionPoints[0]
        for i in 0..<facility.info.capacity {
            var filler = GuineaPig.create(name: "Filler\(i)", gender: .male)
            filler.position = Position(x: Double(interactionPoint.x), y: Double(interactionPoint.y))
            filler.behaviorState = .playing
            filler.targetFacilityId = facility.id
            state.addGuineaPig(filler)
        }

        // Rebuild spatial grid so countPigsUsingFacility sees the fillers
        controller.collision.rebuildSpatialGrid()

        var pig = pigAt(x: Double(interactionPoint.x), y: Double(interactionPoint.y), state: .wandering)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    // MARK: - Critical vs Normal Cooldown Duration

    @Test("Critical pig gets shorter cooldown on arrival failure")
    func criticalPigGetsShorterCooldown() {
        let (manager, state, _) = makeManager()
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.hunger = Double(GameConfig.Needs.criticalThreshold) - 5  // Critical
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getFailedCooldown(pig.id) == GameConfig.Behavior.criticalFailedCooldownCycles)
    }

    @Test("Non-critical pig gets normal cooldown on arrival failure")
    func nonCriticalPigGetsNormalCooldown() {
        let (manager, state, controller) = makeManager()
        let facility = placeFacility(type: .campfire, x: 4, y: 9, state: state)

        // Fill campfire to capacity at the interaction point
        let interactionPoint = facility.interactionPoints[0]
        for i in 0..<facility.info.capacity {
            var filler = GuineaPig.create(name: "Filler\(i)", gender: .male)
            filler.position = Position(x: Double(interactionPoint.x), y: Double(interactionPoint.y))
            filler.behaviorState = .socializing
            filler.targetFacilityId = facility.id
            state.addGuineaPig(filler)
        }

        // Rebuild spatial grid so countPigsUsingFacility sees the fillers
        controller.collision.rebuildSpatialGrid()

        var pig = pigAt(x: Double(interactionPoint.x), y: Double(interactionPoint.y), state: .wandering)
        pig.needs.hunger = 80.0  // Not critical
        pig.needs.thirst = 80.0  // Not critical
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getFailedCooldown(pig.id) == GameConfig.Behavior.arrivalFailedCooldownCycles)
    }

    // MARK: - cleanupTargetState Safety Net

    @Test("cleanupTargetState sets cooldown when failed set is nonempty but cooldown is zero")
    func cleanupTargetStateSafetyNet() {
        let (manager, state, controller) = makeManager()

        var pig = pigAt(x: 5.0, y: 9.0, state: .idle)
        pig.needs.hunger = 80.0
        pig.needs.thirst = 80.0
        state.addGuineaPig(pig)

        // Simulate the bug: failed set exists but no cooldown
        manager.addFailedFacility(pig.id, UUID())
        #expect(manager.getFailedCooldown(pig.id) == 0)
        #expect(!manager.getFailedFacilities(pig.id).isEmpty)

        // Run a decision cycle — cleanupTargetState should catch this
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)

        // Safety net should have set a cooldown instead of clearing the failed set
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    @Test("cleanupTargetState clears failed set only after cooldown expires")
    func cleanupTargetStateClearsAfterCooldown() {
        let (manager, state, controller) = makeManager()

        var pig = pigAt(x: 5.0, y: 9.0, state: .idle)
        pig.needs = Needs(hunger: 90, thirst: 90, energy: 90, happiness: 90, health: 100,
                          social: 90, boredom: 0)
        state.addGuineaPig(pig)

        let failedId = UUID()
        manager.addFailedFacility(pig.id, failedId)
        manager.setFailedCooldown(pig.id, 2)

        // First decision: cooldown ticks from 2 to 1
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        state.updateGuineaPig(pig)
        #expect(manager.getFailedCooldown(pig.id) == 1)
        #expect(!manager.getFailedFacilities(pig.id).isEmpty)

        // Second decision: cooldown ticks from 1 to 0, failed set cleared
        pig = state.getGuineaPig(pig.id)!
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(manager.getFailedFacilities(pig.id).isEmpty)
    }

    // MARK: - seekFacilityForNeed Sets Cooldown with Backoff

    @Test("seekFacilityForNeed sets failed cooldown alongside unreachable backoff")
    func seekFacilityForNeedSetsCooldownWithBackoff() {
        let (manager, state, controller) = makeManager()

        // No food facilities at all — seek will fail
        var pig = pigAt(x: 5.0, y: 9.0, state: .idle)
        pig.needs.hunger = 30.0  // Urgent
        state.addGuineaPig(pig)

        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")

        // Both unreachable backoff and failed cooldown should be set
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") > 0)
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    // MARK: - Integration: Loop Breaks

    @Test("Seek-arrive-fail loop breaks with cooldown")
    func seekArriveFailLoopBreaks() {
        let (manager, state, controller) = makeManager()

        // Place a single food bowl that is empty
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.hunger = 30.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        // First arrival: pig fails, cooldown is set
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
        #expect(manager.getFailedCooldown(pig.id) > 0)

        // On the next decision, the failed set should NOT be cleared — the pig is
        // protected from immediately re-seeking the same empty bowl.
        state.updateGuineaPig(pig)
        pig = state.getGuineaPig(pig.id)!
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // The failed set must still contain the facility (the key invariant)
        #expect(manager.getFailedFacilities(pig.id).contains(facility.id))
        // Cooldown is still positive (may have been refreshed by seekFacilityForNeed)
        #expect(manager.getFailedCooldown(pig.id) > 0)
    }

    @Test("Area change clears unreachable backoff but preserves failed cooldown")
    func areaChangeClearsBackoffPreservesCooldown() {
        let (_, state, controller) = makeManager()

        var pig = pigAt(x: 5.0, y: 9.0, state: .idle)
        pig.needs.hunger = 30.0
        state.addGuineaPig(pig)

        // Set both unreachable backoff and failed cooldown
        controller.setUnreachableBackoff(pig.id, need: "hunger", cycles: 5)
        controller.facilityManager.setFailedCooldown(pig.id, 3)
        controller.facilityManager.addFailedFacility(pig.id, UUID())

        // Simulate area change via clearUnreachableBackoff (called by BehaviorController.update)
        controller.clearUnreachableBackoff(pig.id)

        // Unreachable backoff should be cleared
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") == 0)
        // Failed cooldown should persist
        #expect(controller.facilityManager.getFailedCooldown(pig.id) == 3)
        #expect(!controller.facilityManager.getFailedFacilities(pig.id).isEmpty)
    }
}
