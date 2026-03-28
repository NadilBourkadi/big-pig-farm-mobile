/// PathfindingBenchmarkTests — Profile GKGridGraph vs custom A* on 96x56 grids.
///
/// Compares Apple's GKGridGraph pathfinding against a hand-rolled A* that reads
/// FarmGrid.isWalkable directly. Measures time per query, graph construction cost,
/// and memory overhead. The custom A* is test-only — not a production replacement.
///
/// Output lines use the `[PathBench]` prefix for grep-ability.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Min-Heap (test-only)

/// Array-backed binary min-heap ordered by `priority`.
private struct MinHeap<T> {
    private var storage: [(priority: Int, value: T)] = []

    var isEmpty: Bool { storage.isEmpty }

    mutating func push(_ value: T, priority: Int) {
        storage.append((priority, value))
        siftUp(storage.count - 1)
    }

    mutating func pop() -> T? {
        guard !storage.isEmpty else { return nil }
        if storage.count == 1 { return storage.removeLast().value }
        let result = storage[0].value
        storage[0] = storage.removeLast()
        siftDown(0)
        return result
    }

    private mutating func siftUp(_ index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            guard storage[i].priority < storage[parent].priority else { break }
            storage.swapAt(i, parent)
            i = parent
        }
    }

    private mutating func siftDown(_ index: Int) {
        var i = index
        let count = storage.count
        while true {
            var smallest = i
            let left = 2 * i + 1
            let right = 2 * i + 2
            if left < count && storage[left].priority < storage[smallest].priority { smallest = left }
            if right < count && storage[right].priority < storage[smallest].priority { smallest = right }
            guard smallest != i else { break }
            storage.swapAt(i, smallest)
            i = smallest
        }
    }
}

// MARK: - Custom A* (test-only)

/// A* pathfinder that reads FarmGrid.isWalkable directly — no GKGridGraph overhead.
/// Uses Manhattan heuristic on a 4-directional grid. Matches the Python source's algorithm.
private struct AStarPathfinder {
    let farm: FarmGrid

    /// Maximum iterations before giving up (matches Python: 1500 + 250 * area_count).
    private var maxIterations: Int { 1_500 + 250 * max(farm.areas.count, 1) }

    private static let offsets = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    func findPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition] {
        if start == goal { return [start] }
        guard farm.isWalkable(start.x, start.y), farm.isWalkable(goal.x, goal.y) else { return [] }

        var openSet = MinHeap<GridPosition>()
        var cameFrom: [GridPosition: GridPosition] = [:]
        var gScore: [GridPosition: Int] = [start: 0]

        openSet.push(start, priority: start.manhattanDistance(to: goal))
        var iterations = 0

        var closedSet: Set<GridPosition> = []

        while let current = openSet.pop() {
            if current == goal { return reconstructPath(cameFrom: cameFrom, current: current) }
            guard !closedSet.contains(current) else { continue }
            closedSet.insert(current)
            iterations += 1
            if iterations >= maxIterations { return [] }

            let currentG = gScore[current, default: Int.max]

            for (dx, dy) in Self.offsets {
                let nx = current.x + dx
                let ny = current.y + dy
                guard farm.isWalkable(nx, ny) else { continue }

                let neighbor = GridPosition(x: nx, y: ny)
                let tentativeG = currentG + 1

                if tentativeG < gScore[neighbor, default: Int.max] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeG
                    openSet.push(neighbor, priority: tentativeG + neighbor.manhattanDistance(to: goal))
                }
            }
        }
        return []
    }

    private func reconstructPath(cameFrom: [GridPosition: GridPosition], current: GridPosition) -> [GridPosition] {
        var path = [current]
        var node = current
        while let prev = cameFrom[node] {
            path.append(prev)
            node = prev
        }
        return path.reversed()
    }
}

// MARK: - Grid Factories (test-only)

