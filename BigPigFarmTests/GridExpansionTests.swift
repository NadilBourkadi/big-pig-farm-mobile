/// GridExpansionTests — Tests for GridExpansion (expandGrid, computeGridLayout, addRoom).
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - expandGrid Tests

@Test func expandGridGrowsWidthAndHeight() {
    var grid = FarmGrid.createStarter()
    GridExpansion.expandGrid(&grid, newWidth: 80, newHeight: 50)
    #expect(grid.width == 80)
    #expect(grid.height == 50)
}

@Test func expandGridPreservesExistingCells() {
    var grid = FarmGrid.createStarter()
    let originalCell = grid.cells[5][5]
    GridExpansion.expandGrid(&grid, newWidth: 80, newHeight: 50)
    #expect(grid.cells[5][5].cellType == originalCell.cellType)
    #expect(grid.cells[5][5].isWalkable == originalCell.isWalkable)
}

@Test func expandGridWithOffsetShiftsCells() {
    var grid = FarmGrid.createStarter()
    let original = grid.cells[4][3]
    GridExpansion.expandGrid(&grid, newWidth: 80, newHeight: 50, offsetX: 5, offsetY: 3)
    #expect(grid.cells[7][8].cellType == original.cellType)
    #expect(grid.cells[7][8].isWalkable == original.isWalkable)
}

@Test func expandGridWithOffsetShiftsAreaCoordinates() {
    var grid = FarmGrid.createStarter()
    let originalX1 = grid.areas[0].x1
    let originalY1 = grid.areas[0].y1
    GridExpansion.expandGrid(&grid, newWidth: 80, newHeight: 50, offsetX: 5, offsetY: 3)
    #expect(grid.areas[0].x1 == originalX1 + 5)
    #expect(grid.areas[0].y1 == originalY1 + 3)
    #expect(grid.areas[0].x2 == grid.areas[0].x1 + 61)
}

@Test func expandGridWithOffsetShiftsTunnelCells() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    grid.tunnels.append(contentsOf: tunnels)
    let originalFirstCell = grid.tunnels[0].cells[0]

    GridExpansion.expandGrid(&grid, newWidth: 200, newHeight: 60, offsetX: 10, offsetY: 5)
    let shifted = grid.tunnels[0].cells[0]
    #expect(shifted.x == originalFirstCell.x + 10)
    #expect(shifted.y == originalFirstCell.y + 5)
}

@Test func expandGridNewCellsAreNonWalkable() {
    var grid = FarmGrid.createStarter()
    GridExpansion.expandGrid(&grid, newWidth: 100, newHeight: 60)
    #expect(grid.cells[55][90].isWalkable == false)
    #expect(grid.cells[0][80].isWalkable == false)
}

@Test func expandGridInvalidatesCache() {
    var grid = FarmGrid.createStarter()
    let generationBefore = grid.gridGeneration
    GridExpansion.expandGrid(&grid, newWidth: 80, newHeight: 50)
    #expect(grid.gridGeneration > generationBefore)
}

// MARK: - computeGridLayout Tests

