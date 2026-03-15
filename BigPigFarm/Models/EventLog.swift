import Foundation

/// A single event log entry for the event feed.
/// Maps from: game/game_state.py.
struct EventLog: Identifiable, Codable, Sendable {
    /// Transient identity for SwiftUI ForEach — not persisted (excluded from CodingKeys).
    let id = UUID()
    let timestamp: Date
    let gameDay: Int
    let message: String
    let eventType: String   // "info", "birth", "death", "sale", "purchase"

    enum CodingKeys: String, CodingKey {
        case timestamp
        case gameDay = "game_day"
        case message
        case eventType = "event_type"
    }
}
