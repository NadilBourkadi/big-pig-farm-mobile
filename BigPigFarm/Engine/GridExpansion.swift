/// GridExpansion — Tier-based farm grid expansion logic.
/// Maps from: game/world_expansion.py
import Foundation

// MARK: - AddRoomResult

/// Result of adding a new room to the farm.
struct AddRoomResult: Sendable {
    var area: FarmArea
    /// All farm tunnels after the rebuild — not just tunnels for the new room.
    /// Filter by areaAId/areaBId matching the new area if only new connections are needed.
    var tunnels: [TunnelConnection]
    var offsetX: Int
    var offsetY: Int
    var roomDeltas: [UUID: GridPosition]
}

// MARK: - GridExpansion

enum GridExpansion {
    /// Expand the grid canvas and shift existing content by offset.
    /// New cells are non-walkable void.
    static func expandGrid(
        _ farm: inout FarmGrid,
        newWidth: Int,
        newHeight: Int,
        offsetX: Int = 0,
        offsetY: Int = 0
    ) {
        var voidCell = Cell()
        voidCell.isWalkable = false
        var newCells = [[Cell]](
            repeating: [Cell](repeating: voidCell, count: newWidth),
            count: newHeight
        )

        for y in 0..<farm.height {
            for x in 0..<farm.width {
                let nx = x + offsetX
                let ny = y + offsetY
                guard nx >= 0 && nx < newWidth && ny >= 0 && ny < newHeight else { continue }
                newCells[ny][nx] = farm.cells[y][x]
            }
        }

        farm.width = newWidth
        farm.height = newHeight
        farm.cells = newCells

        if offsetX != 0 || offsetY != 0 {
            for i in farm.areas.indices {
                farm.areas[i].x1 += offsetX
                farm.areas[i].y1 += offsetY
                farm.areas[i].x2 += offsetX
                farm.areas[i].y2 += offsetY
            }
            for i in farm.tunnels.indices {
                farm.tunnels[i].cells = farm.tunnels[i].cells.map {
                    GridPosition(x: $0.x + offsetX, y: $0.y + offsetY)
                }
            }
        }

        farm.invalidateWalkableCache()
    }

    /// Compute world-coordinate origins for each area using 2-column grid.
    /// Returns [areaIndex: GridPosition] for each area.
    static func computeGridLayout(_ farm: FarmGrid) -> [Int: GridPosition] {
        let gap = 7 // Gap between room walls for tunnel corridor

        guard !farm.areas.isEmpty else { return [:] }

        let maxCol = farm.areas.map(\.gridCol).max() ?? 0
        let maxRow = farm.areas.map(\.gridRow).max() ?? 0

        var colWidths = [Int](repeating: 0, count: maxCol + 1)
        var rowHeights = [Int](repeating: 0, count: maxRow + 1)
        for area in farm.areas {
            let areaWidth = area.x2 - area.x1 + 1
            let areaHeight = area.y2 - area.y1 + 1
            colWidths[area.gridCol] = max(colWidths[area.gridCol], areaWidth)
            rowHeights[area.gridRow] = max(rowHeights[area.gridRow], areaHeight)
        }

        var colOffsets = [Int](repeating: 0, count: maxCol + 1)
        if maxCol > 0 {
            for col in 1...maxCol {
                colOffsets[col] = colOffsets[col - 1] + colWidths[col - 1] + gap
            }
        }
        var rowOffsets = [Int](repeating: 0, count: maxRow + 1)
        if maxRow > 0 {
            for row in 1...maxRow {
                rowOffsets[row] = rowOffsets[row - 1] + rowHeights[row - 1] + gap
            }
        }

        var origins: [Int: GridPosition] = [:]
        for (i, area) in farm.areas.enumerated() {
            let areaWidth = area.x2 - area.x1 + 1
            let areaHeight = area.y2 - area.y1 + 1
            let cx = colOffsets[area.gridCol] + (colWidths[area.gridCol] - areaWidth) / 2
            let cy = rowOffsets[area.gridRow] + (rowHeights[area.gridRow] - areaHeight) / 2
            origins[i] = GridPosition(x: cx, y: cy)
        }
        return origins
    }

