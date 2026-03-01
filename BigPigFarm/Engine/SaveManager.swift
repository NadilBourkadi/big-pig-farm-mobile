/// SaveManager — JSON persistence via FileManager.
/// Maps from: data/persistence.py (simplified from SQLite to JSON)
import Foundation

// MARK: - SaveManager

/// Handles saving and loading game state as JSON files.
/// `baseDirectoryURL` is injectable for test isolation.
struct SaveManager: Sendable {
    static let schemaVersion: Int = 1
    static let saveFileName = "save.json"
    static let backupFileName = "save.json.bak"

    let baseDirectoryURL: URL

    init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var saveFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.saveFileName) }
    var backupFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.backupFileName) }
}

// MARK: - Save

extension SaveManager {
    /// Encode `state` to JSON and write atomically, backing up the previous save first.
    @MainActor
    func save(_ state: GameState) throws {
        let data = try state.encodeToJSON()
        try saveData(data)
        state.lastSave = Date()
    }

    /// Write pre-encoded JSON data atomically, backing up the previous save first.
    /// Not `@MainActor` — caller encodes on main actor, passes Data here for background use.
    func saveData(_ data: Data) throws {
        makeBackup()
        try data.write(to: saveFileURL, options: .atomic)
    }
}

// MARK: - Load

extension SaveManager {
    /// Load game state from the primary save, falling back to backup on corruption.
    /// Returns nil if no save exists.
    @MainActor
    func load() -> GameState? {
        loadFromURL(saveFileURL) ?? loadFromURL(backupFileURL)
    }

    /// True if a primary save file exists.
    func hasSave() -> Bool {
        FileManager.default.fileExists(atPath: saveFileURL.path)
    }

    /// Remove both save and backup files.
    func deleteSave() {
        try? FileManager.default.removeItem(at: saveFileURL)
        try? FileManager.default.removeItem(at: backupFileURL)
    }
}

// MARK: - Private Helpers

private extension SaveManager {
    /// Copy the current save to `.bak` before overwriting.
    func makeBackup() {
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else { return }
        try? FileManager.default.removeItem(at: backupFileURL)
        try? FileManager.default.copyItem(at: saveFileURL, to: backupFileURL)
    }

    /// Decode a save file at `url`, run migration, and return the restored state.
    @MainActor
    func loadFromURL(_ url: URL) -> GameState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(SaveEnvelope.self, from: data)
            let state = GameState.fromSnapshot(envelope.snapshot)
            SaveMigration.migrateIfNeeded(state)
            return state
        } catch {
            print("[SaveManager] Failed to load from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