/// Single-area 96x56 grid, all interior cells walkable.
@MainActor
private func makeOpenGrid() -> FarmGrid {
    var grid = FarmGrid(width: 96, height: 56)
    let area = FarmArea(
        id: UUID(), name: "Open", biome: .meadow,
        x1: 0, y1: 0, x2: 95, y2: 55, isStarter: true
    )
    grid.addArea(area)
    return grid
}

/// Single-area 96x56 grid with ~200 scattered non-walkable cells (deterministic).
@MainActor
private func makeObstacleGrid() -> FarmGrid {
    var grid = makeOpenGrid()
    // Place obstacles in a deterministic pattern: every cell where (x*7 + y*13) % 23 == 0
    for y in 2..<54 {
        for x in 2..<94 where (x * 7 + y * 13) % 23 == 0 {
            grid.cells[y][x].isWalkable = false
        }
    }
    grid.invalidateWalkableCache()
    return grid
}

/// 4-room 96x56 grid with gap corridors between rooms (simulates tunnel zones).
@MainActor
private func makeMultiRoomGrid() -> FarmGrid {
    var grid = FarmGrid(width: 96, height: 56)
    let areas = [
        FarmArea(id: UUID(), name: "NW", biome: .meadow,
                 x1: 0, y1: 0, x2: 43, y2: 24, gridCol: 0, gridRow: 0),
        FarmArea(id: UUID(), name: "NE", biome: .burrow,
                 x1: 48, y1: 0, x2: 91, y2: 24, gridCol: 1, gridRow: 0),
        FarmArea(id: UUID(), name: "SW", biome: .garden,
                 x1: 0, y1: 28, x2: 43, y2: 52, gridCol: 0, gridRow: 1),
        FarmArea(id: UUID(), name: "SE", biome: .alpine,
                 x1: 48, y1: 28, x2: 91, y2: 52, gridCol: 1, gridRow: 1),
    ]
    for area in areas { grid.addArea(area) }
    return grid
}

// MARK: - Pair Generators

/// Deterministic start/goal pairs within Manhattan distance 5–15.
private func shortPairs(count: Int, width: Int, height: Int) -> [(GridPosition, GridPosition)] {
    (0..<count).map { i in
        let sx = 3 + (i * 7) % (width - 6)
        let sy = 3 + (i * 3) % (height - 6)
        let dx = 3 + (i % 11)
        let dy = 2 + (i % 5)
        let gx = min(sx + dx, width - 3)
        let gy = min(sy + dy, height - 3)
        return (GridPosition(x: sx, y: sy), GridPosition(x: gx, y: gy))
    }
}

/// Deterministic start/goal pairs with Manhattan distance 80+.
private func longPairs(count: Int, width: Int, height: Int) -> [(GridPosition, GridPosition)] {
    (0..<count).map { i in
        let sx = 2 + (i * 3) % 20
        let sy = 2 + (i * 5) % 15
        let gx = width - 3 - (i * 7) % 20
        let gy = height - 3 - (i * 11) % 15
        return (GridPosition(x: sx, y: sy), GridPosition(x: gx, y: gy))
    }
}

// MARK: - Benchmark Suite

@Suite("Pathfinding Benchmark")
@MainActor
struct PathfindingBenchmarkTests {

    // MARK: - Graph Construction

    @Test("Graph construction: GKGridGraph vs A* on 96x56")
    func graphConstruction() {
        let grid = makeOpenGrid()
        let clock = ContinuousClock()

        let memBefore = memoryUsageMB()
        let gkElapsed = clock.measure { _ = Pathfinding(farm: grid) }
        let memAfterGK = memoryUsageMB()

        let gkMemDelta = memAfterGK - memBefore

        print("[PathBench] Graph construction (96x56 open):")
        print("  GKGridGraph:  build=\(fmt(gkElapsed.milliseconds))ms" +
              "  memDelta=\(fmt(gkMemDelta))MB")
        print("  Custom A*:    no graph construction (reads FarmGrid directly)")

        // Regression guard: construction under 3s in debug
        #expect(gkElapsed.milliseconds < 3_000, "GKGridGraph build took \(fmt(gkElapsed.milliseconds))ms")
    }

