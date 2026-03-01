/// CollisionTests — Tests for CollisionHandler (blocking, separation, rescue).
import Foundation
import Testing
@testable import BigPigFarm

// MARK: - CollisionHandler Blocking

@MainActor
struct CollisionBlockingTests {

    @Test("Default blocking: pig within 2.5 of target is blocked")
    func testIsPositionBlockedDefault() {
        let state = makeGameState()
        let blocker = makePigAt(x: 10.0, y: 10.0, state: .idle)
        state.addGuineaPig(blocker)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var mover = makePigAt(x: 7.0, y: 10.0, state: .wandering)
        mover.needs.health = 100.0
        // Target is 1.5 away from blocker — within default 2.5 threshold
        #expect(handler.isPositionBlocked(targetX: 10.0 - 1.5, targetY: 10.0, excludePig: mover))
    }

    @Test("Default blocking: pig beyond 2.5 of target is not blocked")
    func testIsPositionNotBlockedDefault() {
        let state = makeGameState()
        let blocker = makePigAt(x: 10.0, y: 10.0, state: .idle)
        state.addGuineaPig(blocker)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var mover = makePigAt(x: 3.0, y: 10.0, state: .wandering)
        mover.needs.health = 100.0
        // Target is 3.0 away from blocker — outside default 2.5 threshold
        #expect(!handler.isPositionBlocked(targetX: 7.0, targetY: 10.0, excludePig: mover))
    }

    @Test("Both-moving blocking uses 1.5 radius instead of 2.5")
    func testIsPositionBlockedBothMoving() {
        let state = makeGameState()
        let fakeSteps = [GridPosition(x: 1, y: 1)]
        let blocker = makePigAt(x: 10.0, y: 10.0, state: .wandering, path: fakeSteps)
        state.addGuineaPig(blocker)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var mover = makePigAt(x: 7.0, y: 10.0, state: .wandering, path: fakeSteps)
        mover.needs.health = 100.0
        // Target is 2.0 away — inside 2.5 default, but outside 1.5 both-moving threshold
        #expect(!handler.isPositionBlocked(targetX: 8.0, targetY: 10.0, excludePig: mover))
    }

    @Test("Facility-use blocking uses 1.5 radius")
    func testIsPositionBlockedFacilityUse() {
        let state = makeGameState()
        let blocker = makePigAt(x: 10.0, y: 10.0, state: .eating)
        state.addGuineaPig(blocker)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var mover = makePigAt(x: 7.0, y: 10.0, state: .wandering)
        mover.needs.health = 100.0
        // Target is 2.0 away from eating pig — inside 2.5 default, outside 1.5 facility threshold
        #expect(!handler.isPositionBlocked(targetX: 8.0, targetY: 10.0, excludePig: mover))
    }

    @Test("Emergency override: critical health skips all blocking")
    func testIsPositionBlockedEmergencyOverride() {
        let state = makeGameState()
        let blocker = makePigAt(x: 10.0, y: 10.0, state: .idle)
        state.addGuineaPig(blocker)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var mover = makePigAt(x: 7.0, y: 10.0, state: .wandering)
        mover.needs.health = 15.0  // below criticalThreshold (20)
        // Would normally be blocked but health override skips all checks
        #expect(!handler.isPositionBlocked(targetX: 10.0, targetY: 10.0, excludePig: mover))
    }

    @Test("Courting pig is not blocked by its partner")
    func testIsPositionBlockedCourtingPartner() {
        let state = makeGameState()
        let partner = makePigAt(x: 10.0, y: 10.0, state: .courting)
        state.addGuineaPig(partner)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        var courter = makePigAt(x: 7.0, y: 10.0, state: .courting)
        courter.needs.health = 100.0
        courter.courtingPartnerId = partner.id
        #expect(!handler.isPositionBlocked(targetX: 10.0, targetY: 10.0, excludePig: courter))
    }
}

// MARK: - CollisionHandler Cell Occupancy

