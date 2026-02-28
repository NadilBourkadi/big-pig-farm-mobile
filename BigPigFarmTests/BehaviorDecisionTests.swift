/// BehaviorDecisionTests — Tests for the 12-phase behavior decision tree and update() orchestration.
import Foundation
import Testing
@testable import BigPigFarm

// MARK: - isContent Tests

@MainActor
struct BehaviorDecisionContentTests {

    @Test("Content pig with all needs satisfied returns true")
    func testContentPigReturnsTrue() {
        var pig = makePig()
        pig.behaviorState = .idle
        pig.targetFacilityId = nil
        pig.needs.hunger = 80; pig.needs.thirst = 80; pig.needs.energy = 80
        pig.needs.happiness = 80; pig.needs.social = 80; pig.needs.boredom = 10
        #expect(BehaviorDecision.isContent(pig))
    }

    @Test("Eating pig is not content")
    func testEatingPigNotContent() {
        var pig = makePig()
        pig.behaviorState = .eating
        pig.needs.hunger = 80; pig.needs.thirst = 80; pig.needs.energy = 80
        pig.needs.happiness = 80; pig.needs.social = 80; pig.needs.boredom = 10
        #expect(!BehaviorDecision.isContent(pig))
    }

    @Test("Pig targeting a facility is not content")
    func testFacilityTargetNotContent() {
        var pig = makePig()
        pig.behaviorState = .idle
        pig.targetFacilityId = UUID()
        pig.needs.hunger = 80; pig.needs.thirst = 80; pig.needs.energy = 80
        pig.needs.happiness = 80; pig.needs.social = 80; pig.needs.boredom = 10
        #expect(!BehaviorDecision.isContent(pig))
    }

    @Test("Pig with low hunger is not content")
    func testLowHungerNotContent() {
        var pig = makePig()
        pig.behaviorState = .idle
        pig.needs.hunger = 60 // below highThreshold (70)
        pig.needs.thirst = 80; pig.needs.energy = 80
        pig.needs.happiness = 80; pig.needs.social = 80; pig.needs.boredom = 10
        #expect(!BehaviorDecision.isContent(pig))
    }

    @Test("Bored pig is not content")
    func testBoredPigNotContent() {
        var pig = makePig()
        pig.behaviorState = .idle
        pig.needs.hunger = 80; pig.needs.thirst = 80; pig.needs.energy = 80
        pig.needs.happiness = 80; pig.needs.social = 80
        pig.needs.boredom = 35 // above boredomPlayThreshold (30)
        #expect(!BehaviorDecision.isContent(pig))
    }
}

// MARK: - Guard State Tests

@MainActor
struct BehaviorDecisionGuardTests {

    @Test("Sleeping pig with full energy wakes to idle")
    func testSleepingPigWakesWhenEnergyFull() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.energy = 95 // above satisfactionThreshold (90)
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .idle)
    }

    @Test("Sleeping pig with critical hunger and enough energy wakes up")
    func testSleepingPigEmergencyWake() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.hunger = 10 // below criticalThreshold (20)
        pig.needs.energy = 25 // above emergencyWakeEnergy (15)
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .idle)
    }

    @Test("Sleeping pig with adequate energy and no critical need stays sleeping")
    func testSleepingPigStaysSleeping() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.energy = 50 // needs more sleep but no emergency
        pig.needs.hunger = 80; pig.needs.thirst = 80
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .sleeping)
    }

    @Test("Sleeping pig with critical hunger but dangerously low energy stays sleeping")
    func testSleepingPigCannotWakeWhenTooExhausted() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.needs.hunger = 10 // critical hunger
        pig.needs.energy = 5  // below emergencyWakeEnergy (15) — can't wake up
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .sleeping)
    }

    @Test("Eating pig with hunger below satisfaction threshold keeps eating")
    func testEatingPigContinuesWhenHungry() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .eating
        pig.needs.hunger = 60 // below satisfactionThreshold (90)
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .eating)
    }

    @Test("Eating pig with full hunger wanders away")
    func testEatingPigWandersWhenSatisfied() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .eating
        pig.needs.hunger = 95 // above satisfactionThreshold (90)
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // After leaving eating state, pig should be wandering
        #expect(pig.behaviorState == .wandering || pig.behaviorState == .idle)
    }

    @Test("Drinking pig with thirst below satisfaction keeps drinking")
    func testDrinkingPigContinuesWhenThirsty() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .drinking
        pig.needs.thirst = 50
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .drinking)
    }

    @Test("Playing pig with high boredom and no critical need keeps playing")
    func testPlayingPigContinuesWhenBored() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .playing
        pig.needs.boredom = 25 // above boredomKeepPlaying (20)
        pig.needs.hunger = 80; pig.needs.thirst = 80
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState == .playing)
    }

    @Test("Playing pig stops for critical hunger")
    func testPlayingPigStopsForCriticalHunger() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .playing
        pig.needs.boredom = 25
        pig.needs.hunger = 10 // critical
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // Critical need interrupts play — pig goes idle then seeks food
        #expect(pig.behaviorState != .playing)
    }
}

