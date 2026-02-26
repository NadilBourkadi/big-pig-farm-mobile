/// FarmGrid — 2D grid representation with cell types.
/// Maps from: game/farm_grid.py
// TODO: Implement in doc 04
import Foundation

/// Type of content in a grid cell.
enum CellType: String, Codable, CaseIterable, Sendable {
    case empty
    case wall
    case facility
    case tunnel
}

/// A single cell in the farm grid.
struct Cell: Codable, Sendable {
    var type: CellType
    var position: Position
}

/// The 2D grid underlying the farm layout.
struct FarmGrid: Codable, Sendable {
    // TODO: Implement in doc 04
}
