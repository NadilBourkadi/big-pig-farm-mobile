import Foundation

/// Tracks in-game time progression.
/// Maps from: game/game_state.py `GameTime`.
///
/// Day/hour/minute are derived from `totalGameMinutes` plus a base offset,
/// avoiding floating-point accumulation drift in the integer clock fields.
struct GameTime: Codable, Sendable {
    var lastUpdate = Date()
    var totalGameMinutes: Double = 0.0

    /// Absolute offset in minutes from the epoch (day 1, 00:00 = 0).
    /// Default 480 = day 1, 08:00. Recalculated when day/hour/minute are set directly.
    private var clockBaseMinutes: Double = 8 * 60

    init(day: Int = 1, hour: Int = 8, minute: Int = 0) {
        self.clockBaseMinutes = Double((day - 1) * 1440 + hour * 60 + minute)
    }

    // MARK: - Derived clock fields

    /// Total elapsed minutes (base + accumulated) as an integer.
    private var absoluteWholeMinutes: Int {
        // Tiny epsilon prevents near-miss truncation from float imprecision
        // (e.g. 59.99999998 → 59 instead of 60).
        Int(clockBaseMinutes + totalGameMinutes + 1e-9)
    }

    var day: Int {
        get { 1 + absoluteWholeMinutes / 1440 }
        set { setClockBase(day: newValue, hour: hour, minute: minute) }
    }

    var hour: Int {
        get { (absoluteWholeMinutes / 60) % 24 }
        set { setClockBase(day: day, hour: newValue, minute: minute) }
    }

    var minute: Int {
        get { absoluteWholeMinutes % 60 }
        set { setClockBase(day: day, hour: hour, minute: newValue) }
    }

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
        lastUpdate = Date()
    }

    /// Recalculate the base offset so the given day/hour/minute are reflected
    /// at the current totalGameMinutes. Each property setter calls this independently,
    /// reading the other two computed properties. Chaining sets (e.g. `time.day = 2;
    /// time.hour = 0`) works correctly because each setter commits before the next reads.
    private mutating func setClockBase(day: Int, hour: Int, minute: Int) {
        let target = Double((day - 1) * 1440 + hour * 60 + minute)
        clockBaseMinutes = target - totalGameMinutes
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
        case lastUpdate = "last_update"
        case totalGameMinutes = "total_game_minutes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let day = try container.decode(Int.self, forKey: .day)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        totalGameMinutes = try container.decode(Double.self, forKey: .totalGameMinutes)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
        clockBaseMinutes = Double((day - 1) * 1440 + hour * 60 + minute) - totalGameMinutes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(totalGameMinutes, forKey: .totalGameMinutes)
        try container.encode(lastUpdate, forKey: .lastUpdate)
    }
}
