/// CollisionFacilityRescueTests — Tests for CollisionHandler facility targets and rescue.
import Foundation
import Testing
@testable import BigPigFarmCore

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
