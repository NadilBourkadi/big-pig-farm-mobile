/// BehaviorSocializingCommitmentTests — Tests for the socializing commitment
/// counter (bead oxp8). Verifies that pigs commit to a minimum number of
/// decision cycles in the `.socializing` state, preventing rapid partner-
/// flipping when the spatial grid changes between ticks.
import Foundation
import Testing
@testable import BigPigFarmCore

@MainActor
struct BehaviorSocializingCommitmentTests {

    // MARK: - Helpers

    // swiftlint:disable:next large_tuple
    func makeManager() -> (FacilityManager, GameState, BehaviorController) {
        let state = makeGameState()
        let controller = makeController(state: state)
        return (controller.facilityManager, state, controller)
    }

    func nonCriticalPig(at x: Double, y: Double) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.position = Position(x: x, y: y)
        pig.behaviorState = .wandering
        pig.needs.hunger = 80.0
        pig.needs.thirst = 80.0
        pig.personality = []
        return pig
    }

    // MARK: - Counter accessors

    @Test("Socializing commitment starts at zero by default")
    func commitmentDefaultZero() {
        let (_, _, controller) = makeManager()
        #expect(controller.getSocializingCommitment(UUID()) == 0)
    }

    @Test("startSocializingCommitment sets the configured value")
    func startSetsCommitment() {
        let (_, _, controller) = makeManager()
        let id = UUID()
        controller.startSocializingCommitment(id)
        #expect(controller.getSocializingCommitment(id)
            == GameConfig.Behavior.socializingMinCommitmentCycles)
    }

    @Test("decrementSocializingCommitment ticks down by 1")
    func decrementTicksDown() {
        let (_, _, controller) = makeManager()
        let id = UUID()
        controller.startSocializingCommitment(id)
        let initial = GameConfig.Behavior.socializingMinCommitmentCycles
        let after = controller.decrementSocializingCommitment(id)
        #expect(after == initial - 1)
        #expect(controller.getSocializingCommitment(id) == initial - 1)
    }

    @Test("Decrement removes entry when reaching zero")
    func decrementClearsAtZero() {
        let (_, _, controller) = makeManager()
        let id = UUID()
        controller.startSocializingCommitment(id)
        for _ in 0..<GameConfig.Behavior.socializingMinCommitmentCycles {
            controller.decrementSocializingCommitment(id)
        }
        #expect(controller.getSocializingCommitment(id) == 0)
        // Further decrements stay at 0
        let after = controller.decrementSocializingCommitment(id)
        #expect(after == 0)
    }

    @Test("clearSocializingCommitment zeroes the counter")
    func clearZeroes() {
        let (_, _, controller) = makeManager()
        let id = UUID()
        controller.startSocializingCommitment(id)
        controller.clearSocializingCommitment(id)
        #expect(controller.getSocializingCommitment(id) == 0)
    }

    @Test("cleanupDeadPig clears socializing commitment")
    func cleanupDeadPigClearsCommitment() {
        let (_, _, controller) = makeManager()
        let id = UUID()
        controller.startSocializingCommitment(id)
        controller.cleanupDeadPig(id)
        #expect(controller.getSocializingCommitment(id) == 0)
    }

    // MARK: - Decision integration

    @Test("Socializing pig stays committed across decision cycles even with low social need")
    func socializingStaysCommittedDespiteLowNeed() {
        let (_, state, controller) = makeManager()

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.behaviorState = .socializing
        pig.needs.social = 100  // Already satisfied — would normally exit immediately
        pig.targetDescription = "going to friend"
        state.addGuineaPig(pig)
        controller.startSocializingCommitment(pig.id)

        let initialCommitment = controller.getSocializingCommitment(pig.id)
        // Cover all committed cycles, not just the first N-1 — the final
        // committed cycle should also keep the pig in `.socializing`.
        for _ in 0..<initialCommitment {
            BehaviorDecision.makeDecision(controller: controller, pig: &pig)
            #expect(pig.behaviorState == .socializing, "Pig should stay committed to socializing")
        }
    }

    @Test("Critical hunger overrides socializing commitment")
    func criticalHungerOverridesCommitment() {
        let (_, state, controller) = makeManager()

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.behaviorState = .socializing
        pig.needs.social = 50
        pig.needs.hunger = Double(GameConfig.Needs.criticalThreshold) - 5.0
        pig.targetDescription = "going to friend"
        state.addGuineaPig(pig)
        controller.startSocializingCommitment(pig.id)

        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState != .socializing)
        #expect(controller.getSocializingCommitment(pig.id) == 0)
    }

    @Test("Commitment expires after socializingMinCommitmentCycles, allowing exit when satisfied")
    func commitmentExpiresAndExits() {
        let (_, state, controller) = makeManager()

        var pig = nonCriticalPig(at: 5.0, y: 9.0)
        pig.behaviorState = .socializing
        pig.needs.social = 100  // Already satisfied
        pig.targetDescription = "going to friend"
        state.addGuineaPig(pig)
        controller.startSocializingCommitment(pig.id)

        // Burn through commitment
        let cycles = GameConfig.Behavior.socializingMinCommitmentCycles
        for _ in 0..<cycles {
            BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        }
        // After commitment expires, satisfied pig should exit on next decision
        BehaviorDecision.makeDecision(controller: controller, pig: &pig)
        #expect(pig.behaviorState != .socializing)
    }
}
