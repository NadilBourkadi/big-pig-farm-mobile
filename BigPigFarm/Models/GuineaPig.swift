/// GuineaPig — Core pig entity with needs, position, personality, and behavior state.
/// Maps from: entities/guinea_pig.py
// TODO: Implement in doc 02
import Foundation

/// Biological sex of a guinea pig.
enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

/// Lifecycle stage based on age.
enum AgeGroup: String, Codable, CaseIterable, Sendable {
    case baby
    case juvenile
    case adult
    case senior
}

/// Active behavior state for the AI decision tree.
enum BehaviorState: String, Codable, CaseIterable, Sendable {
    case idle
    case wandering
    case seekingFood
    case seekingWater
    case seekingShelter
    case socializing
    case resting
    case fleeing
}

/// Personality traits affecting behavior weights.
struct Personality: Codable, Sendable {
    // TODO: Implement in doc 02
}

/// Physical position on the farm grid.
struct Position: Codable, Sendable, Hashable {
    var x: Int
    var y: Int
}

/// Guinea pig need levels (0.0–1.0).
struct Needs: Codable, Sendable {
    // TODO: Implement in doc 02
}

/// The core guinea pig entity.
struct GuineaPig: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in doc 02
}
