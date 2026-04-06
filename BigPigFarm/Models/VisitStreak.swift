/// VisitStreak -- Consecutive daily visits tracking.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

// MARK: - VisitStreak

/// Tracks consecutive visit streaks. A new day is counted on the first visit
/// of each calendar day; the 24-hour rolling window controls streak expiry only.
struct VisitStreak: Codable, Sendable {
    /// Current streak count (consecutive days).
    var currentStreak: Int = 0

    /// Timestamp of the last visit.
    var lastVisitDate: Date?

    // MARK: - Computed Properties

    /// Timestamp when the current streak expires (lastVisitDate + 24h).
    /// Controls whether the streak resets, not whether a new day is counted.
    var streakExpiresAt: Date? {
        guard let last = lastVisitDate else { return nil }
        return last.addingTimeInterval(GameConfig.Prestige.streakWindowSeconds)
    }

    /// Whether the streak is still active (within 24h of last visit).
    func isStreakActive(at now: Date = Date()) -> Bool {
        guard let expiry = streakExpiresAt else { return false }
        return now < expiry
    }

    /// Time remaining in the streak window (seconds). Returns 0 if expired.
    func timeRemainingSeconds(at now: Date = Date()) -> TimeInterval {
        guard let expiry = streakExpiresAt else { return 0 }
        return max(0, expiry.timeIntervalSince(now))
    }

    /// Record a visit. Updates streak count and last visit date.
    /// Only increments the streak on the first visit of each calendar day.
    /// Returns the new streak count.
    @discardableResult
    mutating func recordVisit(at now: Date = Date()) -> Int {
        // Device-local calendar so "same day" matches what the player's clock shows.
        if let last = lastVisitDate, Calendar.current.isDate(last, inSameDayAs: now) {
            lastVisitDate = now
            return currentStreak
        }
        if isStreakActive(at: now) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        lastVisitDate = now
        return currentStreak
    }

    // MARK: - Streak Bonuses

    /// Breeding chance bonus from current streak (Day 2+: +5%).
    var breedingChanceBonus: Double {
        if currentStreak >= 2 { return GameConfig.Prestige.streakDay2BreedingBonus }
        return 0
    }

    /// Sale value bonus from current streak (Day 5+: +10%).
    var saleValueBonus: Double {
        if currentStreak >= 5 { return GameConfig.Prestige.streakDay5SaleBonus }
        return 0
    }

    /// Extra treats per visit from streak (Day 3: +1, Day 7: +1 more).
    var bonusTreats: Int {
        var bonus = 0
        if currentStreak >= 3 { bonus += 1 }
        if currentStreak >= 7 { bonus += 1 }
        return bonus
    }

    /// Bonus Rosettes earned on next Pig Show from streak.
    var bonusRosettes: Int {
        if currentStreak >= 30 { return 5 }
        if currentStreak >= 14 { return 2 }
        if currentStreak >= 7 { return 1 }
        return 0
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case lastVisitDate = "last_visit_date"
    }
}
