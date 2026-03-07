# Spec 04 — Game Engine

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** 02 (Data Models)
> **Blocks:** 05 (Behavior AI), 06 (Farm Scene), 07 (SwiftUI Screens), 08 (Persistence)

---

## 1. Overview

This document specifies the complete game engine layer for the iOS port: the `GameState` observable container, the `GameEngine` tick loop, the `FarmGrid` spatial world with pathfinding, tunnels, areas, and expansion, the `SimulationRunner` tick orchestration, the collision system, the needs system, the facility manager, the auto-arrange algorithm, the economy subsystems (shop, market, contracts, upgrades, currency), and the protocol interfaces that decouple simulation subsystems from the concrete state type.

Together these systems form the headless simulation -- everything needed to run the game without rendering. An implementer can build and test the entire engine in a console test harness before any SpriteKit or SwiftUI code exists.

### Scope

**In scope:**
- `GameState` (`@Observable class`) -- root state container with all game data
- `GameEngine` -- timer-based tick loop with 7 speed levels
- `GameTime` -- game clock advancement
- `FarmGrid` -- 2D cell grid, walkability, facility placement, area queries
- `Pathfinding` -- `GKGridGraph` integration replacing custom A*
- `Tunnels` -- corridor carving between adjacent areas
- `AreaManager` -- area registration, cell repair, tunnel rebuild
- `GridExpansion` -- grid resizing, 2-column layout, room addition
- `NeedsSystem` -- decay/recovery per game hour, personality modifiers, perk effects
- `Collision` -- spatial hash grid, tiered separation, blocking checks
- `SimulationRunner` -- 13-phase tick orchestration with event callbacks
- `FacilityManager` -- path caching, facility scoring, arrival handling, resource consumption
- `AutoResources` -- drip system, auto-feeders, veggie gardens, AoE facilities
- `AutoArrange` -- zone-based facility layout algorithm
- `Shop` -- facility/perk/tier/room purchase
- `Market` -- pig valuation and selling with contract fulfillment
- `Contracts` -- breeding contract generation, matching, expiry
- `Upgrades` -- 22 permanent perk definitions
- `Currency` -- money management and formatting
- `Protocols` -- narrow protocol interfaces for simulation subsystems

**Out of scope:**
- Behavior AI decision tree, movement, seeking, courtship -- Doc 05
- Breeding pair selection, pregnancy advancement, birth, aging, culling -- Doc 05
- Acclimation system -- Doc 05
- SpriteKit rendering -- Doc 06
- SwiftUI screens -- Doc 07
- Save/load persistence mechanics -- Doc 08

### Deliverable Summary

| Category | Files | Maps From |
|----------|-------|-----------|
| Engine | 10 files | `game/state.py`, `game/engine.py`, `game/world.py`, `game/world_*.py`, `game/auto_arrange.py`, `game/facades.py` |
| Simulation | 4 files | `simulation/runner.py`, `simulation/collision.py`, `simulation/needs.py`, `simulation/auto_resources.py`, `simulation/facility_manager.py` |
| Economy | 5 files | `economy/shop.py`, `economy/market.py`, `economy/contracts.py`, `economy/upgrades.py`, `economy/currency.py` |
| Tests | 3 files | New |

---

## 2. GameState (@Observable class)

**Maps from:** `game/state.py` (265 lines)
**Swift file:** `Engine/GameState.swift`

### Architecture Decision

Per ROADMAP Decision 1, `GameState` is an `@Observable class` (not a struct). The simulation tick mutates dozens of fields across multiple pigs per frame. Reference semantics avoid copy overhead and simplify nested mutation. `@Observable` gives SwiftUI automatic view updates when screens read state properties.

`GameState` is `@MainActor` to ensure all mutations happen on the main thread. It conforms to `@unchecked Sendable` because `@Observable` classes cannot be `Sendable` by default but we guarantee main-actor isolation.

### Type Signature

```swift
import Foundation
import Observation

@Observable
@MainActor
// SAFETY: @unchecked Sendable is safe because every stored property is
// only ever read or written while isolated to @MainActor. Do NOT add
// nonisolated methods that access mutable state.
final class GameState: @unchecked Sendable {
    // MARK: - Core Collections

    /// All guinea pigs keyed by UUID. O(1) lookup.
    var guineaPigs: [UUID: GuineaPig] = [:]

    /// All facilities keyed by UUID. O(1) lookup.
    var facilities: [UUID: Facility] = [:]

    // MARK: - Cached List Snapshots (invalidated on add/remove)

    private var pigsListCache: [GuineaPig]?
    private var facilitiesListCache: [Facility]?
    private var facilitiesByTypeCache: [FacilityType: [Facility]]?

    // MARK: - World

    var farm: FarmGrid = FarmGrid.createStarter()

    // MARK: - Economy

    var money: Int = EconomyConfig.startingMoney

    // MARK: - Time

    var gameTime: GameTime = GameTime()
    var speed: GameSpeed = .normal
    var isPaused: Bool = false

    // MARK: - Session Tracking

    var sessionStart: Date = Date()
    var lastSave: Date?

    // MARK: - Event Log

    var events: [EventLog] = []
    let maxEvents: Int = 100

    // MARK: - Collections

    var pigdex: Pigdex = Pigdex()
    var contractBoard: ContractBoard = ContractBoard()

    // MARK: - Breeding

    var breedingProgram: BreedingProgram = BreedingProgram()
    var breedingPair: BreedingPair?

    // MARK: - Social Affinity

    /// Tracks socialization history between pig pairs.
    /// Key: "smallerUUID:largerUUID", Value: completed socialization count (max 10).
    /// Note: ":" is a safe separator because UUID strings contain only hex digits and "-".
    var socialAffinity: [String: Int] = [:]

    // MARK: - Progression

    var farmTier: Int = 1
    var purchasedUpgrades: Set<String> = []

    // MARK: - Statistics

    var totalPigsBorn: Int = 0
    var totalPigsSold: Int = 0
    var totalEarnings: Int = 0
}
```

### Mutation Methods

```swift
extension GameState {
    // MARK: - Guinea Pig Management

    func addGuineaPig(_ pig: GuineaPig) {
        guineaPigs[pig.id] = pig
        pigsListCache = nil
    }

    func removeGuineaPig(_ pigID: UUID) -> GuineaPig? {
        guard let pig = guineaPigs.removeValue(forKey: pigID) else { return nil }
        pigsListCache = nil
        // Prune affinity entries for the removed pig
        let pigStr = pigID.uuidString
        socialAffinity = socialAffinity.filter { key, _ in
            !key.contains(pigStr)
        }
        return pig
    }

    func getGuineaPig(_ pigID: UUID) -> GuineaPig? {
        guineaPigs[pigID]
    }

    func getPigsList() -> [GuineaPig] {
        if let cached = pigsListCache { return cached }
        let list = Array(guineaPigs.values)
        pigsListCache = list
        return list
    }

    // MARK: - Facility Management

    func addFacility(_ facility: Facility) -> Bool {
        guard farm.placeFacility(facility) else { return false }
        facilities[facility.id] = facility
        facilitiesListCache = nil
        facilitiesByTypeCache = nil
        return true
    }

    func removeFacility(_ facilityID: UUID) -> Facility? {
        guard let facility = facilities.removeValue(forKey: facilityID) else { return nil }
        farm.removeFacility(facility)
        facilitiesListCache = nil
        facilitiesByTypeCache = nil
        return facility
    }

    func getFacility(_ facilityID: UUID) -> Facility? {
        facilities[facilityID]
    }

    func getFacilitiesByType(_ type: FacilityType) -> [Facility] {
        if facilitiesByTypeCache == nil {
            var cache: [FacilityType: [Facility]] = [:]
            for facility in facilities.values {
                cache[facility.facilityType, default: []].append(facility)
            }
            facilitiesByTypeCache = cache
        }
        return facilitiesByTypeCache?[type] ?? []
    }

    func getFacilitiesList() -> [Facility] {
        if let cached = facilitiesListCache { return cached }
        let list = Array(facilities.values)
        facilitiesListCache = list
        return list
    }

    // MARK: - Economy

    func addMoney(_ amount: Int) {
        money += amount
        if amount > 0 { totalEarnings += amount }
    }

    func spendMoney(_ amount: Int) -> Bool {
        guard money >= amount else { return false }
        money -= amount
        return true
    }

    // MARK: - Events

    func logEvent(_ message: String, eventType: String = "info") {
        let event = EventLog(
            gameDay: gameTime.day,
            message: message,
            eventType: eventType
        )
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    // MARK: - Computed Properties

    var pigCount: Int { guineaPigs.count }
    var capacity: Int { farm.capacity }
    var isAtCapacity: Bool { pigCount >= capacity }

    // MARK: - Breeding Pair

    func setBreedingPair(maleID: UUID, femaleID: UUID) {
        breedingPair = BreedingPair(maleID: maleID, femaleID: femaleID)
    }

    func clearBreedingPair() {
        breedingPair = nil
    }

    // MARK: - Social Affinity

    static func affinityKey(_ id1: UUID, _ id2: UUID) -> String {
        let a = id1.uuidString
        let b = id2.uuidString
        return a < b ? "\(a):\(b)" : "\(b):\(a)"
    }

    func getAffinity(_ id1: UUID, _ id2: UUID) -> Int {
        socialAffinity[Self.affinityKey(id1, id2)] ?? 0
    }

    func incrementAffinity(_ id1: UUID, _ id2: UUID) {
        let key = Self.affinityKey(id1, id2)
        socialAffinity[key] = min((socialAffinity[key] ?? 0) + 1, 10)
    }

    // MARK: - Upgrades

    func hasUpgrade(_ upgradeID: String) -> Bool {
        purchasedUpgrades.contains(upgradeID)
    }
}
```

### Supporting Types

`GameTime`, `EventLog`, and `BreedingPair` are already specified in Doc 02. Their signatures are repeated here for completeness since `GameState` depends on them:

```swift
struct GameTime: Codable, Sendable {
    var day: Int = 1
    var hour: Int = 8        // Start at 8 AM
    var minute: Int = 0
    var lastUpdate: Date = Date()
    var totalGameMinutes: Double = 0.0

    var isDaytime: Bool { 6 <= hour && hour < 20 }

    var timeOfDay: String {
        switch hour {
        case 6..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<20: return "Evening"
        default: return "Night"
        }
    }

    var displayTime: String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    mutating func advance(_ minutes: Double) {
        totalGameMinutes += minutes
        minute += Int(minutes)
        while minute >= 60 { minute -= 60; hour += 1 }
        while hour >= 24 { hour -= 24; day += 1 }
    }
}

struct EventLog: Codable, Sendable {
    var timestamp: Date = Date()
    var gameDay: Int = 1
    var message: String
    var eventType: String = "info"
}

struct BreedingPair: Codable, Sendable {
    let maleID: UUID
    let femaleID: UUID
}
```