@MainActor
struct CollisionCellOccupancyTests {

    @Test("isCellOccupiedByPig returns true when pig is present")
    func testIsCellOccupiedByPig() {
        let state = makeGameState()
        let pig = makePigAt(x: 5.0, y: 5.0)
        state.addGuineaPig(pig)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        #expect(handler.isCellOccupiedByPig(x: 5, y: 5, excludePig: nil))
    }

    @Test("isCellOccupiedByPig returns false when the only pig is excluded")
    func testIsCellOccupiedByPigExcluded() {
        let state = makeGameState()
        let pig = makePigAt(x: 5.0, y: 5.0)
        state.addGuineaPig(pig)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        #expect(!handler.isCellOccupiedByPig(x: 5, y: 5, excludePig: pig))
    }

    @Test("isCellOccupiedByPig returns false for empty cell")
    func testIsCellOccupiedByPigEmpty() {
        let state = makeGameState()
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        #expect(!handler.isCellOccupiedByPig(x: 10, y: 10, excludePig: nil))
    }
}

// MARK: - CollisionHandler Separation

@MainActor
struct CollisionSeparationTests {

    @Test("Two idle pigs within minPigDistance (3.0) are pushed apart")
    func testSeparateOverlappingBothIdle() throws {
        let state = makeGameState()
        let pigA = makePigAt(x: 5.0, y: 5.0, state: .idle)
        let pigB = makePigAt(x: 7.0, y: 5.0, state: .idle)  // 2.0 apart, threshold 3.0
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        let dx = updatedB.position.x - updatedA.position.x
        let dy = updatedB.position.y - updatedA.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        #expect(dist >= GameConfig.Behavior.minPigDistance)
    }

    @Test("Two moving pigs within separationBothMoving (1.0) are pushed apart")
    func testSeparateOverlappingBothMoving() throws {
        let state = makeGameState()
        let steps = [GridPosition(x: 20, y: 5)]
        let pigA = makePigAt(x: 5.0, y: 5.0, state: .wandering, path: steps)
        let pigB = makePigAt(x: 5.5, y: 5.0, state: .wandering, path: steps)  // 0.5 apart, threshold 1.0
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        let dx = updatedB.position.x - updatedA.position.x
        let dy = updatedB.position.y - updatedA.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        #expect(dist >= GameConfig.Behavior.separationBothMoving)
    }

    @Test("Courting pair at close distance is NOT separated")
    func testSeparateOverlappingSkipsCourtingPair() throws {
        let state = makeGameState()
        var pigA = makePigAt(x: 5.0, y: 5.0, state: .courting)
        var pigB = makePigAt(x: 5.3, y: 5.0, state: .courting)  // 0.3 apart, below all thresholds
        pigA.courtingPartnerId = pigB.id
        pigB.courtingPartnerId = pigA.id
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        #expect(abs(updatedA.position.x - 5.0) < 0.001)
        #expect(abs(updatedB.position.x - 5.3) < 0.001)
    }

    @Test("Exactly overlapping pigs (distance ≈ 0) get one pushed in random direction")
    func testSeparateExactOverlap() throws {
        let state = makeGameState()
        let pigA = makePigAt(x: 5.0, y: 5.0, state: .idle)
        let pigB = makePigAt(x: 5.0, y: 5.0, state: .idle)  // exact overlap
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        // Which pig is pushed depends on UUID string ordering (the canonical "second" pig in the pair
        // is always pushed). Check that the two pigs are now apart from each other.
        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        let dx = updatedB.position.x - updatedA.position.x
        let dy = updatedB.position.y - updatedA.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        #expect(dist > 0.0)
    }

