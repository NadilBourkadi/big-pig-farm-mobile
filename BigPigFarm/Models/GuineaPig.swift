/// GuineaPig — Core pig entity with needs, position, personality, and behavior state.
/// Maps from: entities/guinea_pig.py
import Foundation

// MARK: - Gender

/// Biological sex of a guinea pig.
enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

// MARK: - AgeGroup

/// Lifecycle stage based on age (no juvenile stage in the source game).
enum AgeGroup: String, Codable, CaseIterable, Sendable {
    case baby
    case adult
    case senior
}

// MARK: - BehaviorState

/// Active behavior state for the AI decision tree.
enum BehaviorState: String, Codable, CaseIterable, Sendable {
    case idle
    case wandering
    case eating
    case drinking
    case playing
    case sleeping
    case socializing
    case courting
}

// MARK: - Personality

/// Personality traits that modify behavior weights.
enum Personality: String, Codable, CaseIterable, Sendable {
    case greedy     // +50% hunger decay, eats more
    case lazy       // -30% energy decay, sleeps more
    case playful    // +50% boredom decay, uses toys more
    case shy        // Avoids other pigs, prefers hideouts
    case social     // Seeks other pigs, happiness from groups
    case brave      // Explores more, less hideout time
    case picky      // Prefers high-quality facilities
}

// MARK: - Stubs (implemented in later tasks)

/// Physical position on the farm grid (sub-cell precision).
struct Position: Codable, Sendable, Hashable {
    var x: Double = 0.0
    var y: Double = 0.0
}

/// Guinea pig need levels (0.0-100.0).
struct Needs: Codable, Sendable {
    // TODO: Implement in struct translation task
}

/// The core guinea pig entity.
struct GuineaPig: Identifiable, Codable, Sendable {
    let id: UUID
    // TODO: Implement in struct translation task
}