---

## 3. GameEngine (Tick Loop)

**Maps from:** `game/engine.py` (122 lines)
**Swift file:** `Engine/GameEngine.swift`

### Architecture Decision

Per ROADMAP, the Python `asyncio` tick loop becomes a `Timer.scheduledTimer` on the main run loop. The timer fires at 10 TPS (100ms interval). Each tick computes a speed-scaled delta, advances game time, and invokes registered tick callbacks.

### Type Signature

```swift
import Foundation

@MainActor
final class GameEngine {
    let state: GameState
    private var timer: Timer?
    private var tickCallbacks: [(Double) -> Void] = []
    private var lastTickTime: CFTimeInterval = 0

    init(state: GameState) {
        self.state = state
    }

    // MARK: - Tick Callback Registration

    func registerTickCallback(_ callback: @escaping (Double) -> Void) {
        tickCallbacks.append(callback)
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        lastTickTime = CACurrentMediaTime()
        let interval = 1.0 / Double(SimulationConfig.ticksPerSecond) // 0.1s
        // Use .common run loop mode so the timer fires during scroll/tracking
        // (UIScrollView switches to .tracking mode, which suspends .default timers)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() { state.isPaused = true }
    func resume() { state.isPaused = false }

    func togglePause() -> Bool {
        state.isPaused.toggle()
        return state.isPaused
    }

    func setSpeed(_ speed: GameSpeed) {
        state.speed = speed
    }

    /// Cycle through speed settings. Returns the new speed.
    /// If currently paused, cycling does nothing — use `resume()` first.
    func cycleSpeed(debug: Bool = false) -> GameSpeed {
        guard state.speed != .paused else { return .paused }
        var speeds: [GameSpeed] = [.normal, .fast, .faster, .fastest]
        if debug { speeds.append(contentsOf: [.debug, .debugFast]) }
        let currentIndex = speeds.firstIndex(of: state.speed) ?? 0
        let newIndex = (currentIndex + 1) % speeds.count
        state.speed = speeds[newIndex]
        return state.speed
    }

    // MARK: - Private

    private func timerFired() {
        let now = CACurrentMediaTime()
        var deltaTime = now - lastTickTime
        lastTickTime = now

        // Clamp delta to prevent huge jumps after app sleep/wake
        deltaTime = min(deltaTime, 0.5)

        guard !state.isPaused, state.speed != .paused else { return }

        // Scale delta by game speed
        let gameDelta = deltaTime * Double(state.speed.rawValue)
        tick(gameDelta)

        // Update last-update timestamp
        state.gameTime.lastUpdate = Date()
    }

    private func tick(_ deltaSeconds: Double) {
        // Convert real seconds to game minutes
        // At normal speed (rawValue=3): 1 real second = 30 game minutes
        // (speed.rawValue / realSecondsPerGameMinute). Adjust realSecondsPerGameMinute
        // in GameConfig.Time to change pacing.
        let gameMinutes = deltaSeconds / TimeConfig.realSecondsPerGameMinute

        // Advance game time
        state.gameTime.advance(gameMinutes)

        // Call all registered tick callbacks
        // Pass game-minutes to simulation callbacks (needs, economy, auto-resources).
        // Phase 3 movement code that needs real seconds should read deltaSeconds
        // from a separate property or parameter — see §11 SimulationRunner.
        for callback in tickCallbacks {
            callback(gameMinutes)
        }
    }
}
```

### Speed Levels

The `GameSpeed` enum is already defined in Doc 02. The raw values are the internal multipliers; display labels are separate:

| Case | Raw Value | Display Label | Notes |
|------|-----------|--------------|-------|
| `paused` | 0 | "0x" | Simulation frozen |
| `normal` | 3 | "1x" | Default |
| `fast` | 6 | "2x" | |
| `faster` | 15 | "5x" | |
| `fastest` | 60 | "20x" | |
| `debug` | 300 | "100x" | Debug builds only |
| `debugFast` | 900 | "300x" | Debug builds only |

The display labels are decoupled from raw values. Add a computed property on `GameSpeed`:

```swift
extension GameSpeed {
    var displayLabel: String {
        switch self {
        case .paused: return "0x"
        case .normal: return "1x"
        case .fast: return "2x"
        case .faster: return "5x"
        case .fastest: return "20x"
        case .debug: return "100x"
        case .debugFast: return "300x"
        }
    }
}
```

---

## 4. FarmGrid

**Maps from:** `game/world.py` (497 lines)
**Swift file:** `Engine/FarmGrid.swift`

### Cell Types

`CellType` and `Cell` are specified in Doc 02. Repeated here with full field list:

```swift
enum CellType: String, Codable, Sendable {
    case floor, bedding, grass, wall
}

struct Cell: Codable, Sendable {
    var cellType: CellType = .floor
    var facilityID: UUID? = nil
    var isWalkable: Bool = true
    var areaID: UUID? = nil
    var isTunnel: Bool = false
    var isCorner: Bool = false
    var isHorizontalWall: Bool = false
}
```

### FarmGrid Type Signature

```swift
struct FarmGrid: Codable, Sendable {
    var width: Int
    var height: Int
    var tier: Int = 1
    var cells: [[Cell]] = []

    // Multi-area support
    var areas: [FarmArea] = []
    var tunnels: [TunnelConnection] = []

    // Grid generation counter -- incremented when walkable grid changes.
    // Used by path cache to invalidate stale entries.
    var gridGeneration: Int = 0

    // MARK: - Transient Caches (not serialized)

    /// Cached walkable positions (invalidated on grid changes).
    private var walkableCache: [GridPosition]?

    /// Per-area walkable position cache.
    private var areaWalkableCache: [UUID: [GridPosition]] = [:]

    /// O(1) area lookup by UUID.
    private var areaLookup: [UUID: FarmArea] = [:]

    /// Biome -> areas cache.
    private var biomeAreaCache: [String: [FarmArea]] = [:]

    // MARK: - CodingKeys (exclude transient caches)

    enum CodingKeys: String, CodingKey {
        case width, height, tier, cells, areas, tunnels, gridGeneration
    }
}
```

Note: Transient caches are excluded from `CodingKeys` and rebuilt in `init(from:)` via a `rebuildCaches()` method.

### Factory Method

```swift
extension FarmGrid {
    /// Create a starter farm grid with a MEADOW area.
    static func createStarter() -> FarmGrid {
        let tierInfo = TierUpgradeConfig.forTier(1)
        var grid = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight)
        grid.createLegacyStarterArea()
        return grid
    }

    /// Create a MEADOW starter area covering the entire grid.
    mutating func createLegacyStarterArea() {
        let area = FarmArea(
            name: "Meadow Room",
            biome: .meadow,
            x1: 0, y1: 0,
            x2: width - 1, y2: height - 1,
            isStarter: true
        )
        addArea(area)
    }
}
```

### Cell Query Methods

```swift
extension FarmGrid {
    func isValidPosition(_ x: Int, _ y: Int) -> Bool {
        0 <= x && x < width && 0 <= y && y < height
    }

    func isWalkable(_ x: Int, _ y: Int) -> Bool {
        guard isValidPosition(x, y) else { return false }
        return cells[y][x].isWalkable
    }

    func getCell(_ x: Int, _ y: Int) -> Cell? {
        guard isValidPosition(x, y) else { return nil }
        return cells[y][x]
    }
}
```

### Facility Placement

```swift
extension FarmGrid {
    /// Place a facility on the grid. Returns true if successful.
    mutating func placeFacility(_ facility: Facility) -> Bool {
        // Check all cells are available
        for pos in facility.cells {
            guard isValidPosition(pos.x, pos.y) else { return false }
            let cell = cells[pos.y][pos.x]
            guard cell.facilityID == nil, cell.isWalkable else { return false }
        }
        // Place the facility
        for pos in facility.cells {
            cells[pos.y][pos.x].facilityID = facility.id
            cells[pos.y][pos.x].isWalkable = false
        }
        invalidateWalkableCache()
        return true
    }

    /// Remove a facility from the grid.
    mutating func removeFacility(_ facility: Facility) {
        for pos in facility.cells {
            guard isValidPosition(pos.x, pos.y) else { continue }
            cells[pos.y][pos.x].facilityID = nil
            cells[pos.y][pos.x].isWalkable = true
        }
        invalidateWalkableCache()
    }
}
```

### Area Lookup Queries

```swift
extension FarmGrid {
    func getAreaAt(_ x: Int, _ y: Int) -> FarmArea? {
        guard isValidPosition(x, y) else { return nil }
        guard let areaID = cells[y][x].areaID else { return nil }
        return areaLookup[areaID]
    }

    func getAreaByID(_ areaID: UUID) -> FarmArea? {
        areaLookup[areaID]
    }

    mutating func findAreasByBiome(_ biomeValue: String) -> [FarmArea] {
        // Rebuild cache if empty (lazily populated on first query)
        if biomeAreaCache.isEmpty {
            var cache: [String: [FarmArea]] = [:]
            for area in areas {
                cache[area.biome.rawValue, default: []].append(area)
            }
            biomeAreaCache = cache
        }
        return biomeAreaCache[biomeValue] ?? []
    }

    func getAreaCapacity(_ areaID: UUID) -> Int {
        guard areas.contains(where: { $0.id == areaID }) else { return 0 }
        return TierUpgradeConfig.forTier(tier).capacityPerRoom
    }

    func getBiomeAt(_ x: Int, _ y: Int) -> BiomeType? {
        getAreaAt(x, y)?.biome
    }

    /// Pig capacity = capacityPerRoom * number of rooms.
    var capacity: Int {
        areas.count * TierUpgradeConfig.forTier(tier).capacityPerRoom
    }

    /// Cost info for the next room addition, or nil if at max.
    var nextRoomCost: RoomCost? {
        let nextIndex = areas.count
        guard nextIndex < RoomCostConfig.all.count else { return nil }
        return RoomCostConfig.all[nextIndex]
    }
}
```

### Cache Invalidation

```swift
extension FarmGrid {
    mutating func invalidateWalkableCache() {
        walkableCache = nil
        areaWalkableCache = [:]
        biomeAreaCache = [:]
        gridGeneration += 1
    }

    /// Rebuild transient caches after deserialization.
    mutating func rebuildCaches() {
        areaLookup = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        invalidateWalkableCache()
    }
}
```

### Wall Flag Computation

