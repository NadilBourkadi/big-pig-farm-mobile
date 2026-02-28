/// Tunnels — Tunnel carving between farm areas.
/// Maps from: game/world_tunnels.py
import Foundation

// Tunnel corridor half-width. Full width = 2 * tunnelHalfWidth + 1 = 5 cells.
// iOS uses uniform width for both orientations (Python doubles vertical width
// to compensate for terminal character aspect ratio; SpriteKit has square pixels).
private let tunnelHalfWidth = 2

// MARK: - Tunnels

enum Tunnels {
    /// Carve two 5-wide tunnel corridors between two areas.
    /// Tunnels are placed at 1/3 and 2/3 of the shared wall overlap.
    /// Returns the new TunnelConnections (does NOT append to farm.tunnels — caller handles that).
    static func connectAreas(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let dx = areaB.centerX - areaA.centerX
        let dy = areaB.centerY - areaA.centerY
        if abs(dx) >= abs(dy) {
            return carveHorizontalTunnels(&farm, areaA: areaA, areaB: areaB)
        } else {
            return carveVerticalTunnels(&farm, areaA: areaA, areaB: areaB)
        }
    }
}

// MARK: - Horizontal Tunnels

extension Tunnels {
    private static func carveHorizontalTunnels(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let (left, right) = areaA.centerX <= areaB.centerX
            ? (areaA, areaB) : (areaB, areaA)

        var overlapY1 = max(left.interiorY1, right.interiorY1)
        var overlapY2 = min(left.interiorY2, right.interiorY2)

        if overlapY2 - overlapY1 < 2 {
            let midY = (left.centerY + right.centerY) / 2
            overlapY1 = midY - 1
            overlapY2 = midY + 1
        }

        let span = overlapY2 - overlapY1
        let centerA = overlapY1 + span / 4
        let centerB = overlapY1 + 3 * span / 4
        let xRange = left.x2...right.x1

        let tunnel1 = carveOneHorizontalTunnel(
            &farm, areaAID: left.id, areaBID: right.id,
            xRange: xRange, centerY: centerA
        )
        let tunnel2 = carveOneHorizontalTunnel(
            &farm, areaAID: left.id, areaBID: right.id,
            xRange: xRange, centerY: centerB
        )

        farm.computeWallFlags()
        farm.invalidateWalkableCache()
        return [tunnel1, tunnel2]
    }

    private static func carveOneHorizontalTunnel(
        _ farm: inout FarmGrid,
        areaAID: UUID, areaBID: UUID,
        xRange: ClosedRange<Int>, centerY: Int
    ) -> TunnelConnection {
        let halfWidth = tunnelHalfWidth
        var tunnelCells: [GridPosition] = []

        for x in xRange {
            for dy in -halfWidth...halfWidth {
                let y = centerY + dy
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .floor
                farm.cells[y][x].isWalkable = true
                farm.cells[y][x].isTunnel = true
                tunnelCells.append(GridPosition(x: x, y: y))
            }
            for barrierDY in [-(halfWidth + 1), halfWidth + 1] {
                let y = centerY + barrierDY
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .wall
                farm.cells[y][x].isWalkable = false
                farm.cells[y][x].isTunnel = true
                farm.cells[y][x].isHorizontalWall = true
                tunnelCells.append(GridPosition(x: x, y: y))
            }
        }

        return TunnelConnection(
            id: UUID(), areaAId: areaAID, areaBId: areaBID,
            cells: tunnelCells, orientation: "horizontal"
        )
    }
}

// MARK: - Vertical Tunnels

extension Tunnels {
    private static func carveVerticalTunnels(
        _ farm: inout FarmGrid,
        areaA: FarmArea,
        areaB: FarmArea
    ) -> [TunnelConnection] {
        let (top, bottom) = areaA.centerY <= areaB.centerY
            ? (areaA, areaB) : (areaB, areaA)

        var overlapX1 = max(top.interiorX1, bottom.interiorX1)
        var overlapX2 = min(top.interiorX2, bottom.interiorX2)

        if overlapX2 - overlapX1 < 2 {
            let midX = (top.centerX + bottom.centerX) / 2
            overlapX1 = midX - 1
            overlapX2 = midX + 1
        }

        let span = overlapX2 - overlapX1
        let centerA = overlapX1 + span / 4
        let centerB = overlapX1 + 3 * span / 4
        let yRange = top.y2...bottom.y1

        let tunnel1 = carveOneVerticalTunnel(
            &farm, areaAID: top.id, areaBID: bottom.id,
            yRange: yRange, centerX: centerA
        )
        let tunnel2 = carveOneVerticalTunnel(
            &farm, areaAID: top.id, areaBID: bottom.id,
            yRange: yRange, centerX: centerB
        )

        farm.computeWallFlags()
        farm.invalidateWalkableCache()
        return [tunnel1, tunnel2]
    }

    private static func carveOneVerticalTunnel(
        _ farm: inout FarmGrid,
        areaAID: UUID, areaBID: UUID,
        yRange: ClosedRange<Int>, centerX: Int
    ) -> TunnelConnection {
        let halfWidth = tunnelHalfWidth
        var tunnelCells: [GridPosition] = []

        for y in yRange {
            for dx in -halfWidth...halfWidth {
                let x = centerX + dx
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .floor
                farm.cells[y][x].isWalkable = true
                farm.cells[y][x].isTunnel = true
                tunnelCells.append(GridPosition(x: x, y: y))
            }
            for barrierDX in [-(halfWidth + 1), halfWidth + 1] {
                let x = centerX + barrierDX
                guard farm.isValidPosition(x, y) else { continue }
                farm.cells[y][x].cellType = .wall
                farm.cells[y][x].isWalkable = false
                farm.cells[y][x].isTunnel = true
                // Vertical tunnel barrier walls are vertical (not horizontal)
                tunnelCells.append(GridPosition(x: x, y: y))
            }
        }

        return TunnelConnection(
            id: UUID(), areaAId: areaAID, areaBId: areaBID,
            cells: tunnelCells, orientation: "vertical"
        )
    }
}
