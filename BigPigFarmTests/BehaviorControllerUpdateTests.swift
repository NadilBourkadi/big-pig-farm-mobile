/// BehaviorControllerUpdateTests — Tests for BehaviorController.update() orchestration:
/// decision timer gating, emergency interval override, courtship timer advancement,
/// area-change backoff clearing, and default wander/idle fallback.
import Foundation
import Testing
@testable import BigPigFarm

// MARK: - Decision Timer Gating Tests

@MainActor
struct BehaviorDecisionTimerTests {

    @Test("update() does not fire decision when timer has not expired")
    func testUpdateDoesNotDecideBeforeTimerExpires() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.energy = 95 // would wake if decision fires
        // Pre-set timer so newTimer = 1.5 + 0.4 = 1.9 < decisionIntervalSeconds (2.0)
        controller.setDecisionTimer(pig.id, 1.5)
        controller.update(pig: &pig, gameMinutes: 0.4)
        // Timer hasn't expired — no decision fired — pig stays sleeping
        #expect(pig.behaviorState == .sleeping)
    }

    @Test("update() fires decision when timer expires")
    func testUpdateDecidesWhenTimerExpires() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.energy = 95 // will wake if decision fires
        // Pre-set timer so newTimer = 1.5 + 1.0 = 2.5 >= decisionIntervalSeconds (2.0)
        controller.setDecisionTimer(pig.id, 1.5)
        controller.update(pig: &pig, gameMinutes: 1.0)
        // Decision fired — pig should have woken up
        #expect(pig.behaviorState == .idle || pig.behaviorState == .wandering)
    }

    @Test("Emergency override fires decision immediately regardless of timer")
    func testEmergencyOverrideFiresImmediately() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.hunger = 10 // critical — emergency interval = 0
        pig.needs.energy = 25 // above emergencyWakeEnergy — will wake up
        controller.setDecisionTimer(pig.id, 0.0) // timer at zero, not expired normally
        controller.update(pig: &pig, gameMinutes: 0.05) // tiny tick, but 0.05 >= 0.0
        // Emergency: pig woke up due to critical hunger
        #expect(pig.behaviorState == .idle || pig.behaviorState == .wandering)
    }
}

// MARK: - Courtship Timer Tests

@MainActor
struct BehaviorDecisionCourtshipTimerTests {

    @Test("Courtship timer advances when initiator is adjacent to partner")
    func testCourtshipTimerAdvancesWhenAdjacent() throws {
        let state = makeGameState()
        let controller = makeController(state: state)
        var male = makePig(x: 5.0, y: 5.0)
        var female = makePig(x: 6.0, y: 5.0) // within minPigDistance + 2 = 5.0
        male.behaviorState = .courting
        male.courtingInitiator = true
        male.courtingPartnerId = female.id
        male.courtingTimer = 0.0
        male.path = []
        female.behaviorState = .courting
        female.courtingPartnerId = male.id
        state.addGuineaPig(male)
        state.addGuineaPig(female)
        var updatedMale = try #require(state.getGuineaPig(male.id))
        // Do NOT pre-set decision timer: forcing a decision would call seekCourtingPartner,
        // setting a non-empty path that blocks updateCurrentBehavior from advancing the timer.
        // With no pre-set timer, newTimer < decisionIntervalSeconds so decision never fires.
        controller.update(pig: &updatedMale, gameMinutes: 0.5)
        // courtingTimer should have increased (updateCurrentBehavior advances it)
        #expect(updatedMale.courtingTimer > 0.0)
    }

    @Test("Completed courtship is queued when timer crosses threshold")
    func testCourtshipCompletionQueued() throws {
        let state = makeGameState()
        let controller = makeController(state: state)
        var male = makePig(x: 5.0, y: 5.0)
        var female = makePig(x: 6.0, y: 5.0)
        let threshold = GameConfig.Behavior.courtshipTogetherSeconds // 4.0
        male.behaviorState = .courting
        male.courtingInitiator = true
        male.courtingPartnerId = female.id
        male.courtingTimer = threshold - 0.1 // just below threshold
        male.path = []
        female.behaviorState = .courting
        female.courtingPartnerId = male.id
        state.addGuineaPig(male)
        state.addGuineaPig(female)
        var updatedMale = try #require(state.getGuineaPig(male.id))
        // Do NOT pre-set decision timer: forcing a decision calls seekCourtingPartner which
        // sets a path, preventing updateCurrentBehavior from advancing the courtship timer.
        // Advance enough to cross the threshold (3.9 + 0.2 = 4.1 >= courtshipTogetherSeconds=4.0)
        controller.update(pig: &updatedMale, gameMinutes: 0.2)
        let completed = controller.drainCompletedCourtships()
        #expect(!completed.isEmpty)
        #expect(completed.first?.0 == male.id || completed.first?.1 == female.id)
    }
}

// MARK: - Area Change Tests

@MainActor
struct BehaviorDecisionAreaTests {

    @Test("Unreachable backoff is cleared when pig moves to a new area")
    func testAreaChangeClearsUnreachableBackoff() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.currentAreaId = UUID() // some area ID
        // Set an unreachable backoff
        controller.setUnreachableBackoff(pig.id, need: "hunger", cycles: 3)
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") == 3)
        // Move pig to a new area by changing currentAreaId during update.
        // farm.getAreaAt() for the starter farm returns nil at the default pig position,
        // so newAreaId = nil != pig.currentAreaId (UUID) → backoff is cleared.
        controller.update(pig: &pig, gameMinutes: 0.1)
        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") == 0)
    }
}

// MARK: - Default Behavior Tests

@MainActor
struct BehaviorDecisionDefaultTests {

    @Test("Pig with all needs satisfied and no traits makes a valid decision")
    func testSatisfiedPigMakesValidDecision() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle
        pig.personality = [] // No personality traits
        pig.needs.hunger = 90; pig.needs.thirst = 90; pig.needs.energy = 90
        pig.needs.happiness = 90; pig.needs.social = 90; pig.needs.boredom = 5
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // Phases 9-12 handle a satisfied pig — result is idle or wandering
        let validStates: Set<BehaviorState> = [.idle, .wandering]
        #expect(validStates.contains(pig.behaviorState))
    }
}
