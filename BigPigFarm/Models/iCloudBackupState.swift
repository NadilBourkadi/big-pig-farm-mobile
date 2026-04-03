/// iCloudBackupState — Tracks iCloud backup metadata in UserDefaults.
///
/// App-level preference (not per-save). Stored in UserDefaults like
/// CoachMarkState — survives farm resets because backup metadata is
/// independent of which farm save is loaded.
import Foundation

struct iCloudBackupState: Codable, Sendable, Equatable {
    var lastBackupDate: Date?

    // MARK: - UserDefaults Persistence

    private static let userDefaultsKey = "iCloudBackupState"

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return Self()
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Self.self, from: data)
        } catch {
            return Self()
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