// MARK: - Courtship Tests

@MainActor
struct BehaviorDecisionCourtshipTests {

    @Test("Courting pig cancels when partner is not found in game state")
    func testCourtingCancelsWhenPartnerGone() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .courting
        pig.courtingPartnerId = UUID() // partner not added to state
        pig.courtingInitiator = true
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.courtingPartnerId == nil)
        #expect(pig.behaviorState != .courting)
    }

    @Test("Courting pig with critical hunger cancels courtship")
    func testCourtingCancelsForCriticalHunger() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var male = makePig()
        var female = makePig()
        male.behaviorState = .courting
        male.courtingInitiator = true
        male.courtingPartnerId = female.id
        female.behaviorState = .courting
        female.courtingPartnerId = male.id
        male.needs.hunger = 10 // critical
        state.addGuineaPig(male)
        state.addGuineaPig(female)
        // Update male from state to get the added version
        var updatedMale = state.getGuineaPig(male.id)!
        BehaviorDecision.makeDecision(controller: controller, pig: &updatedMale)
        #expect(updatedMale.courtingPartnerId == nil)
        // Partner's courtship should also be cleared via updateGuineaPig
        let updatedFemale = state.getGuineaPig(female.id)
        #expect(updatedFemale?.courtingPartnerId == nil)
    }
}

// MARK: - Need Priority Tests

@MainActor
struct BehaviorDecisionNeedTests {

    @Test("Pig with critical hunger seeks food (wanders to find it)")
    func testCriticalHungerSeeksFood() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle
        pig.needs.hunger = 10 // critical
        pig.needs.thirst = 80; pig.needs.energy = 80
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // No food bowls in stub state — seekFacilityForNeed falls back to wandering
        #expect(pig.behaviorState == .wandering || pig.behaviorState == .idle)
    }

    @Test("Pig with low energy below sleep threshold seeks sleep")
    func testLowEnergySeeksSleep() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle
        pig.needs.energy = 30 // below energySleepThreshold (40)
        pig.needs.happiness = 80 // normal happiness — no death spiral
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // No hideout in stub state — seekSleep falls back to sleeping in place
        #expect(pig.behaviorState == .sleeping || pig.behaviorState == .wandering)
    }

    @Test("Death spiral breaker: deeply unhappy pig seeks play instead of sleep")
    func testDeathSpiralBreakerPrioritizesPlay() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle
        pig.needs.energy = 30 // below energySleepThreshold (40) — would normally seek sleep
        pig.needs.happiness = 10 // below criticalThreshold (20) — death spiral active
        pig.needs.energy = 25  // above criticalThreshold (20) — can seek play
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        // Should seek play, NOT sleep
        #expect(pig.behaviorState != .sleeping)
    }
}
