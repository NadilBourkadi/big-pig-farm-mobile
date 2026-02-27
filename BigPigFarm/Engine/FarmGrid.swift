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

// MARK: - FarmGrid (Doc 04 scope)

/// The 2D grid underlying the farm layout.
struct FarmGrid: Codable, Sendable {
    // TODO: Implement in doc 04
}
