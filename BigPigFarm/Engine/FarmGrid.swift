/// FarmGrid — 2D grid representation with cell types.
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

// MARK: - Stubs (implemented in later tasks)

/// A single cell in the farm grid.
struct Cell: Codable, Sendable {
    // TODO: Implement in struct translation task
}

/// The 2D grid underlying the farm layout.
struct FarmGrid: Codable, Sendable {
    // TODO: Implement in doc 04
}