```swift
extension FarmGrid {
    /// Pre-compute isCorner and isHorizontalWall for all wall cells.
    /// Tunnel cells with manually-set flags are preserved.
    mutating func computeWallFlags() {
        // Reset flags on non-tunnel cells
        for y in 0..<height {
            for x in 0..<width {
                if !cells[y][x].isTunnel {
                    cells[y][x].isCorner = false
                    cells[y][x].isHorizontalWall = false
                }
            }
        }
        for area in areas {
            for x in area.x1...area.x2 {
                for y in area.y1...area.y2 {
                    guard isValidPosition(x, y) else { continue }
                    guard cells[y][x].cellType == .wall else { continue }
                    if (x == area.x1 || x == area.x2) && (y == area.y1 || y == area.y2) {
                        cells[y][x].isCorner = true
                    } else if (y == area.y1 || y == area.y2) && area.x1 <= x && x <= area.x2 {
                        cells[y][x].isHorizontalWall = true
                    }
                }
            }
        }
    }
}
```

---

## 5. Pathfinding (GKGridGraph)

**Maps from:** `game/world_pathfinding.py` (142 lines)
**Swift file:** `Engine/Pathfinding.swift`

### Architecture Decision

Per ROADMAP Decision 2, we use `GKGridGraph` from GameplayKit instead of porting the custom A*. `GKGridGraph` handles node creation, neighbor connectivity, and `findPath(from:to:)` internally with optimized C++ code. The graph is rebuilt when the walkable grid changes (tracked by `gridGeneration`).

### Design

The `Pathfinding` type wraps a `GKGridGraph<GKGridGraphNode>` and provides the same API surface as the Python `world_pathfinding.py` functions. It holds a reference to the `FarmGrid` it was built from and tracks the `gridGeneration` at build time so callers know when to rebuild.

```swift
import GameplayKit

struct Pathfinding: Sendable {
    private let graph: GKGridGraph<GKGridGraphNode>
    private let builtGeneration: Int
    private let gridWidth: Int
    private let gridHeight: Int

    /// Build a pathfinding graph from the current FarmGrid state.
    /// Removes nodes for non-walkable cells.
    init(farm: FarmGrid) {
        builtGeneration = farm.gridGeneration
        gridWidth = farm.width
        gridHeight = farm.height

        // Create a full grid graph (4-directional, no diagonals)
        let graph = GKGridGraph<GKGridGraphNode>(
            fromGridStartingAt: vector_int2(0, 0),
            width: Int32(farm.width),
            height: Int32(farm.height),
            diagonalsAllowed: false
        )

        // Remove non-walkable nodes
        var nodesToRemove: [GKGridGraphNode] = []
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                if !farm.cells[y][x].isWalkable {
                    if let node = graph.node(atGridPosition: vector_int2(Int32(x), Int32(y))) {
                        nodesToRemove.append(node)
                    }
                }
            }
        }
        graph.remove(nodesToRemove)

        self.graph = graph
    }

    /// Check if this graph is still valid for the given farm.
    func isValid(for farm: FarmGrid) -> Bool {
        builtGeneration == farm.gridGeneration
    }

    /// Find a path from start to goal. Returns an array of GridPositions
    /// (empty if no path exists). The start position is included.
    func findPath(
        from start: GridPosition,
        to goal: GridPosition
    ) -> [GridPosition] {
        guard let startNode = graph.node(
            atGridPosition: vector_int2(Int32(start.x), Int32(start.y))
        ) else { return [] }

        var targetNode = graph.node(
            atGridPosition: vector_int2(Int32(goal.x), Int32(goal.y))
        )

        // If goal is non-walkable, find nearest walkable
        if targetNode == nil {
            guard let nearest = findNearestWalkableNode(to: goal) else { return [] }
            targetNode = nearest
        }

        guard let target = targetNode else { return [] }

        if startNode === target { return [start] }

        let pathNodes = graph.findPath(from: startNode, to: target)
        return pathNodes.compactMap { node in
            guard let gridNode = node as? GKGridGraphNode else { return nil }
            return GridPosition(
                x: Int(gridNode.gridPosition.x),
                y: Int(gridNode.gridPosition.y)
            )
        }
    }

    /// Find the nearest walkable graph node to a position (BFS up to maxDistance).
    func findNearestWalkable(
        to pos: GridPosition,
        maxDistance: Int = 5
    ) -> GridPosition? {
        guard let node = findNearestWalkableNode(to: pos, maxDistance: maxDistance) else {
            return nil
        }
        return GridPosition(x: Int(node.gridPosition.x), y: Int(node.gridPosition.y))
    }

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
```

### Random Walkable Position Lookup

These use the `FarmGrid` walkable cache directly (no graph needed):

```swift
extension FarmGrid {
    /// Find a random walkable position on the grid (cached).
    mutating func findRandomWalkable() -> GridPosition? {
        if walkableCache == nil {
            var positions: [GridPosition] = []
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    if isWalkable(x, y) {
                        positions.append(GridPosition(x: x, y: y))
                    }
                }
            }
            walkableCache = positions
        }
        return walkableCache?.randomElement()
    }

    /// Find a random walkable position within a specific area (cached).
    mutating func findRandomWalkableInArea(_ areaID: UUID) -> GridPosition? {
        if let cached = areaWalkableCache[areaID] {
            return cached.randomElement()
        }
        guard let area = areaLookup[areaID] else { return nil }
        var positions: [GridPosition] = []
        for y in area.y1...area.y2 {
            for x in area.x1...area.x2 {
                if isWalkable(x, y) && cells[y][x].areaID == areaID {
                    positions.append(GridPosition(x: x, y: y))
                }
            }
        }
        areaWalkableCache[areaID] = positions
        return positions.randomElement()
    }
}
```

### Graph Lifecycle

The `Pathfinding` graph must be rebuilt whenever `FarmGrid.gridGeneration` changes (facility placed/removed, area added, tunnels carved). The `FacilityManager` (Section 12) owns the `Pathfinding` instance and checks `isValid(for:)` before each use.

---

## 6. Tunnels

**Maps from:** `game/world_tunnels.py` (181 lines)
**Swift file:** `Engine/Tunnels.swift`

### Decision Needed: Vertical Tunnel Width

The Python codebase doubles the vertical tunnel half-width (`TUNNEL_HALF_WIDTH * 2 + 1 = 5` cells total width) to compensate for terminal characters being approximately 2x taller than wide. SpriteKit renders square pixels, so this compensation is unnecessary.

**Recommendation:** Use the same half-width (2) for both horizontal and vertical tunnels on iOS. This produces uniform 5-cell-wide corridors in both orientations. The constant is defined once:

```swift
/// Tunnel corridor half-width. Full width = 2 * halfWidth + 1 = 5 cells.
private let tunnelHalfWidth = 2
```

### Tunnel Carving API

```swift
enum Tunnels {
    /// Carve two 5-wide tunnel corridors between two areas.
    /// Tunnels are placed at 1/3 and 2/3 of the shared wall overlap.
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
```

### Horizontal Tunnel Carving

```swift
private static func carveHorizontalTunnels(
    _ farm: inout FarmGrid,
    areaA: FarmArea,
    areaB: FarmArea
) -> [TunnelConnection] {
    let (left, right) = areaA.centerX <= areaB.centerX
        ? (areaA, areaB) : (areaB, areaA)

    let tunnelX1 = left.x2
    let tunnelX2 = right.x1

    let overlapY1 = max(left.interiorY1, right.interiorY1)
    let overlapY2 = min(left.interiorY2, right.interiorY2)

    let span = max(3, overlapY2 - overlapY1)
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
```

Each `carveOneHorizontalTunnel` iterates `x` from `x1` to `x2`, carving a walkable corridor from `centerY - halfWidth` to `centerY + halfWidth`, and placing barrier walls at `centerY - halfWidth - 1` and `centerY + halfWidth + 1`. Each cell gets `isTunnel = true`.

Vertical tunnels follow the same pattern but iterate `y` and carve along `x`. On iOS, vertical tunnels use the same `tunnelHalfWidth` (not doubled) since SpriteKit has square pixels.

---

## 7. Area Management

**Maps from:** `game/world_areas.py` (142 lines)
**Swift file:** `Engine/AreaManager.swift`

### API

```swift
enum AreaManager {
    /// Register an area and carve its walls and interior cells.
    static func addArea(_ farm: inout FarmGrid, area: FarmArea) {
        farm.areas.append(area)
        farm.areaLookup[area.id] = area

        for x in area.x1...area.x2 {
            for y in area.y1...area.y2 {
                guard farm.isValidPosition(x, y) else { continue }
                let isBorder = x == area.x1 || x == area.x2
                    || y == area.y1 || y == area.y2
                if isBorder {
                    farm.cells[y][x].cellType = .wall
                    farm.cells[y][x].isWalkable = false
                } else {
                    farm.cells[y][x].cellType = .floor
                    farm.cells[y][x].isWalkable = true
                }
                farm.cells[y][x].areaID = area.id
            }
        }
        farm.computeWallFlags()
        farm.invalidateWalkableCache()
    }

    /// Re-stamp area_id on border cells and mark void cells non-walkable.
    /// Needed after room repositioning to fix orphaned cells.
    static func repairAreaCells(_ farm: inout FarmGrid) { ... }

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
        // Clear existing tunnel cells
        for tunnel in farm.tunnels {
            for pos in tunnel.cells {
                guard farm.isValidPosition(pos.x, pos.y) else { continue }
                farm.cells[pos.y][pos.x].isTunnel = false
                farm.cells[pos.y][pos.x].isHorizontalWall = false
                if farm.cells[pos.y][pos.x].areaID != nil {
                    farm.cells[pos.y][pos.x].cellType = .wall
                    farm.cells[pos.y][pos.x].isWalkable = false
                } else {
                    farm.cells[pos.y][pos.x].cellType = .floor
                    farm.cells[pos.y][pos.x].isWalkable = false
                }
            }
        }
        farm.tunnels.removeAll()
        // Re-carve each adjacent pair
        for (areaA, areaB) in getAdjacentPairs(farm) {
            let newTunnels = Tunnels.connectAreas(&farm, areaA: areaA, areaB: areaB)
            farm.tunnels.append(contentsOf: newTunnels)
        }
    }
}
```

### repairAreaCells Implementation

This function performs two passes:

1. **Clear orphaned cells**: Any cell whose `areaID` points to an area that no longer contains that position gets its `areaID` set to `nil` and `isWalkable` set to `false`.
2. **Stamp area cells**: For each area, iterate its bounds and set border cells to `.wall` (non-walkable) and interior cells to `.floor` (walkable, unless occupied by a facility).

After both passes, call `computeWallFlags()` and `invalidateWalkableCache()`.

---

## 8. Grid Expansion and Room Addition

**Maps from:** `game/world_expansion.py` (256 lines)
**Swift file:** `Engine/GridExpansion.swift`

### Grid Expansion

