/// BehaviorMovementTests — Tests for BehaviorMovement waypoint consumption,
/// speed modifiers, wandering, biome target selection, and rescue logic.
import Foundation
import Testing
@testable import BigPigFarm

// MARK: - Movement Tests

@MainActor
struct BehaviorMovementTests {

    // MARK: - updateMovement

    @Test("Sleeping pig is skipped during movement update")
    func testSleepingPigIsSkipped() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .sleeping
        pig.path = [GridPosition(x: 6, y: 5), GridPosition(x: 7, y: 5)]
        let startPos = pig.position

        BehaviorMovement.updateMovement(controller: controller, pig: &pig, gameMinutes: 1.0)

        #expect(pig.position == startPos)
        #expect(pig.path.count == 2)
    }

    @Test("Empty path does not move pig")
    func testEmptyPathNoOp() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.path = []
        let startPos = pig.position

        BehaviorMovement.updateMovement(controller: controller, pig: &pig, gameMinutes: 1.0)

        #expect(pig.position == startPos)
    }

    @Test("updateMovement consumes waypoints within budget")
    func testConsumesSingleWaypoint() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 3.0, y: 3.0)
        pig.path = [GridPosition(x: 4, y: 3)]

        // baseMoveSpeed = 1.0, budget = 1.0 * 2.0 = 2.0 > dist(1.0), should reach
        BehaviorMovement.updateMovement(controller: controller, pig: &pig, gameMinutes: 2.0)

        #expect(pig.position.x == 4.0)
        #expect(pig.position.y == 3.0)
        #expect(pig.path.isEmpty)
        #expect(pig.targetPosition == nil)
    }

    @Test("Tired pig moves at half speed")
    func testTiredPigHalfSpeed() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var normalPig = makePig(x: 5.0, y: 5.0)
        normalPig.path = [GridPosition(x: 10, y: 5)]

        var tiredPig = makePig(x: 5.0, y: 5.0)
        tiredPig.needs.energy = Double(GameConfig.Behavior.energySleepThreshold) - 1.0
        tiredPig.path = [GridPosition(x: 10, y: 5)]

        BehaviorMovement.updateMovement(controller: controller, pig: &normalPig, gameMinutes: 1.0)
        BehaviorMovement.updateMovement(controller: controller, pig: &tiredPig, gameMinutes: 1.0)

        // Tired pig moves half as far
        let normalDist = abs(normalPig.position.x - 5.0)
        let tiredDist = abs(tiredPig.position.x - 5.0)
        #expect(normalDist > tiredDist)
        #expect(abs(normalDist - tiredDist * 2) < 0.01)
    }

    @Test("Baby pig moves at 0.7x speed")
    func testBabyPigSlowerSpeed() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var adultPig = makePig(x: 5.0, y: 5.0)
        adultPig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        adultPig.path = [GridPosition(x: 10, y: 5)]

        var babyPig = makePig(x: 5.0, y: 5.0)
        babyPig.ageDays = 0.5 // baby
        babyPig.path = [GridPosition(x: 10, y: 5)]

        BehaviorMovement.updateMovement(controller: controller, pig: &adultPig, gameMinutes: 1.0)
        BehaviorMovement.updateMovement(controller: controller, pig: &babyPig, gameMinutes: 1.0)

        let adultDist = abs(adultPig.position.x - 5.0)
        let babyDist = abs(babyPig.position.x - 5.0)
        #expect(adultDist > babyDist)
    }

    @Test("Blocked annotation is stripped on successful movement")
    func testBlockedAnnotationStrippedOnMove() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 3.0, y: 3.0)
        pig.path = [GridPosition(x: 4, y: 3)]
        pig.targetDescription = "going to Hideout (blocked)"

        BehaviorMovement.updateMovement(controller: controller, pig: &pig, gameMinutes: 2.0)

        #expect(pig.targetDescription == "going to Hideout")
    }

    // MARK: - clampToBounds

    @Test("clampToBounds restricts pig to walkable interior")
    func testClampToBoundsInsideWalls() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 0.0, y: 0.0) // on wall

        BehaviorMovement.clampToBounds(controller: controller, pig: &pig)

        #expect(pig.position.x >= 1.0)
        #expect(pig.position.y >= 1.0)
    }

    @Test("clampToBounds restricts pig beyond grid width")
    func testClampToBoundsBeyondGrid() {
        let state = makeGameState()
        let controller = makeController(state: state)
        let farm = state.farm
        var pig = makePig(x: Double(farm.width + 10), y: Double(farm.height + 10))

        BehaviorMovement.clampToBounds(controller: controller, pig: &pig)

        #expect(pig.position.x <= Double(farm.width - 2))
        #expect(pig.position.y <= Double(farm.height - 2))
    }

    // MARK: - startWandering

    @Test("startWandering creates a non-empty path")
    func testStartWanderingCreatesPath() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.path = []

        BehaviorMovement.startWandering(controller: controller, pig: &pig)

        #expect(!pig.path.isEmpty)
        #expect(pig.behaviorState == .wandering)
    }

    @Test("startWandering sets behavior state to wandering")
    func testStartWanderingSetsState() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle

        BehaviorMovement.startWandering(controller: controller, pig: &pig)

        #expect(pig.behaviorState == .wandering)
    }

    // MARK: - rescueToWalkable

    @Test("rescueToWalkable clears movement state")
    func testRescueToWalkableClearsState() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.path = [GridPosition(x: 9, y: 9)]
        pig.targetPosition = Position(x: 9, y: 9)
        pig.targetFacilityId = UUID()
        pig.targetDescription = "going somewhere"
        pig.behaviorState = .wandering

        BehaviorMovement.rescueToWalkable(controller: controller, pig: &pig)

        #expect(pig.path.isEmpty)
        #expect(pig.targetPosition == nil)
        #expect(pig.targetFacilityId == nil)
        #expect(pig.targetDescription == nil)
        #expect(pig.behaviorState == .idle)
    }

    @Test("rescueToWalkable moves pig to walkable cell")
    func testRescueToWalkableMovesToWalkableCell() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 0.0, y: 0.0) // on wall

        BehaviorMovement.rescueToWalkable(controller: controller, pig: &pig)

        let gx = Int(pig.position.x)
        let gy = Int(pig.position.y)
        #expect(state.farm.isWalkable(gx, gy))
    }

    // MARK: - getBiomeWanderTarget

    @Test("getBiomeWanderTarget returns color-matched area")
    func testBiomeTargetColorMatch() {
        let state = makeGameState()
        let controller = makeController(state: state)
        // randomCommon() always yields E/B/D loci → baseColor .black.
        // Meadow's signature color is .black, so this pig gets a color match.
        let pig = makePig()

        let (area, isColorMatch) = BehaviorMovement.getBiomeWanderTarget(controller: controller, pig: pig)

        #expect(area != nil)
        #expect(isColorMatch == true)
        #expect(area?.biome == .meadow)
    }

    @Test("getBiomeWanderTarget returns preferred biome as fallback")
    func testBiomeTargetPreferredBiomeFallback() {
        let state = makeGameState()
        let controller = makeController(state: state)
        // dLocus "d/d" → hasD=false → .blue (no biome in starter farm maps to blue)
        let blueGenotype = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "d", second: "d")
        )
        var pig = GuineaPig.create(name: "Test", gender: .female, genotype: blueGenotype)
        pig.position = Position(x: 5.0, y: 5.0)
        pig.behaviorState = .wandering
        pig.preferredBiome = "meadow"

        let (area, isColorMatch) = BehaviorMovement.getBiomeWanderTarget(controller: controller, pig: pig)

        #expect(area != nil)
        #expect(isColorMatch == false)
    }

    @Test("getBiomeWanderTarget returns nil when no biome matches")
    func testBiomeTargetNoBiome() {
        let state = GameState()
        state.farm = FarmGrid(width: 20, height: 20) // no areas
        let controller = makeController(state: state)
        var pig = makePig()
        pig.preferredBiome = nil

        let (area, isColorMatch) = BehaviorMovement.getBiomeWanderTarget(controller: controller, pig: pig)

        #expect(area == nil)
        #expect(isColorMatch == false)
    }

    // MARK: - BehaviorController tracking accessors

    @Test("Blocked time accumulates and resets correctly")
    func testBlockedTimeAccumulatesAndResets() {
        let state = makeGameState()
        let controller = makeController(state: state)
        let pigId = UUID()

        #expect(controller.getBlockedTime(pigId) == 0.0)
        controller.setBlockedTime(pigId, 2.5)
        #expect(controller.getBlockedTime(pigId) == 2.5)
        controller.resetBlockedState(pigId)
        #expect(controller.getBlockedTime(pigId) == 0.0)
    }

    @Test("Stuck position and timer track correctly")
    func testStuckPositionTracking() {
        let state = makeGameState()
        let controller = makeController(state: state)
        let pigId = UUID()
        let pos = GridPosition(x: 5, y: 5)

        #expect(controller.getStuckPosition(pigId) == nil)
        controller.setStuckPosition(pigId, pos)
        controller.setStuckTime(pigId, 3.0)
        #expect(controller.getStuckPosition(pigId) == pos)
        #expect(controller.getStuckTime(pigId) == 3.0)
        controller.clearStuckState(pigId)
        #expect(controller.getStuckPosition(pigId) == nil)
        #expect(controller.getStuckTime(pigId) == 0.0)
    }

    @Test("Decision timer resets correctly")
    func testDecisionTimerReset() {
        let state = makeGameState()
        let controller = makeController(state: state)
        let pigId = UUID()

        controller.setDecisionTimer(pigId, 5.0)
        #expect(controller.getDecisionTimer(pigId) == 5.0)
        controller.resetDecisionTimer(pigId)
        #expect(controller.getDecisionTimer(pigId) == 0.0)
    }
}
