/// Facility — Farm facilities (food bowls, water bottles, shelters, toys, etc.).
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

// MARK: - Stubs (implemented in later tasks)

/// Physical size of a facility on the grid.
struct FacilitySize: Codable, Sendable {
    let width: Int
    let height: Int
}

/// A placed facility on the farm grid.
struct Facility: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in struct translation task
}