    // MARK: - Short Paths

    @Test("Short paths: 100 queries, Manhattan distance 5-15")
    func shortPathComparison() {
        let grid = makeOpenGrid()
        let gk = Pathfinding(farm: grid)
        let astar = AStarPathfinder(farm: grid)
        let pairs = shortPairs(count: 100, width: grid.width, height: grid.height)
        let clock = ContinuousClock()

        let gkElapsed = clock.measure {
            for (start, goal) in pairs { _ = gk.findPath(from: start, to: goal) }
        }
        let astarElapsed = clock.measure {
            for (start, goal) in pairs { _ = astar.findPath(from: start, to: goal) }
        }

        let ratio = gkElapsed.milliseconds / max(astarElapsed.milliseconds, 0.001)
        let gkAvg = fmt(gkElapsed.milliseconds / 100)
        let astarAvg = fmt(astarElapsed.milliseconds / 100)

        print("[PathBench] Short paths (100 queries, d=5-15):")
        print("  GKGridGraph:  total=\(fmt(gkElapsed.milliseconds))ms  avg=\(gkAvg)ms/query")
        print("  Custom A*:    total=\(fmt(astarElapsed.milliseconds))ms  avg=\(astarAvg)ms/query")
        print("  Ratio: GK/A* = \(fmt(ratio))x")

        #expect(gkElapsed.milliseconds < 5_000)
        #expect(astarElapsed.milliseconds < 5_000)
    }

    // MARK: - Long Paths

    @Test("Long paths: 50 queries, Manhattan distance 80+")
    func longPathComparison() {
        let grid = makeOpenGrid()
        let gk = Pathfinding(farm: grid)
        let astar = AStarPathfinder(farm: grid)
        let pairs = longPairs(count: 50, width: grid.width, height: grid.height)
        let clock = ContinuousClock()

        let gkElapsed = clock.measure {
            for (start, goal) in pairs { _ = gk.findPath(from: start, to: goal) }
        }
        let astarElapsed = clock.measure {
            for (start, goal) in pairs { _ = astar.findPath(from: start, to: goal) }
        }

        let ratio = gkElapsed.milliseconds / max(astarElapsed.milliseconds, 0.001)
        let gkAvg = fmt(gkElapsed.milliseconds / 50)
        let astarAvg = fmt(astarElapsed.milliseconds / 50)

        print("[PathBench] Long paths (50 queries, d=80+):")
        print("  GKGridGraph:  total=\(fmt(gkElapsed.milliseconds))ms  avg=\(gkAvg)ms/query")
        print("  Custom A*:    total=\(fmt(astarElapsed.milliseconds))ms  avg=\(astarAvg)ms/query")
        print("  Ratio: GK/A* = \(fmt(ratio))x")

        #expect(gkElapsed.milliseconds < 10_000)
        #expect(astarElapsed.milliseconds < 10_000)
    }

    // MARK: - Obstacles

    @Test("Obstacle grid: 50 mixed queries with scattered walls")
    func obstaclePathComparison() {
        let grid = makeObstacleGrid()
        let gk = Pathfinding(farm: grid)
        let astar = AStarPathfinder(farm: grid)
        let pairs = longPairs(count: 50, width: grid.width, height: grid.height)
        let clock = ContinuousClock()

        let gkElapsed = clock.measure {
            for (start, goal) in pairs { _ = gk.findPath(from: start, to: goal) }
        }
        let astarElapsed = clock.measure {
            for (start, goal) in pairs { _ = astar.findPath(from: start, to: goal) }
        }

        let ratio = gkElapsed.milliseconds / max(astarElapsed.milliseconds, 0.001)
        let gkAvg = fmt(gkElapsed.milliseconds / 50)
        let astarAvg = fmt(astarElapsed.milliseconds / 50)

        print("[PathBench] Obstacle grid (50 queries, ~200 walls):")
        print("  GKGridGraph:  total=\(fmt(gkElapsed.milliseconds))ms  avg=\(gkAvg)ms/query")
        print("  Custom A*:    total=\(fmt(astarElapsed.milliseconds))ms  avg=\(astarAvg)ms/query")
        print("  Ratio: GK/A* = \(fmt(ratio))x")

        #expect(gkElapsed.milliseconds < 10_000)
        #expect(astarElapsed.milliseconds < 10_000)
    }

