/// FarmGridTests — Tests for FarmGrid, cell queries, facility placement, area management.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Grid Creation

@Test func createStarterHasCorrectDimensions() {
    let grid = FarmGrid.createStarter()
    #expect(grid.width == 18)
    #expect(grid.height == 18)
    #expect(grid.tier == 1)
}

@Test func createStarterHasOneArea() {
    let grid = FarmGrid.createStarter()
    #expect(grid.areas.count == 1)
}

@Test func createStarterAreaIsMeadow() {
    let grid = FarmGrid.createStarter()
    #expect(grid.areas[0].biome == .meadow)
    #expect(grid.areas[0].name == "Meadow Room")
    #expect(grid.areas[0].isStarter == true)
}

@Test func createStarterAreaCoversEntireGrid() {
    let grid = FarmGrid.createStarter()
    let area = grid.areas[0]
    #expect(area.x1 == 0)
    #expect(area.y1 == 0)
    #expect(area.x2 == 17)
    #expect(area.y2 == 17)
}

@Test func createStarterBorderCellsAreWalls() {
    let grid = FarmGrid.createStarter()
    // Top row
    for x in 0..<grid.width {
        #expect(grid.cells[0][x].cellType == .wall)
        #expect(grid.cells[0][x].isWalkable == false)
    }
    // Bottom row
    for x in 0..<grid.width {
        #expect(grid.cells[grid.height - 1][x].cellType == .wall)
        #expect(grid.cells[grid.height - 1][x].isWalkable == false)
    }
    // Left column
    for y in 0..<grid.height {
        #expect(grid.cells[y][0].cellType == .wall)
    }
    // Right column
    for y in 0..<grid.height {
        #expect(grid.cells[y][grid.width - 1].cellType == .wall)
    }
}

@Test func createStarterInteriorCellsAreWalkable() {
    let grid = FarmGrid.createStarter()
    for y in 1..<(grid.height - 1) {
        for x in 1..<(grid.width - 1) {
            #expect(grid.cells[y][x].cellType == .floor)
            #expect(grid.cells[y][x].isWalkable == true)
        }
    }
}

@Test func createStarterAreaIdSetOnAllCells() {
    let grid = FarmGrid.createStarter()
    let areaId = grid.areas[0].id
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            #expect(grid.cells[y][x].areaId == areaId)
        }
    }
}

// MARK: - Cell Queries

@Test func isValidPositionInBounds() {
    let grid = FarmGrid(width: 10, height: 8)
    #expect(grid.isValidPosition(0, 0) == true)
    #expect(grid.isValidPosition(9, 7) == true)
    #expect(grid.isValidPosition(5, 3) == true)
}

@Test func isValidPositionOutOfBounds() {
    let grid = FarmGrid(width: 10, height: 8)
    #expect(grid.isValidPosition(-1, 0) == false)
    #expect(grid.isValidPosition(0, -1) == false)
    #expect(grid.isValidPosition(10, 0) == false)
    #expect(grid.isValidPosition(0, 8) == false)
}

@Test func isWalkableWall() {
    let grid = FarmGrid.createStarter()
    #expect(grid.isWalkable(0, 0) == false)   // corner wall
    #expect(grid.isWalkable(5, 0) == false)   // top wall
    #expect(grid.isWalkable(-1, 0) == false)  // out of bounds
}

@Test func isWalkableFloor() {
    let grid = FarmGrid.createStarter()
    #expect(grid.isWalkable(1, 1) == true)
    #expect(grid.isWalkable(8, 8) == true)
}

@Test func getCellReturnsCorrectly() {
    let grid = FarmGrid.createStarter()
    let cell = grid.getCell(1, 1)
    #expect(cell != nil)
    #expect(cell?.cellType == .floor)
    #expect(grid.getCell(-1, 0) == nil)
    #expect(grid.getCell(100, 100) == nil)
}

// MARK: - Facility Placement

@Test func placeFacilitySuccess() {
    var grid = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
    let result = grid.placeFacility(facility)
    #expect(result == true)
}

@Test func placeFacilityOutOfBounds() {
    var grid = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 61, y: 36)
    let result = grid.placeFacility(facility)
    #expect(result == false)
}

@Test func placeFacilityOnWall() {
    var grid = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 0, y: 0)
    let result = grid.placeFacility(facility)
    #expect(result == false)
}

@Test func placeFacilityOverlap() {
    var grid = FarmGrid.createStarter()
    let f1 = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = grid.placeFacility(f1)
    let f2 = Facility.create(type: .foodBowl, x: 5, y: 5)
    let result = grid.placeFacility(f2)
    #expect(result == false)
}

@Test func placeFacilitySetsIdAndWalkable() {
    var grid = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = grid.placeFacility(facility)
    for pos in facility.cells {
        let cell = grid.getCell(pos.x, pos.y)
        #expect(cell?.facilityId == facility.id)
        #expect(cell?.isWalkable == false)
    }
}

@Test func removeFacilityRestoresState() {
    var grid = FarmGrid.createStarter()
    let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = grid.placeFacility(facility)
    grid.removeFacility(facility)
    for pos in facility.cells {
        let cell = grid.getCell(pos.x, pos.y)
        #expect(cell?.facilityId == nil)
        #expect(cell?.isWalkable == true)
    }
}

