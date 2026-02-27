/// BehaviorMovementBiome — Biome-aware wander direction helpers for pig movement.
/// Extends BehaviorMovement with biome target selection and weighted direction picking.
import Foundation

extension BehaviorMovement {

    // MARK: - Biome Target Selection

    /// Find the biome area this pig is drawn to (color match > preferred biome).
    /// Returns (area, isColorMatch). Returns (nil, false) when no matching biome exists.
    @MainActor
    static func getBiomeWanderTarget(
        controller: BehaviorController,
        pig: GuineaPig
    ) -> (FarmArea?, Bool) {
        let pigPos = pig.position.gridPosition
        if let biomeValue = colorToBiome[pig.phenotype.baseColor] {
            let areas = controller.gameState.farm.findAreasByBiome(biomeValue)
            if !areas.isEmpty {
                let closest = areas.min {
                    abs($0.centerX - pigPos.x) + abs($0.centerY - pigPos.y) <
                    abs($1.centerX - pigPos.x) + abs($1.centerY - pigPos.y)
                }
                return (closest, true)
            }
        }
        if let preferred = pig.preferredBiome {
            let areas = controller.gameState.farm.findAreasByBiome(preferred)
            if !areas.isEmpty {
                let closest = areas.min {
                    abs($0.centerX - pigPos.x) + abs($0.centerY - pigPos.y) <
                    abs($1.centerX - pigPos.x) + abs($1.centerY - pigPos.y)
                }
                return (closest, false)
            }
        }
        return (nil, false)
    }

    // MARK: - Wander Direction Selection

    /// Return cardinal directions in priority order, biased toward `targetArea` if set.
    static func wanderDirections(pig: GuineaPig, targetArea: FarmArea?) -> [(Int, Int)] {
        let allDirs: [(Int, Int)] = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        guard let area = targetArea else {
            var dirs = allDirs
            dirs.shuffle()
            return dirs
        }
        let preferred = weightedRandomDirection(pig: pig, targetArea: area)
        return [preferred] + allDirs.filter { $0 != preferred }
    }

    /// Pick one cardinal direction weighted toward `targetArea`.
    ///
    /// Inside area: boost directions away from the nearest edge (keep pig inside).
    /// Outside area: boost directions toward the area center (pull pig toward biome).
    static func weightedRandomDirection(pig: GuineaPig, targetArea: FarmArea) -> (Int, Int) {
        let directions: [(Int, Int)] = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        let gx = Int(pig.position.x)
        let gy = Int(pig.position.y)
        let inside = targetArea.containsInterior(x: gx, y: gy)
        let weights: [Double] = directions.map { direction in
            let (dx, dy) = direction
            if inside {
                let edgeDist: Int
                switch (dx, dy) {
                case (1, 0):  edgeDist = targetArea.interiorX2 - gx
                case (-1, 0): edgeDist = gx - targetArea.interiorX1
                case (0, 1):  edgeDist = targetArea.interiorY2 - gy
                default:      edgeDist = gy - targetArea.interiorY1
                }
                return edgeDist > 3 ? GameConfig.Behavior.biomeWanderBiasInside : 1.0
            } else {
                let alignment = dx * (targetArea.centerX - gx) + dy * (targetArea.centerY - gy)
                return alignment > 0 ? GameConfig.Behavior.biomeWanderBiasOutside : 1.0
            }
        }
        // Weighted random pick: sample proportional to weights
        let total = weights.reduce(0, +)
        var rand = Double.random(in: 0..<max(total, .ulpOfOne))
        for (index, weight) in weights.enumerated() {
            rand -= weight
            if rand <= 0 { return directions[index] }
        }
        return directions.last ?? (0, 1)
    }
}
