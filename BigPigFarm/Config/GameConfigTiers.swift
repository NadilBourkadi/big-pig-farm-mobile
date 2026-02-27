/// GameConfigTiers — Game speed levels and tier/room data tables.
/// Maps from: data/config.py (GameSpeed enum, TIER_UPGRADES, ROOM_COSTS)
import Foundation

// MARK: - GameSpeed

/// Game speed multiplier levels. Raw value is the tick multiplier.
/// Display labels are decoupled from the internal multiplier values.
enum GameSpeed: Int, Codable, CaseIterable, Sendable {
    case paused = 0
    case normal = 3
    case fast = 6
    case faster = 15
    case fastest = 60
    case debug = 300
    case debugFast = 900

    /// Human-readable label for the speed control UI.
    var displayLabel: String {
        switch self {
        case .paused: "0x"
        case .normal: "1x"
        case .fast: "2x"
        case .faster: "5x"
        case .fastest: "20x"
        case .debug: "100x"
        case .debugFast: "300x"
        }
    }
}
