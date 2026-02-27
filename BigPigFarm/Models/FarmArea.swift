/// FarmArea -- Discrete areas within the farm connected by tunnels.
/// Maps from: entities/areas.py
import Foundation

// MARK: - FarmArea

/// A discrete area of the farm with its own grid region.
struct FarmArea: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var biome: BiomeType
    var x1: Int       // Top-left corner (inclusive, wall)
    var y1: Int
    var x2: Int       // Bottom-right corner (inclusive, wall)
    var y2: Int
    var isStarter: Bool = false
    var gridCol: Int = 0
    var gridRow: Int = 0

    // Computed interior bounds (inside walls)
    var interiorX1: Int { x1 + 1 }
    var interiorY1: Int { y1 + 1 }
    var interiorX2: Int { x2 - 1 }
    var interiorY2: Int { y2 - 1 }
    var interiorWidth: Int { interiorX2 - interiorX1 + 1 }
    var interiorHeight: Int { interiorY2 - interiorY1 + 1 }
    var centerX: Int { (x1 + x2) / 2 }
    var centerY: Int { (y1 + y2) / 2 }

    /// Check if a point is inside the area (including walls).
    func contains(x: Int, y: Int) -> Bool {
        x1 <= x && x <= x2 && y1 <= y && y <= y2
    }

    /// Check if a point is inside the walkable interior.
    func containsInterior(x: Int, y: Int) -> Bool {
        interiorX1 <= x && x <= interiorX2 && interiorY1 <= y && y <= interiorY2
    }

    enum CodingKeys: String, CodingKey {
        case id, name, biome, x1, y1, x2, y2
        case isStarter = "is_starter"
        case gridCol = "grid_col"
        case gridRow = "grid_row"
    }
}

// MARK: - TunnelConnection

/// A connection between two farm areas via a tunnel.
struct TunnelConnection: Identifiable, Codable, Sendable {
    let id: UUID
    var areaAId: UUID
    var areaBId: UUID
    var cells: [GridPosition] = []
    var orientation: String = "horizontal"

    enum CodingKeys: String, CodingKey {
        case id
        case areaAId = "area_a_id"
        case areaBId = "area_b_id"
        case cells, orientation
    }
}
