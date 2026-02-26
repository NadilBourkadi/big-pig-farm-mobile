/// Facility — Farm facilities (food bowls, water bottles, shelters, toys, etc.).
/// Maps from: entities/facility.py
// TODO: Implement in doc 02
import Foundation

/// Physical size of a facility on the grid.
enum FacilitySize: String, Codable, CaseIterable, Sendable {
    case small, medium, large
}

/// Category of facility.
enum FacilityType: String, Codable, CaseIterable, Sendable {
    case food, water, shelter, enrichment, medical, breeding
}

/// A placed facility on the farm grid.
struct Facility: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in doc 02
}
