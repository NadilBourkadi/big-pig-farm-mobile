/// SpriteTypes — Rendering-related enums for sprites and indicators.
/// Maps from: data/sprites.py, data/indicator_sprites.py
import Foundation

// MARK: - Direction

/// Facing direction for pig sprites.
enum Direction: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

// MARK: - ZoomLevel

/// Farm viewport zoom levels for sprite detail selection.
enum ZoomLevel: String, Codable, CaseIterable, Sendable {
    case far
    case normal
    case close
}

// MARK: - IndicatorType

/// Status indicator types displayed above pigs, ordered by display priority.
enum IndicatorType: String, Codable, CaseIterable, Sendable {
    case health
    case hunger
    case thirst
    case energy
    case courting
    case pregnant
}
