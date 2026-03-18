/// AreaManagerTests — Tests for AreaManager (adjacency, tunnel rebuild, cell repair).
/// Split from TunnelsAndAreaManagerTests.swift to stay under 300 lines.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Test Helpers

/// Two side-by-side areas separated by a 7-cell horizontal gap.
@MainActor private func makeAreaManagerTwoAreaGrid() -> FarmGrid {
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
@MainActor private func makeAreaManagerTwoAreaGridVertical() -> FarmGrid {
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

// MARK: - AreaManager: Adjacency

@Test @MainActor func getAdjacentPairsHorizontal() {
    let grid = makeAreaManagerTwoAreaGrid()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test @MainActor func getAdjacentPairsVertical() {
    let grid = makeAreaManagerTwoAreaGridVertical()
    let pairs = AreaManager.getAdjacentPairs(grid)
    #expect(pairs.count == 1)
}

@Test @MainActor func getAdjacentPairsNonAdjacent() {
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

@Test @MainActor func getAdjacentPairsFourAreaGrid() {
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

@Test @MainActor func rebuildTunnelsSkipsSingleArea() {
    var grid = FarmGrid.createStarter()
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.isEmpty)
}

@Test @MainActor func rebuildTunnelsCreatesNewConnections() {
    var grid = makeAreaManagerTwoAreaGrid()
    AreaManager.rebuildTunnels(&grid)
    #expect(grid.tunnels.count == 2)
    #expect(grid.tunnels.allSatisfy { !$0.cells.isEmpty })
}

@Test @MainActor func rebuildTunnelsClearsOldTunnels() {
    var grid = makeAreaManagerTwoAreaGrid()
    AreaManager.rebuildTunnels(&grid)
    let firstCellCount = grid.tunnels.flatMap { $0.cells }.count

    AreaManager.rebuildTunnels(&grid)
    let secondCellCount = grid.tunnels.flatMap { $0.cells }.count

    // Rebuild should produce the same geometry
    #expect(grid.tunnels.count == 2)
    #expect(secondCellCount == firstCellCount)
}

// MARK: - AreaManager: Cell Repair

@Test @MainActor func repairAreaCellsStampsInteriorCells() {
    var grid = makeAreaManagerTwoAreaGrid()
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

@Test @MainActor func repairAreaCellsStampsBorderCellsAsWalls() {
    var grid = makeAreaManagerTwoAreaGrid()
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

@Test @MainActor func repairAreaCellsPreservesFacilityOccupancy() {
    var grid = makeAreaManagerTwoAreaGrid()
    let area = grid.areas[0]
    let facilityX = area.interiorX1 + 2
    let facilityY = area.interiorY1 + 2
    grid.cells[facilityY][facilityX].facilityId = UUID()
    grid.cells[facilityY][facilityX].isWalkable = false

    AreaManager.repairAreaCells(&grid)

    #expect(grid.cells[facilityY][facilityX].isWalkable == false)
    #expect(grid.cells[facilityY][facilityX].facilityId != nil)
}

@Test @MainActor func repairAreaCellsMarksVoidNonWalkable() {
    var grid = makeAreaManagerTwoAreaGrid()
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

@Test @MainActor func repairAreaCellsClearsOrphanedAreaId() {
    var grid = makeAreaManagerTwoAreaGrid()
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
