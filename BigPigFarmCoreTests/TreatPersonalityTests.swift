/// TreatPersonalityTests — Tests for personality-based treat movement modifiers.
/// Covers: greedy/brave/lazy speed multipliers, shy reaction delay, and modifier stacking.
import Foundation
import Testing
@testable import BigPigFarmCore

// MARK: - Speed Modifier Tests

@MainActor
struct TreatSpeedModifierTests {

    @Test("Greedy pig computes faster speed when seekingTreat")
    func testGreedyTreatSpeed() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var greedyPig = makePig()
        greedyPig.personality = [.greedy]
        greedyPig.behaviorState = .seekingTreat

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat

        let greedySpeed = BehaviorMovement.computeSpeed(controller: controller, pig: greedyPig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        #expect(greedySpeed == normalSpeed * GameConfig.Behavior.greedyTreatSpeedMult)
    }

    @Test("Brave pig computes slightly faster speed when seekingTreat")
    func testBraveTreatSpeed() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var bravePig = makePig()
        bravePig.personality = [.brave]
        bravePig.behaviorState = .seekingTreat

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat

        let braveSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: bravePig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        #expect(braveSpeed == normalSpeed * GameConfig.Behavior.braveTreatSpeedMult)
    }

    @Test("Lazy pig computes slower speed when seekingTreat")
    func testLazyTreatSpeed() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var lazyPig = makePig()
        lazyPig.personality = [.lazy]
        lazyPig.behaviorState = .seekingTreat

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat

        let lazySpeed = BehaviorMovement.computeSpeed(controller: controller, pig: lazyPig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        #expect(lazySpeed == normalSpeed * GameConfig.Behavior.lazyTreatSpeedMult)
        #expect(lazySpeed < normalSpeed)
    }

    @Test("Speed modifiers stack for pig with multiple traits")
    func testSpeedModifiersStack() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var multiPig = makePig()
        multiPig.personality = [.greedy, .brave]
        multiPig.behaviorState = .seekingTreat

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat

        let multiSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: multiPig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        let expected = normalSpeed
            * GameConfig.Behavior.greedyTreatSpeedMult
            * GameConfig.Behavior.braveTreatSpeedMult
        #expect(abs(multiSpeed - expected) < 0.001)
    }

    @Test("Personality modifiers do NOT apply when pig is wandering")
    func testModifiersOnlyApplyWhenSeekingTreat() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var greedyPig = makePig()
        greedyPig.personality = [.greedy]
        greedyPig.behaviorState = .wandering

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .wandering

        let greedySpeed = BehaviorMovement.computeSpeed(controller: controller, pig: greedyPig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        #expect(greedySpeed == normalSpeed)
    }

    @Test("Non-affecting personalities (social, picky) do not change treat speed")
    func testNonAffectingTraits() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var socialPig = makePig()
        socialPig.personality = [.social]
        socialPig.behaviorState = .seekingTreat

        var normalPig = makePig()
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat

        let socialSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: socialPig)
        let normalSpeed = BehaviorMovement.computeSpeed(controller: controller, pig: normalPig)

        #expect(socialSpeed == normalSpeed)
    }
}

// MARK: - Movement Integration Tests

@MainActor
struct TreatSpeedMovementTests {

    @Test("Greedy pig advances further per tick than normal pig when seeking treat")
    func testGreedyPigMovesFurther() {
        let state = makeGameState()
        let controller = makeController(state: state)

        var greedyPig = makePig(x: 5.0, y: 5.0)
        greedyPig.personality = [.greedy]
        greedyPig.behaviorState = .seekingTreat
        greedyPig.path = [GridPosition(x: 10, y: 5)]

        var normalPig = makePig(x: 5.0, y: 5.0)
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat
        normalPig.path = [GridPosition(x: 10, y: 5)]

        BehaviorMovement.updateMovement(controller: controller, pig: &greedyPig, gameMinutes: 0.3)
        BehaviorMovement.updateMovement(controller: controller, pig: &normalPig, gameMinutes: 0.3)

        let greedyDist = greedyPig.position.x - 5.0
        let normalDist = normalPig.position.x - 5.0
        #expect(greedyDist > normalDist)
    }

