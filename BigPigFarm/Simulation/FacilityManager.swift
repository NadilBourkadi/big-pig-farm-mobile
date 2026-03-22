/// FacilityManager — Core class, path caching, failure tracking, and area populations.
/// Maps from: simulation/facility_manager.py
import Foundation

// MARK: - PathCacheKey

/// Identifies a cached path by endpoints and grid generation.
/// The generation field auto-invalidates entries when the walkable layout changes.
struct PathCacheKey: Hashable, Sendable {
    let start: GridPosition
    let goal: GridPosition
    let generation: Int
}

// MARK: - OrderedPathCache

/// Approximate-LRU path cache. New entries append to an order array;
/// eviction removes from the front. O(1) writes, O(n) eviction (n ≤ 2048).
/// Profile before upgrading to a doubly-linked-list LRU.
/// @MainActor — all access goes through FacilityManager which is @MainActor.
@MainActor
final class OrderedPathCache {
    private var cache: [PathCacheKey: [GridPosition]] = [:]
    private var order: [PathCacheKey] = []
    let maxSize: Int

    init(maxSize: Int = 2048) {
        self.maxSize = maxSize
        cache.reserveCapacity(maxSize)
    }

    func get(_ key: PathCacheKey) -> [GridPosition]? {
        cache[key]
    }

