/// BreedingPair -- Male/female pig ID pair for breeding.
/// Maps from: game/game_state.py (BreedingPair data type)
import Foundation

/// A breeding pair of male and female pig IDs.
struct BreedingPair: Codable, Sendable {
    let maleId: UUID
    let femaleId: UUID

    enum CodingKeys: String, CodingKey {
        case maleId = "male_id"
        case femaleId = "female_id"
    }
}
