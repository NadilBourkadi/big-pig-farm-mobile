/// SaveManager — JSON persistence via FileManager.
/// Maps from: data/persistence.py (simplified from SQLite to JSON)
import Foundation

// MARK: - PrestigeEnvelope

/// Versioned wrapper around PrestigeState for safe migration checks.
struct PrestigeEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let prestige: PrestigeState

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case prestige
    }
}

// MARK: - SaveManager

/// Handles saving and loading game state as JSON files.
/// `baseDirectoryURL` is injectable for test isolation.
struct SaveManager: Sendable {
    static let schemaVersion: Int = 1
    static let prestigeSchemaVersion: Int = 1
    static let saveFileName = "save.json"
    static let backupFileName = "save.json.bak"
    static let prestigeFileName = "prestige.json"
    static let prestigeBackupFileName = "prestige.json.bak"

    let baseDirectoryURL: URL

    init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var saveFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.saveFileName) }
    var backupFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.backupFileName) }
    var prestigeFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.prestigeFileName) }
    var prestigeBackupFileURL: URL { baseDirectoryURL.appendingPathComponent(Self.prestigeBackupFileName) }
}

// MARK: - Game Save

extension SaveManager {
    /// Encode `state` to JSON and write atomically, backing up the previous save first.
    @MainActor
    func save(_ state: GameState) throws {
        state.lastSave = Date()
        let data = try state.encodeToJSON()
        try saveData(data)
    }

    /// Write pre-encoded JSON data atomically, backing up the previous save first.
    /// Not `@MainActor` — intended for auto-save where the caller encodes on the main actor
    /// then dispatches this write to a background task. Only one concurrent writer is safe;
    /// the backup-then-write sequence is not internally synchronized.
    func saveData(_ data: Data) throws {
        makeBackup(at: saveFileURL, backupAt: backupFileURL)
        try data.write(to: saveFileURL, options: .atomic)
    }
}

// MARK: - Game Load

extension SaveManager {
    /// Load game state from the primary save, falling back to backup on corruption.
    /// Returns nil if no save exists.
    @MainActor
    func load() -> GameState? {
        loadGameFromURL(saveFileURL) ?? loadGameFromURL(backupFileURL)
    }

    /// True if a primary save file exists.
    func hasSave() -> Bool {
        FileManager.default.fileExists(atPath: saveFileURL.path)
    }

    /// Remove only the game save and backup (preserves prestige state).
    func deleteGameSave() {
        try? FileManager.default.removeItem(at: saveFileURL)
        try? FileManager.default.removeItem(at: backupFileURL)
    }

    /// Remove all save files — game and prestige. Dev tool only.
    func deleteAllSaves() {
        deleteGameSave()
        try? FileManager.default.removeItem(at: prestigeFileURL)
        try? FileManager.default.removeItem(at: prestigeBackupFileURL)
    }
}

// MARK: - Prestige Save/Load

extension SaveManager {
    /// Save prestige state to its own JSON file (survives farm resets).
    func savePrestigeState(_ state: PrestigeState) throws {
        let envelope = PrestigeEnvelope(schemaVersion: Self.prestigeSchemaVersion, prestige: state)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(envelope)
        makeBackup(at: prestigeFileURL, backupAt: prestigeBackupFileURL)
        try data.write(to: prestigeFileURL, options: .atomic)
    }

    /// Load prestige state from disk. Returns nil if no prestige save exists.
    func loadPrestigeState() -> PrestigeState? {
        loadPrestigeFromURL(prestigeFileURL) ?? loadPrestigeFromURL(prestigeBackupFileURL)
    }

    /// True if a prestige save file exists.
    func hasPrestigeSave() -> Bool {
        FileManager.default.fileExists(atPath: prestigeFileURL.path)
    }
}

// MARK: - Private Helpers

private extension SaveManager {
    /// Copy a save file to its backup location before overwriting.
    func makeBackup(at primary: URL, backupAt backup: URL) {
        guard FileManager.default.fileExists(atPath: primary.path) else { return }
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: primary, to: backup)
    }

    /// Decode a game save file at `url`, run migration, and return the restored state.
    @MainActor
    func loadGameFromURL(_ url: URL) -> GameState? {
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

    /// Decode a prestige save file at `url`.
    func loadPrestigeFromURL(_ url: URL) -> PrestigeState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(PrestigeEnvelope.self, from: data)
            return envelope.prestige
        } catch {
            print("[SaveManager] Failed to load prestige from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