    func set(_ key: PathCacheKey, path: [GridPosition]) {
        if cache[key] != nil {
            cache[key] = path
            return
        }
        cache[key] = path
        order.append(key)
        while cache.count > maxSize, !order.isEmpty {
            let oldest = order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    func clear() {
        cache.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    var count: Int { cache.count }
    var isEmpty: Bool { cache.isEmpty }
}

// MARK: - FacilityManager

/// Manages facility selection, occupancy tracking, and resource consumption.
/// Ported from Python FacilityManager (~858 lines). Split across three files:
///   FacilityManager.swift — core, path cache, failure tracking, area populations
///   FacilityScoring.swift — scoring, ranking, occupancy detection
///   FacilityConsumption.swift — arrival handling, resource consumption, alternatives
@MainActor
final class FacilityManager {
    weak var gameState: GameState!
    let collision: CollisionHandler

    // MARK: - Path Cache

    let pathCache = OrderedPathCache()
    private var pathfindingGraph: Pathfinding?

    // Performance counters (reset each debug snapshot window)
    var cacheHits: Int = 0
    var cacheMisses: Int = 0

    // MARK: - Failure Tracking

    private var failedFacilities: [UUID: Set<UUID>] = [:]
    private var failedCooldowns: [UUID: Int] = [:]

    // MARK: - Area Populations

    private(set) var areaPopulations: [UUID: Int] = [:]
    private(set) var areaCapacities: [UUID: Int] = [:]

    // MARK: - Init

    init(gameState: GameState, collision: CollisionHandler) {
        self.gameState = gameState
        self.collision = collision
    }

    // MARK: - Path Cache

    /// Find a path using the cross-tick LRU cache.
    /// Tries a cheap straight-line shortcut before falling back to A*.
    func cachedFindPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition] {
        if start == goal { return [start] }

        let generation = gameState.farm.gridGeneration
        let key = PathCacheKey(start: start, goal: goal, generation: generation)

        if let cached = pathCache.get(key) {
            cacheHits += 1
            return cached
        }

        // Straight-line shortcut for nearby goals (avoids A* heap overhead)
        let manhattan = abs(start.x - goal.x) + abs(start.y - goal.y)
        if manhattan <= GameConfig.Behavior.straightLineMaxDistance {
            if let straight = tryStraightLine(from: start, to: goal) {
                pathCache.set(key, path: straight)
                return straight
            }
        }

        cacheMisses += 1
        let path = fullFindPath(from: start, to: goal)
        pathCache.set(key, path: path)
        return path
    }

    /// Walk one cell at a time towards goal — diagonal first, then axis steps.
    /// Returns nil if blocked in all directions (caller falls through to A*).
    func tryStraightLine(from start: GridPosition, to goal: GridPosition) -> [GridPosition]? {
        let farm = gameState.farm
        var path = [start]
        var cx = start.x
        var cy = start.y

        let stepX = goal.x > cx ? 1 : goal.x < cx ? -1 : 0
        let stepY = goal.y > cy ? 1 : goal.y < cy ? -1 : 0

        while cx != goal.x || cy != goal.y {
            // Try diagonal when both axes need movement
            if cx != goal.x && cy != goal.y {
                let nx = cx + stepX
                let ny = cy + stepY
                if farm.isWalkable(nx, ny) {
                    cx = nx; cy = ny
                    path.append(GridPosition(x: cx, y: cy))
                    continue
                }
            }
            // Try X-axis step
            if cx != goal.x {
                let nx = cx + stepX
                if farm.isWalkable(nx, cy) {
                    cx = nx
                    path.append(GridPosition(x: cx, y: cy))
                    continue
                }
            }
            // Try Y-axis step
            if cy != goal.y {
                let ny = cy + stepY
                if farm.isWalkable(cx, ny) {
                    cy = ny
                    path.append(GridPosition(x: cx, y: cy))
                    continue
                }
            }
            // All directions blocked
            return nil
        }
        return path
    }

    /// Full A* via GKGridGraph. Rebuilds graph if the grid layout has changed.
    private func fullFindPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition] {
        if pathfindingGraph == nil || !(pathfindingGraph?.isValid(for: gameState.farm) ?? false) {
            pathfindingGraph = Pathfinding(farm: gameState.farm)
        }
        return pathfindingGraph?.findPath(from: start, to: goal) ?? []
    }

    // MARK: - Area Populations

    /// Rebuild per-area pig population and capacity caches. O(pigs + areas).
    /// Called once per tick before scoring runs.
    func updateAreaPopulations() {
        let farm = gameState.farm
        areaPopulations.removeAll(keepingCapacity: true)
        areaCapacities.removeAll(keepingCapacity: true)

        for pig in gameState.getPigsList() {
            if let areaId = pig.currentAreaId {
                areaPopulations[areaId, default: 0] += 1
            }
        }
        for area in farm.areas {
            areaCapacities[area.id] = farm.getAreaCapacity(area.id)
        }
    }

    // MARK: - Failure Tracking

    func getFailedFacilities(_ pigId: UUID) -> Set<UUID> {
        failedFacilities[pigId] ?? []
    }

    func addFailedFacility(_ pigId: UUID, _ facilityId: UUID) {
        failedFacilities[pigId, default: []].insert(facilityId)
    }

    func clearFailedFacilities(_ pigId: UUID) {
        failedFacilities[pigId] = []
    }

    func getFailedCooldown(_ pigId: UUID) -> Int {
        failedCooldowns[pigId] ?? 0
    }

    func setFailedCooldown(_ pigId: UUID, _ cycles: Int) {
        failedCooldowns[pigId] = cycles
    }

    func tickFailedCooldown(_ pigId: UUID) {
        guard var cooldown = failedCooldowns[pigId], cooldown > 0 else { return }
        cooldown -= 1
        if cooldown <= 0 {
            failedFacilities[pigId] = []
            failedCooldowns.removeValue(forKey: pigId)
        } else {
            failedCooldowns[pigId] = cooldown
        }
    }

    /// Set arrival failure cooldown, using shorter cooldown for critical needs.
    func setArrivalFailedCooldown(pig: GuineaPig) {
        let isCritical = pig.needs.hunger < Double(GameConfig.Needs.criticalThreshold)
            || pig.needs.thirst < Double(GameConfig.Needs.criticalThreshold)
        setFailedCooldown(
            pig.id,
            isCritical
                ? GameConfig.Behavior.criticalFailedCooldownCycles
                : GameConfig.Behavior.arrivalFailedCooldownCycles
        )
    }

    // MARK: - Lifecycle

    func cleanupPig(_ pigId: UUID) {
        failedFacilities.removeValue(forKey: pigId)
        failedCooldowns.removeValue(forKey: pigId)
    }

    func resetAll() {
        failedFacilities.removeAll()
        failedCooldowns.removeAll()
        pathCache.clear()
    }

    func resetPerfCounters() {
        cacheHits = 0
        cacheMisses = 0
    }

    // MARK: - Internal Accessors (used by extension files)

    var farm: FarmGrid { gameState.farm }
    var pigs: [UUID: GuineaPig] { gameState.guineaPigs }

    func getFacilityBiome(_ facility: Facility) -> String? {
        guard let areaId = facility.areaId else { return nil }
        return gameState.farm.getAreaByID(areaId)?.biome.rawValue
    }

    /// Target facility first, then all facilities (used by arrival/consumption code).
    func getCandidateFacilitiesForArrival(pig: GuineaPig) -> [Facility] {
        if let targetId = pig.targetFacilityId,
           let target = gameState.getFacility(targetId) {
            return [target]
        }
        return gameState.getFacilitiesList()
    }

    /// Count other pigs currently eating at the same facility (Feast Table social bonus).
    func countCoDiners(pig: GuineaPig, facility: Facility) -> Int {
        var counted: Set<UUID> = []
        for point in facility.interactionPoints {
            for other in collision.spatialGrid.getNearby(
                x: Double(point.x), y: Double(point.y), pigs: pigs
            ) {
                if other.id == pig.id || counted.contains(other.id) { continue }
                if other.behaviorState == .eating && other.targetFacilityId == facility.id {
                    counted.insert(other.id)
                }
            }
        }
        return counted.count
    }
}
