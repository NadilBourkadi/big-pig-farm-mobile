/// Pathfinding — GKGridGraph integration for pig navigation.
/// Maps from: game/pathfinding.py
import Foundation
import GameplayKit

/// Wraps GKGridGraph for grid-based pathfinding.
///
/// GKGridGraph and GKGridGraphNode are NSObject subclasses and are not Sendable.
/// This struct is @unchecked Sendable because:
/// - All stored properties are `let` — immutable after construction
/// - `GKGridGraph.findPath(from:to:)` and `.node(atGridPosition:)` are read-only
/// - All callers run on @MainActor (simulation tick loop); no concurrent access
struct Pathfinding: @unchecked Sendable {
    private let graph: GKGridGraph<GKGridGraphNode>
    private let builtGeneration: Int
    private let gridWidth: Int
    private let gridHeight: Int

    /// Build a pathfinding graph from the current FarmGrid state.
    /// Non-walkable cells are removed from the graph in a single batch operation.
    init(farm: FarmGrid) {
        builtGeneration = farm.gridGeneration
        gridWidth = farm.width
        gridHeight = farm.height

        let graph = GKGridGraph<GKGridGraphNode>(
            fromGridStartingAt: vector_int2(0, 0),
            width: Int32(farm.width),
            height: Int32(farm.height),
            diagonalsAllowed: false
        )

        var nodesToRemove: [GKGridGraphNode] = []
        for y in 0..<farm.height {
            for x in 0..<farm.width where !farm.cells[y][x].isWalkable {
                if let node = graph.node(atGridPosition: vector_int2(Int32(x), Int32(y))) {
                    nodesToRemove.append(node)
                }
            }
        }
        graph.remove(nodesToRemove)
        self.graph = graph
    }

    /// Returns true if this graph matches the current grid generation.
    /// When false, callers should rebuild with a fresh Pathfinding(farm:).
    func isValid(for farm: FarmGrid) -> Bool {
        builtGeneration == farm.gridGeneration
    }

    /// Find a path from start to goal. Returns GridPositions including the start.
    /// Returns an empty array if no path exists.
    /// If goal is non-walkable, finds the nearest walkable cell to goal instead.
    func findPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition] {
        guard let startNode = graph.node(
            atGridPosition: vector_int2(Int32(start.x), Int32(start.y))
        ) else { return [] }

        var targetNode = graph.node(
            atGridPosition: vector_int2(Int32(goal.x), Int32(goal.y))
        )
        if targetNode == nil {
            guard let nearest = findNearestWalkableNode(to: goal) else { return [] }
            targetNode = nearest
        }

        guard let target = targetNode else { return [] }
        if startNode === target { return [start] }

        let pathNodes = graph.findPath(from: startNode, to: target)
        return pathNodes.compactMap { node -> GridPosition? in
            guard let gridNode = node as? GKGridGraphNode else { return nil }
            return GridPosition(x: Int(gridNode.gridPosition.x), y: Int(gridNode.gridPosition.y))
        }
    }

    /// Find the nearest walkable position to pos, searching from distance 1 outward.
    /// Returns nil if no walkable cell found within maxDistance.
    func findNearestWalkable(to pos: GridPosition, maxDistance: Int = 5) -> GridPosition? {
        guard let node = findNearestWalkableNode(to: pos, maxDistance: maxDistance) else {
            return nil
        }
        return GridPosition(x: Int(node.gridPosition.x), y: Int(node.gridPosition.y))
    }

    // MARK: - Private

    /// Searches expanding Manhattan-distance shells for the nearest walkable node.
    private func findNearestWalkableNode(
        to pos: GridPosition,
        maxDistance: Int = 5
    ) -> GKGridGraphNode? {
        for distance in 1...maxDistance {
            for dx in -distance...distance {
                for dy in -distance...distance {
                    guard abs(dx) + abs(dy) == distance else { continue }
                    let nx = pos.x + dx
                    let ny = pos.y + dy
                    if let node = graph.node(
                        atGridPosition: vector_int2(Int32(nx), Int32(ny))
                    ) {
                        return node
                    }
                }
            }
        }
        return nil
    }
}
