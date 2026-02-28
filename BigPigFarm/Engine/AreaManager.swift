/// AreaManager — Management of discrete farm areas.
/// Maps from: game/world_areas.py
import Foundation

/// Manages the collection of farm areas and their relationships.
/// Caseless enum used as a namespace — cannot be instantiated.
enum AreaManager {

    // MARK: - Cell Repair

    /// Re-stamp areaId on border/interior cells and mark void cells non-walkable.
    ///
    /// Three-pass algorithm:
    ///   Pass 1: Clear orphaned areaId from cells outside their area bounds.
    ///           These "ghost cells" arise from room repositioning.
    ///   Pass 2: Stamp each area's bounds with correct wall/floor/areaId.
    ///           Preserves facilityId occupancy (facility cells stay non-walkable).
    ///   Pass 3: Mark void cells (outside all areas and tunnels) non-walkable.
    static func repairAreaCells(_ farm: inout FarmGrid) {
        clearOrphanedCells(&farm)
        for area in farm.areas {
            stampAreaBounds(&farm, area: area)
        }
        markVoidCells(&farm)
        farm.computeWallFlags()
        farm.invalidateWalkableCache()
    }

    // MARK: - Cell Repair Helpers

    /// Pass 1: Reset cells whose areaId points to an area that no longer contains that position.
    private static func clearOrphanedCells(_ farm: inout FarmGrid) {
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                let cell = farm.cells[y][x]
                guard let areaId = cell.areaId, !cell.isTunnel else { continue }
                let area = farm.getAreaByID(areaId)
                if area?.contains(x: x, y: y) != true {
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

    /// Pass 2: Stamp an area's bounds with correct wall/floor/areaId.
    /// Interior cells occupied by a facility keep isWalkable = false.
    private static func stampAreaBounds(_ farm: inout FarmGrid, area: FarmArea) {
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
                    if farm.cells[y][x].facilityId == nil {
                        farm.cells[y][x].isWalkable = true
                    }
                    farm.cells[y][x].areaId = area.id
                }
            }
        }
    }

    /// Pass 3: Mark cells outside all areas and tunnels as non-walkable.
    private static func markVoidCells(_ farm: inout FarmGrid) {
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                if farm.cells[y][x].areaId == nil && !farm.cells[y][x].isTunnel {
                    farm.cells[y][x].isWalkable = false
                }
            }
        }
    }

    // MARK: - Adjacency

    /// Return all pairs of areas in horizontally or vertically adjacent grid slots.
    /// Uses gridCol/gridRow on FarmArea to determine adjacency.
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

    // MARK: - Tunnel Rebuild

    /// Re-carve all tunnel connections for the current area layout.
    /// Clears all existing tunnel cells, then reconnects all adjacent area pairs.
    static func rebuildTunnels(_ farm: inout FarmGrid) {
        guard farm.areas.count >= 2 else { return }

        // Clear all existing tunnel cells back to base state before re-carving
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

        // Re-carve tunnels for each adjacent area pair
        for (areaA, areaB) in getAdjacentPairs(farm) {
            let newTunnels = Tunnels.connectAreas(&farm, areaA: areaA, areaB: areaB)
            farm.tunnels.append(contentsOf: newTunnels)
        }
    }
}