```swift
enum GridExpansion {
    /// Expand the grid canvas and shift existing content by offset.
    /// New cells are non-walkable void.
    static func expandGrid(
        _ farm: inout FarmGrid,
        newWidth: Int,
        newHeight: Int,
        offsetX: Int = 0,
        offsetY: Int = 0
    ) {
        var newCells = (0..<newHeight).map { _ in
            (0..<newWidth).map { _ in Cell(isWalkable: false) }
        }
        // Copy existing cells at offset
        for y in 0..<farm.height {
            for x in 0..<farm.width {
                let nx = x + offsetX
                let ny = y + offsetY
                if 0 <= nx && nx < newWidth && 0 <= ny && ny < newHeight {
                    newCells[ny][nx] = farm.cells[y][x]
                }
            }
        }
        farm.width = newWidth
        farm.height = newHeight
        farm.cells = newCells

        // Shift area coordinates
        if offsetX != 0 || offsetY != 0 {
            for i in farm.areas.indices {
                farm.areas[i].x1 += offsetX
                farm.areas[i].y1 += offsetY
                farm.areas[i].x2 += offsetX
                farm.areas[i].y2 += offsetY
            }
            for i in farm.tunnels.indices {
                farm.tunnels[i].cells = farm.tunnels[i].cells.map {
                    GridPosition(x: $0.x + offsetX, y: $0.y + offsetY)
                }
            }
        }
        farm.invalidateWalkableCache()
    }
}
```

### 2-Column Grid Layout

Rooms are arranged in a 2-column grid layout. Each room gets a `(gridCol, gridRow)` slot assigned in reading order (left-to-right, top-to-bottom). The `computeGridLayout` function calculates world-coordinate origins for each area:

```swift
extension GridExpansion {
    /// Compute world-coordinate origins for each area using 2-column grid.
    /// Returns [areaIndex: GridPosition] for each area.
    static func computeGridLayout(_ farm: FarmGrid) -> [Int: GridPosition] {
        let gap = 7 // Gap between room walls for tunnel corridor

        // Collect room dimensions per slot
        var slots: [(col: Int, row: Int, width: Int, height: Int)] = []
        for area in farm.areas {
            let w = area.x2 - area.x1 + 1
            let h = area.y2 - area.y1 + 1
            slots.append((area.gridCol, area.gridRow, w, h))
        }
        guard !slots.isEmpty else { return [:] }

        let maxCol = slots.map(\.col).max() ?? 0
        let maxRow = slots.map(\.row).max() ?? 0

        // Max width per column, max height per row
        var colWidths = [Int](repeating: 0, count: maxCol + 1)
        var rowHeights = [Int](repeating: 0, count: maxRow + 1)
        for s in slots {
            colWidths[s.col] = max(colWidths[s.col], s.width)
            rowHeights[s.row] = max(rowHeights[s.row], s.height)
        }

        // Cumulative offsets
        var colOffsets = [Int](repeating: 0, count: maxCol + 1)
        for c in 1...maxCol { colOffsets[c] = colOffsets[c-1] + colWidths[c-1] + gap }
        var rowOffsets = [Int](repeating: 0, count: maxRow + 1)
        for r in 1...maxRow { rowOffsets[r] = rowOffsets[r-1] + rowHeights[r-1] + gap }

        // Compute origin per area (centered within its slot)
        var origins: [Int: GridPosition] = [:]
        for (i, s) in slots.enumerated() {
            let cx = colOffsets[s.col] + (colWidths[s.col] - s.width) / 2
            let cy = rowOffsets[s.row] + (rowHeights[s.row] - s.height) / 2
            origins[i] = GridPosition(x: cx, y: cy)
        }
        return origins
    }
}
```

### Room Addition

```swift
extension GridExpansion {
    /// Add a new room with the given biome using 2-column grid layout.
    /// Returns (newArea, tunnels, entityOffsetX, entityOffsetY, roomDeltas)
    /// or nil if at max rooms.
    /// roomDeltas maps areaID -> (dx, dy) for each existing area that repositioned.
    static func addRoom(
        _ farm: inout FarmGrid,
        biome: BiomeType,
        roomName: String? = nil
    ) -> (
        area: FarmArea,
        tunnels: [TunnelConnection],
        offsetX: Int,
        offsetY: Int,
        roomDeltas: [UUID: GridPosition]
    )? {
        // Implementation follows the same algorithm as Python:
        // 1. Ensure starter area exists
        // 2. Check room count against RoomCostConfig.all
        // 3. Assign next 2-column grid slot (col = index % 2, row = index / 2)
        // 4. Create FarmArea with placeholder coords
        // 5. Temporarily add to compute full grid layout
        // 6. Calculate required grid size
        // 7. Remove temporary area
        // 8. Compute offset for existing content
        // 9. Expand grid if needed
        // 10. Reposition existing areas to new grid positions
        // 11. Place new area at computed position
        // 12. Rebuild all tunnel connections
        // 13. Return results with entity relocation data
        ...
    }
}
```

The `roomDeltas` return value tells the caller how to relocate pigs and facilities when existing rooms shift position during grid expansion. This is critical for `Shop.purchaseNewRoom()` (Section 14).

---

## 9. Needs System

**Maps from:** `simulation/needs.py` (227 lines)
**Swift file:** `Simulation/NeedsSystem.swift`

### API

```swift
enum NeedsSystem {
    /// Count nearby pigs for every pig using the spatial grid. O(n * k).
    static func precomputeNearbyCounts(
        pigs: [GuineaPig],
        radius: Double,
        spatialGrid: SpatialGrid
    ) -> [UUID: Int]

    /// Update all needs for a guinea pig based on elapsed game time.
    static func updateAllNeeds(
        pig: inout GuineaPig,
        gameMinutes: Double,
        state: any NeedsContext,
        nearbyCount: Int
    )

    /// Determine which need is most urgent and should be addressed.
    static func getMostUrgentNeed(_ pig: GuineaPig) -> String

    /// Get facility types that address a specific need (in priority order).
    static func getTargetFacilityForNeed(_ need: String) -> [FacilityType]?

    /// Calculate an overall wellbeing score (0-100).
    static func calculateOverallWellbeing(_ pig: GuineaPig) -> Double
}
```

### Needs Decay and Recovery

All rates are per **game hour**. The `gameMinutes` parameter is divided by 60.0 to get hours.

#### Primary Decay (per game hour)

| Need | Base Rate | Personality Modifier |
|------|-----------|---------------------|
| Hunger | 0.6 | Greedy: x1.5 |
| Thirst | 0.8 | None |
| Energy | 0.6 | Lazy: x0.7 (slower decay) |
| Boredom | +2.0 (increases) | Playful: x1.5 |
| Social (alone) | 2.0 | Social: x1.3, Shy: x0.5 |
| Social (with pigs) | 0.5 | Same modifiers |

#### Happiness Model

Happiness is derived, not directly decayed:
- **Contentment recovery**: +2.0/hr when hunger >= 40, thirst >= 40, energy >= 20
- **Critical drain**: -2.0/hr (hunger < 20), -2.5/hr (thirst < 20), -1.5/hr (energy < 20)
- **Boredom drain**: -1.0/hr when boredom > 70
- **Biome bonus**: +1.5/hr when in preferred biome
- **Climate Control perk**: +0.3/hr in all biomes

#### Social Recovery

```
if nearbyPigs > 0:
    socialBoost = min(nearbyPigs * 3.0, 8.0) * hours
    pig.needs.social += socialBoost
    pig.needs.social -= 0.5 * hours * socialModifier
else:
    pig.needs.social -= 2.0 * hours * socialModifier
```

#### Health

- **Drain**: -0.3/hr when hunger < 20, -0.5/hr when thirst < 20
- **Passive recovery**: +1.0/hr when no primary need is critical (doubled by Pig Spa perk)
- **Sleep recovery**: +1.5/hr while sleeping

#### Behavior Recovery (per game hour)

| State | Effect |
|-------|--------|
| EATING | hunger +80.0, happiness +2.0 |
| DRINKING | thirst +100.0 |
| SLEEPING | energy +25.0 (x1.25 with Premium Bedding), health +1.5 |
| PLAYING | happiness +15.0, boredom -15.0, energy -1.0 |
| SOCIALIZING | happiness +10.0, social +10.0 |

Note: Food/water recovery rates are `BASE_RATE * hours * 2` (the `* 2` is baked into the Python code).

#### Enrichment Program Perk

When active, `boredomModifier *= 0.8` (20% slower boredom growth).

#### Clamping

After all updates, call `pig.needs.clampAll()` to keep all values in 0...100.

### Most Urgent Need Priority

```swift
static func getMostUrgentNeed(_ pig: GuineaPig) -> String {
    let priorities: [(String, Double, Double)] = [
        ("thirst",    pig.needs.thirst,    Double(NeedsConfig.criticalThreshold)),
        ("hunger",    pig.needs.hunger,    Double(NeedsConfig.criticalThreshold)),
        ("energy",    pig.needs.energy,    Double(NeedsConfig.lowThreshold)),
        ("happiness", pig.needs.happiness, Double(NeedsConfig.lowThreshold)),
        ("social",    pig.needs.social,    Double(NeedsConfig.lowThreshold)),
    ]
    // First pass: find critical needs
    for (name, value, threshold) in priorities {
        if value < threshold { return name }
    }
    // Second pass: find moderately low needs
    for (name, value, _) in priorities {
        if value < Double(NeedsConfig.highThreshold) { return name }
    }
    return "none"
}
```

### Need-to-Facility Mapping

```swift
static func getTargetFacilityForNeed(_ need: String) -> [FacilityType]? {
    switch need {
    case "hunger":    return [.hayRack, .feastTable, .foodBowl]
    case "thirst":    return [.waterBottle]
    case "energy":    return [.hideout]
    case "happiness": return [.playArea, .exerciseWheel, .tunnel]
    case "social":    return [.playArea]
    default:          return nil
    }
}
```

---

## 10. Collision and Spatial Grid

**Maps from:** `simulation/collision.py` (250 lines)
**Swift file:** `Simulation/Collision.swift`

### SpatialGrid

A uniform grid that bins pigs into cells for O(k) proximity lookups instead of O(n^2) all-pairs.