    // MARK: - Multi-Room

    @Test("Multi-room: 50 cross-room queries through gap corridors")
    func multiRoomComparison() {
        let grid = makeMultiRoomGrid()
        let gk = Pathfinding(farm: grid)
        let astar = AStarPathfinder(farm: grid)
        // Cross-room pairs: NW corner to SE corner
        let pairs = longPairs(count: 50, width: grid.width, height: grid.height)
        let clock = ContinuousClock()

        let gkElapsed = clock.measure {
            for (start, goal) in pairs { _ = gk.findPath(from: start, to: goal) }
        }
        let astarElapsed = clock.measure {
            for (start, goal) in pairs { _ = astar.findPath(from: start, to: goal) }
        }

        let ratio = gkElapsed.milliseconds / max(astarElapsed.milliseconds, 0.001)
        let gkAvg = fmt(gkElapsed.milliseconds / 50)
        let astarAvg = fmt(astarElapsed.milliseconds / 50)

        print("[PathBench] Multi-room (50 cross-room queries):")
        print("  GKGridGraph:  total=\(fmt(gkElapsed.milliseconds))ms  avg=\(gkAvg)ms/query")
        print("  Custom A*:    total=\(fmt(astarElapsed.milliseconds))ms  avg=\(astarAvg)ms/query")
        print("  Ratio: GK/A* = \(fmt(ratio))x")

        #expect(gkElapsed.milliseconds < 10_000)
        #expect(astarElapsed.milliseconds < 10_000)
    }

    // MARK: - No-Path (Disconnected)

    @Test("No-path: 20 queries to unreachable cells")
    func noPathComparison() {
        var grid = makeOpenGrid()
        // Seal a 5x5 room (outer ring non-walkable, 3x3 walkable interior at 81-83 x 41-43)
        for col in 80...84 { grid.cells[40][col].isWalkable = false }
        for col in 80...84 { grid.cells[44][col].isWalkable = false }
        for row in 40...44 { grid.cells[row][80].isWalkable = false }
        for row in 40...44 { grid.cells[row][84].isWalkable = false }
        grid.invalidateWalkableCache()

        let gk = Pathfinding(farm: grid)
        let astar = AStarPathfinder(farm: grid)
        let goal = GridPosition(x: 82, y: 42)
        let starts = (0..<20).map { idx in GridPosition(x: 3 + idx * 3, y: 3) }
        let clock = ContinuousClock()

        let gkElapsed = clock.measure {
            for start in starts { _ = gk.findPath(from: start, to: goal) }
        }
        let astarElapsed = clock.measure {
            for start in starts { _ = astar.findPath(from: start, to: goal) }
        }

        let ratio = gkElapsed.milliseconds / max(astarElapsed.milliseconds, 0.001)
        let gkAvg = fmt(gkElapsed.milliseconds / 20)
        let astarAvg = fmt(astarElapsed.milliseconds / 20)

        print("[PathBench] No-path queries (20 queries, isolated goal):")
        print("  GKGridGraph:  total=\(fmt(gkElapsed.milliseconds))ms  avg=\(gkAvg)ms/query")
        print("  Custom A*:    total=\(fmt(astarElapsed.milliseconds))ms  avg=\(astarAvg)ms/query")
        print("  Ratio: GK/A* = \(fmt(ratio))x")
    }
}

// MARK: - Formatting

private func fmt(_ value: Double) -> String {
    String(format: "%.2f", value)
}
