/// Collision — Spatial hash grid and separation forces for pig collision.
/// Maps from: simulation/collision.py
import Foundation

// MARK: - SpatialGrid

/// Uniform spatial hash grid for O(n*k) proximity lookups.
/// Cell size of 5 keeps bucket sizes small on typical farm layouts.
struct SpatialGrid: Sendable {
    private static let cellSize: Int = 5
    private var cells: [GridPosition: [UUID]] = [:]

    mutating func rebuild(pigs: [GuineaPig]) {
        cells.removeAll(keepingCapacity: true)
        for pig in pigs {
            let key = GridPosition(
                x: Int(pig.position.x) / Self.cellSize,
                y: Int(pig.position.y) / Self.cellSize
            )
            cells[key, default: []].append(pig.id)
        }
    }

    func getNearby(x: Double, y: Double, pigs: [UUID: GuineaPig]) -> [GuineaPig] {
        let cx = Int(x) / Self.cellSize
        let cy = Int(y) / Self.cellSize
        var result: [GuineaPig] = []
        for dx in -1...1 {
            for dy in -1...1 {
                let key = GridPosition(x: cx + dx, y: cy + dy)
                for id in cells[key] ?? [] {
                    if let pig = pigs[id] {
                        result.append(pig)
                    }
                }
            }
        }
        return result
    }

    func uniqueNearbyPairs(pigs: [UUID: GuineaPig]) -> [(GuineaPig, GuineaPig)] {
        var seen: Set<String> = []
        var pairs: [(GuineaPig, GuineaPig)] = []
        for (_, bucket) in cells {
            for i in 0..<bucket.count {
                for j in (i + 1)..<bucket.count {
                    let leftId = bucket[i].uuidString
                    let rightId = bucket[j].uuidString
                    let key = leftId < rightId ? "\(leftId):\(rightId)" : "\(rightId):\(leftId)"
                    guard seen.insert(key).inserted else { continue }
                    if let pigA = pigs[bucket[i]], let pigB = pigs[bucket[j]] {
                        pairs.append((pigA, pigB))
                    }
                }
            }
        }
        return pairs
    }
}

// MARK: - CollisionHandler

/// Handles collision detection and pig separation using the spatial grid.
@MainActor
final class CollisionHandler {
    private unowned let gameState: GameState
    var spatialGrid = SpatialGrid()

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func rebuildSpatialGrid() {
        // TODO(pfw): Implement full spatial grid rebuild with area-aware bucketing
        spatialGrid.rebuild(pigs: gameState.getPigsList())
    }

    func separateOverlappingPigs() {
        // TODO(pfw): Implement tiered blocking/separation thresholds (5 tiers)
    }

    func rescueNonWalkablePigs(_ pigs: [GuineaPig]) {
        // TODO(pfw): Teleport pigs stuck on non-walkable cells to nearest walkable cell
    }

    func isCellOccupiedByPig(x: Int, y: Int, excludePig: GuineaPig?) -> Bool {
        // TODO(pfw): Check spatial grid for pig occupancy at given cell
        false
    }

    func isPositionBlocked(
        targetX: Double,
        targetY: Double,
        excludePig: GuineaPig,
        minDistance: Double
    ) -> Bool {
        // TODO(pfw): Return true if another pig is within minDistance of target
        false
    }

    func getPigsTargetingFacility(_ facilityID: UUID) -> Set<UUID> {
        // TODO(pfw): Return IDs of pigs currently targeting this facility
        []
    }
}