```swift
// SAFETY: @unchecked Sendable — only accessed from @MainActor via CollisionHandler.
final class SpatialGrid: @unchecked Sendable {
    private let cellSize: Int
    private var cells: [GridPosition: [GuineaPig]] = [:]

    init(cellSize: Int = 5) {
        self.cellSize = cellSize
    }

    /// Re-bin all pigs into grid cells. Call once per tick.
    func rebuild(_ pigs: [GuineaPig]) {
        cells.removeAll(keepingCapacity: true)
        for pig in pigs {
            let key = GridPosition(
                x: Int(pig.position.x) / cellSize,
                y: Int(pig.position.y) / cellSize
            )
            cells[key, default: []].append(pig)
        }
    }

    /// Return all pigs in the same and 8 adjacent cells.
    func getNearby(x: Double, y: Double) -> [GuineaPig] {
        let cx = Int(x) / cellSize
        let cy = Int(y) / cellSize
        var result: [GuineaPig] = []
        for dx in -1...1 {
            for dy in -1...1 {
                if let bucket = cells[GridPosition(x: cx + dx, y: cy + dy)] {
                    result.append(contentsOf: bucket)
                }
            }
        }
        return result
    }

    /// Return unique (pigA, pigB) pairs that share the same or adjacent cells.
    func uniqueNearbyPairs() -> [(GuineaPig, GuineaPig)] {
        var seen: Set<String> = [] // "smallerID:largerID"
        var pairs: [(GuineaPig, GuineaPig)] = []
        for (key, bucket) in cells {
            var neighborhood: [GuineaPig] = []
            for dx in -1...1 {
                for dy in -1...1 {
                    if let nb = cells[GridPosition(x: key.x + dx, y: key.y + dy)] {
                        neighborhood.append(contentsOf: nb)
                    }
                }
            }
            for a in bucket {
                for b in neighborhood {
                    guard a.id < b.id else { continue }
                    let pairKey = "\(a.id):\(b.id)"
                    if seen.insert(pairKey).inserted {
                        pairs.append((a, b))
                    }
                }
            }
        }
        return pairs
    }
}
```

### CollisionHandler

```swift
// SAFETY: @unchecked Sendable — only accessed from @MainActor via SimulationRunner.
final class CollisionHandler: @unchecked Sendable {
    let gameState: GameState
    let spatialGrid = SpatialGrid()

    /// Index: facility UUID -> set of pig UUIDs targeting that facility.
    private var facilityTargets: [UUID: Set<UUID>] = [:]

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Re-bin all pigs and rebuild facility target index. Call once per tick.
    func rebuildSpatialGrid() {
        let pigs = gameState.getPigsList()
        spatialGrid.rebuild(pigs)
        // Rebuild facility target index in the same O(N) pass
        var targets: [UUID: Set<UUID>] = [:]
        for pig in pigs {
            if let facilityID = pig.targetFacilityID {
                targets[facilityID, default: []].insert(pig.id)
            }
        }
        facilityTargets = targets
    }

    func getPigsTargetingFacility(_ facilityID: UUID) -> Set<UUID> {
        facilityTargets[facilityID] ?? []
    }

    func isCellOccupiedByPig(x: Int, y: Int, excludePig: GuineaPig? = nil) -> Bool {
        for other in spatialGrid.getNearby(x: Double(x), y: Double(y)) {
            if let exclude = excludePig, other.id == exclude.id { continue }
            let otherPos = other.position.gridPos
            if otherPos.x == x && otherPos.y == y { return true }
        }
        return false
    }

    /// Check if moving to a position would collide with another pig.
    func isPositionBlocked(
        targetX: Double,
        targetY: Double,
        excludePig: GuineaPig,
        minDistance: Double = BehaviorConfig.blockingDefault
    ) -> Bool {
        // Emergency override: critical health pigs ignore blocking
        if excludePig.needs.health < Double(NeedsConfig.criticalThreshold) {
            return false
        }
        for other in spatialGrid.getNearby(x: targetX, y: targetY) {
            if other.id == excludePig.id { continue }
            // Skip blocking for courting partner
            if excludePig.courtingPartnerID == other.id
                && excludePig.behaviorState == .courting { continue }

            let effectiveDistance: Double
            if !excludePig.path.isEmpty && !other.path.isEmpty {
                effectiveDistance = BehaviorConfig.blockingBothMoving
            } else if [.eating, .drinking, .sleeping, .playing]
                        .contains(other.behaviorState) {
                effectiveDistance = BehaviorConfig.blockingFacilityUse
            } else {
                effectiveDistance = minDistance
            }

            let dx = targetX - other.position.x
            let dy = targetY - other.position.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < effectiveDistance { return true }
        }
        return false
    }
}
```

### Tiered Separation

The `separateOverlappingPigs()` method uses tiered thresholds based on movement state:

| State | Separation Threshold | Blocking Threshold |
|-------|---------------------|-------------------|
| Both moving | 1.0 | 1.5 |
| Both using facility | 1.0 | 1.5 |
| One moving | 2.0 | 2.5 |
| Both idle | 3.0 (MIN_PIG_DISTANCE) | 2.5 |

The invariant is: separation threshold <= blocking threshold for the same state, so separation never undoes movement that passed the blocking check.

Courting pairs skip separation entirely so they can remain adjacent.

When pigs are exactly overlapping (distance <= 0.01), one pig is pushed in a random direction by `MIN_PIG_DISTANCE / 2`.

Both new positions must be walkable; if either is not, the separation is skipped to prevent ratcheting near walls.

---

## 11. SimulationRunner (Tick Orchestration)

**Maps from:** `simulation/runner.py` (253 lines)
**Swift file:** `Simulation/SimulationRunner.swift`

### Design

