/// Facility -- Farm facilities (food bowls, water bottles, shelters, toys, etc.).
/// Maps from: entities/facilities.py
import Foundation

// MARK: - FacilityType

/// All 17 facility types that can be built on the farm.
/// Raw values match the Python `FacilityType(str, Enum)` values for JSON compatibility.
enum FacilityType: String, Codable, CaseIterable, Sendable {
    case foodBowl = "food_bowl"
    case waterBottle = "water_bottle"
    case hayRack = "hay_rack"
    case hideout
    case exerciseWheel = "exercise_wheel"
    case tunnel
    case playArea = "play_area"
    case breedingDen = "breeding_den"
    case nursery
    case veggieGarden = "veggie_garden"
    case groomingStation = "grooming_station"
    case geneticsLab = "genetics_lab"
    case feastTable = "feast_table"
    case campfire
    case therapyGarden = "therapy_garden"
    case hotSpring = "hot_spring"
    case stage

    /// Human-readable name for display.
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - FacilitySize

/// Physical size of a facility on the grid.
struct FacilitySize: Codable, Sendable {
    let width: Int
    let height: Int
}

// MARK: - FacilityInfo

/// Typed metadata for a facility type (not Codable -- static lookup data).
struct FacilityInfo: Sendable {
    let name: String
    let size: FacilitySize
    let baseCost: Int
    let description: String
    let capacity: Int
    let refillCost: Int
    let healthBonus: Double
    let happinessBonus: Double
    let socialBonus: Double
    let breedingBonus: Double
    let growthBonus: Double
    let saleBonus: Double
    let foodProduction: Int
}

// MARK: - Facility Info Lookup Table

/// All 17 facility metadata entries. Populated from FACILITY_INFO in Python.
let facilityInfo: [FacilityType: FacilityInfo] = [
    .foodBowl: FacilityInfo(
        name: "Food Bowl", size: FacilitySize(width: 2, height: 1),
        baseCost: 20, description: "Provides food to reduce hunger",
        capacity: 200, refillCost: 5,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .waterBottle: FacilityInfo(
        name: "Water Bottle", size: FacilitySize(width: 1, height: 2),
        baseCost: 20, description: "Provides water for hydration",
        capacity: 200, refillCost: 2,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .hayRack: FacilityInfo(
        name: "Hay Rack", size: FacilitySize(width: 2, height: 1),
        baseCost: 80, description: "Fiber source, +5% health bonus",
        capacity: 200, refillCost: 5,
        healthBonus: 0.05, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .hideout: FacilityInfo(
        name: "Hideout", size: FacilitySize(width: 3, height: 2),
        baseCost: 60, description: "Sleep and shelter, +10% happiness",
        capacity: 2, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.10, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .exerciseWheel: FacilityInfo(
        name: "Exercise Wheel", size: FacilitySize(width: 2, height: 2),
        baseCost: 150, description: "Entertainment and fitness, +5% health",
        capacity: 2, refillCost: 0,
        healthBonus: 0.05, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .tunnel: FacilityInfo(
        name: "Tunnel System", size: FacilitySize(width: 3, height: 1),
        baseCost: 200, description: "Exploration and play, +15% happiness",
        capacity: 3, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.15, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .playArea: FacilityInfo(
        name: "Play Area", size: FacilitySize(width: 3, height: 2),
        baseCost: 600, description: "Social activities, +social chance",
        capacity: 4, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.20,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .breedingDen: FacilityInfo(
        name: "Breeding Den", size: FacilitySize(width: 2, height: 2),
        baseCost: 3000, description: "Private space for mating",
        capacity: 0, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.15, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .nursery: FacilityInfo(
        name: "Nursery", size: FacilitySize(width: 3, height: 2),
        baseCost: 5000, description: "Baby care, faster growth",
        capacity: 4, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.20, saleBonus: 0.0, foodProduction: 0),
    .veggieGarden: FacilityInfo(
        name: "Veggie Garden", size: FacilitySize(width: 2, height: 2),
        baseCost: 5000, description: "Grows fresh vegetables",
        capacity: 0, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 10),
    .groomingStation: FacilityInfo(
        name: "Grooming Station", size: FacilitySize(width: 2, height: 1),
        baseCost: 500, description: "Health and appearance, +15% sale value",
        capacity: 0, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.15, foodProduction: 0),
    .geneticsLab: FacilityInfo(
        name: "Genetics Lab", size: FacilitySize(width: 3, height: 2),
        baseCost: 1000,
        description: "Reveals carrier alleles and boosts mutation rate",
        capacity: 0, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.0, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .feastTable: FacilityInfo(
        name: "Feast Table", size: FacilitySize(width: 5, height: 5),
        baseCost: 350,
        description: "Communal eating -- co-diners get social recovery",
        capacity: 300, refillCost: 8,
        healthBonus: 0.0, happinessBonus: 0.05, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .campfire: FacilityInfo(
        name: "Campfire", size: FacilitySize(width: 5, height: 5),
        baseCost: 1200,
        description: "Nighttime social gathering -- draws pigs after dark",
        capacity: 3, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.10, socialBonus: 0.15,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .therapyGarden: FacilityInfo(
        name: "Therapy Garden", size: FacilitySize(width: 5, height: 5),
        baseCost: 1500,
        description: "Unhappy pigs recover happiness and health here",
        capacity: 2, refillCost: 0,
        healthBonus: 0.08, happinessBonus: 0.20, socialBonus: 0.0,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .hotSpring: FacilityInfo(
        name: "Hot Spring", size: FacilitySize(width: 6, height: 6),
        baseCost: 15000,
        description: "Multi-need sleep -- energy, happiness, health, and social recovery",
        capacity: 4, refillCost: 0,
        healthBonus: 0.05, happinessBonus: 0.08, socialBonus: 0.10,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
    .stage: FacilityInfo(
        name: "Stage", size: FacilitySize(width: 6, height: 6),
        baseCost: 150_000,
        description: "Performer entertains nearby pigs with AoE happiness and social",
        capacity: 1, refillCost: 0,
        healthBonus: 0.0, happinessBonus: 0.15, socialBonus: 0.20,
        breedingBonus: 0.0, growthBonus: 0.0, saleBonus: 0.0, foodProduction: 0),
]

// MARK: - Facility

/// A placed facility on the farm grid.
struct Facility: Identifiable, Codable, Sendable {
    let id: UUID
    var facilityType: FacilityType
    var positionX: Int
    var positionY: Int
    var level: Int = 1
    let maxLevel: Int = 3

    // Resource state
    var currentAmount: Double = 100.0
    var maxAmount: Double = 100.0
    var autoRefill: Bool = false

    // Area tracking
    var areaId: UUID?

    // MARK: - Computed Properties

    var info: FacilityInfo {
        guard let value = facilityInfo[facilityType] else {
            preconditionFailure("Missing facilityInfo for \(facilityType)")
        }
        return value
    }

    var name: String { info.name }
    var size: FacilitySize { info.size }
    var width: Int { size.width }
    var height: Int { size.height }

    /// All cells occupied by this facility.
    var cells: [GridPosition] {
        var result: [GridPosition] = []
        for dx in 0..<width {
            for dy in 0..<height {
                result.append(GridPosition(x: positionX + dx, y: positionY + dy))
            }
        }
        return result
    }

    /// Primary cell where guinea pigs interact with this facility (front-center).
    var interactionPoint: GridPosition {
        GridPosition(x: positionX + width / 2, y: positionY + height)
    }

    /// All valid cells where guinea pigs can interact with this facility.
    /// Returns cells along the front and sides, filtering out negative coordinates.
    var interactionPoints: [GridPosition] {
        var points: [GridPosition] = []
        // Front (bottom) of the facility
        for dx in 0..<width {
            let px = positionX + dx
            let py = positionY + height
            if px >= 0 && py >= 0 {
                points.append(GridPosition(x: px, y: py))
            }
        }
        // Sides
        for dy in 0..<height {
            // Left side
            let leftX = positionX - 1
            let leftY = positionY + dy
            if leftX >= 0 && leftY >= 0 {
                points.append(GridPosition(x: leftX, y: leftY))
            }
            // Right side
            let rightX = positionX + width
            let rightY = positionY + dy
            if rightX >= 0 && rightY >= 0 {
                points.append(GridPosition(x: rightX, y: rightY))
            }
        }
        return points
    }

    var isEmpty: Bool { currentAmount <= 0 }

    var fillPercentage: Double {
        if maxAmount <= 0 { return 100.0 }
        return (currentAmount / maxAmount) * 100
    }

    // MARK: - Methods

    /// Consume resources from this facility. Returns amount actually consumed.
    mutating func consume(_ amount: Double) -> Double {
        let actual = min(amount, currentAmount)
        currentAmount -= actual
        return actual
    }

    /// Refill the facility. Pass nil to refill to max.
    mutating func refill(_ amount: Double? = nil) {
        let configuredCapacity = Double(info.capacity)
        if maxAmount < configuredCapacity {
            maxAmount = configuredCapacity
        }
        if let amount = amount {
            currentAmount = min(maxAmount, currentAmount + amount)
        } else {
            currentAmount = maxAmount
        }
    }

    /// Upgrade the facility to next level. Returns true if successful.
    mutating func upgrade() -> Bool {
        if level >= maxLevel { return false }
        level += 1
        maxAmount *= 1.5
        return true
    }

    /// Calculate cost to upgrade to next level.
    func getUpgradeCost() -> Int {
        if level >= maxLevel { return 0 }
        return Int(Double(info.baseCost) * Double(level + 1) * 0.75)
    }

    /// Create a new facility at the given position.
    static func create(type: FacilityType, x: Int, y: Int) -> Self {
        guard let info = facilityInfo[type] else {
            preconditionFailure("Missing facilityInfo for \(type)")
        }
        let capacity = Double(info.capacity)
        return Self(
            id: UUID(),
            facilityType: type,
            positionX: x,
            positionY: y,
            currentAmount: capacity,
            maxAmount: capacity
        )
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case facilityType = "facility_type"
        case positionX = "position_x"
        case positionY = "position_y"
        case level
        case maxLevel = "max_level"
        case currentAmount = "current_amount"
        case maxAmount = "max_amount"
        case autoRefill = "auto_refill"
        case areaId = "area_id"
    }
}