    @Test("Lazy pig advances less per tick than normal pig when seeking treat")
    func testLazyPigMovesSlower() {
        let state = makeGameState()
        let controller = makeController(state: state)

        var lazyPig = makePig(x: 5.0, y: 5.0)
        lazyPig.personality = [.lazy]
        lazyPig.behaviorState = .seekingTreat
        lazyPig.path = [GridPosition(x: 10, y: 5)]

        var normalPig = makePig(x: 5.0, y: 5.0)
        normalPig.personality = []
        normalPig.behaviorState = .seekingTreat
        normalPig.path = [GridPosition(x: 10, y: 5)]

        BehaviorMovement.updateMovement(controller: controller, pig: &lazyPig, gameMinutes: 0.3)
        BehaviorMovement.updateMovement(controller: controller, pig: &normalPig, gameMinutes: 0.3)

        let lazyDist = lazyPig.position.x - 5.0
        let normalDist = normalPig.position.x - 5.0
        #expect(lazyDist < normalDist)
    }
}

// MARK: - Shy Delay Tests

@MainActor
struct TreatShyDelayTests {

    @Test("Shy pig does not pathfind on first tick after treat dispatch")
    func testShyPigHesitates() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.personality = [.shy]
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetTreatType = .leafyGreens
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = []
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        // Shy pig should still be seeking but without a path (hesitating)
        #expect(updatedPig.behaviorState == .seekingTreat)
        #expect(updatedPig.path.isEmpty)
        #expect(controller.getShyTreatDelay(pig.id) != nil)
    }

    @Test("Shy pig pathfinds after delay expires")
    func testShyDelayExpiry() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.personality = [.shy]
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetTreatType = .leafyGreens
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = []
        state.addGuineaPig(pig)

        // Tick enough game-minutes to exhaust the shy delay
        let delay = GameConfig.Behavior.shyTreatReactionDelay
        var updatedPig = pig
        // First tick: initializes delay and decrements by 0.3 → remaining ≈ 1.7
        controller.update(pig: &updatedPig, gameMinutes: 0.3)
        state.updateGuineaPig(updatedPig)

        // Tick until delay is consumed (each tick = 0.3 game-minutes)
        let ticksNeeded = Int(ceil(delay / 0.3)) + 1
        for _ in 0..<ticksNeeded {
            controller.update(pig: &updatedPig, gameMinutes: 0.3)
            state.updateGuineaPig(updatedPig)
        }

        // After delay expires, pig should have a path (or arrived if close enough)
        #expect(updatedPig.behaviorState == .seekingTreat)
        #expect(!updatedPig.path.isEmpty)
    }

    @Test("Non-shy pig pathfinds immediately on first tick")
    func testNonShyPigPathfindsImmediately() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.personality = [.greedy] // Not shy
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetTreatType = .leafyGreens
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = []
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        // Non-shy pig should have computed a path immediately
        #expect(updatedPig.behaviorState == .seekingTreat)
        #expect(!updatedPig.path.isEmpty)
        #expect(controller.getShyTreatDelay(pig.id) == nil)
    }

    @Test("Shy delay is cleaned up when pig arrives at treat")
    func testShyDelayCleanupOnArrival() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 10.0, y: 8.0)
        pig.personality = [.shy]
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 10, y: 8) // Already at target
        pig.targetTreatType = .leafyGreens
        pig.targetPosition = Position(x: 10.0, y: 8.0)
        pig.path = []
        state.addGuineaPig(pig)

        // Even though pig is shy, it's already at the target — arrival takes priority.
        // The first tick initializes delay, but arrival check sees manhattan distance 0.
        // We need to tick past the shy delay first, then arrival fires.
        let delay = GameConfig.Behavior.shyTreatReactionDelay
        var updatedPig = pig
        let ticksNeeded = Int(ceil(delay / 0.3)) + 2
        for _ in 0..<ticksNeeded {
            controller.update(pig: &updatedPig, gameMinutes: 0.3)
            state.updateGuineaPig(updatedPig)
        }

        #expect(updatedPig.behaviorState == .idle)
        #expect(controller.getShyTreatDelay(pig.id) == nil)
    }

    @Test("Shy delay is cleaned up on cleanupDeadPig")
    func testShyDelayCleanupOnDeath() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.personality = [.shy]
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetTreatType = .leafyGreens
        pig.path = []
        state.addGuineaPig(pig)

        // Initialize the shy delay
        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)
        #expect(controller.getShyTreatDelay(pig.id) != nil)

        // Clean up the pig
        controller.cleanupDeadPig(pig.id)
        #expect(controller.getShyTreatDelay(pig.id) == nil)
    }

    @Test("Shy delay is cleaned up on resetAllTracking")
    func testShyDelayCleanupOnReset() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.personality = [.shy]
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetTreatType = .leafyGreens
        pig.path = []
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)
        #expect(controller.getShyTreatDelay(pig.id) != nil)

        controller.resetAllTracking()
        #expect(controller.getShyTreatDelay(pig.id) == nil)
    }
}
