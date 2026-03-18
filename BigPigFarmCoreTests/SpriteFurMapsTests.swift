import Testing
@testable import BigPigFarmCore

@Suite("SpriteFurMaps")
struct SpriteFurMapsTests {

    // MARK: - Count Tests

    @Test func adultAllFurCount() {
        #expect(SpriteFurMaps.adultAllFur.count == 37)
    }

    @Test func adultInnerFurCount() {
        #expect(SpriteFurMaps.adultInnerFur.count == 25)
    }

    @Test func adultEarPixelsCount() {
        #expect(SpriteFurMaps.adultEarPixels.count == 1)
    }

    @Test func babyAllFurCount() {
        #expect(SpriteFurMaps.babyAllFur.count == 8)
    }

    @Test func babyInnerFurCount() {
        #expect(SpriteFurMaps.babyInnerFur.count == 3)
    }

    @Test func babyEarPixelsCount() {
        #expect(SpriteFurMaps.babyEarPixels.count == 1)
    }

    // MARK: - Subset Invariants

    @Test func adultInnerFurIsSubsetOfAllFur() {
        #expect(SpriteFurMaps.adultInnerFur.isSubset(of: SpriteFurMaps.adultAllFur))
    }

    @Test func adultInnerFurIsStrictSubset() {
        #expect(SpriteFurMaps.adultInnerFur.isStrictSubset(of: SpriteFurMaps.adultAllFur))
    }

    @Test func babyInnerFurIsSubsetOfAllFur() {
        #expect(SpriteFurMaps.babyInnerFur.isSubset(of: SpriteFurMaps.babyAllFur))
    }

    @Test func babyInnerFurIsStrictSubset() {
        #expect(SpriteFurMaps.babyInnerFur.isStrictSubset(of: SpriteFurMaps.babyAllFur))
    }

    // MARK: - Disjoint Invariants

    @Test func adultEarPixelsDisjointFromAllFur() {
        #expect(SpriteFurMaps.adultEarPixels.isDisjoint(with: SpriteFurMaps.adultAllFur))
    }

    @Test func babyEarPixelsDisjointFromAllFur() {
        #expect(SpriteFurMaps.babyEarPixels.isDisjoint(with: SpriteFurMaps.babyAllFur))
    }

    // MARK: - Bounds Checks

    @Test func adultCoordsWithinSpriteBounds() {
        let allAdult = SpriteFurMaps.adultAllFur
            .union(SpriteFurMaps.adultInnerFur)
            .union(SpriteFurMaps.adultEarPixels)
        for pos in allAdult {
            #expect(pos.x >= 0 && pos.x < 14, "adult x=\(pos.x) out of bounds")
            #expect(pos.y >= 0 && pos.y < 8, "adult y=\(pos.y) out of bounds")
        }
    }

    @Test func babyCoordsWithinSpriteBounds() {
        let allBaby = SpriteFurMaps.babyAllFur
            .union(SpriteFurMaps.babyInnerFur)
            .union(SpriteFurMaps.babyEarPixels)
        for pos in allBaby {
            #expect(pos.x >= 0 && pos.x < 8, "baby x=\(pos.x) out of bounds")
            #expect(pos.y >= 0 && pos.y < 6, "baby y=\(pos.y) out of bounds")
        }
    }

    // MARK: - Spot-Check Known Coordinates

    @Test func adultInnerFurContainsCenterBody() {
        // x=5, y=4 is well inside the adult body
        #expect(SpriteFurMaps.adultInnerFur.contains(GridPosition(x: 5, y: 4)))
    }

    @Test func adultEarPixelLocation() {
        #expect(SpriteFurMaps.adultEarPixels.contains(GridPosition(x: 10, y: 0)))
    }

    @Test func babyEarPixelLocation() {
        #expect(SpriteFurMaps.babyEarPixels.contains(GridPosition(x: 5, y: 0)))
    }

    @Test func babyInnerFurContainsEarNeighbor() {
        // x=5, y=1 is directly below the baby ear at (5,0)
        #expect(SpriteFurMaps.babyInnerFur.contains(GridPosition(x: 5, y: 1)))
    }

    // MARK: - Edge Exclusion

    @Test func adultLeftmostFurNotInnerFur() {
        // x=1, y=4 is adjacent to dark outline on the left
        #expect(!SpriteFurMaps.adultInnerFur.contains(GridPosition(x: 1, y: 4)))
    }

    @Test func adultRightmostFurNotInnerFur() {
        // x=12, y=4 is adjacent to dark outline on the right
        #expect(!SpriteFurMaps.adultInnerFur.contains(GridPosition(x: 12, y: 4)))
    }

    @Test func adultIsolatedFurNotInnerFur() {
        // x=12, y=2 is isolated fur on the right edge of the head
        #expect(!SpriteFurMaps.adultInnerFur.contains(GridPosition(x: 12, y: 2)))
    }
}
