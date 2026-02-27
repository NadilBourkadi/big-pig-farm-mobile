/// FarmGrid -- 2D grid representation with cell types.
/// Maps from: game/world.py
import Foundation

// MARK: - CellType

/// Type of terrain in a grid cell.
enum CellType: String, Codable, CaseIterable, Sendable {
    case floor
    case bedding
    case grass
    case wall
}

// MARK: - Cell

/// A single cell in the farm grid.
struct Cell: Codable, Sendable {
    var cellType: CellType = .floor
    var facilityId: UUID?
    var isWalkable: Bool = true
    var areaId: UUID?
    var isTunnel: Bool = false
    var isCorner: Bool = false
    var isHorizontalWall: Bool = false

    enum CodingKeys: String, CodingKey {
        case cellType = "cell_type"
        case facilityId = "facility_id"
        case isWalkable = "is_walkable"
        case areaId = "area_id"
        case isTunnel = "is_tunnel"
        case isCorner = "is_corner"
        case isHorizontalWall = "is_horizontal_wall"
    }
}

// MARK: - FarmGrid

/// The 2D grid underlying the farm layout.
/// Row-major indexing: cells[y][x].
struct FarmGrid: Codable, Sendable {
    var width: Int
    var height: Int
    var tier: Int
    var cells: [[Cell]]
    var areas: [FarmArea]
    var tunnels: [TunnelConnection]

    /// Incremented when walkable grid changes. Used by path cache to invalidate.
    var gridGeneration: Int

    // MARK: - Transient Caches (not serialized)
    // Internal access — AreaManager and Tunnels need these.

    var walkableCache: [GridPosition]?
    var areaWalkableCache: [UUID: [GridPosition]]
    var areaLookup: [UUID: FarmArea]
    var biomeAreaCache: [String: [FarmArea]]

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case width, height, tier, cells, areas, tunnels
        case gridGeneration = "grid_generation"
    }

    // MARK: - Init

    init(width: Int, height: Int, tier: Int = 1) {
        self.width = width
        self.height = height
        self.tier = tier
        self.cells = (0..<height).map { _ in
            [Cell](repeating: Cell(), count: width)
        }
        self.areas = []
        self.tunnels = []
        self.gridGeneration = 0
        self.walkableCache = nil
        self.areaWalkableCache = [:]
        self.areaLookup = [:]
        self.biomeAreaCache = [:]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        tier = try container.decode(Int.self, forKey: .tier)
        cells = try container.decode([[Cell]].self, forKey: .cells)
        areas = try container.decode([FarmArea].self, forKey: .areas)
        tunnels = try container.decode([TunnelConnection].self, forKey: .tunnels)
        gridGeneration = try container.decode(Int.self, forKey: .gridGeneration)
        walkableCache = nil
        areaWalkableCache = [:]
        areaLookup = [:]
        biomeAreaCache = [:]
        rebuildCaches()
    }
}

// MARK: - Cell Queries

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

// MARK: - Cache Management

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

// MARK: - Wall Flag Computation

extension FarmGrid {
    /// Pre-compute isCorner and isHorizontalWall for all wall cells.
    /// Tunnel cells with manually-set flags are preserved.
    mutating func computeWallFlags() {
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
                    if (x == area.x1 || x == area.x2)
                        && (y == area.y1 || y == area.y2) {
                        cells[y][x].isCorner = true
                    } else if (y == area.y1 || y == area.y2)
                                && area.x1 <= x && x <= area.x2 {
                        cells[y][x].isHorizontalWall = true
                    }
                }
            }
        }
    }
}

// MARK: - Area Management

extension FarmGrid {
    /// Register an area and carve its walls and interior cells.
    mutating func addArea(_ area: FarmArea) {
        areas.append(area)
        areaLookup[area.id] = area

        for x in area.x1...area.x2 {
            for y in area.y1...area.y2 {
                guard isValidPosition(x, y) else { continue }
                let isBorder = x == area.x1 || x == area.x2
                    || y == area.y1 || y == area.y2
                if isBorder {
                    cells[y][x].cellType = .wall
                    cells[y][x].isWalkable = false
                } else {
                    cells[y][x].cellType = .floor
                    cells[y][x].isWalkable = true
                }
                cells[y][x].areaId = area.id
            }
        }
        computeWallFlags()
        invalidateWalkableCache()
    }
}

