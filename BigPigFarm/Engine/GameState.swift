/// GameState -- Root observable state container for the entire game.
/// Maps from: game/game_state.py
import Foundation
import Observation

// MARK: - Data Types (Doc 02 scope)

/// Tracks in-game time progression.
struct GameTime: Codable, Sendable {
    var day: Int = 1
    var hour: Int = 8
    var minute: Int = 0
    var lastUpdate: Date = Date()
    var totalGameMinutes: Double = 0.0

    var isDaytime: Bool { 6 <= hour && hour < 20 }

    var timeOfDay: String {
        if hour < 6 { return "Night" }
        if hour < 12 { return "Morning" }
        if hour < 18 { return "Afternoon" }
        if hour < 20 { return "Evening" }
        return "Night"
    }

    var displayTime: String {
        String(format: "Day %d %02d:%02d", day, hour, minute)
    }

    /// Advance game time by the given number of minutes.
    mutating func advance(minutes: Double) {
        totalGameMinutes += minutes
        var totalMinutes = Double(minute) + minutes
        var totalHours = Double(hour)
        var totalDays = day

        totalHours += (totalMinutes / 60).rounded(.down)
        totalMinutes = totalMinutes.truncatingRemainder(dividingBy: 60)

        totalDays += Int(totalHours / 24)
        totalHours = totalHours.truncatingRemainder(dividingBy: 24)

        day = totalDays
        hour = Int(totalHours)
        minute = Int(totalMinutes)
        lastUpdate = Date()
    }

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
        case lastUpdate = "last_update"
        case totalGameMinutes = "total_game_minutes"
    }
}

/// A single event log entry for the event feed.
struct EventLog: Codable, Sendable {
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

/// A breeding pair of male and female pig IDs.
struct BreedingPair: Codable, Sendable {
    let maleId: UUID
    let femaleId: UUID

    enum CodingKeys: String, CodingKey {
        case maleId = "male_id"
        case femaleId = "female_id"
    }
}

// MARK: - GameState (Doc 04 scope)

/// The central game state, observed by both SwiftUI and SpriteKit layers.
@Observable
final class GameState: @unchecked Sendable {
    // TODO: Implement in doc 04
}
