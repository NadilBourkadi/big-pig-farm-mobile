/// TunnelsAndAreaManagerTests — Tests for tunnel carving (Tunnels.connectAreas).
/// AreaManager tests are in AreaManagerTests.swift.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Test Helpers

/// Two side-by-side areas separated by a 7-cell horizontal gap.
/// areaA is on the left (col 0), areaB is on the right (col 1).
@MainActor private func makeTwoAreaGrid() -> FarmGrid {
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
@MainActor private func makeTwoAreaGridVertical() -> FarmGrid {
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

@Test @MainActor func connectAreasCreatesHorizontalTunnels() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
    #expect(tunnels.allSatisfy { $0.orientation == "horizontal" })
}

@Test @MainActor func connectAreasCreatesVerticalTunnels() {
    var grid = makeTwoAreaGridVertical()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(tunnels.count == 2)
    #expect(tunnels.allSatisfy { $0.orientation == "vertical" })
}

@Test @MainActor func connectAreasOrderDoesNotMatter() {
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

@Test @MainActor func horizontalTunnelCorridorCellsAreWalkable() {
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

@Test @MainActor func horizontalTunnelBarrierWallsAreNotWalkable() {
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

@Test @MainActor func verticalTunnelBarrierWallsAreNotHorizontal() {
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

@Test @MainActor func tunnelCorridorCellTypeIsFloor() {
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

@Test @MainActor func tunnelBarrierCellTypeIsWall() {
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

@Test @MainActor func tunnelConnectionRecordsCorrectAreaIDs() {
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

@Test @MainActor func tunnelConnectionRecordsCells() {
    var grid = makeTwoAreaGrid()
    let tunnels = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])

    for tunnel in tunnels {
        #expect(!tunnel.cells.isEmpty)
        for pos in tunnel.cells {
            #expect(grid.isValidPosition(pos.x, pos.y))
        }
    }
}

@Test @MainActor func tunnelHalfWidthProduces5CellWideCorridor() {
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

@Test @MainActor func connectAreasIncreasesGridGeneration() {
    var grid = makeTwoAreaGrid()
    let generationBefore = grid.gridGeneration
    _ = Tunnels.connectAreas(&grid, areaA: grid.areas[0], areaB: grid.areas[1])
    #expect(grid.gridGeneration > generationBefore)
}

@Test @MainActor func tunnelCellsInGapHaveNoAreaId() {
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

@Test @MainActor func tunnelFlagPreservedDuringComputeWallFlags() {
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

@Test @MainActor func pathfindingCanRouteThroughTunnel() {
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