// MARK: - Factory

extension FarmGrid {
    /// Create a starter farm grid with a single MEADOW area.
    static func createStarter() -> FarmGrid {
        let tierInfo = getTierUpgrade(tier: 1)
        var grid = FarmGrid(width: tierInfo.roomWidth, height: tierInfo.roomHeight)
        grid.createLegacyStarterArea()
        return grid
    }

    /// Create a MEADOW starter area covering the entire grid.
    mutating func createLegacyStarterArea() {
        let area = FarmArea(
            id: UUID(),
            name: "Meadow Room",
            biome: .meadow,
            x1: 0, y1: 0,
            x2: width - 1, y2: height - 1,
            isStarter: true
        )
        addArea(area)
    }
}

// MARK: - Area Lookup Queries

extension FarmGrid {
    func getAreaAt(_ x: Int, _ y: Int) -> FarmArea? {
        guard isValidPosition(x, y) else { return nil }
        guard let areaId = cells[y][x].areaId else { return nil }
        return areaLookup[areaId]
    }

    func getAreaByID(_ areaId: UUID) -> FarmArea? {
        areaLookup[areaId]
    }

    mutating func findAreasByBiome(_ biomeValue: String) -> [FarmArea] {
        if biomeAreaCache.isEmpty {
            var cache: [String: [FarmArea]] = [:]
            for area in areas {
                cache[area.biome.rawValue, default: []].append(area)
            }
            biomeAreaCache = cache
        }
        return biomeAreaCache[biomeValue] ?? []
    }

    func getAreaCapacity(_ areaId: UUID) -> Int {
        guard areas.contains(where: { $0.id == areaId }) else { return 0 }
        return getTierUpgrade(tier: tier).capacityPerRoom
    }

    func getBiomeAt(_ x: Int, _ y: Int) -> BiomeType? {
        getAreaAt(x, y)?.biome
    }

    /// Pig capacity = capacityPerRoom * number of rooms.
    var capacity: Int {
        areas.count * getTierUpgrade(tier: tier).capacityPerRoom
    }

    /// Cost info for the next room addition, or nil if at max.
    var nextRoomCost: RoomCost? {
        let nextIndex = areas.count
        guard nextIndex < roomCosts.count else { return nil }
        return roomCosts[nextIndex]
    }
}

// MARK: - Facility Placement

extension FarmGrid {
    /// Place a facility on the grid. Returns true if successful.
    mutating func placeFacility(_ facility: Facility) -> Bool {
        for pos in facility.cells {
            guard isValidPosition(pos.x, pos.y) else { return false }
            let cell = cells[pos.y][pos.x]
            guard cell.facilityId == nil, cell.isWalkable else { return false }
        }
        for pos in facility.cells {
            cells[pos.y][pos.x].facilityId = facility.id
            cells[pos.y][pos.x].isWalkable = false
        }
        invalidateWalkableCache()
        return true
    }

    /// Remove a facility from the grid.
    mutating func removeFacility(_ facility: Facility) {
        for pos in facility.cells {
            guard isValidPosition(pos.x, pos.y) else { continue }
            cells[pos.y][pos.x].facilityId = nil
            cells[pos.y][pos.x].isWalkable = true
        }
        invalidateWalkableCache()
    }
}

// MARK: - Random Walkable Lookups

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
    mutating func findRandomWalkableInArea(_ areaId: UUID) -> GridPosition? {
        if let cached = areaWalkableCache[areaId] {
            return cached.randomElement()
        }
        guard let area = areaLookup[areaId] else { return nil }
        var positions: [GridPosition] = []
        for y in area.y1...area.y2 {
            for x in area.x1...area.x2 {
                if isWalkable(x, y) && cells[y][x].areaId == areaId {
                    positions.append(GridPosition(x: x, y: y))
                }
            }
        }
        areaWalkableCache[areaId] = positions
        return positions.randomElement()
    }
}
