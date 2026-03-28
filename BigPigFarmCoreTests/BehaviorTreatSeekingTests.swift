/// BehaviorTreatSeekingTests — Tests for treat-seeking behavior state integration.
import Foundation
import Testing
@testable import BigPigFarmCore

// MARK: - State Setup Tests

@MainActor
struct TreatSeekingStateTests {

    @Test("Setting seekingTreat state configures pig properties correctly")
    func testSeekingTreatStateSetup() {
        var pig = makePig()
        let treatPos = GridPosition(x: 15, y: 10)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = treatPos
        pig.targetPosition = Position(x: Double(treatPos.x), y: Double(treatPos.y))
        pig.targetDescription = "going to treat"
        pig.path = []

        #expect(pig.behaviorState == .seekingTreat)
        #expect(pig.targetTreatGridPosition == treatPos)
        #expect(pig.targetDescription == "going to treat")
    }

    @Test("displayState for seekingTreat is walking")
    func testDisplayStateIsWalking() {
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        #expect(pig.displayState == "walking")
    }

    @Test("seekingTreat raw value is seeking_treat")
    func testRawValue() {
        #expect(BehaviorState.seekingTreat.rawValue == "seeking_treat")
    }

    @Test("seekingTreat round-trips through Codable")
    func testCodableRoundTrip() throws {
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 10, y: 8)

        let data = try JSONEncoder().encode(pig)
        let decoded = try JSONDecoder().decode(GuineaPig.self, from: data)

        #expect(decoded.behaviorState == .seekingTreat)
        #expect(decoded.targetTreatGridPosition == GridPosition(x: 10, y: 8))
    }
}

// MARK: - Decision Guard Tests

@MainActor
struct TreatSeekingDecisionTests {

    @Test("Seeking-treat pig stays in seekingTreat after makeDecision")
    func testGuardKeepsSeeking() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = [GridPosition(x: 10, y: 8)]
        pig.needs.hunger = 80; pig.needs.thirst = 80

        BehaviorDecision.makeDecision(controller: controller, pig: &pig)

        #expect(pig.behaviorState == .seekingTreat)
        #expect(pig.targetTreatGridPosition != nil)
    }

    @Test("Seeking-treat pig cancels on critical hunger")
    func testCriticalHungerCancels() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = [GridPosition(x: 10, y: 8)]
        pig.needs.hunger = 10 // Below criticalThreshold (20)
        pig.needs.thirst = 80

        BehaviorDecision.makeDecision(controller: controller, pig: &pig)

        #expect(pig.behaviorState != .seekingTreat)
        #expect(pig.targetTreatGridPosition == nil)
        #expect(pig.path.isEmpty)
    }

    @Test("Seeking-treat pig cancels on critical thirst")
    func testCriticalThirstCancels() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.needs.thirst = 10 // Below criticalThreshold (20)
        pig.needs.hunger = 80

        BehaviorDecision.makeDecision(controller: controller, pig: &pig)

        #expect(pig.behaviorState != .seekingTreat)
        #expect(pig.targetTreatGridPosition == nil)
    }
}

// MARK: - Arrival Detection Tests

@MainActor
struct TreatArrivalTests {

    @Test("Pig at treat position with empty path transitions to idle")
    func testArrivalDetected() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 10.0, y: 8.0)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 10, y: 8)
        pig.targetPosition = Position(x: 10.0, y: 8.0)
        pig.path = [] // Path consumed — pig is at target
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        #expect(updatedPig.behaviorState == .idle)
        #expect(updatedPig.targetTreatGridPosition == nil)
        #expect(updatedPig.targetPosition == nil)
    }

    @Test("Pig near treat (manhattan distance 1) transitions to idle")
    func testNearbyArrival() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 10.0, y: 8.0)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 11, y: 8) // 1 cell away
        pig.targetPosition = Position(x: 11.0, y: 8.0)
        pig.path = []
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        #expect(updatedPig.behaviorState == .idle)
        #expect(updatedPig.targetTreatGridPosition == nil)
    }

    @Test("Pig far from treat with empty path gets new path")
    func testRePathfindsWhenFar() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 15, y: 10)
        pig.targetPosition = Position(x: 15.0, y: 10.0)
        pig.path = [] // Path consumed but pig isn't there yet
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        // On a starter grid, (5,5) → (15,10) is reachable.
        // Pig should still be seeking with a freshly computed path.
        #expect(updatedPig.behaviorState == .seekingTreat)
        #expect(!updatedPig.path.isEmpty)
    }

    @Test("Lost treat target resets pig to idle")
    func testLostTargetResetsToIdle() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = nil // Lost target
        pig.path = []
        state.addGuineaPig(pig)

        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        #expect(updatedPig.behaviorState == .idle)
    }
}

// MARK: - Movement Integration Tests

@MainActor
struct TreatMovementTests {

    @Test("Seeking-treat pig with path advances along it")
    func testMovementAlongPath() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.behaviorState = .seekingTreat
        pig.targetTreatGridPosition = GridPosition(x: 8, y: 5)
        pig.targetPosition = Position(x: 8.0, y: 5.0)
        pig.path = [
            GridPosition(x: 6, y: 5),
            GridPosition(x: 7, y: 5),
            GridPosition(x: 8, y: 5),
        ]
        state.addGuineaPig(pig)

        let originalX = pig.position.x
        var updatedPig = pig
        controller.update(pig: &updatedPig, gameMinutes: 0.3)

        // Pig should have moved toward the first waypoint
        #expect(updatedPig.position.x >= originalX)
        #expect(updatedPig.behaviorState == .seekingTreat)
    }

    @Test("Sleeping pig does not move even if seekingTreat path exists")
    func testSleepingPigDoesNotMove() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.behaviorState = .sleeping // Guard prevents seekingTreat from taking over
        pig.path = [GridPosition(x: 6, y: 5)]
        state.addGuineaPig(pig)

        let originalPos = pig.position
        var updatedPig = pig
        // BehaviorMovement.updateMovement skips sleeping pigs
        BehaviorMovement.updateMovement(controller: controller, pig: &updatedPig, gameMinutes: 0.3)

        #expect(updatedPig.position.x == originalPos.x)
        #expect(updatedPig.position.y == originalPos.y)
    }
}

// MARK: - NeedsSystem Integration

@MainActor
struct TreatSeekingNeedsTests {

    @Test("seekingTreat does not apply special behavior recovery")
    func testNoSpecialRecovery() {
        let state = makeGameState()
        var pig = makePig()
        pig.behaviorState = .seekingTreat
        pig.needs.hunger = 50; pig.needs.thirst = 50
        pig.needs.energy = 50; pig.needs.happiness = 50

        let initialNeeds = pig.needs
        NeedsSystem.updateAllNeeds(pig: &pig, gameMinutes: 0.3, state: state, nearbyCount: 0)

        // seekingTreat follows the idle/wandering/courting break path — no special recovery.
        // Needs should decay normally (hunger/thirst decrease, etc.) but no state-specific boost.
        // Hunger should decrease (natural decay) — not increase.
        #expect(pig.needs.hunger <= initialNeeds.hunger)
    }
}
