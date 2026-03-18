/// CollisionSpatialGridTests — Tests for SpatialGrid rebuild, proximity, and pair generation.
import Foundation
import Testing
@testable import BigPigFarmCore

// MARK: - SpatialGrid Rebuild and Proximity

@MainActor
struct SpatialGridRebuildTests {

    @Test("Rebuild and getNearby returns pig at same position")
    func testRebuildAndGetNearby() {
        var grid = SpatialGrid()
        let pig = makePigAt(x: 5.0, y: 5.0)
        grid.rebuild(pigs: [pig])
        let pigs = [pig.id: pig]
        let nearby = grid.getNearby(x: 5.0, y: 5.0, pigs: pigs)
        #expect(nearby.count == 1)
        #expect(nearby[0].id == pig.id)
    }

    @Test("getNearby excludes pigs more than one cell away")
    func testGetNearbyExcludesFarPigs() {
        var grid = SpatialGrid()
        let close = makePigAt(x: 5.0, y: 5.0)
        let far = makePigAt(x: 25.0, y: 25.0)  // 3+ cells away
        grid.rebuild(pigs: [close, far])
        let pigs = [close.id: close, far.id: far]
        let nearby = grid.getNearby(x: 5.0, y: 5.0, pigs: pigs)
        let ids = Set(nearby.map { $0.id })
        #expect(ids.contains(close.id))
        #expect(!ids.contains(far.id))
    }

    @Test("Rebuild with empty pig list returns no pairs")
    func testRebuildEmptyGrid() {
        var grid = SpatialGrid()
        grid.rebuild(pigs: [])
        let pairs = grid.uniqueNearbyPairs(pigs: [:])
        #expect(pairs.isEmpty)
    }

    @Test("Pigs at the same position form a pair")
    func testPigsAtSamePosition() {
        var grid = SpatialGrid()
        let pigA = makePigAt(x: 5.0, y: 5.0)
        let pigB = makePigAt(x: 5.0, y: 5.0)
        grid.rebuild(pigs: [pigA, pigB])
        let pigs = [pigA.id: pigA, pigB.id: pigB]
        let pairs = grid.uniqueNearbyPairs(pigs: pigs)
        #expect(pairs.count == 1)
    }

    @Test("Pigs straddling a cell boundary are still found by getNearby")
    func testCellBoundary() {
        var grid = SpatialGrid()
        // x=4 is cell 0, x=5 is cell 1 — adjacent cells
        let left = makePigAt(x: 4.9, y: 5.0)
        let right = makePigAt(x: 5.1, y: 5.0)
        grid.rebuild(pigs: [left, right])
        let pigs = [left.id: left, right.id: right]
        let nearby = grid.getNearby(x: 4.9, y: 5.0, pigs: pigs)
        let ids = Set(nearby.map { $0.id })
        #expect(ids.contains(left.id))
        #expect(ids.contains(right.id))
    }
}

// MARK: - SpatialGrid uniqueNearbyPairs

@MainActor
struct SpatialGridPairsTests {

    @Test("Pigs in adjacent cells form a pair (cross-cell regression)")
    func testUniqueNearbyPairsAdjacentCells() {
        // This test verifies the fix: the old stub only paired intra-cell.
        // Pig A is in cell (0,1) and pig B is in cell (1,1) — adjacent, not same.
        var grid = SpatialGrid()
        let pigA = makePigAt(x: 4.9, y: 5.0)   // cell x=0 (4/5=0)
        let pigB = makePigAt(x: 5.1, y: 5.0)   // cell x=1 (5/5=1)
        grid.rebuild(pigs: [pigA, pigB])
        let pigs = [pigA.id: pigA, pigB.id: pigB]
        let pairs = grid.uniqueNearbyPairs(pigs: pigs)
        #expect(pairs.count == 1)
        let ids = Set(pairs.flatMap { [$0.0.id, $0.1.id] })
        #expect(ids == [pigA.id, pigB.id])
    }

    @Test("Three pigs near cell boundary produce no duplicate pairs")
    func testUniqueNearbyPairsDedup() {
        var grid = SpatialGrid()
        let pigA = makePigAt(x: 4.5, y: 5.0)
        let pigB = makePigAt(x: 5.5, y: 5.0)
        let pigC = makePigAt(x: 5.0, y: 5.0)
        grid.rebuild(pigs: [pigA, pigB, pigC])
        let pigs = [pigA.id: pigA, pigB.id: pigB, pigC.id: pigC]
        let pairs = grid.uniqueNearbyPairs(pigs: pigs)
        // 3 pigs → 3 unique pairs
        #expect(pairs.count == 3)
        // Verify no duplicates: every pair should appear exactly once
        var pairKeys = Set<String>()
        for (pigLeft, pigRight) in pairs {
            let key = pigLeft.id < pigRight.id
                ? "\(pigLeft.id):\(pigRight.id)"
                : "\(pigRight.id):\(pigLeft.id)"
            let inserted = pairKeys.insert(key).inserted
            #expect(inserted, "Duplicate pair found: \(key)")
        }
    }

    @Test("Pigs far apart produce no pairs")
    func testNoPairsWhenFarApart() {
        var grid = SpatialGrid()
        let pigA = makePigAt(x: 5.0, y: 5.0)
        let pigB = makePigAt(x: 50.0, y: 50.0)
        grid.rebuild(pigs: [pigA, pigB])
        let pigs = [pigA.id: pigA, pigB.id: pigB]
        let pairs = grid.uniqueNearbyPairs(pigs: pigs)
        #expect(pairs.isEmpty)
    }
}
