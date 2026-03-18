/// SpatialGridMovePigTests — Tests for SpatialGrid.movePig incremental bucket updates.
import Foundation
import Testing
@testable import BigPigFarmCore

// MARK: - SpatialGrid Incremental Updates

@MainActor
struct SpatialGridMovePigTests {

    @Test("movePig re-buckets UUID: old bucket loses it, new bucket exposes it via getNearby")
    func testMovePigCrossBucketRebuckets() {
        var grid = SpatialGrid()
        let pig = makePigAt(x: 3.0, y: 3.0)  // bucket (0,0) with cellSize=5
        grid.rebuild(pigs: [pig])

        // Simulate pig moving to (30.0, 3.0) — bucket (6,0), non-adjacent to (0,0)
        var movedPig = pig
        movedPig.position = Position(x: 30.0, y: 3.0)
        let pigDict: [UUID: GuineaPig] = [movedPig.id: movedPig]

        // Before movePig: stale bucket means pig is invisible at new position
        let beforeFix = grid.getNearby(x: 30.0, y: 3.0, pigs: pigDict)
        #expect(beforeFix.isEmpty, "Stale grid should miss pig that moved across bucket boundary")

        // After movePig: incremental update makes pig visible at new position
        grid.movePig(id: pig.id, from: pig.position, to: movedPig.position)
        let afterFix = grid.getNearby(x: 30.0, y: 3.0, pigs: pigDict)
        #expect(afterFix.count == 1, "Updated grid should find pig at new bucket")
        #expect(afterFix[0].id == pig.id)
    }

    @Test("movePig is no-op when pig stays in the same bucket")
    func testMovePigSameBucketNoOp() {
        var grid = SpatialGrid()
        let pig = makePigAt(x: 3.0, y: 3.0)  // bucket (0,0)
        grid.rebuild(pigs: [pig])

        // Move within same bucket (3.0→4.0, both map to Int(x)/5 = 0)
        var sameId = pig
        sameId.position = Position(x: 4.0, y: 3.0)
        let pigDict: [UUID: GuineaPig] = [sameId.id: sameId]

        grid.movePig(id: pig.id, from: pig.position, to: sameId.position)

        // Pig should still be found at the original query position (same bucket)
        let result = grid.getNearby(x: 3.0, y: 3.0, pigs: pigDict)
        #expect(result.count == 1)
    }

    @Test("notifyPigMoved via CollisionHandler makes isPositionBlocked accurate after cross-bucket move")
    func testNotifyPigMovedFixesBlocking() {
        let state = makeGameState()
        var pigA = makePigAt(x: 3.0, y: 3.0, state: .wandering)  // bucket (0,0)
        var pigB = makePigAt(x: 30.0, y: 3.0, state: .idle)       // bucket (6,0)
        pigA.needs.health = 100.0
        pigB.needs.health = 100.0
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)

        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        // Move pig A to pig B's position in the live dictionary
        var movedA = pigA
        movedA.position = Position(x: 30.0, y: 3.0)
        state.updateGuineaPig(movedA)

        // Notify the spatial grid of the move
        handler.notifyPigMoved(id: pigA.id, from: pigA.position, to: movedA.position)

        // Now pig B should be blocked from moving to (30, 3) — pig A is there
        #expect(
            handler.isPositionBlocked(targetX: 30.0, targetY: 3.0, excludePig: pigB),
            "isPositionBlocked should detect pig A after notifyPigMoved"
        )
    }

    @Test("Without notifyPigMoved, cross-bucket move is invisible to isPositionBlocked (regression proof)")
    func testWithoutNotifyPigMovedBlockingFails() {
        let state = makeGameState()
        var pigA = makePigAt(x: 3.0, y: 3.0, state: .wandering)  // bucket (0,0)
        var pigB = makePigAt(x: 30.0, y: 3.0, state: .idle)       // bucket (6,0)
        pigA.needs.health = 100.0
        pigB.needs.health = 100.0
        state.addGuineaPig(pigA)
        state.addGuineaPig(pigB)

        let handler = CollisionHandler(gameState: state)
        handler.rebuildSpatialGrid()

        // Move pig A in the live dictionary but do NOT notify the spatial grid
        var movedA = pigA
        movedA.position = Position(x: 30.0, y: 3.0)
        state.updateGuineaPig(movedA)

        // Pig A's UUID is still in bucket (0,0), invisible to queries at (30,3)
        #expect(
            !handler.isPositionBlocked(targetX: 30.0, targetY: 3.0, excludePig: pigB),
            "Stale spatial grid should fail to detect pig A at new bucket (documents the bug)"
        )
    }
}
