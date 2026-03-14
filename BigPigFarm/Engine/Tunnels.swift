/// Tunnels — Tunnel carving between farm areas.
/// Maps from: game/world_tunnels.py
import Foundation

/// Tunnel corridor half-width. Full width = 2 * tunnelHalfWidth + 1 = 5 cells.
/// Both horizontal and vertical use the same width on iOS (SpriteKit has square pixels;
/// Python doubles vertical width to compensate for terminal character aspect ratio).
private let tunnelHalfWidth = 2

/// Handles tunnel creation and connectivity between farm areas.
/// Caseless enum used as a namespace — cannot be instantiated.
enum Tunnels {

    // MARK: - Public API

    /// Carve two 5-wide tunnel corridors between two areas.
    /// Tunnels are placed at 1/4 and 3/4 of the shared wall overlap
    /// so traffic can flow through both without bottlenecking.
    /// Returns the new TunnelConnections — does NOT append to farm.tunnels.
    static func connectAreas(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let dx = abs(areaB.centerX - areaA.centerX)
        let dy = abs(areaB.centerY - areaA.centerY)
        if dx >= dy {
            return carveHorizontalTunnels(&farm, areaA: areaA, areaB: areaB)
        } else {
            return carveVerticalTunnels(&farm, areaA: areaA, areaB: areaB)
        }
    }
}

// MARK: - Horizontal Tunnels

private extension Tunnels {

    /// Carve two horizontal tunnels between left/right areas.
    static func carveHorizontalTunnels(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let (left, right) = areaA.centerX <= areaB.centerX
            ? (areaA, areaB) : (areaB, areaA)

        let tunnelX1 = left.x2
        let tunnelX2 = right.x1

        var overlapY1 = max(left.interiorY1, right.interiorY1)
        var overlapY2 = min(left.interiorY2, right.interiorY2)

        // Fallback when vertical overlap is too narrow
        if overlapY2 - overlapY1 < 2 {
            let midY = (left.centerY + right.centerY) / 2
            overlapY1 = midY - 1
            overlapY2 = midY + 1
        }

        let span = overlapY2 - overlapY1
        let centerA = overlapY1 + span / 4
        let centerB = overlapY1 + 3 * span / 4

        let tunnel1 = carveOneHorizontalTunnel(
            &farm, areaAID: left.id, areaBID: right.id,
            x1: tunnelX1, x2: tunnelX2, centerY: centerA
        )
        let tunnel2 = carveOneHorizontalTunnel(
            &farm, areaAID: left.id, areaBID: right.id,
            x1: tunnelX1, x2: tunnelX2, centerY: centerB
        )

        farm.computeWallFlags()
        farm.invalidateWalkableCache()
        return [tunnel1, tunnel2]
    }

    /// Carve a single 5-wide horizontal tunnel with barrier walls on each side.
    static func carveOneHorizontalTunnel(
        _ farm: inout FarmGrid,
        areaAID: UUID,
        areaBID: UUID,
        x1: Int,
        x2: Int,
        centerY: Int
    ) -> TunnelConnection {
        let hw = tunnelHalfWidth
        var tunnelCells: [GridPosition] = []

        for x in x1...x2 {
            // Walkable corridor cells
            for dy in -hw...hw {
                let y = centerY + dy
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .floor
                farm.cells[y][x].isWalkable = true
                farm.cells[y][x].isTunnel = true
                tunnelCells.append(GridPosition(x: x, y: y))
            }
            // Barrier walls above and below the corridor.
            // Mouth columns (x == x1 or x == x2) carry the adjacent area's ID so the
            // renderer can draw the area's wall texture instead of the tunnel texture.
            for barrierDY in [-(hw + 1), hw + 1] {
                let y = centerY + barrierDY
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .wall
                farm.cells[y][x].isWalkable = false
                farm.cells[y][x].isTunnel = true
                farm.cells[y][x].isHorizontalWall = true
                if x == x1 {
                    farm.cells[y][x].tunnelMouthAreaId = areaAID
                } else if x == x2 {
                    farm.cells[y][x].tunnelMouthAreaId = areaBID
                }
                tunnelCells.append(GridPosition(x: x, y: y))
            }
        }

        return TunnelConnection(
            id: UUID(),
            areaAId: areaAID,
            areaBId: areaBID,
            cells: tunnelCells,
            orientation: "horizontal"
        )
    }
}

// MARK: - Vertical Tunnels

private extension Tunnels {

    /// Carve two vertical tunnels between top/bottom areas.
    static func carveVerticalTunnels(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let (top, bottom) = areaA.centerY <= areaB.centerY
            ? (areaA, areaB) : (areaB, areaA)

        let tunnelY1 = top.y2
        let tunnelY2 = bottom.y1

        var overlapX1 = max(top.interiorX1, bottom.interiorX1)
        var overlapX2 = min(top.interiorX2, bottom.interiorX2)

        // Fallback when horizontal overlap is too narrow
        if overlapX2 - overlapX1 < 2 {
            let midX = (top.centerX + bottom.centerX) / 2
            overlapX1 = midX - 1
            overlapX2 = midX + 1
        }

        let span = overlapX2 - overlapX1
        let centerA = overlapX1 + span / 4
        let centerB = overlapX1 + 3 * span / 4

        let tunnel1 = carveOneVerticalTunnel(
            &farm, areaAID: top.id, areaBID: bottom.id,
            y1: tunnelY1, y2: tunnelY2, centerX: centerA
        )
        let tunnel2 = carveOneVerticalTunnel(
            &farm, areaAID: top.id, areaBID: bottom.id,
            y1: tunnelY1, y2: tunnelY2, centerX: centerB
        )

        farm.computeWallFlags()
        farm.invalidateWalkableCache()
        return [tunnel1, tunnel2]
    }

    /// Carve a single 5-wide vertical tunnel with barrier walls on each side.
    /// Vertical tunnel barriers are vertical walls — isHorizontalWall stays false.
    static func carveOneVerticalTunnel(
        _ farm: inout FarmGrid,
        areaAID: UUID,
        areaBID: UUID,
        y1: Int,
        y2: Int,
        centerX: Int
    ) -> TunnelConnection {
        let hw = tunnelHalfWidth
        var tunnelCells: [GridPosition] = []

        for y in y1...y2 {
            // Walkable corridor cells
            for dx in -hw...hw {
                let x = centerX + dx
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .floor
                farm.cells[y][x].isWalkable = true
                farm.cells[y][x].isTunnel = true
                tunnelCells.append(GridPosition(x: x, y: y))
            }
            // Barrier walls left and right of the corridor.
            // Explicitly clear isHorizontalWall — the cell may have been an area border wall
            // before tunnel carving, and inherited isHorizontalWall = true from that state.
            // Mouth rows (y == y1 or y == y2) carry the adjacent area's ID so the
            // renderer can draw the area's wall texture instead of the tunnel texture.
            for barrierDX in [-(hw + 1), hw + 1] {
                let x = centerX + barrierDX
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .wall
                farm.cells[y][x].isWalkable = false
                farm.cells[y][x].isTunnel = true
                farm.cells[y][x].isHorizontalWall = false
                if y == y1 {
                    farm.cells[y][x].tunnelMouthAreaId = areaAID
                } else if y == y2 {
                    farm.cells[y][x].tunnelMouthAreaId = areaBID
                }
                tunnelCells.append(GridPosition(x: x, y: y))
            }
        }

        return TunnelConnection(
            id: UUID(),
            areaAId: areaAID,
            areaBId: areaBID,
            cells: tunnelCells,
            orientation: "vertical"
        )
    }
}
