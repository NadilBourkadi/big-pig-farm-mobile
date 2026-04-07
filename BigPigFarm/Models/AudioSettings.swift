/// AudioSettings — Mute toggle for sound effects.
///
/// App-level preference (not per-save). Stored in UserDefaults like
/// CoachMarkState — survives farm resets because audio preference is
/// independent of which farm save is loaded.
import Foundation

struct AudioSettings: Codable, Sendable, Equatable {
    var isEnabled: Bool = true

    // MARK: - UserDefaults Persistence

    private static let userDefaultsKey = "audioSettings"

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
