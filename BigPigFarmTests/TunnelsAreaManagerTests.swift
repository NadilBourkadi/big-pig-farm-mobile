/// TunnelsAreaManagerTests — Tests for Tunnels carving and AreaManager.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Shared Helpers (internal — used by GridExpansionTests too)

func makeTwoRoomGrid() -> FarmGrid {
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
    grid.addArea(left)
    grid.addArea(right)
    return grid
}

func makeStackedRoomGrid() -> FarmGrid {
    var grid = FarmGrid(width: 70, height: 85)
    let top = FarmArea(
        id: UUID(), name: "Top", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let bottom = FarmArea(
        id: UUID(), name: "Bottom", biome: .garden,
        x1: 0, y1: 44, x2: 61, y2: 80,
        gridCol: 0, gridRow: 1
    )
    grid.addArea(top)
    grid.addArea(bottom)
    return grid
}

// MARK: - Tunnel Carving Tests

@Test func connectAreasHorizontalCarvesTunnelCells() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(!tunnels.isEmpty)
    let allCells = tunnels.flatMap(\.cells)
    #expect(!allCells.isEmpty)
    for pos in allCells {
        #expect(grid.cells[pos.y][pos.x].isTunnel == true)
    }
}

@Test func connectAreasHorizontalMakesWalkableCorridors() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    let walkableCells = tunnels.flatMap(\.cells).filter { grid.cells[$0.y][$0.x].isWalkable }
    #expect(!walkableCells.isEmpty)
}

@Test func connectAreasReturnsTwoTunnels() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
}

@Test func connectAreasHorizontalOrientation() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    for tunnel in tunnels {
        #expect(tunnel.orientation == "horizontal")
    }
}

@Test func connectAreasVerticalCarvesTunnelCells() {
    var grid = makeStackedRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
    for tunnel in tunnels {
        #expect(tunnel.orientation == "vertical")
    }
    let allCells = tunnels.flatMap(\.cells)
    for pos in allCells {
        #expect(grid.cells[pos.y][pos.x].isTunnel == true)
    }
}

@Test func connectAreasHorizontalTunnelWidthIsFive() {
    var grid = makeTwoRoomGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    let tunnel = tunnels[0]
    let midX = (grid.areas[0].x2 + grid.areas[1].x1) / 2
    let walkableAtMidX = tunnel.cells.filter { $0.x == midX && grid.cells[$0.y][$0.x].isWalkable }
    // 5-wide walkable corridor (halfWidth=2, range -2...+2 = 5 cells)
    #expect(walkableAtMidX.count == 5)
}

@Test func connectAreasDoesNotAppendToFarmTunnels() {
    var grid = makeTwoRoomGrid()
    let countBefore = grid.tunnels.count
    _ = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    // connectAreas returns tunnels but does NOT append to farm.tunnels
    #expect(grid.tunnels.count == countBefore)
}

// MARK: - AreaManager Tests

@Test func repairAreaCellsFixesOrphanedCells() {
    var grid = FarmGrid.createStarter()
    let areaId = grid.areas[0].id
    let outsideX = 5; let outsideY = 5
    grid.areas[0].x2 = 3
    grid.areas[0].y2 = 3
    grid.areaLookup[areaId] = grid.areas[0]
    grid.cells[outsideY][outsideX].areaId = areaId
    AreaManager.repairAreaCells(&grid)
    #expect(grid.cells[outsideY][outsideX].areaId == nil)
    #expect(grid.cells[outsideY][outsideX].isWalkable == false)
}

@Test func repairAreaCellsPreservesOccupiedCells() {
    var grid = FarmGrid.createStarter()
    grid.cells[5][5].facilityId = UUID()
    grid.cells[5][5].isWalkable = false
    AreaManager.repairAreaCells(&grid)
    #expect(grid.cells[5][5].isWalkable == false)
}

@Test func repairAreaCellsRestoresInteriorWalkability() {
    var grid = FarmGrid.createStarter()
    grid.cells[10][10].isWalkable = false
    grid.cells[10][10].cellType = .wall
    AreaManager.repairAreaCells(&grid)
    #expect(grid.cells[10][10].isWalkable == true)
    #expect(grid.cells[10][10].cellType == .floor)
}

@Test func repairAreaCellsMarksVoidNonWalkable() {
    var grid = FarmGrid.createStarter()
    GridExpansion.expandGrid(&grid, newWidth: 100, newHeight: 60)
    AreaManager.repairAreaCells(&grid)
    #expect(grid.cells[5][80].isWalkable == false)
}

@Test func getAdjacentPairsFindsHorizontalNeighbors() {
    let grid = makeTwoRoomGrid()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test func getAdjacentPairsFindsVerticalNeighbors() {
    let grid = makeStackedRoomGrid()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test func getAdjacentPairsNoDiagonals() {
    var grid = FarmGrid(width: 200, height: 200)
    let areaTopLeft = FarmArea(
        id: UUID(), name: "A", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let areaDiagonal = FarmArea(
        id: UUID(), name: "B", biome: .burrow,
        x1: 100, y1: 100, x2: 161, y2: 136,
        gridCol: 1, gridRow: 1
    )
    grid.areas.append(areaTopLeft)
    grid.areas.append(areaDiagonal)
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.isEmpty)
}

@Test func rebuildTunnelsClearsOldAndRecarves() {
    var grid = makeTwoRoomGrid()
    let initial = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    grid.tunnels.append(contentsOf: initial)
    let countBefore = grid.tunnels.count
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.count == countBefore)
}

@Test func rebuildTunnelsDoesNothingForSingleArea() {
    var grid = FarmGrid.createStarter()
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.isEmpty)
}