    // swiftlint:disable function_body_length
    /// Add a new room with the given biome using 2-column grid layout.
    /// Returns AddRoomResult or nil if at max rooms.
    /// roomDeltas maps areaID -> (dx, dy) for each existing area that repositioned.
    static func addRoom(
        _ farm: inout FarmGrid,
        biome: BiomeType,
        roomName: String? = nil
    ) -> AddRoomResult? {
        if farm.areas.isEmpty {
            farm.createLegacyStarterArea()
        }

        let roomIdx = farm.areas.count
        guard roomIdx < roomCosts.count else { return nil }

        let tierInfo = getTierUpgrade(tier: farm.tier)
        let roomWidth = tierInfo.roomWidth
        let roomHeight = tierInfo.roomHeight
        let name = roomName ?? "\(biomes[biome]?.displayName ?? biome.rawValue.capitalized) Room"

        let newCol = roomIdx % 2
        let newRow = roomIdx / 2

        var newArea = FarmArea(
            id: UUID(), name: name, biome: biome,
            x1: 0, y1: 0, x2: roomWidth - 1, y2: roomHeight - 1
        )
        newArea.gridCol = newCol
        newArea.gridRow = newRow

        // Temporarily add to compute full grid layout with new area included
        farm.areas.append(newArea)
        farm.areaLookup[newArea.id] = newArea
        let origins = computeGridLayout(farm)
        let totalSize = computeTotalSize(from: origins, areas: farm.areas)
        farm.areas.removeLast()
        farm.areaLookup.removeValue(forKey: newArea.id)

        var offsetX = 0
        var offsetY = 0
        if !farm.areas.isEmpty, let newOrigin0 = origins[0] {
            offsetX = newOrigin0.x - farm.areas[0].x1
            offsetY = newOrigin0.y - farm.areas[0].y1
        }

        let shiftX = offsetX < 0 ? -offsetX : 0
        let shiftY = offsetY < 0 ? -offsetY : 0
        let finalW = max(max(farm.width + max(0, offsetX), totalSize.x), farm.width + shiftX)
        let finalH = max(max(farm.height + max(0, offsetY), totalSize.y), farm.height + shiftY)

        var entityOffsetX = 0
        var entityOffsetY = 0
        var roomDeltas: [UUID: GridPosition] = [:]

        if offsetX != 0 || offsetY != 0 {
            let result = repositionExistingAreas(
                &farm, origins: origins,
                shift: GridPosition(x: shiftX, y: shiftY),
                finalSize: GridPosition(x: finalW, y: finalH)
            )
            entityOffsetX = result.entityOffsetX
            entityOffsetY = result.entityOffsetY
            roomDeltas = result.roomDeltas
        } else if finalW > farm.width || finalH > farm.height {
            expandGrid(&farm, newWidth: finalW, newHeight: finalH)
        }

        guard let newOrigin = origins[roomIdx] else { return nil }
        newArea.x1 = newOrigin.x
        newArea.y1 = newOrigin.y
        newArea.x2 = newOrigin.x + roomWidth - 1
        newArea.y2 = newOrigin.y + roomHeight - 1
        farm.addArea(newArea)

        AreaManager.rebuildTunnels(&farm)

        return AddRoomResult(
            area: newArea, tunnels: farm.tunnels,
            offsetX: entityOffsetX, offsetY: entityOffsetY,
            roomDeltas: roomDeltas
        )
    }
    // swiftlint:enable function_body_length
}

// MARK: - Private Helpers

private extension GridExpansion {
    static func computeTotalSize(from origins: [Int: GridPosition], areas: [FarmArea]) -> GridPosition {
        var totalWidth = 0
        var totalHeight = 0
        for (i, area) in areas.enumerated() {
            guard let origin = origins[i] else { continue }
            totalWidth = max(totalWidth, origin.x + (area.x2 - area.x1 + 1))
            totalHeight = max(totalHeight, origin.y + (area.y2 - area.y1 + 1))
        }
        return GridPosition(x: totalWidth, y: totalHeight)
    }

    struct RepositionResult: Sendable {
        var entityOffsetX: Int
        var entityOffsetY: Int
        var roomDeltas: [UUID: GridPosition]
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func repositionExistingAreas(
        _ farm: inout FarmGrid,
        origins: [Int: GridPosition],
        shift: GridPosition,
        finalSize: GridPosition
    ) -> RepositionResult {
        // Clear tunnel cells before repositioning
        for tunnel in farm.tunnels {
            for pos in tunnel.cells {
                guard farm.isValidPosition(pos.x, pos.y) else { continue }
                farm.cells[pos.y][pos.x].isTunnel = false
                farm.cells[pos.y][pos.x].isHorizontalWall = false
            }
        }
        farm.tunnels.removeAll()

        var entityOffsetX = 0
        var entityOffsetY = 0
        let needsExpand = finalSize.x > farm.width || finalSize.y > farm.height
            || shift.x > 0 || shift.y > 0
        if needsExpand {
            expandGrid(&farm, newWidth: finalSize.x, newHeight: finalSize.y,
                       offsetX: shift.x, offsetY: shift.y)
            entityOffsetX = shift.x
            entityOffsetY = shift.y
        }

        // Clear all area ownership to avoid ghost cells at old positions
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                if farm.cells[y][x].areaId != nil && !farm.cells[y][x].isTunnel {
                    farm.cells[y][x].areaId = nil
                    farm.cells[y][x].cellType = .floor
                    farm.cells[y][x].isWalkable = false
                    farm.cells[y][x].isCorner = false
                    farm.cells[y][x].isHorizontalWall = false
                }
            }
        }

        // Compute per-room deltas BEFORE repositioning
        var roomDeltas: [UUID: GridPosition] = [:]
        for (i, area) in farm.areas.enumerated() {
            guard let target = origins[i] else { continue }
            let dx = target.x - area.x1
            let dy = target.y - area.y1
            if dx != 0 || dy != 0 {
                roomDeltas[area.id] = GridPosition(x: dx, y: dy)
            }
        }

        // Reposition existing areas to their new grid positions
        for i in farm.areas.indices {
            guard let target = origins[i] else { continue }
            let areaWidth = farm.areas[i].x2 - farm.areas[i].x1 + 1
            let areaHeight = farm.areas[i].y2 - farm.areas[i].y1 + 1
            farm.areas[i].x1 = target.x
            farm.areas[i].y1 = target.y
            farm.areas[i].x2 = target.x + areaWidth - 1
            farm.areas[i].y2 = target.y + areaHeight - 1
            farm.areaLookup[farm.areas[i].id] = farm.areas[i]
        }

        AreaManager.repairAreaCells(&farm)

        return RepositionResult(
            entityOffsetX: entityOffsetX,
            entityOffsetY: entityOffsetY,
            roomDeltas: roomDeltas
        )
    }
}
