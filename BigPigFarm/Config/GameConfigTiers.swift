/// GameConfigTiers -- Game speed levels and tier/room data tables.
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
    ///
    /// Labels represent real-time speed relative to normal (3 tps = 1×),
    /// not the raw tick-rate value. e.g. debugFast has raw value 900 tps
    /// but displays "300x" because 900 / 3 = 300× real time.
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

// MARK: - TierUpgrade

/// Definition for a farm tier upgrade with requirements and room specs.
struct TierUpgrade: Codable, Sendable {
    let name: String
    let tier: Int
    let cost: Int
    let requiredPigsBorn: Int
    let requiredPigdex: Int
    let requiredContracts: Int
    let maxRooms: Int
    let roomWidth: Int
    let roomHeight: Int
    let capacityPerRoom: Int
}

/// All 5 tier upgrade definitions — retuned for prestige pacing (Section 7B).
let tierUpgrades: [TierUpgrade] = [
    TierUpgrade(name: "Starter", tier: 1, cost: 0,
                requiredPigsBorn: 0, requiredPigdex: 0, requiredContracts: 0,
                maxRooms: 1, roomWidth: 18, roomHeight: 18, capacityPerRoom: 8),
    TierUpgrade(name: "Apprentice", tier: 2, cost: 1_000,
                requiredPigsBorn: 8, requiredPigdex: 5, requiredContracts: 0,
                maxRooms: 2, roomWidth: 21, roomHeight: 21, capacityPerRoom: 10),
    TierUpgrade(name: "Expert", tier: 3, cost: 8_000,
                requiredPigsBorn: 30, requiredPigdex: 18, requiredContracts: 5,
                maxRooms: 3, roomWidth: 24, roomHeight: 24, capacityPerRoom: 14),
    TierUpgrade(name: "Master", tier: 4, cost: 30_000,
                requiredPigsBorn: 75, requiredPigdex: 40, requiredContracts: 12,
                maxRooms: 6, roomWidth: 27, roomHeight: 27, capacityPerRoom: 18),
    TierUpgrade(name: "Grand Master", tier: 5, cost: 100_000,
                requiredPigsBorn: 150, requiredPigdex: 70, requiredContracts: 25,
                maxRooms: 8, roomWidth: 30, roomHeight: 30, capacityPerRoom: 24),
]

/// Get the tier upgrade definition for a given tier number.
func getTierUpgrade(tier: Int) -> TierUpgrade {
    tierUpgrades.first { $0.tier == tier } ?? tierUpgrades[0]
}

// MARK: - RoomCost

/// Cost definition for adding a new room to the farm.
struct RoomCost: Codable, Sendable {
    let name: String
    let cost: Int
}

/// Room costs in order of purchase — retuned for prestige pacing (Section 7A).
let roomCosts: [RoomCost] = [
    RoomCost(name: "Starter Hutch", cost: 0),
    RoomCost(name: "Cozy Enclosure", cost: 1_500),
    RoomCost(name: "Family Pen", cost: 8_000),
    RoomCost(name: "Guinea Grove", cost: 40_000),
    RoomCost(name: "Piggy Paradise", cost: 150_000),
    RoomCost(name: "Ultimate Farm", cost: 750_000),
    RoomCost(name: "Grand Estate", cost: 4_000_000),
    RoomCost(name: "Pig Empire", cost: 25_000_000),
]