`SimulationRunner` is the single callback registered with `GameEngine`. It orchestrates all per-tick game systems in the correct order. It does not own the behavior AI (that is Doc 05's `BehaviorController`); instead, it calls `controller.update(pig, delta)` for each pig.

### Type Signature

```swift
@MainActor
final class SimulationRunner {
    let state: GameState
    let behaviorController: BehaviorController
    private var saveCounter: Int = 0

    // Rolling TPS measurement (last 50 tick timestamps)
    private var tickTimestamps: [CFTimeInterval] = []
    private let maxTimestamps = 50
    var currentTPS: Double = 0.0

    // Throttle expensive breeding checks to every 10 ticks (~1s)
    private var breedingCheckCounter: Int = 0
    private let breedingCheckInterval: Int = 10

    // Farm Bell perk: throttle to once per game-hour
    private var lastFarmBellHour: Int = -1

    // MARK: - Event Callbacks

    /// Called when a pig is sold: (pigName, totalValue, contractBonus, pigID)
    var onPigSold: ((String, Int, Int, UUID) -> Void)?

    /// Called when a pregnancy starts: (maleName, femaleName)
    var onPregnancy: ((String, String) -> Void)?

    /// Called when a birth occurs: (eventMessage)
    var onBirth: ((String) -> Void)?

    init(
        state: GameState,
        behaviorController: BehaviorController
    ) {
        self.state = state
        self.behaviorController = behaviorController
    }
}
```

### Tick Method: 13-Phase Execution Order

```swift
extension SimulationRunner {
    func tick(_ gameMinutes: Double) {
        let tickStart = CACurrentMediaTime()
        recordTimestamp(tickStart)

        let pigs = state.getPigsList()

        // Phase 1: Rebuild spatial grid (used by needs, behaviors, collision)
        behaviorController.collision.rebuildSpatialGrid()

        // Phase 1b: Rebuild per-area population/capacity caches
        behaviorController.facilityManager.updateAreaPopulations()

        // Phase 2: Update all guinea pig needs
        let nearbyCounts = NeedsSystem.precomputeNearbyCounts(
            pigs: pigs,
            radius: NeedsConfig.socialRadius,
            spatialGrid: behaviorController.collision.spatialGrid
        )
        for var pig in pigs {
            NeedsSystem.updateAllNeeds(
                pig: &pig,
                gameMinutes: gameMinutes,
                state: state,
                nearbyCount: nearbyCounts[pig.id] ?? 0
            )
            state.guineaPigs[pig.id] = pig
        }

        // Phase 2a: Farm Bell perk notification
        checkFarmBell(pigs: pigs)

        // Phase 2b: Automatic resource systems
        let gameHours = gameMinutes / 60.0
        AutoResources.tickAutoResources(state: state, gameHours: gameHours)
        AutoResources.tickVeggieGardens(state: state, gameHours: gameHours)
        AutoResources.tickAoeFacilities(state: state, gameHours: gameHours)

        // Phase 3: Update behaviors (Doc 05 — BehaviorController)
        // Movement interpolation needs real seconds, not game-minutes.
        // Derive from gameMinutes using the same conversion factor.
        let realSeconds = gameMinutes * TimeConfig.realSecondsPerGameMinute
        for var pig in pigs {
            behaviorController.update(&pig, deltaSeconds: realSeconds)
            state.guineaPigs[pig.id] = pig
        }

        // Phase 3b: Process completed courtships -> start pregnancies
        // (Doc 05 handles courtship completion tracking)

        // Phase 4: Separate overlapping pigs
        behaviorController.separateOverlappingPigs()

        // Phase 4b: Rescue pigs on non-walkable cells
        behaviorController.rescueNonWalkablePigs(pigs)

        // Phase 5: Biome acclimation (Doc 05)

        // Phase 6: Advance pregnancies (Doc 05)

        // Phase 7: Age pigs and cleanup dead (Doc 05)

        // Phase 8: Cull surplus breeders (Doc 05)

        // Phase 9: Auto-sell marked adults (Doc 05)

        // Phase 10: Check breeding opportunities (throttled)
        breedingCheckCounter += 1
        let runExpensive = breedingCheckCounter >= breedingCheckInterval
        if runExpensive { breedingCheckCounter = 0 }
        // Breeding.checkBreedingOpportunities(state, runExpensive: runExpensive)
        // (Doc 05 specifies the breeding system)

        // Phase 11: Contract refresh/expiry
        checkContractRefresh()

        // Phase 13: Auto-save every 300 ticks (~30 seconds)
        saveCounter += 1
        if saveCounter >= 300 {
            saveCounter = 0
            // SaveManager handles background serialization (Doc 08)
        }
    }
}
```

Note: Phases 5-9 are placeholders that will be implemented when Doc 05 (Behavior AI) is written. The `SimulationRunner` calls into the `BehaviorController` and breeding/birth/culling systems which are specified in that document.

### Farm Bell Check

```swift
private func checkFarmBell(pigs: [GuineaPig]) {
    guard state.hasUpgrade("farm_bell") else { return }
    let currentHour = state.gameTime.day * 24 + state.gameTime.hour
    guard currentHour != lastFarmBellHour else { return }
    let criticalPigs = pigs.filter {
        $0.needs.hunger < Double(NeedsConfig.criticalThreshold)
        || $0.needs.thirst < Double(NeedsConfig.criticalThreshold)
    }
    guard !criticalPigs.isEmpty else { return }
    lastFarmBellHour = currentHour
    let names = criticalPigs.prefix(3).map(\.name).joined(separator: ", ")
    let suffix = criticalPigs.count > 3
        ? " (+\(criticalPigs.count - 3) more)" : ""
    state.logEvent(
        "Farm Bell: \(names)\(suffix) need food/water!",
        eventType: "farm_bell"
    )
}
```

### Contract Refresh

```swift
private func checkContractRefresh() {
    let gameDay = state.gameTime.day
    var board = state.contractBoard
    board.checkExpiry(gameDay: gameDay)
    if board.needsRefresh(gameDay: gameDay)
        || (board.activeContracts.isEmpty && board.lastRefreshDay == 0) {
        let playerBiomes = state.farm.areas.map(\.biome)
        let newContracts = ContractGenerator.generateContracts(
            farmTier: state.farmTier,
            gameDay: gameDay,
            availableBiomes: playerBiomes,
            gameState: state
        )
        board.activeContracts.append(contentsOf: newContracts)
        board.lastRefreshDay = gameDay
    }
    state.contractBoard = board
}
```

### TPS Measurement

```swift
private func recordTimestamp(_ time: CFTimeInterval) {
    tickTimestamps.append(time)
    if tickTimestamps.count > maxTimestamps {
        tickTimestamps.removeFirst()
    }
    if tickTimestamps.count >= 2 {
        let elapsed = tickTimestamps.last! - tickTimestamps.first!
        if elapsed > 0 {
            currentTPS = Double(tickTimestamps.count - 1) / elapsed
        }
    }
}
```

---

## 12. FacilityManager

**Maps from:** `simulation/facility_manager.py` (858 lines)
**Swift file:** `Simulation/FacilityManager.swift`

### Design

`FacilityManager` handles facility selection, path caching, occupancy tracking, arrival handling, and resource consumption. It owns a `Pathfinding` instance and an LRU path cache.

### Type Signature

```swift
@MainActor
final class FacilityManager {
    let gameState: GameState
    let collision: CollisionHandler

    // Cross-tick LRU path cache. Keyed on (start, goal, gridGeneration).
    private var pathCache: OrderedPathCache
    private let pathCacheMaxSize = 2048

    // Failed facility tracking per pig
    private var failedFacilities: [UUID: Set<UUID>] = [:]
    private var failedCooldowns: [UUID: Int] = [:]

    // Path cache performance counters
    var cacheHits: Int = 0
    var cacheMisses: Int = 0

    // Per-area population/capacity caches (rebuilt each tick)
    private var areaPopulations: [UUID: Int] = [:]
    private var areaCapacities: [UUID: Int] = [:]

    // Pathfinding graph (rebuilt when grid changes)
    private var pathfinding: Pathfinding?

    init(gameState: GameState, collision: CollisionHandler) {
        self.gameState = gameState
        self.collision = collision
        self.pathCache = OrderedPathCache()
    }
}
```

### Path Cache

The path cache uses a dictionary with LRU eviction. The cache key includes `gridGeneration` so entries auto-invalidate when the walkable grid changes:

```swift
struct PathCacheKey: Hashable {
    let start: GridPosition
    let goal: GridPosition
    let generation: Int
}

final class OrderedPathCache {
    private var cache: [PathCacheKey: [GridPosition]] = [:]
    private var order: [PathCacheKey] = []
    private let maxSize: Int

    init(maxSize: Int = 2048) {
        self.maxSize = maxSize
    }

    func get(_ key: PathCacheKey) -> [GridPosition]? {
        // O(1) lookup — skip move-to-end to avoid O(n) scan on every read.
        // Eviction becomes approximate-LRU, which is acceptable at this scale.
        // Profile before upgrading to a doubly-linked-list LRU or NSCache.
        return cache[key]
    }

    func set(_ key: PathCacheKey, path: [GridPosition]) {
        cache[key] = path
        order.removeAll { $0 == key }
        order.append(key)
        // Evict oldest if over capacity
        while cache.count > maxSize, let oldest = order.first {
            order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
```

### Straight-Line Shortcut

Before invoking A*, the manager tries a straight-line walk for nearby goals (Manhattan distance <= 6). This avoids the A* heap/dict overhead for the common nearby-facility case:

```swift
func tryStraightLine(
    from start: GridPosition,
    to goal: GridPosition,
    farm: FarmGrid
) -> [GridPosition]? {
    var path = [start]
    var current = start
    let stepX = goal.x > current.x ? 1 : (goal.x < current.x ? -1 : 0)
    let stepY = goal.y > current.y ? 1 : (goal.y < current.y ? -1 : 0)

    while current != goal {
        // Try diagonal, then X, then Y
        if current.x != goal.x && current.y != goal.y {
            let next = GridPosition(x: current.x + stepX, y: current.y + stepY)
            if farm.isWalkable(next.x, next.y) {
                current = next; path.append(current); continue
            }
        }
        if current.x != goal.x {
            let next = GridPosition(x: current.x + stepX, y: current.y)
            if farm.isWalkable(next.x, next.y) {
                current = next; path.append(current); continue
            }
        }
        if current.y != goal.y {
            let next = GridPosition(x: current.x, y: current.y + stepY)
            if farm.isWalkable(next.x, next.y) {
                current = next; path.append(current); continue
            }
        }
        return nil // Blocked
    }
    return path
}
```

### Key Methods

```swift
extension FacilityManager {
    /// Rebuild per-area population and capacity caches. O(pigs + areas).
    func updateAreaPopulations()

    /// Get candidate facilities ranked by heuristic (no A* calls).
    /// Filters by type, removes empty/failed, applies Manhattan pre-filter,
    /// ranks by spread score (distance + crowding + biome + overcrowding).
    func getCandidateFacilitiesRanked(
        pig: GuineaPig,
        facilityType: FacilityType
    ) -> [Facility]

    /// Find an unoccupied interaction point and the path to it.
    /// Returns (point, path) or nil if all points are occupied/unreachable.
    func findOpenInteractionPoint(
        pig: GuineaPig,
        facility: Facility
    ) -> (point: GridPosition, path: [GridPosition])?

    /// Check if pig arrived at a facility and update behavior state.
    func checkArrivedAtFacility(_ pig: inout GuineaPig)

    /// Consume resources from a nearby facility (eating/drinking/sleeping/playing).
    func consumeFromNearbyFacility(_ pig: inout GuineaPig, deltaSeconds: Double)

    /// Try to find an alternative facility when blocked. Returns true if found.
    func tryAlternativeFacility(
        pig: inout GuineaPig,
        blockedTarget: Position
    ) -> Bool

    /// Remove tracking state for a dead/sold pig.
    func cleanupPig(_ pigID: UUID)
}
```

### Facility Scoring (rankFacilitiesBySpread)

The scoring function combines multiple factors:

```
score = distance * 2.0                    // FACILITY_DISTANCE_WEIGHT
      + crowdCount * 25.0                 // CROWDING_PENALTY
      + random(0, 3.0)                    // SCORING_RANDOM_VARIANCE
      + biomeAffinityPenalty              // 30.0 if outside preferred biome
      + overcrowdingPenalty               // 10.0 per pig over room capacity
```

The biome affinity penalty is reduced by 60% if the pig's base color matches the facility biome's signature color.

After ranking, there is a 30% chance to shuffle an uncrowded facility to the front (`UNCROWDED_CHANCE`).

---

## 13. Auto Resources

**Maps from:** `simulation/auto_resources.py` (134 lines)
**Swift file:** `Simulation/AutoResources.swift`

### API

```swift
enum AutoResources {
    /// Run drip system and auto-feeder logic for all food/water facilities.
    static func tickAutoResources(state: GameState, gameHours: Double) {
        let hasDrip = state.hasUpgrade("drip_system")
        let hasAuto = state.hasUpgrade("auto_feeders")
        guard hasDrip || hasAuto else { return }

        let dripRate: Double = 2.0 // Units per game hour

        for var facility in state.getFacilitiesList() {
            guard AutoResources.foodWaterTypes.contains(facility.facilityType)
                else { continue }
            if hasDrip { facility.refill(dripRate * gameHours) }
            if hasAuto && facility.fillPercentage < 25.0 { facility.refill() }
            state.facilities[facility.id] = facility
        }
    }

    /// Veggie gardens produce food and distribute to nearby bowls/hay racks.
    static func tickVeggieGardens(state: GameState, gameHours: Double) {
        let gardens = state.getFacilitiesByType(.veggieGarden)
        guard !gardens.isEmpty else { return }
        let foodFacilities = state.getFacilitiesByType(.foodBowl)
            + state.getFacilitiesByType(.hayRack)
            + state.getFacilitiesByType(.feastTable)
        guard !foodFacilities.isEmpty else { return }

        for garden in gardens {
            let production = garden.info.foodProduction * gameHours
            guard production > 0 else { continue }
            let targets = foodFacilities.filter {
                $0.currentAmount < $0.maxAmount
            }
            guard !targets.isEmpty else { continue }
            let perTarget = production / Double(targets.count)
            for var target in targets {
                target.refill(perTarget)
                state.facilities[target.id] = target
            }
        }
    }

    /// Apply AoE effects from Stage and Campfire facilities.
    static func tickAoeFacilities(state: GameState, gameHours: Double) {
        let pigs = state.getPigsList()
        guard !pigs.isEmpty else { return }

        // Stage AoE: audience within 6 cells of active performer
        let stages = state.getFacilitiesByType(.stage)
        for stage in stages {
            let hasPerformer = pigs.contains {
                $0.behaviorState == .playing && $0.targetFacilityID == stage.id
            }
            guard hasPerformer else { continue }

            let stageX = Double(stage.positionX) + Double(stage.width) / 2.0
            let stageY = Double(stage.positionY) + Double(stage.height) / 2.0
            let radiusSq = 6.0 * 6.0

            for var pig in pigs {
                if pig.targetFacilityID == stage.id
                    && pig.behaviorState == .playing { continue }
                let dx = pig.position.x - stageX
                let dy = pig.position.y - stageY
                if dx * dx + dy * dy <= radiusSq {
                    pig.needs.happiness = min(100, pig.needs.happiness + 2.0 * gameHours)
                    pig.needs.social = min(100, pig.needs.social + 1.5 * gameHours)
                    state.guineaPigs[pig.id] = pig
                }
            }
        }
    }

    // Food/water facility types affected by automation perks
    static let foodWaterTypes: Set<FacilityType> = [
        .foodBowl, .hayRack, .waterBottle, .feastTable
    ]
}
```

---

## 14. Economy -- Shop

**Maps from:** `economy/shop.py` (441 lines)
**Swift file:** `Economy/Shop.swift`

### ShopItem

```swift
struct ShopItem: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    let facilityType: FacilityType?
    var unlocked: Bool
    let requiredTier: Int
}
```

### Shop Items List

All 17 facility shop items with costs from `EconomyConfig`:

| ID | Name | Cost | Tier | FacilityType |
|----|------|------|------|-------------|
| `food_bowl` | Food Bowl | 20 | 1 | `.foodBowl` |
| `water_bottle` | Water Bottle | 20 | 1 | `.waterBottle` |
| `hideout` | Hideout | 60 | 1 | `.hideout` |
| `hay_rack` | Hay Rack | 80 | 2 | `.hayRack` |
| `exercise_wheel` | Exercise Wheel | 150 | 2 | `.exerciseWheel` |
| `tunnel` | Tunnel System | 200 | 2 | `.tunnel` |
| `feast_table` | Feast Table | 350 | 2 | `.feastTable` |
| `play_area` | Play Area | 600 | 3 | `.playArea` |
| `grooming_station` | Grooming Station | 500 | 3 | `.groomingStation` |
| `genetics_lab` | Genetics Lab | 1000 | 3 | `.geneticsLab` |
| `campfire` | Campfire | 1200 | 3 | `.campfire` |
| `therapy_garden` | Therapy Garden | 1500 | 3 | `.therapyGarden` |
| `breeding_den` | Breeding Den | 3000 | 4 | `.breedingDen` |
| `nursery` | Nursery | 5000 | 4 | `.nursery` |
| `veggie_garden` | Veggie Garden | 5000 | 4 | `.veggieGarden` |
| `hot_spring` | Hot Spring | 15000 | 4 | `.hotSpring` |
| `stage` | Stage | 150000 | 5 | `.stage` |

### Key Functions

```swift
enum Shop {
    /// Get shop items filtered by category with tier-based unlock status.
    static func getShopItems(
        category: ShopCategory? = nil,
        farmTier: Int = 1
    ) -> [ShopItem]

    /// Purchase a facility item at the given position.
    /// Returns true if purchase and placement succeed.
    static func purchaseItem(
        state: GameState,
        item: ShopItem,
        position: GridPosition?
    ) -> Bool

    /// Sell a facility and refund its cost.
    static func sellFacility(state: GameState, facility: Facility) -> Int

    /// Get the next tier upgrade info, or nil if at max.
    static func getNextTierUpgrade(state: GameState) -> TierUpgrade?

    /// Check which requirements are met for a tier upgrade.
    static func checkTierRequirements(
        state: GameState,
        upgrade: TierUpgrade
    ) -> [String: Bool]

    /// Purchase the next tier upgrade. Returns true if successful.
    /// Resizes all rooms to the new tier dimensions.
    static func purchaseTierUpgrade(state: GameState) -> Bool

    /// Purchase a new room with the given biome. Returns true if successful.
    /// Handles grid expansion, entity relocation, and cost deduction.
    static func purchaseNewRoom(
        state: GameState,
        biome: BiomeType
    ) -> Bool

    /// Get total cost for adding a room (room cost + biome cost).
    static func getRoomTotalCost(state: GameState, biome: BiomeType) -> Int
}
```

### Tier Upgrade Requirements

| Tier | Name | Cost | Pigs Born | Pigdex | Contracts | Max Rooms |
|------|------|------|-----------|--------|-----------|-----------|
| 1 | Starter | 0 | 0 | 0 | 0 | 1 |
| 2 | Apprentice | 300 | 3 | 2 | 0 | 2 |
| 3 | Expert | 1500 | 10 | 8 | 2 | 3 |
| 4 | Master | 5000 | 25 | 18 | 5 | 6 |
| 5 | Grand Master | 15000 | 50 | 30 | 10 | 8 |

### Room Costs

| Room Index | Name | Cost |
|-----------|------|------|
| 0 | Starter Hutch | 0 (free) |
| 1 | Cozy Enclosure | 500 |
| 2 | Family Pen | 2000 |
| 3 | Guinea Grove | 8000 |
| 4 | Piggy Paradise | 25000 |
| 5 | Ultimate Farm | 100000 |
| 6 | Grand Estate | 300000 |
| 7 | Pig Empire | 800000 |

---

## 15. Economy -- Market

**Maps from:** `economy/market.py` (174 lines)
**Swift file:** `Economy/Market.swift`

### Pig Valuation

```swift
struct SaleResult: Sendable {
    let baseValue: Int
    let contractBonus: Int
    let matchedContract: BreedingContract?
    var total: Int { baseValue + contractBonus }
}

enum Market {
    /// Calculate the sale value of a guinea pig.
    static func calculatePigValue(
        pig: GuineaPig,
        state: GameState
    ) -> Int

    /// Calculate sale value with individual multiplier breakdown.
    static func calculatePigValueBreakdown(
        pig: GuineaPig,
        state: GameState
    ) -> PigValueBreakdown

    /// Sell a guinea pig. Returns SaleResult with value breakdown.
    static func sellPig(state: GameState, pig: GuineaPig) -> SaleResult

    /// Get current market information (total value, rarity counts, etc.).
    static func getMarketInfo(state: GameState) -> MarketInfo
}
```

### Value Calculation Formula

```
total = base * rarityMult * ageMult * healthMult * groomingMult * perkMult
```

| Factor | Values |
|--------|--------|
| Base | 25 Squeaks |
| Rarity | Common: 1.0, Uncommon: 1.5, Rare: 2.5, Very Rare: 4.0, Legendary: 10.0 |
| Age | Baby: 0.5, Adult: 1.0, Senior: 0.8 |
| Health | `max(0.5, health / 100.0)` |
| Grooming | 1.15 if any grooming station exists, else 1.0 |
| Perk: Market Connections | x1.10 (all pigs) |
| Perk: Premium Branding | x1.20 (rare+ pigs) |
| Perk: Influencer Pig | x1.50 (legendary pigs) |
| **Minimum** | 1 Squeak |

Perk multipliers stack multiplicatively.

### Sell Flow

1. Calculate pig value
2. Check contract fulfillment (`contractBoard.checkAndFulfill(pig, farm:)`)
3. If contract matched, calculate bonus (with Trade Network perk: x1.25)
4. Remove pig from game state
5. Increment `totalPigsSold`
6. Add money (value + contract bonus)
7. Log event

---

## 16. Economy -- Contracts

**Maps from:** `economy/contracts.py` (307 lines)
**Swift file:** `Economy/Contracts.swift`

### Contract Difficulty

| Difficulty | Requirements | Reward Range | Min Tier |
|-----------|-------------|-------------|----------|
| Easy | Color only | 500-1000 | 1 |
| Medium | Color + Pattern | 2000-4000 | 2 |
| Hard | Color + Pattern + Intensity | 5000-10000 | 3 |
| Expert | All 4 traits | 12000-20000 | 4 |
| Legendary | All 4 + forced Roan | 20000-40000 | 5 (requires VIP Contracts perk) |

Biome requirements: tier 3+, Hard/Expert/Legendary, 30% chance. Biome contracts get +50% reward bonus.

### Contract Generation

```swift
enum ContractGenerator {
    static func generateContracts(
        farmTier: Int,
        gameDay: Int,
        availableBiomes: [BiomeType],
        gameState: GameState
    ) -> [BreedingContract]
}
```

Number of contracts: `min(maxActive, max(2, farmTier))`. Max active is 4, or 5 with Contract Negotiator perk. Expiry: 20 days from creation. Refresh interval: every 10 days.

### Trait Tier Requirements for Contracts

| Trait | Values Available at Tier |
|-------|------------------------|
| Colors | Black, Chocolate, Golden (T1), Cream (T2), Blue, Lilac, Saffron (T3), Smoke (T4) |
| Patterns | Solid, Dutch, Dalmatian (T1) |
| Intensity | Full (T1), Chinchilla, Himalayan (T2) |
| Roan | None (T1), Roan (T3) |

---

## 17. Economy -- Upgrades and Currency

**Maps from:** `economy/upgrades.py` (264 lines), `economy/currency.py` (38 lines)
**Swift files:** `Economy/Upgrades.swift`, `Economy/Currency.swift`

### 22 Permanent Perks

| Category | ID | Name | Cost | Tier | Effect |
|----------|-----|------|------|------|--------|
| Automation | `bulk_feeders` | Bulk Feeders | 350 | 2 | Food/water capacity x2 |
| Automation | `drip_system` | Drip System | 1800 | 3 | +2 units/game-hour passive regen |
| Automation | `auto_feeders` | Auto-Feeders | 6000 | 4 | Auto-refill when < 25% |
| Breeding | `fertility_herbs` | Fertility Herbs | 400 | 2 | +5% base breeding chance |
| Breeding | `litter_boost` | Litter Boost | 7000 | 4 | Max litter size +1 |
| Breeding | `genetic_accelerator` | Genetic Accelerator | 20000 | 5 | Mutation rate x2 |
| Comfort | `premium_bedding` | Premium Bedding | 250 | 2 | Sleep energy +25% |
| Comfort | `enrichment_program` | Enrichment Program | 1000 | 3 | Boredom rate -20% |
| Comfort | `climate_control` | Climate Control | 2000 | 3 | +0.3 happiness/hr all biomes |
| Comfort | `pig_spa` | Pig Spa Package | 5000 | 4 | Passive health recovery x2 |
| Economy | `market_connections` | Market Connections | 500 | 2 | Sale values +10% |
| Economy | `premium_branding` | Premium Branding | 2500 | 3 | Rare+ pigs +20% sale |
| Economy | `trade_network` | Trade Network | 8000 | 4 | Contract rewards +25% |
| Economy | `influencer_pig` | Influencer Pig | 25000 | 5 | Legendary pigs +50% sale |
| Movement | `paved_paths` | Paved Paths | 300 | 2 | Movement speed +20% |
| Movement | `express_lanes` | Express Lanes | 4000 | 4 | Movement speed +50% |
| QoL | `farm_bell` | Farm Bell | 200 | 2 | Critical hunger/thirst notification |
| QoL | `adoption_discount` | Adoption Discount | 300 | 2 | Adoption prices -15% |
| QoL | `speed_breeding` | Speed Breeding License | 1500 | 3 | Pregnancy duration -25% |
| QoL | `contract_negotiator` | Contract Negotiator | 1200 | 3 | +1 max active contract |
| QoL | `lucky_clover` | Lucky Clover | 5000 | 4 | Pigdex bonus 50-200 Squeaks (10%) |
| QoL | `vip_contracts` | VIP Contract Access | 15000 | 5 | Unlocks Legendary contracts |

### Upgrade Definition Type

```swift
struct UpgradeDefinition: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let requiredTier: Int
    let category: String
}
```

All upgrades are stored in a static dictionary for O(1) lookup:

```swift
enum Upgrades {
    static let all: [String: UpgradeDefinition] = [
        "bulk_feeders": UpgradeDefinition(...),
        // ... all 22 entries
    ]
}
```

### Currency

```swift
enum Currency {
    static func addMoney(state: GameState, amount: Int, reason: String = "") {
        state.addMoney(amount)
        if !reason.isEmpty {
            state.logEvent("Earned \(amount) Squeaks: \(reason)", eventType: "income")
        }
    }

    static func spendMoney(state: GameState, amount: Int, reason: String = "") -> Bool {
        guard state.spendMoney(amount) else { return false }
        if !reason.isEmpty {
            state.logEvent("Spent \(amount) Squeaks: \(reason)", eventType: "purchase")
        }
        return true
    }

    static func canAfford(state: GameState, amount: Int) -> Bool {
        state.money >= amount
    }

    /// Format money for display (number only, no prefix).
    static func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000_000 { return String(format: "%.1fM", Double(amount) / 1_000_000) }
        if amount >= 1_000 { return String(format: "%.1fK", Double(amount) / 1_000) }
        return "\(amount)"
    }

    /// Format money with Sq prefix for compact UI display.
    static func formatCurrency(_ amount: Int) -> String {
        "Sq\(formatMoney(amount))"
    }
}
```

---

## 18. Auto-Arrange

**Maps from:** `game/auto_arrange.py` (787 lines)
**Swift file:** `Engine/AutoArrange.swift`

### Design

Auto-arrange repositions all facilities into logical zones after farm expansion or manual trigger. The algorithm has three layout modes:

1. **Small farm** (width < 70 or height < 35): 3-zone type-grouped layout
2. **Large single-area farm**: Neighborhood layout with utility zone
3. **Multi-area farm**: Per-area arrangement with proportional distribution

### Zone Layout

Small farm / per-area layout:
```
+----------------------------+
| FEEDING+HYDRATION | REST+PLAY |
|                   |           |
| UTILITY (full width)          |
+----------------------------+
```

Top split: left 50% / right 50%, bottom 30% for utility.

### Key Types

```swift
struct Zone: Sendable {
    let name: String
    let x1: Int
    let y1: Int
    let x2: Int
    let y2: Int
    var width: Int { x2 - x1 + 1 }
    var height: Int { y2 - y1 + 1 }
}

struct Placement: Sendable {
    let facility: Facility
    let newX: Int
    let newY: Int
}
```

### API

```swift
enum AutoArrange {
    /// Compute new positions for all facilities without mutating state.
    /// Returns (placements, overflow) where overflow couldn't fit.
    static func computeArrangement(state: GameState) -> ([Placement], [Facility])

    /// Remove all facilities, reposition, and re-place them.
    static func applyArrangement(
        state: GameState,
        placements: [Placement],
        overflow: [Facility]
    )

    /// Reset all pig navigation after facility rearrangement.
    static func clearPigNavigation(state: GameState)
}
```

### Facility Zone Mapping

| FacilityType | Zone |
|-------------|------|
| foodBowl, hayRack, veggieGarden | feeding |
| waterBottle | hydration |
| hideout | rest |
| exerciseWheel, tunnel, playArea | play |
| breedingDen, nursery, groomingStation, geneticsLab | utility |

On small farms, hydration merges into feeding and play merges into rest.

### Shelf Packing Algorithm

Facilities within a zone are packed using a shelf algorithm:
1. Sort facilities by sprite area (largest first)
2. Pack left-to-right into horizontal shelves
3. Distribute shelves vertically to maximize spacing within the zone
4. Check sprite footprint against occupied set to prevent overlap

For multi-area farms, essential facilities (food, water, rest, play) are distributed with a minimum target of 1 per area, then utility facilities are distributed proportionally by area size.

---

## 19. Protocol Interfaces

**Maps from:** `game/facades.py` (84 lines)
**Swift file:** `Engine/Protocols.swift`

The Python codebase uses Protocol classes (structural typing) to define narrow views of `GameState` for each simulation subsystem. In Swift, these become explicit protocols that `GameState` conforms to.

```swift
/// Used by simulation/needs.py -- read-only pig/biome access.
protocol NeedsContext: AnyObject {
    var farm: FarmGrid { get }
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
}

/// Used by simulation/breeding.py -- breeding pair management.
protocol BreedingContext: AnyObject {
    var breedingPair: BreedingPair? { get set }
    var breedingProgram: BreedingProgram { get set }
    var contractBoard: ContractBoard { get set }
    var gameTime: GameTime { get }
    var isAtCapacity: Bool { get }
    func clearBreedingPair()
    func getAffinity(_ id1: UUID, _ id2: UUID) -> Int
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func getGuineaPig(_ pigID: UUID) -> GuineaPig?
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
    func logEvent(_ message: String, eventType: String)
    func setBreedingPair(maleID: UUID, femaleID: UUID)
}

/// Used by simulation/birth.py -- birth processing, aging, pigdex.
protocol BirthContext: AnyObject {
    var breedingProgram: BreedingProgram { get set }
    var capacity: Int { get }
    var farm: FarmGrid { get }
    var gameTime: GameTime { get }
    var isAtCapacity: Bool { get }
    var pigCount: Int { get }
    var pigdex: Pigdex { get set }
    var totalPigsBorn: Int { get set }
    func addGuineaPig(_ pig: GuineaPig)
    func addMoney(_ amount: Int)
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func getGuineaPig(_ pigID: UUID) -> GuineaPig?
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
    func logEvent(_ message: String, eventType: String)
    func removeGuineaPig(_ pigID: UUID) -> GuineaPig?
}

/// Used by simulation/culling.py -- surplus management.
protocol CullingContext: AnyObject {
    var breedingProgram: BreedingProgram { get }
    var contractBoard: ContractBoard { get }
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func getPigsList() -> [GuineaPig]
    func logEvent(_ message: String, eventType: String)
}
```

`GameState` implicitly satisfies all four protocols. Add explicit conformance declarations:

```swift
extension GameState: NeedsContext, BreedingContext, BirthContext, CullingContext {}
```

---

## 20. Testing Strategy

### Unit Tests

| Test File | Tests |
|-----------|-------|
| `GameStateTests.swift` | Add/remove pig/facility, money operations, affinity, event log trimming, capacity calculation |
| `FarmGridTests.swift` | Cell queries, facility placement/removal, walkability, area lookup, wall flag computation |
| `PathfindingTests.swift` | GKGridGraph construction, find_path on simple grids, nearest walkable, obstacle avoidance |
| `NeedsSystemTests.swift` | Decay rates, personality modifiers, behavior recovery, perk effects, clamping |
| `CollisionTests.swift` | SpatialGrid binning, getNearby correctness, tiered separation, blocking checks |
| `EconomyTests.swift` | Pig valuation formula, rarity multipliers, perk stacking, currency formatting |
| `ContractTests.swift` | Contract generation by tier, matching, expiry, refresh |
| `GridExpansionTests.swift` | expandGrid offset, 2-column layout computation, room addition |

### Integration Test

Run a 1000-tick headless simulation with 10 pigs and verify:
- Pig needs decay and recover correctly
- Pigs do not end up on non-walkable cells
- No crashes from edge cases (empty facility list, full capacity, etc.)
- TPS measurement produces reasonable values
- Auto-save counter increments correctly

---

## 21. Decisions Needed

### Decision: Vertical Tunnel Width on iOS

**Context:** Python doubles vertical tunnel width to compensate for terminal character aspect ratio. SpriteKit has square pixels.

**Recommendation:** Use uniform 5-cell-wide tunnels for both orientations. See Section 6.

**Status:** Recommended, not yet confirmed.

### Decision: GKGridGraph Rebuild Strategy

**Context:** The pathfinding graph must be rebuilt when `gridGeneration` changes. Two options:

1. **Lazy rebuild:** Check `isValid(for:)` on each pathfinding call, rebuild if stale. Simple but may cause a frame spike when the graph is rebuilt mid-tick.
2. **Eager rebuild:** Rebuild at the start of each tick in `SimulationRunner`. Predictable timing but rebuilds even when no paths are needed.

**Recommendation:** Lazy rebuild. Grid changes are rare (facility placed/removed, room added). The rebuild cost is O(width * height) which for a 96x56 grid is ~5,000 operations -- negligible in Swift. Profile to confirm.

### Decision: FarmGrid as Struct vs Class

**Context:** `FarmGrid` is currently specified as a `struct` (value type) per Doc 02. However, it contains a 2D array of cells (`[[Cell]]`) that gets mutated frequently, and it is embedded inside `GameState` (a class). Mutating a struct property on a class triggers copy-on-write for the entire 2D array.

**Recommendation:** Keep as `struct` for now. The `cells` array uses COW semantics and only copies when there are multiple references. Since `GameState` is the sole owner, mutations should be in-place. Profile during Phase 1 to verify. If performance is an issue, consider making `FarmGrid` a class or using a flat `[Cell]` array with manual index calculation.

### Decision: Path Cache Implementation

**Context:** Python uses `OrderedDict` for O(1) LRU eviction. Swift has no built-in ordered dictionary.

**Options:**
1. Custom linked list + dictionary (classic LRU)
2. Array-based ordering (simpler, O(n) move-to-end)
3. `NSCache` (automatic eviction but no LRU ordering guarantee)
4. Third-party library

**Recommendation:** Array-based ordering (Option 2) for the initial implementation. The cache has a max size of 2048 entries. The O(n) `removeAll(where:)` for move-to-end is fast enough at this scale. If profiling shows it matters, upgrade to a linked-list LRU.

---

## 22. File Summary

| File | Lines (est.) | Maps From |
|------|-------------|-----------|
| `Engine/GameState.swift` | ~250 | `game/state.py` |
| `Engine/GameEngine.swift` | ~100 | `game/engine.py` |
| `Engine/FarmGrid.swift` | ~300 | `game/world.py` |
| `Engine/Pathfinding.swift` | ~150 | `game/world_pathfinding.py` |
| `Engine/Tunnels.swift` | ~180 | `game/world_tunnels.py` |
| `Engine/AreaManager.swift` | ~140 | `game/world_areas.py` |
| `Engine/GridExpansion.swift` | ~250 | `game/world_expansion.py` |
| `Engine/AutoArrange.swift` | ~300 | `game/auto_arrange.py` |
| `Engine/Protocols.swift` | ~80 | `game/facades.py` |
| `Simulation/SimulationRunner.swift` | ~200 | `simulation/runner.py` |
| `Simulation/NeedsSystem.swift` | ~200 | `simulation/needs.py` |
| `Simulation/Collision.swift` | ~250 | `simulation/collision.py` |
| `Simulation/FacilityManager.swift` | ~300 | `simulation/facility_manager.py` |
| `Simulation/AutoResources.swift` | ~130 | `simulation/auto_resources.py` |
| `Economy/Shop.swift` | ~250 | `economy/shop.py` |
| `Economy/Market.swift` | ~150 | `economy/market.py` |
| `Economy/Contracts.swift` | ~250 | `economy/contracts.py` |
| `Economy/Upgrades.swift` | ~200 | `economy/upgrades.py` |
| `Economy/Currency.swift` | ~40 | `economy/currency.py` |
| **Total** | **~3,720** | |
