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

/// All 5 tier upgrade definitions.
let tierUpgrades: [TierUpgrade] = [
    TierUpgrade(name: "Starter", tier: 1, cost: 0,
                requiredPigsBorn: 0, requiredPigdex: 0, requiredContracts: 0,
                maxRooms: 1, roomWidth: 18, roomHeight: 18, capacityPerRoom: 8),
    TierUpgrade(name: "Apprentice", tier: 2, cost: 300,
                requiredPigsBorn: 3, requiredPigdex: 2, requiredContracts: 0,
                maxRooms: 2, roomWidth: 21, roomHeight: 21, capacityPerRoom: 10),
    TierUpgrade(name: "Expert", tier: 3, cost: 1500,
                requiredPigsBorn: 10, requiredPigdex: 8, requiredContracts: 2,
                maxRooms: 3, roomWidth: 24, roomHeight: 24, capacityPerRoom: 14),
    TierUpgrade(name: "Master", tier: 4, cost: 5000,
                requiredPigsBorn: 25, requiredPigdex: 18, requiredContracts: 5,
                maxRooms: 6, roomWidth: 27, roomHeight: 27, capacityPerRoom: 18),
    TierUpgrade(name: "Grand Master", tier: 5, cost: 15000,
                requiredPigsBorn: 50, requiredPigdex: 30, requiredContracts: 10,
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

/// Room costs in order of purchase.
let roomCosts: [RoomCost] = [
    RoomCost(name: "Starter Hutch", cost: 0),
    RoomCost(name: "Cozy Enclosure", cost: 500),
    RoomCost(name: "Family Pen", cost: 2000),
    RoomCost(name: "Guinea Grove", cost: 8000),
    RoomCost(name: "Piggy Paradise", cost: 25000),
    RoomCost(name: "Ultimate Farm", cost: 100000),
    RoomCost(name: "Grand Estate", cost: 300000),
    RoomCost(name: "Pig Empire", cost: 800000),
]
