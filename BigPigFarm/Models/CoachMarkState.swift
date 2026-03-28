/// CoachMarkState — Tracks which onboarding coach marks have been dismissed.
///
/// App-level preference (not per-save). Stored in UserDefaults like
/// NotificationPreferences — survives farm resets and prestige resets
/// because a player who has already been onboarded should not see hints again.
///
/// Maps from: N/A (new for mobile)
import Foundation

// MARK: - CoachMarkID

enum CoachMarkID: String, Codable, CaseIterable, Sendable {
    case welcomeTapPig = "welcome_tap_pig"
    case openShop = "open_shop"
    case refillFacilities = "refill_facilities"
    case breedingReady = "breeding_ready"
    case editMode = "edit_mode"
    case firstSale = "first_sale"
}

// MARK: - CoachMarkState

struct CoachMarkState: Codable, Sendable, Equatable {
    var dismissed: Set<CoachMarkID> = []

    func isShown(_ id: CoachMarkID) -> Bool {
        dismissed.contains(id)
    }

    mutating func markShown(_ id: CoachMarkID) {
        dismissed.insert(id)
    }

    mutating func resetAll() {
        dismissed.removeAll()
    }

    // MARK: - UserDefaults Persistence

    private static let userDefaultsKey = "coachMarkState"

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return Self()
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            return Self()
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