    @Test("Separation is skipped when new position would be on a wall")
    func testSeparateOnlyIfBothWalkable() throws {
        let state = makeGameState()
        // pigA is close to the left wall — separation would push it off-grid
        let pigA = makePigAt(x: 1.0, y: 5.0, state: .idle)
        let pigB = makePigAt(x: 2.0, y: 5.0, state: .idle)  // 1.0 apart, threshold 3.0
        let origAx = pigA.position.x
        let origBx = pigB.position.x
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        // Separation would push A into the wall (x <= 0), so neither pig should move
        #expect(abs(updatedA.position.x - origAx) < 0.001)
        #expect(abs(updatedB.position.x - origBx) < 0.001)
    }

    @Test("Both-facility-use pigs use 1.0 separation threshold")
    func testSeparateFacilityUse() throws {
        let state = makeGameState()
        let pigA = makePigAt(x: 5.0, y: 5.0, state: .eating)
        let pigB = makePigAt(x: 6.5, y: 5.0, state: .sleeping)  // 1.5 apart, outside 1.0 facility threshold
        let origAx = pigA.position.x
        let origBx = pigB.position.x
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        handler.separateOverlappingPigs()

        // 1.5 apart > 1.0 threshold → no separation
        let updatedA = try #require(state.guineaPigs[pigA.id])
        let updatedB = try #require(state.guineaPigs[pigB.id])
        #expect(abs(updatedA.position.x - origAx) < 0.001)
        #expect(abs(updatedB.position.x - origBx) < 0.001)
    }
}

// MARK: - CollisionHandler Facility Targets

@MainActor
struct CollisionFacilityTargetTests {

    @Test("rebuildSpatialGrid indexes pigs by targetFacilityId")
    func testRebuildSpatialGridFacilityTargets() {
        let state = makeGameState()
        let facilityID = UUID()
        var pigA = makePigAt(x: 5.0, y: 5.0)
        var pigB = makePigAt(x: 8.0, y: 5.0)
        pigA.targetFacilityId = facilityID
        pigB.targetFacilityId = facilityID
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        let targeting = handler.getPigsTargetingFacility(facilityID)
        #expect(targeting.count == 2)
        #expect(targeting.contains(pigA.id))
        #expect(targeting.contains(pigB.id))
    }

    @Test("getPigsTargetingFacility returns empty for unknown facility")
    func testGetPigsTargetingFacilityEmpty() {
        let state = makeGameState()
        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()
        let targeting = handler.getPigsTargetingFacility(UUID())
        #expect(targeting.isEmpty)
    }
}

// MARK: - CollisionHandler Rescue

@MainActor
struct CollisionRescueTests {

    @Test("Pig on non-walkable cell is teleported to a walkable cell")
    func testRescueNonWalkablePigs() throws {
        let state = makeGameState()
        // The starter farm has walls at x=0 and y=0 border
        var pig = makePigAt(x: 0.0, y: 5.0, state: .wandering)  // wall cell at x=0
        pig.path = [GridPosition(x: 10, y: 5)]
        pig.targetFacilityId = UUID()
        state.addGuineaPig(pig)
        let handler = CollisionHandler(gameState: state)
        handler.rescueNonWalkablePigs([pig])

        let rescued = try #require(state.guineaPigs[pig.id])
        let gx = Int(rescued.position.x)
        let gy = Int(rescued.position.y)
        #expect(state.farm.isWalkable(gx, gy))
        #expect(rescued.path.isEmpty)
        #expect(rescued.targetFacilityId == nil)
        #expect(rescued.behaviorState == .idle)
    }

    @Test("Pig on walkable cell is not moved by rescue")
    func testRescueSkipsWalkablePig() throws {
        let state = makeGameState()
        let pig = makePigAt(x: 5.0, y: 5.0, state: .wandering)
        let origX = pig.position.x
        let origY = pig.position.y
        state.addGuineaPig(pig)
        let handler = CollisionHandler(gameState: state)
        handler.rescueNonWalkablePigs([pig])

        let after = try #require(state.guineaPigs[pig.id])
        #expect(abs(after.position.x - origX) < 0.001)
        #expect(abs(after.position.y - origY) < 0.001)
    }
}
