/// TunnelsAndAreaManagerTests — Tests for tunnel carving and area management.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Test Helpers

/// Two side-by-side areas separated by a 7-cell horizontal gap.
/// areaA is on the left (col 0), areaB is on the right (col 1).
private func makeTwoAreaGrid() -> FarmGrid {
    let gap = 7
    let roomWidth = 20
    let roomHeight = 15
    let totalWidth = roomWidth * 2 + gap
    var grid = FarmGrid(width: totalWidth, height: roomHeight)

    let areaA = FarmArea(
        id: UUID(),
        name: "Left Room",
        biome: .meadow,
        x1: 0, y1: 0, x2: roomWidth - 1, y2: roomHeight - 1,
        gridCol: 0, gridRow: 0
    )
    let areaB = FarmArea(
        id: UUID(),
        name: "Right Room",
        biome: .burrow,
        x1: roomWidth + gap, y1: 0, x2: totalWidth - 1, y2: roomHeight - 1,
        gridCol: 1, gridRow: 0
    )
    grid.addArea(areaA)
    grid.addArea(areaB)
    return grid
}

/// Two stacked areas separated by a 7-cell vertical gap.
/// areaA is on top (row 0), areaB is on the bottom (row 1).
private func makeTwoAreaGridVertical() -> FarmGrid {
    let gap = 7
    let roomWidth = 30
    let roomHeight = 12
    let totalHeight = roomHeight * 2 + gap
    var grid = FarmGrid(width: roomWidth, height: totalHeight)

    let areaA = FarmArea(
        id: UUID(),
        name: "Top Room",
        biome: .meadow,
        x1: 0, y1: 0, x2: roomWidth - 1, y2: roomHeight - 1,
        gridCol: 0, gridRow: 0
    )
    let areaB = FarmArea(
        id: UUID(),
        name: "Bottom Room",
        biome: .burrow,
        x1: 0, y1: roomHeight + gap, x2: roomWidth - 1, y2: totalHeight - 1,
        gridCol: 0, gridRow: 1
    )
    grid.addArea(areaA)
    grid.addArea(areaB)
    return grid
}

// MARK: - Tunnels: Basic Connection

@Test func connectAreasCreatesHorizontalTunnels() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
    #expect(tunnels.allSatisfy { $0.orientation == "horizontal" })
}

@Test func connectAreasCreatesVerticalTunnels() {
    var grid = makeTwoAreaGridVertical()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
    #expect(tunnels.allSatisfy { $0.orientation == "vertical" })
}

@Test func connectAreasOrderDoesNotMatter() {
    var gridAB = makeTwoAreaGrid()
    let tunnelsAB = Tunnels.connectAreas(&gridAB, areaA: gridAB.areas[0], areaB: gridAB.areas[1])

    var gridBA = makeTwoAreaGrid()
    let tunnelsBA = Tunnels.connectAreas(&gridBA, areaA: gridBA.areas[1], areaB: gridBA.areas[0])

    // Both orderings should produce 2 horizontal tunnels of the same total cell count
    #expect(tunnelsAB.count == tunnelsBA.count)
    let totalCellsAB = tunnelsAB.reduce(0) { $0 + $1.cells.count }
    let totalCellsBA = tunnelsBA.reduce(0) { $0 + $1.cells.count }
    #expect(totalCellsAB == totalCellsBA)
}

// MARK: - Tunnels: Cell Properties

@Test func horizontalTunnelCorridorCellsAreWalkable() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        let corridorCells = tunnel.cells.filter { pos in
            grid.cells[pos.y][pos.x].cellType == .floor
        }
        #expect(!corridorCells.isEmpty)
        for pos in corridorCells {
            #expect(grid.cells[pos.y][pos.x].isWalkable == true)
            #expect(grid.cells[pos.y][pos.x].isTunnel == true)
        }
    }
}

@Test func horizontalTunnelBarrierWallsAreNotWalkable() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        let barrierCells = tunnel.cells.filter { pos in
            grid.cells[pos.y][pos.x].cellType == .wall
        }
        #expect(!barrierCells.isEmpty)
        for pos in barrierCells {
            #expect(grid.cells[pos.y][pos.x].isWalkable == false)
            #expect(grid.cells[pos.y][pos.x].isTunnel == true)
            #expect(grid.cells[pos.y][pos.x].isHorizontalWall == true)
        }
    }
}

@Test func verticalTunnelBarrierWallsAreNotHorizontal() {
    var grid = makeTwoAreaGridVertical()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        let barrierCells = tunnel.cells.filter { pos in
            grid.cells[pos.y][pos.x].cellType == .wall
        }
        #expect(!barrierCells.isEmpty)
        for pos in barrierCells {
            // Vertical tunnel barriers are vertical walls — NOT horizontal
            #expect(grid.cells[pos.y][pos.x].isHorizontalWall == false)
            #expect(grid.cells[pos.y][pos.x].isTunnel == true)
        }
    }
}

