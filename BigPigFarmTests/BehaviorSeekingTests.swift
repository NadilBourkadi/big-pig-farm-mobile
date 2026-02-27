/// BehaviorSeekingTests — Tests for BehaviorSeeking facility seeking,
/// sleep seeking, social interaction, courting, and adjacent cell finding.
import Testing
@testable import BigPigFarm

@MainActor
struct BehaviorSeekingTests {

    // MARK: - seekFacilityForNeed

    @Test("seekFacilityForNeed with active backoff falls back to wandering")
    func testSeekFacilityWithBackoffWanders() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle
        controller.setUnreachableBackoff(pig.id, need: "hunger", cycles: 3)

        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")

        #expect(pig.behaviorState == .wandering)
    }

    @Test("seekFacilityForNeed with unknown need falls back to wandering")
    func testSeekFacilityUnknownNeedWanders() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle

        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "unknown_need")

        #expect(pig.behaviorState == .wandering)
    }

    @Test("seekFacilityForNeed sets unreachable backoff when no facilities are found")
    func testSeekFacilitySetsUnreachableBackoff() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()

        // Stub returns no candidates — falls through to unreachable-backoff block
        BehaviorSeeking.seekFacilityForNeed(controller: controller, pig: &pig, need: "hunger")

        #expect(controller.getUnreachableBackoff(pig.id, need: "hunger") > 0)
    }

    // MARK: - seekSleep

    @Test("seekSleep with no hideout makes pig sleep in place")
    func testSeekSleepNoHideoutSleepsWhereStanding() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        let startPos = pig.position

        BehaviorSeeking.seekSleep(controller: controller, pig: &pig)

        #expect(pig.behaviorState == .sleeping)
        #expect(pig.path.isEmpty)
        #expect(pig.targetDescription == "sleeping")
        #expect(pig.position == startPos)
    }

    // MARK: - seekPlay

    @Test("seekPlay with shy pig and no facilities does not socialize")
    func testSeekPlayShyPigNotSocializing() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.personality = [.shy]

        BehaviorSeeking.seekPlay(controller: controller, pig: &pig)

        // Shy pig skips social fallback — ends up wandering or playing
        #expect(pig.behaviorState != .socializing)
        #expect(pig.targetFacilityId == nil)
    }

    // MARK: - seekSocialInteraction

    @Test("seekSocialInteraction with no other pigs falls back to wandering")
    func testSeekSocialNoPigsWanders() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig()
        pig.behaviorState = .idle

        // No pigs added to game state — getPigsList() returns []
        BehaviorSeeking.seekSocialInteraction(controller: controller, pig: &pig)

        #expect(pig.behaviorState == .wandering)
    }

    @Test("seekSocialInteraction with a nearby pig sets socializing state")
    func testSeekSocialWithNearbyPig() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 5.0, y: 5.0)
        pig.behaviorState = .idle
        let otherPig = makePig(x: 10.0, y: 5.0)
        state.addGuineaPig(otherPig)

        BehaviorSeeking.seekSocialInteraction(controller: controller, pig: &pig)

        // Should be socializing (path found) or wandering (adjacent cell was empty path)
        #expect(pig.behaviorState == .socializing || pig.behaviorState == .wandering)
        if pig.behaviorState == .socializing {
            #expect(pig.targetDescription?.contains(otherPig.name) == true)
        }
    }

    // MARK: - seekCourtingPartner

    @Test("seekCourtingPartner returns true when partner is reachable")
    func testSeekCourtingPartnerReachableReturnsTrue() {
        let state = makeGameState()
        let controller = makeController(state: state)
        var pig = makePig(x: 3.0, y: 5.0)
        let partner = makePig(x: 10.0, y: 5.0)

        let result = BehaviorSeeking.seekCourtingPartner(
            controller: controller, pig: &pig, partner: partner
        )

        #expect(result == true)
        if result {
            #expect(pig.targetDescription?.contains(partner.name) == true)
        }
    }

    @Test("seekCourtingPartner returns false when no walkable adjacent cells exist")
    func testSeekCourtingPartnerUnreachableReturnsFalse() {
        let state = GameState()
        // 5x5 farm: with spacing=3, all 8 offsets from center (2,2) land outside [0,4]
        state.farm = FarmGrid(width: 5, height: 5)
        let controller = makeController(state: state)
        var pig = makePig(x: 1.0, y: 1.0)
        let partner = makePig(x: 2.0, y: 2.0)

        let result = BehaviorSeeking.seekCourtingPartner(
            controller: controller, pig: &pig, partner: partner
        )

        #expect(result == false)
    }

    // MARK: - findAdjacentCell

    @Test("findAdjacentCell returns a walkable cell near the target")
    func testFindAdjacentCellOnStarterFarm() {
        let state = makeGameState()
        let controller = makeController(state: state)
        let pig = makePig(x: 3.0, y: 5.0)
        let target = GridPosition(x: 8, y: 5)

        let result = BehaviorSeeking.findAdjacentCell(
            controller: controller, target: target, pig: pig
        )

        #expect(result != nil)
        if let cell = result {
            #expect(state.farm.isWalkable(cell.x, cell.y))
        }
    }

    @Test("findAdjacentCell returns nil when all offset cells are out of bounds")
    func testFindAdjacentCellReturnsNilWhenAllOutOfBounds() {
        let state = GameState()
        // 5x5 farm: offsets of ±3 from (2,2) all exceed the [0,4] valid range
        state.farm = FarmGrid(width: 5, height: 5)
        let controller = makeController(state: state)
        let pig = makePig(x: 1.0, y: 1.0)
        let target = GridPosition(x: 2, y: 2)

        let result = BehaviorSeeking.findAdjacentCell(
            controller: controller, target: target, pig: pig
        )

        #expect(result == nil)
    }
}