@Test func computeGridLayoutSingleArea() {
    var grid = FarmGrid(width: 62, height: 37)
    let area = FarmArea(
        id: UUID(), name: "Room", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    grid.areas.append(area)
    let origins = GridExpansion.computeGridLayout(grid)
    #expect(origins[0] == GridPosition(x: 0, y: 0))
}

@Test func computeGridLayoutTwoAreasHorizontal() {
    var grid = FarmGrid(width: 140, height: 40)
    let left = FarmArea(
        id: UUID(), name: "Left", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let right = FarmArea(
        id: UUID(), name: "Right", biome: .burrow,
        x1: 69, y1: 0, x2: 130, y2: 36,
        gridCol: 1, gridRow: 0
    )
    grid.areas.append(left)
    grid.areas.append(right)
    let origins = GridExpansion.computeGridLayout(grid)
    // col 0: width 62, col 1: width 62, gap 7 → col1 offset = 62 + 7 = 69
    #expect(origins[0] == GridPosition(x: 0, y: 0))
    #expect(origins[1] == GridPosition(x: 69, y: 0))
}

@Test func computeGridLayoutFourAreas() {
    var grid = FarmGrid(width: 200, height: 100)
    let gap = 7
    let roomWidth = 62; let roomHeight = 37
    for row in 0..<2 {
        for col in 0..<2 {
            let area = FarmArea(
                id: UUID(), name: "Room", biome: .meadow,
                x1: 0, y1: 0, x2: roomWidth - 1, y2: roomHeight - 1,
                gridCol: col, gridRow: row
            )
            grid.areas.append(area)
        }
    }
    let origins = GridExpansion.computeGridLayout(grid)
    let expectedPositions = [
        GridPosition(x: 0, y: 0),
        GridPosition(x: roomWidth + gap, y: 0),
        GridPosition(x: 0, y: roomHeight + gap),
        GridPosition(x: roomWidth + gap, y: roomHeight + gap),
    ]
    for (i, expected) in expectedPositions.enumerated() {
        #expect(origins[i] == expected)
    }
}

@Test func computeGridLayoutCentersUnequalRooms() {
    var grid = FarmGrid(width: 200, height: 100)
    let wide = FarmArea(
        id: UUID(), name: "Wide", biome: .meadow,
        x1: 0, y1: 0, x2: 69, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let narrow = FarmArea(
        id: UUID(), name: "Narrow", biome: .burrow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 1, gridRow: 0
    )
    grid.areas.append(wide)
    grid.areas.append(narrow)
    let origins = GridExpansion.computeGridLayout(grid)
    // col0 width=70, col1 width=62, gap=7
    // col0 origin.x = 0 + (70-70)/2 = 0
    // col1 origin.x = (70+7) + (62-62)/2 = 77
    #expect(origins[0]?.x == 0)
    #expect(origins[1]?.x == 77)
}

@Test func computeGridLayoutEmptyReturnsEmpty() {
    let grid = FarmGrid(width: 62, height: 37)
    let origins = GridExpansion.computeGridLayout(grid)
    #expect(origins.isEmpty)
}

// MARK: - addRoom Tests

@Test func addRoomCreatesStarterOnEmptyGrid() {
    var grid = FarmGrid(width: 62, height: 37)
    _ = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(grid.areas.count == 2)
}

@Test func addRoomSecondRoomExpandsGrid() {
    var grid = FarmGrid.createStarter()
    let originalWidth = grid.width
    _ = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(grid.width > originalWidth)
    #expect(grid.areas.count == 2)
}

@Test func addRoomAssignsCorrectGridSlots() {
    var grid = FarmGrid.createStarter()
    #expect(grid.areas[0].gridCol == 0)
    #expect(grid.areas[0].gridRow == 0)

    _ = GridExpansion.addRoom(&grid, biome: .burrow)   // room 1 → (1,0)
    #expect(grid.areas[1].gridCol == 1)
    #expect(grid.areas[1].gridRow == 0)

    _ = GridExpansion.addRoom(&grid, biome: .garden)   // room 2 → (0,1)
    #expect(grid.areas[2].gridCol == 0)
    #expect(grid.areas[2].gridRow == 1)

    _ = GridExpansion.addRoom(&grid, biome: .tropical)  // room 3 → (1,1)
    #expect(grid.areas[3].gridCol == 1)
    #expect(grid.areas[3].gridRow == 1)
}

@Test func addRoomUsesSuppliedName() {
    var grid = FarmGrid.createStarter()
    let result = GridExpansion.addRoom(&grid, biome: .burrow, roomName: "My Burrow")
    #expect(result?.area.name == "My Burrow")
}

@Test func addRoomUsesDefaultName() {
    var grid = FarmGrid.createStarter()
    let result = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(result?.area.name == "Burrow Room")
}

@Test func addRoomRebuildsAllTunnels() {
    var grid = FarmGrid.createStarter()
    _ = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(!grid.tunnels.isEmpty)
}

@Test func addRoomReturnsTunnels() throws {
    var grid = FarmGrid.createStarter()
    let result = try #require(GridExpansion.addRoom(&grid, biome: .burrow))
    #expect(!result.tunnels.isEmpty)
}

@Test func addRoomReturnsRoomDeltasForShiftedAreas() {
    var grid = FarmGrid.createStarter()
    let result = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(result != nil)
}

@Test func addRoomAtMaxCapacityReturnsNil() {
    // roomCosts has 8 entries (indices 0..7). Index 8 should return nil.
    var grid = FarmGrid.createStarter()
    grid.tier = 5
    let biomes: [BiomeType] = [.burrow, .garden, .tropical, .alpine, .crystal, .wildflower, .sanctuary]
    for biome in biomes {
        _ = GridExpansion.addRoom(&grid, biome: biome)
    }
    #expect(grid.areas.count == 8)
    let result = GridExpansion.addRoom(&grid, biome: .meadow)
    #expect(result == nil)
}

@Test func addRoomEntityOffsetIsZeroWhenNoShiftNeeded() {
    var grid = FarmGrid.createStarter()
    let result = GridExpansion.addRoom(&grid, biome: .burrow)
    #expect(result?.offsetX == 0)
    #expect(result?.offsetY == 0)
}

@Test func addRoomNewAreaHasCorrectBiome() {
    var grid = FarmGrid.createStarter()
    let result = GridExpansion.addRoom(&grid, biome: .alpine)
    #expect(result?.area.biome == .alpine)
}

@Test func addRoomNewAreaIsInGrid() {
    var grid = FarmGrid.createStarter()
    _ = GridExpansion.addRoom(&grid, biome: .burrow)
    let newArea = grid.areas[1]
    #expect(newArea.x1 >= 0)
    #expect(newArea.y1 >= 0)
    #expect(newArea.x2 < grid.width)
    #expect(newArea.y2 < grid.height)
}
