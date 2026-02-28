/// AreaManager — Management of discrete farm areas.
/// Maps from: game/world_areas.py
import Foundation

// MARK: - AreaManager

enum AreaManager {
    /// Re-stamp areaId on cells within each area and clear orphaned cells.
    /// Needed after room repositioning to fix ghost walls/floors.
    static func repairAreaCells(_ farm: inout FarmGrid) {
        clearOrphanedCells(&farm)
        stampAreaCells(&farm)
        markVoidCellsNonWalkable(&farm)
        farm.computeWallFlags()
        farm.invalidateWalkableCache()
    }

    /// Return all pairs of rooms in horizontally/vertically adjacent grid slots.
    static func getAdjacentPairs(_ farm: FarmGrid) -> [(FarmArea, FarmArea)] {
        var pairs: [(FarmArea, FarmArea)] = []
        var bySlot: [GridPosition: FarmArea] = [:]
        for area in farm.areas {
            bySlot[GridPosition(x: area.gridCol, y: area.gridRow)] = area
        }
        for (slot, area) in bySlot {
            if let right = bySlot[GridPosition(x: slot.x + 1, y: slot.y)] {
                pairs.append((area, right))
            }
            if let below = bySlot[GridPosition(x: slot.x, y: slot.y + 1)] {
                pairs.append((area, below))
            }
        }
        return pairs
    }

    /// Re-carve all tunnel connections using current tunnel dimensions.
    static func rebuildTunnels(_ farm: inout FarmGrid) {
        guard farm.areas.count >= 2 else { return }

        // Clear all existing tunnel cells back to base state
        for tunnel in farm.tunnels {
            for pos in tunnel.cells {
                guard farm.isValidPosition(pos.x, pos.y) else { continue }
                farm.cells[pos.y][pos.x].isTunnel = false
                farm.cells[pos.y][pos.x].isHorizontalWall = false
                if farm.cells[pos.y][pos.x].areaId != nil {
                    farm.cells[pos.y][pos.x].cellType = .wall
                    farm.cells[pos.y][pos.x].isWalkable = false
                } else {
                    farm.cells[pos.y][pos.x].cellType = .floor
                    farm.cells[pos.y][pos.x].isWalkable = false
                }
            }
        }
        farm.tunnels.removeAll()

        // Re-carve each adjacent pair with current settings
        for (areaA, areaB) in getAdjacentPairs(farm) {
            let newTunnels = Tunnels.connectAreas(&farm, areaA: areaA, areaB: areaB)
            farm.tunnels.append(contentsOf: newTunnels)
        }
    }
}

// MARK: - Private Helpers

private extension AreaManager {
    /// Pass 1: clear orphaned area ownership from cells that are outside their area bounds.
    static func clearOrphanedCells(_ farm: inout FarmGrid) {
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                guard !farm.cells[y][x].isTunnel else { continue }
                guard let areaId = farm.cells[y][x].areaId else { continue }
                let area = farm.getAreaByID(areaId)
                if area == nil || !area!.contains(x: x, y: y) {
                    farm.cells[y][x].areaId = nil
                    farm.cells[y][x].facilityId = nil
                    farm.cells[y][x].cellType = .floor
                    farm.cells[y][x].isWalkable = false
                    farm.cells[y][x].isCorner = false
                    farm.cells[y][x].isHorizontalWall = false
                }
            }
        }
    }

    /// Pass 2: stamp cells for each area — set wall/floor types and areaId.
    static func stampAreaCells(_ farm: inout FarmGrid) {
        for area in farm.areas {
            for x in area.x1...area.x2 {
                for y in area.y1...area.y2 {
                    guard farm.isValidPosition(x, y) else { continue }
                    guard !farm.cells[y][x].isTunnel else { continue }
                    let isBorder = x == area.x1 || x == area.x2
                        || y == area.y1 || y == area.y2
                    if isBorder {
                        farm.cells[y][x].cellType = .wall
                        farm.cells[y][x].isWalkable = false
                        farm.cells[y][x].areaId = area.id
                    } else {
                        farm.cells[y][x].cellType = .floor
                        farm.cells[y][x].isWalkable = farm.cells[y][x].facilityId == nil
                        farm.cells[y][x].areaId = area.id
                    }
                }
            }
        }
    }

    /// Pass 3: ensure void cells (outside all areas and tunnels) are non-walkable.
    static func markVoidCellsNonWalkable(_ farm: inout FarmGrid) {
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                if farm.cells[y][x].areaId == nil && !farm.cells[y][x].isTunnel {
                    farm.cells[y][x].isWalkable = false
                }
            }
        }
    }
}