@Test func placeFacilityIncrementsGeneration() {
    var grid = FarmGrid.createStarter()
    let genBefore = grid.gridGeneration
    let facility = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = grid.placeFacility(facility)
    #expect(grid.gridGeneration > genBefore)
}

// MARK: - Area Lookups

@Test func getAreaAtValidPosition() {
    let grid = FarmGrid.createStarter()
    let area = grid.getAreaAt(5, 5)
    #expect(area != nil)
    #expect(area?.biome == .meadow)
}

@Test func getAreaAtOutOfBounds() {
    let grid = FarmGrid.createStarter()
    #expect(grid.getAreaAt(-1, 0) == nil)
    #expect(grid.getAreaAt(100, 100) == nil)
}

@Test func getAreaByIDFoundAndNotFound() {
    let grid = FarmGrid.createStarter()
    let area = grid.areas[0]
    #expect(grid.getAreaByID(area.id) != nil)
    #expect(grid.getAreaByID(UUID()) == nil)
}

@Test func findAreasByBiome() {
    var grid = FarmGrid.createStarter()
    let meadows = grid.findAreasByBiome("meadow")
    #expect(meadows.count == 1)
    let deserts = grid.findAreasByBiome("desert")
    #expect(deserts.isEmpty)
}

@Test func getBiomeAtReturnsCorrectBiome() {
    let grid = FarmGrid.createStarter()
    #expect(grid.getBiomeAt(5, 5) == .meadow)
    #expect(grid.getBiomeAt(-1, -1) == nil)
}

@Test func capacityCalculation() {
    let grid = FarmGrid.createStarter()
    // Tier 1: 1 area * 8 capacityPerRoom = 8
    #expect(grid.capacity == 8)
}

@Test func nextRoomCostForStarter() {
    let grid = FarmGrid.createStarter()
    // Starter has 1 area, so next room is index 1 (Cozy Enclosure, 500)
    let cost = grid.nextRoomCost
    #expect(cost != nil)
    #expect(cost?.cost == 500)
    #expect(cost?.name == "Cozy Enclosure")
}

// MARK: - Wall Flags

@Test func computeWallFlagsCorners() {
    let grid = FarmGrid.createStarter()
    // All four corners should be marked
    #expect(grid.cells[0][0].isCorner == true)
    #expect(grid.cells[0][17].isCorner == true)
    #expect(grid.cells[17][0].isCorner == true)
    #expect(grid.cells[17][17].isCorner == true)
}

@Test func computeWallFlagsHorizontalWalls() {
    let grid = FarmGrid.createStarter()
    // Top wall (non-corner) should be horizontal
    #expect(grid.cells[0][1].isHorizontalWall == true)
    #expect(grid.cells[0][8].isHorizontalWall == true)
    // Bottom wall (non-corner) should be horizontal
    #expect(grid.cells[17][1].isHorizontalWall == true)
    // Side walls should NOT be horizontal
    #expect(grid.cells[1][0].isHorizontalWall == false)
    #expect(grid.cells[8][0].isHorizontalWall == false)
}

@Test func computeWallFlagsPreservesTunnelFlags() {
    var grid = FarmGrid.createStarter()
    // Manually mark a cell as tunnel with flags
    grid.cells[0][5].isTunnel = true
    grid.cells[0][5].isHorizontalWall = true
    grid.computeWallFlags()
    // Tunnel cell should preserve its manually-set flags
    #expect(grid.cells[0][5].isHorizontalWall == true)
}

// MARK: - Random Walkable

@Test func findRandomWalkableReturnsInteriorPosition() {
    var grid = FarmGrid.createStarter()
    let pos = grid.findRandomWalkable()
    #expect(pos != nil)
    // Should be interior (not on border)
    if let pos = pos {
        #expect(pos.x >= 1 && pos.x < grid.width - 1)
        #expect(pos.y >= 1 && pos.y < grid.height - 1)
    }
}

@Test func findRandomWalkableInAreaReturnsPositionInArea() {
    var grid = FarmGrid.createStarter()
    let areaId = grid.areas[0].id
    let pos = grid.findRandomWalkableInArea(areaId)
    #expect(pos != nil)
    if let pos = pos {
        #expect(grid.isWalkable(pos.x, pos.y))
        #expect(grid.cells[pos.y][pos.x].areaId == areaId)
    }
}

@Test func findRandomWalkableInUnknownAreaReturnsNil() {
    var grid = FarmGrid.createStarter()
    let pos = grid.findRandomWalkableInArea(UUID())
    #expect(pos == nil)
}

// MARK: - Cache Invalidation

@Test func invalidateCacheIncrementsGeneration() {
    var grid = FarmGrid.createStarter()
    let gen = grid.gridGeneration
    grid.invalidateWalkableCache()
    #expect(grid.gridGeneration == gen + 1)
}

// MARK: - Codable Round-Trip

@Test func farmGridCodableRoundTrip() throws {
    let original = FarmGrid.createStarter()
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(FarmGrid.self, from: data)

    #expect(decoded.width == original.width)
    #expect(decoded.height == original.height)
    #expect(decoded.tier == original.tier)
    #expect(decoded.areas.count == original.areas.count)
    #expect(decoded.areas[0].biome == .meadow)
    // gridGeneration is a runtime cache counter — rebuildCaches() increments it
    // during decode, so we just verify it's positive rather than equal
    #expect(decoded.gridGeneration > 0)
    // Verify caches were rebuilt
    #expect(decoded.areaLookup.count == 1)
}