@Test func tunnelCorridorCellTypeIsFloor() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        let corridorCells = tunnel.cells.filter { pos in
            grid.cells[pos.y][pos.x].isWalkable
        }
        for pos in corridorCells {
            #expect(grid.cells[pos.y][pos.x].cellType == .floor)
        }
    }
}

@Test func tunnelBarrierCellTypeIsWall() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        let barrierCells = tunnel.cells.filter { pos in
            !grid.cells[pos.y][pos.x].isWalkable
        }
        for pos in barrierCells {
            #expect(grid.cells[pos.y][pos.x].cellType == .wall)
        }
    }
}

// MARK: - Tunnels: TunnelConnection Record

@Test func tunnelConnectionRecordsCorrectAreaIDs() {
    var grid = makeTwoAreaGrid()
    let leftArea = grid.areas[0]
    let rightArea = grid.areas[1]
    let tunnels = Tunnels.connectAreas(&grid, areaA: leftArea, areaB: rightArea)

    for tunnel in tunnels {
        let ids = Set([tunnel.areaAId, tunnel.areaBId])
        #expect(ids.contains(leftArea.id))
        #expect(ids.contains(rightArea.id))
    }
}

@Test func tunnelConnectionRecordsCells() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        #expect(!tunnel.cells.isEmpty)
        for pos in tunnel.cells {
            #expect(grid.isValidPosition(pos.x, pos.y))
        }
    }
}

@Test func tunnelHalfWidthProduces5CellWideCorridor() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    // For each tunnel, sample a vertical cross-section in the middle of the gap
    // (x=23 falls between left.x2=19 and right.x1=27) and count walkable cells — must be 5
    let gapCenterX = 23
    for tunnel in tunnels where tunnel.orientation == "horizontal" {
        let floorCellsAtCenter = tunnel.cells.filter { pos in
            pos.x == gapCenterX && grid.cells[pos.y][pos.x].isWalkable
        }
        #expect(floorCellsAtCenter.count == 5)
    }
}

@Test func connectAreasIncreasesGridGeneration() {
    var grid = makeTwoAreaGrid()
    let generationBefore = grid.gridGeneration
    _ = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(grid.gridGeneration > generationBefore)
}

@Test func tunnelCellsInGapHaveNoAreaId() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    // Cells at the center of the gap (x=23) belong to no area
    let gapCenterX = 23
    for tunnel in tunnels {
        let gapCells = tunnel.cells.filter { $0.x == gapCenterX }
        for pos in gapCells where grid.cells[pos.y][pos.x].isWalkable {
            #expect(grid.cells[pos.y][pos.x].areaId == nil)
        }
    }
}

@Test func tunnelFlagPreservedDuringComputeWallFlags() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    // computeWallFlags is called inside connectAreas.
    // Tunnel cells must retain isTunnel == true after the call.
    for tunnel in tunnels {
        for pos in tunnel.cells {
            #expect(grid.cells[pos.y][pos.x].isTunnel == true)
        }
    }
}

// MARK: - Tunnels: Pathfinding Integration

@Test func pathfindingCanRouteThroughTunnel() {
    var grid = makeTwoAreaGrid()
    let leftArea = grid.areas[0]
    let rightArea = grid.areas[1]
    _ = Tunnels.connectAreas(&grid, areaA: leftArea, areaB: rightArea)

    let pf = Pathfinding(farm: grid)
    let from = GridPosition(x: leftArea.centerX, y: leftArea.centerY)
    let to = GridPosition(x: rightArea.centerX, y: rightArea.centerY)
    let path = pf.findPath(from: from, to: to)
    #expect(!path.isEmpty)

    // Path must cross through the gap between the two areas
    let crossesGap = path.contains { pos in
        pos.x > leftArea.x2 && pos.x < rightArea.x1
    }
    #expect(crossesGap)
}

// MARK: - AreaManager: Adjacency

