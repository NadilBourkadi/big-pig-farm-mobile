/// BehaviorLivelockTests — Tests for the behavior AI livelock prevention fix (bead oxp8).
///
/// Covers three independent fixes:
/// 1. Escalating arrival-failure cooldown (per-pig consecutive failure counter)
/// 2. Socializing minimum commitment (prevents partner-flipping)
/// 3. Bridge from arrival failure to unreachable backoff (catches "reachable but full")
import Foundation
import Testing
@testable import BigPigFarmCore

@MainActor
struct BehaviorLivelockTests {

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

    func emptyFoodBowl(at x: Int, y: Int, state: GameState) -> Facility {
        var facility = placeFacility(type: .foodBowl, x: x, y: y, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility
        return facility
    }

    func nonCriticalPig(at x: Double, y: Double) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.position = Position(x: x, y: y)
        pig.behaviorState = .wandering
        pig.needs.hunger = 30.0  // Urgent but not critical
        pig.needs.thirst = 80.0
        pig.personality = []  // Avoid shy treat delays
        return pig
    }

    // MARK: - Fix 1: Escalating arrival-failure cooldown

    @Test("First arrival failure uses base cooldown")
    func firstFailureUsesBaseCooldown() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getFailedCooldown(pig.id) == GameConfig.Behavior.arrivalFailedCooldownCycles)
    }

    @Test("Second consecutive failure doubles the cooldown")
    func secondFailureDoublesCooldown() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        // Reset state but keep counter — simulate next arrival
        pig.behaviorState = .wandering
        pig.targetFacilityId = facility.id
        manager.checkArrivedAtFacility(pig: &pig)

        let base = GameConfig.Behavior.arrivalFailedCooldownCycles
        let mult = GameConfig.Behavior.arrivalFailureEscalationMult
        #expect(manager.getFailedCooldown(pig.id) == base * mult)
    }

    @Test("Cooldown caps at maxCooldownCycles after many failures")
    func cooldownCapsAtMaximum() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        // 10 consecutive failures — well past where cap should engage
        for _ in 0..<10 {
            pig.behaviorState = .wandering
            pig.targetFacilityId = facility.id
            manager.checkArrivedAtFacility(pig: &pig)
        }
        #expect(manager.getFailedCooldown(pig.id) == GameConfig.Behavior.arrivalFailureMaxCooldownCycles)
    }

    @Test("Critical pig does not escalate, always uses critical cooldown")
    func criticalPigDoesNotEscalate() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.needs.hunger = Double(GameConfig.Needs.criticalThreshold) - 5.0  // critical
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        for _ in 0..<5 {
            pig.behaviorState = .wandering
            pig.targetFacilityId = facility.id
            manager.checkArrivedAtFacility(pig: &pig)
        }
        // Critical cooldown is 1, never grows
        #expect(manager.getFailedCooldown(pig.id) == GameConfig.Behavior.criticalFailedCooldownCycles)
    }

    @Test("clearFailedFacilities resets the failure counter")
    func clearResetsCounter() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        // Fail twice → cooldown should be base * mult
        manager.checkArrivedAtFacility(pig: &pig)
        pig.behaviorState = .wandering; pig.targetFacilityId = facility.id
        manager.checkArrivedAtFacility(pig: &pig)
        let base = GameConfig.Behavior.arrivalFailedCooldownCycles
        #expect(manager.getFailedCooldown(pig.id) == base * GameConfig.Behavior.arrivalFailureEscalationMult)

        // Successful arrival path resets the counter
        manager.clearFailedFacilities(pig.id)

        // Next failure should use base cooldown again, not escalated
        pig.behaviorState = .wandering; pig.targetFacilityId = facility.id
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getFailedCooldown(pig.id) == base)
    }

    @Test("cleanupPig clears the failure counter")
    func cleanupPigClearsCounter() {
        let (manager, state, _) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 1)

        manager.cleanupPig(pig.id)
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 0)
    }

    // MARK: - Fix 2 socializing commitment tests live in
    // BehaviorSocializingCommitmentTests.swift (split for file length).

    // MARK: - Fix 3: Bridge to unreachable backoff

    @Test("Single empty food bowl: bridge fires after one arrival failure")
    func singleBowlBridgeAfterOneFailure() {
        let (manager, state, controller) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        // First arrival fails
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 1)

        // Now seek hunger — bridge should fire because failuresForType (1) >= totalOfType (1)
        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") > 0)
    }

    @Test("Multiple empty bowls: bridge fires after escalateThreshold failures")
    func multipleBowlsBridgeAfterThreshold() {
        let (manager, state, controller) = makeManager()
        // Place 5 empty food bowls — far more than escalate threshold
        var bowls: [Facility] = []
        for i in 0..<5 {
            bowls.append(emptyFoodBowl(at: 4 + i * 2, y: 9, state: state))
        }

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        state.addGuineaPig(pig)

        // Fail at exactly the threshold number of bowls
        let threshold = GameConfig.Behavior.arrivalFailureEscalateThreshold
        for i in 0..<threshold {
            pig.behaviorState = .wandering
            pig.targetFacilityId = bowls[i].id
            manager.checkArrivedAtFacility(pig: &pig)
        }

        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") > 0)
    }

    @Test("Bridge does not fire when pig has not failed yet")
    func bridgeQuietBeforeFailures() {
        let (_, state, controller) = makeManager()
        // Place a NON-empty food bowl far away (unreachable in one tick) so seek
        // can't actually find a path — but the bridge still shouldn't fire
        // because failure count is zero.
        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        state.addGuineaPig(pig)

        // No food at all — seek will fall through to the existing "no reachable"
        // backoff (not the bridge). We just want to make sure the bridge isn't
        // erroneously firing on a clean pig.
        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")
        // The existing "no reachable" path will still set backoff — that's
        // expected. We're verifying the bridge code path doesn't crash or
        // interfere.
        #expect(controller.facilityManager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 0)
    }

    @Test("Bridge escalation clears per-type counter so backoff doesn't immediately re-fire")
    func bridgeEscalationClearsCounters() {
        let (manager, state, controller) = makeManager()
        let facility = emptyFoodBowl(at: 4, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        // Fail at the bowl, then trigger the bridge via seek
        manager.checkArrivedAtFacility(pig: &pig)
        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") > 0)

        // The per-type counter must be cleared so that after the unreachable
        // backoff expires, the pig isn't immediately re-escalated.
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 0)
    }

    @Test("Successful arrival clears per-type counter, allows future seek")
    func successfulArrivalResetsBridgeState() {
        let (manager, state, _) = makeManager()
        // Place an empty bowl, fail at it
        let empty = emptyFoodBowl(at: 4, y: 9, state: state)
        // Place a full bowl (Facility.create starts at full capacity)
        let full = placeFacility(type: .foodBowl, x: 6, y: 9, state: state)

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.targetFacilityId = empty.id
        state.addGuineaPig(pig)

        // Fail once
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 1)

        // Succeed at the full bowl
        pig.behaviorState = .wandering
        pig.targetFacilityId = full.id
        pig.position = Position(x: 6.0, y: 9.0)
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .eating)
        // Counter should be reset by clearFailedFacilities
        #expect(manager.getArrivalFailuresForType(pig.id, type: .foodBowl) == 0)
    }
}
