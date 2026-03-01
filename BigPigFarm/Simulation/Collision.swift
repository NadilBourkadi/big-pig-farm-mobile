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

    /// Yield unique (pigA, pigB) pairs from pigs in the same or adjacent cells.
    ///
    /// For each cell, this collects the full 3×3 neighborhood (same + 8 adjacent)
    /// and pairs each pig in the bucket against all pigs in the neighborhood.
    /// Canonical UUID string ordering deduplicates pairs that appear from both sides
    /// of a cell boundary.
    func uniqueNearbyPairs(pigs: [UUID: GuineaPig]) -> [(GuineaPig, GuineaPig)] {
        var seen = Set<String>()
        var pairs: [(GuineaPig, GuineaPig)] = []
        for (cellKey, bucket) in cells {
            var neighborhood: [UUID] = []
            for dx in -1...1 {
                for dy in -1...1 {
                    let nk = GridPosition(x: cellKey.x + dx, y: cellKey.y + dy)
                    if let nb = cells[nk] {
                        neighborhood.append(contentsOf: nb)
                    }
                }
            }
            for aID in bucket {
                for bID in neighborhood {
                    guard aID != bID else { continue }
                    let aStr = aID.uuidString
                    let bStr = bID.uuidString
                    // Canonical ordering — matches Python's `a.id >= b.id: continue`
                    guard aStr < bStr else { continue }
                    let key = "\(aStr):\(bStr)"
                    guard seen.insert(key).inserted else { continue }
                    if let pigA = pigs[aID], let pigB = pigs[bID] {
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
    private weak var gameState: GameState!
    var spatialGrid = SpatialGrid()
    private var facilityTargets: [UUID: Set<UUID>] = [:]

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Re-bin all pigs and rebuild the facility target index.
    /// Call once per tick before behavior updates.
    func rebuildSpatialGrid() {
        let pigs = gameState.getPigsList()
        spatialGrid.rebuild(pigs: pigs)
        var ft: [UUID: Set<UUID>] = [:]
        for pig in pigs {
            if let fid = pig.targetFacilityId {
                ft[fid, default: []].insert(pig.id)
            }
        }
        facilityTargets = ft
    }

    /// Push apart any pigs that are too close to each other.
    ///
    /// Uses tiered separation thresholds based on movement state.
    /// The invariant is: separation threshold < blocking threshold for the same
    /// movement state, so separation never undoes movement that passed the
    /// blocking check.
    func separateOverlappingPigs() {
        let facilityUseStates: Set<BehaviorState> = [.eating, .drinking, .sleeping, .playing]

        for (pigASnapshot, pigBSnapshot) in spatialGrid.uniqueNearbyPairs(pigs: gameState.guineaPigs) {
            // Re-read fresh positions: earlier pair updates in this tick may have moved these pigs.
            guard let pigA = gameState.guineaPigs[pigASnapshot.id],
                  let pigB = gameState.guineaPigs[pigBSnapshot.id] else { continue }

            // Courting pair: skip separation so they can be adjacent.
            if pigA.behaviorState == .courting
                && pigB.behaviorState == .courting
                && pigA.courtingPartnerId == pigB.id {
                continue
            }

            let bothMoving = !pigA.path.isEmpty && !pigB.path.isEmpty
            let bothFacility = facilityUseStates.contains(pigA.behaviorState)
                && facilityUseStates.contains(pigB.behaviorState)

            let threshold: Double
            if bothMoving {
                threshold = GameConfig.Behavior.separationBothMoving    // 1.0
            } else if bothFacility {
                threshold = GameConfig.Behavior.separationFacilityUse   // 1.0
            } else if !pigA.path.isEmpty || !pigB.path.isEmpty {
                threshold = GameConfig.Behavior.separationOneMoving      // 2.0
            } else {
                threshold = GameConfig.Behavior.minPigDistance           // 3.0
            }

            applySeparation(pigA: pigA, pigB: pigB, threshold: threshold)
        }
    }

    /// Apply the push-apart force for a pair of pigs given a separation threshold.
    ///
    /// Only moves both pigs if BOTH new positions are walkable — asymmetric
    /// separation near walls causes ratcheting that pins pigs in place.
    private func applySeparation(pigA: GuineaPig, pigB: GuineaPig, threshold: Double) {
        let dx = pigB.position.x - pigA.position.x
        let dy = pigB.position.y - pigA.position.y
        let distance = (dx * dx + dy * dy).squareRoot()

        if distance < threshold && distance > GameConfig.Behavior.overlapEpsilon {
            let overlap = threshold - distance
            let separation = overlap / 2.0 + GameConfig.Behavior.separationPadding
            let nx = dx / distance
            let ny = dy / distance
            let newAx = pigA.position.x - nx * separation
            let newAy = pigA.position.y - ny * separation
            let newBx = pigB.position.x + nx * separation
            let newBy = pigB.position.y + ny * separation
            if gameState.farm.isWalkable(Int(newAx), Int(newAy))
                && gameState.farm.isWalkable(Int(newBx), Int(newBy)) {
                var movedA = pigA; movedA.position.x = newAx; movedA.position.y = newAy
                var movedB = pigB; movedB.position.x = newBx; movedB.position.y = newBy
                gameState.updateGuineaPig(movedA)
                gameState.updateGuineaPig(movedB)
            }
        } else if distance <= GameConfig.Behavior.overlapEpsilon {
            // Pigs are exactly on top of each other — push one in a random direction.
            let angle = Double.random(in: 0..<(2.0 * .pi))
            let push = GameConfig.Behavior.minPigDistance / 2.0
            let newX = pigB.position.x + push * cos(angle)
            let newY = pigB.position.y + push * sin(angle)
            if gameState.farm.isWalkable(Int(newX), Int(newY)) {
                var movedB = pigB; movedB.position.x = newX; movedB.position.y = newY
                gameState.updateGuineaPig(movedB)
            }
        }
    }

    /// Post-collision sweep: rescue any pigs that ended up on non-walkable cells.
    func rescueNonWalkablePigs(_ pigs: [GuineaPig]) {
        for pig in pigs {
            let gx = Int(pig.position.x)
            let gy = Int(pig.position.y)
            guard !gameState.farm.isWalkable(gx, gy) else { continue }

            var rescued = pig
            rescued.path = []
            rescued.targetPosition = nil
            rescued.targetFacilityId = nil
            rescued.behaviorState = .idle

            if let areaId = pig.currentAreaId,
               let safe = gameState.farm.findRandomWalkableInArea(areaId) {
                rescued.position = Position(x: Double(safe.x), y: Double(safe.y))
            } else if let safe = gameState.farm.findRandomWalkable() {
                rescued.position = Position(x: Double(safe.x), y: Double(safe.y))
            }
            gameState.updateGuineaPig(rescued)
        }
    }

    /// Check if a cell is occupied by another guinea pig.
    func isCellOccupiedByPig(x: Int, y: Int, excludePig: GuineaPig?) -> Bool {
        for otherPig in spatialGrid.getNearby(x: Double(x), y: Double(y), pigs: gameState.guineaPigs) {
            if let exclude = excludePig, otherPig.id == exclude.id { continue }
            let gp = otherPig.position.gridPosition
            if gp.x == x && gp.y == y {
                return true
            }
        }
        return false
    }

    /// Return true if another pig is within minDistance of the target position.
    ///
    /// Uses tiered blocking radii based on movement state, so pigs can pass each
    /// other on the way to facilities instead of forming traffic jams.
    func isPositionBlocked(
        targetX: Double,
        targetY: Double,
        excludePig: GuineaPig,
        minDistance: Double = GameConfig.Behavior.blockingDefault
    ) -> Bool {
        // Emergency override: pigs with critical health ignore blocking so they
        // can push through traffic to reach food/water.
        if excludePig.needs.health < Double(GameConfig.Needs.criticalThreshold) {
            return false
        }

        for otherPig in spatialGrid.getNearby(x: targetX, y: targetY, pigs: gameState.guineaPigs) {
            if otherPig.id == excludePig.id { continue }

            // Don't block a pig from approaching its courting partner.
            if excludePig.courtingPartnerId == otherPig.id
                && excludePig.behaviorState == .courting {
                continue
            }

            let effectiveDistance: Double
            if !excludePig.path.isEmpty && !otherPig.path.isEmpty {
                // Both actively moving — use tighter radius to allow passing.
                effectiveDistance = GameConfig.Behavior.blockingBothMoving
            } else if [BehaviorState.eating, .drinking, .sleeping, .playing]
                .contains(otherPig.behaviorState) {
                // Other pig is using a facility — "tucked in", reduced blocking.
                effectiveDistance = GameConfig.Behavior.blockingFacilityUse
            } else {
                effectiveDistance = minDistance
            }

            let dx = targetX - otherPig.position.x
            let dy = targetY - otherPig.position.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < effectiveDistance {
                return true
            }
        }
        return false
    }

    /// Return the IDs of pigs currently targeting the given facility.
    func getPigsTargetingFacility(_ facilityID: UUID) -> Set<UUID> {
        facilityTargets[facilityID] ?? []
    }
}