@Test func getAdjacentPairsHorizontal() {
    let grid = makeTwoAreaGrid()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test func getAdjacentPairsVertical() {
    let grid = makeTwoAreaGridVertical()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test func getAdjacentPairsNonAdjacent() {
    // Two areas at grid slots (0,0) and (2,0) — not adjacent (gap of 1 slot)
    var grid = FarmGrid(width: 50, height: 15)
    let areaA = FarmArea(id: UUID(), name: "A", biome: .meadow,
                         x1: 0, y1: 0, x2: 14, y2: 14, gridCol: 0, gridRow: 0)
    let areaB = FarmArea(id: UUID(), name: "B", biome: .burrow,
                         x1: 35, y1: 0, x2: 49, y2: 14, gridCol: 2, gridRow: 0)
    grid.addArea(areaA)
    grid.addArea(areaB)

    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.isEmpty)
}

@Test func getAdjacentPairsFourAreaGrid() {
    // 2x2 layout: should produce 4 pairs (2 horizontal + 2 vertical)
    let size = 20
    let gap = 5
    let totalSize = size * 2 + gap
    var grid = FarmGrid(width: totalSize, height: totalSize)

    // gridSlots: (col, row) pairs for a 2x2 layout
    let gridSlots: [(Int, Int)] = [(0, 0), (1, 0), (0, 1), (1, 1)]
    for (col, row) in gridSlots {
        let originX = col * (size + gap)
        let originY = row * (size + gap)
        let area = FarmArea(
            id: UUID(), name: "Room\(col)\(row)", biome: .meadow,
            x1: originX, y1: originY,
            x2: originX + size - 1, y2: originY + size - 1,
            gridCol: col, gridRow: row
        )
        grid.addArea(area)
    }

    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 4)
}

// MARK: - AreaManager: Tunnel Rebuild

@Test func rebuildTunnelsSkipsSingleArea() {
    var grid = FarmGrid.createStarter()
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.isEmpty)
}

@Test func rebuildTunnelsCreatesNewConnections() {
    var grid = makeTwoAreaGrid()
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.count == 2)
    #expect(grid.tunnels.allSatisfy { !$0.cells.isEmpty })
}

@Test func rebuildTunnelsClearsOldTunnels() {
    var grid = makeTwoAreaGrid()
    AreaManager.rebuildTunnels(&grid)
    let firstCellCount = grid.tunnels.flatMap { $0.cells }.count

    AreaManager.rebuildTunnels(&grid)
    let secondCellCount = grid.tunnels.flatMap { $0.cells }.count

    // Rebuild should produce the same geometry
    #expect(grid.tunnels.count == 2)
    #expect(secondCellCount == firstCellCount)
}

// MARK: - AreaManager: Cell Repair

@Test func repairAreaCellsStampsInteriorCells() {
    var grid = makeTwoAreaGrid()
    AreaManager.repairAreaCells(&grid)

    for area in grid.areas {
        for x in area.interiorX1...area.interiorX2 {
            for y in area.interiorY1...area.interiorY2 {
                let cell = grid.cells[y][x]
                #expect(cell.areaId == area.id)
                #expect(cell.cellType == .floor)
                #expect(cell.isWalkable == true)
            }
        }
    }
}

@Test func repairAreaCellsStampsBorderCellsAsWalls() {
    var grid = makeTwoAreaGrid()
    AreaManager.repairAreaCells(&grid)

    let area = grid.areas[0]
    for x in area.x1...area.x2 {
        #expect(grid.cells[area.y1][x].cellType == .wall)
        #expect(grid.cells[area.y2][x].cellType == .wall)
    }
    for y in area.y1...area.y2 {
        #expect(grid.cells[y][area.x1].cellType == .wall)
        #expect(grid.cells[y][area.x2].cellType == .wall)
    }
}

@Test func repairAreaCellsPreservesFacilityOccupancy() {
    var grid = makeTwoAreaGrid()
    let area = grid.areas[0]
    let facilityX = area.interiorX1 + 2
    let facilityY = area.interiorY1 + 2
    grid.cells[facilityY][facilityX].facilityId = UUID()
    grid.cells[facilityY][facilityX].isWalkable = false

    AreaManager.repairAreaCells(&grid)

    #expect(grid.cells[facilityY][facilityX].isWalkable == false)
    #expect(grid.cells[facilityY][facilityX].facilityId != nil)
}

@Test func repairAreaCellsMarksVoidNonWalkable() {
    var grid = makeTwoAreaGrid()
    AreaManager.repairAreaCells(&grid)

    // x=22 is inside the 7-cell gap (left.x2=19, right.x1=27)
    let gapX = 22
    for y in 0..<grid.height {
        let cell = grid.cells[y][gapX]
        if cell.areaId == nil && !cell.isTunnel {
            #expect(cell.isWalkable == false)
        }
    }
}

@Test func repairAreaCellsClearsOrphanedAreaId() {
    var grid = makeTwoAreaGrid()
    let leftArea = grid.areas[0]
    let rightArea = grid.areas[1]

    // Manually assign leftArea's ID to a cell inside rightArea's bounds (ghost cell)
    let orphanX = rightArea.interiorX1 + 1
    let orphanY = rightArea.interiorY1 + 1
    grid.cells[orphanY][orphanX].areaId = leftArea.id

    AreaManager.repairAreaCells(&grid)

    // After repair, the cell should be re-stamped with rightArea's ID
    let repairedAreaId = grid.cells[orphanY][orphanX].areaId
    #expect(repairedAreaId != leftArea.id)
    #expect(repairedAreaId == rightArea.id)
}
