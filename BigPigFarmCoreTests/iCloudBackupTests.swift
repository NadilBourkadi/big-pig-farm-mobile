/// iCloudBackupTests — Tests for iCloud backup state and manager.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - iCloudBackupState Tests

@Test func backupStateStartsWithNilDate() {
    let state = iCloudBackupState()
    #expect(state.lastBackupDate == nil)
}

@Test func backupStatePersistenceRoundTrip() throws {
    let defaults = try #require(UserDefaults(suiteName: "iCloudBackupTests-\(UUID().uuidString)"))
    var state = iCloudBackupState()
    state.lastBackupDate = Date(timeIntervalSince1970: 1_700_000_000)
    state.save(to: defaults)

    let loaded = iCloudBackupState.load(from: defaults)
    #expect(loaded == state)
    #expect(loaded.lastBackupDate != nil)
}

@Test func backupStateLoadReturnsDefaultWhenNoData() throws {
    let defaults = try #require(UserDefaults(suiteName: "iCloudBackupTests-empty-\(UUID().uuidString)"))
    let loaded = iCloudBackupState.load(from: defaults)
    #expect(loaded.lastBackupDate == nil)
}

@Test func backupStateLoadReturnsDefaultOnCorruptData() throws {
    let defaults = try #require(UserDefaults(suiteName: "iCloudBackupTests-corrupt-\(UUID().uuidString)"))
    defaults.set(Data("not valid json".utf8), forKey: "iCloudBackupState")
    let loaded = iCloudBackupState.load(from: defaults)
    #expect(loaded.lastBackupDate == nil)
}

// MARK: - iCloudBackupManager Tests

/// Create a temp directory for test isolation.
private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("iCloudBackupTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Write sample JSON data to simulate a local save file.
private func writeSampleSave(
    to dir: URL, fileName: String = "save.json", content: String = "{}"
) throws {
    let fileURL = dir.appendingPathComponent(fileName)
    try Data(content.utf8).write(to: fileURL)
}

/// Create an isolated UserDefaults suite for test isolation.
private func makeTestDefaults() throws -> UserDefaults {
    try #require(UserDefaults(suiteName: "iCloudBackupTests-mgr-\(UUID().uuidString)"))
}

@Test func managerIsUnavailableWhenContainerURLIsNil() throws {
    let localDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: nil,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    #expect(!manager.isAvailable)
}

@Test func managerIsAvailableWithContainerURL() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    #expect(manager.isAvailable)
}

@Test func backupCopiesSaveFile() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    try writeSampleSave(to: localDir, content: "{\"test\": true}")

    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    manager.backupToCloud()

    // backupToCloud dispatches to a background queue — wait for it
    Thread.sleep(forTimeInterval: 0.5)

    let backupFile = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
        .appendingPathComponent("save.json")
    #expect(FileManager.default.fileExists(atPath: backupFile.path))
    let data = try Data(contentsOf: backupFile)
    #expect(String(data: data, encoding: .utf8) == "{\"test\": true}")
}

@Test func backupCopiesPrestigeFile() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    try writeSampleSave(to: localDir, content: "{\"save\": true}")
    try writeSampleSave(to: localDir, fileName: "prestige.json", content: "{\"prestige\": true}")

    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    let prestigeBackup = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
        .appendingPathComponent("prestige.json")
    #expect(FileManager.default.fileExists(atPath: prestigeBackup.path))
    let data = try Data(contentsOf: prestigeBackup)
    #expect(String(data: data, encoding: .utf8) == "{\"prestige\": true}")
}

@Test func backupNoOpsWhenContainerIsNil() throws {
    let localDir = try makeTempDir()
    try writeSampleSave(to: localDir)
    let manager = iCloudBackupManager(
        containerURL: nil,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.2)
    // No crash, no files created anywhere unexpected
}

@Test func backupNoOpsWhenNoLocalSave() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    let backupDir = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
    let saveBackup = backupDir.appendingPathComponent("save.json")
    #expect(!FileManager.default.fileExists(atPath: saveBackup.path))
}

@Test func backupOverwritesPreviousBackup() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let sm = SaveManager(baseDirectoryURL: localDir)
    let defaults = try makeTestDefaults()

    try writeSampleSave(to: localDir, content: "{\"version\": 1}")
    let manager = iCloudBackupManager(
        containerURL: cloudDir, saveManager: sm, defaults: defaults
    )
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    try Data("{\"version\": 2}".utf8).write(to: sm.saveFileURL)
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    let backupFile = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
        .appendingPathComponent("save.json")
    let data = try Data(contentsOf: backupFile)
    #expect(String(data: data, encoding: .utf8) == "{\"version\": 2}")
}

@Test func backupUpdatesLastBackupDate() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let defaults = try makeTestDefaults()
    try writeSampleSave(to: localDir)
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: defaults
    )
    let before = Date()
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    let state = iCloudBackupState.load(from: defaults)
    #expect(state.lastBackupDate != nil)
    if let date = state.lastBackupDate {
        #expect(date >= before)
    }
}

// MARK: - Restore Tests

@Test func hasCloudBackupReturnsFalseWhenNoBackup() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    #expect(!manager.hasCloudBackup())
}

@Test func hasCloudBackupReturnsTrueAfterBackup() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    try writeSampleSave(to: localDir)
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)
    #expect(manager.hasCloudBackup())
}

@Test func hasCloudBackupReturnsFalseWhenContainerNil() throws {
    let localDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: nil,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    #expect(!manager.hasCloudBackup())
}

@Test func cloudBackupDateReturnsModificationDate() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    try writeSampleSave(to: localDir)
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    let before = Date()
    manager.backupToCloud()
    Thread.sleep(forTimeInterval: 0.5)

    let date = manager.cloudBackupDate()
    #expect(date != nil)
    if let date {
        #expect(date >= before.addingTimeInterval(-1))
    }
}

@Test func restoreCopiesToLocal() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let sm = SaveManager(baseDirectoryURL: localDir)

    let backupDir = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
    try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    try Data("{\"cloud\": true}".utf8).write(to: backupDir.appendingPathComponent("save.json"))

    let manager = iCloudBackupManager(
        containerURL: cloudDir, saveManager: sm, defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(success)

    let restored = try Data(contentsOf: sm.saveFileURL)
    #expect(String(data: restored, encoding: .utf8) == "{\"cloud\": true}")
}

@Test func restoreReturnsFalseWhenNoCloudBackup() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: cloudDir,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(!success)
}

@Test func restoreReturnsFalseWhenContainerNil() throws {
    let localDir = try makeTempDir()
    let manager = iCloudBackupManager(
        containerURL: nil,
        saveManager: SaveManager(baseDirectoryURL: localDir),
        defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(!success)
}

@Test func restoreOverwritesLocalSave() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let sm = SaveManager(baseDirectoryURL: localDir)

    try writeSampleSave(to: localDir, content: "{\"local\": true}")

    let backupDir = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
    try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    try Data("{\"cloud\": true}".utf8).write(to: backupDir.appendingPathComponent("save.json"))

    let manager = iCloudBackupManager(
        containerURL: cloudDir, saveManager: sm, defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(success)

    let data = try Data(contentsOf: sm.saveFileURL)
    #expect(String(data: data, encoding: .utf8) == "{\"cloud\": true}")
}

@Test func restoreAlsoRestoresPrestige() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let sm = SaveManager(baseDirectoryURL: localDir)

    let backupDir = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
    try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    try Data("{\"save\": true}".utf8).write(to: backupDir.appendingPathComponent("save.json"))
    try Data("{\"prestige\": true}".utf8).write(
        to: backupDir.appendingPathComponent("prestige.json")
    )

    let manager = iCloudBackupManager(
        containerURL: cloudDir, saveManager: sm, defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(success)

    let saveData = try Data(contentsOf: sm.saveFileURL)
    #expect(String(data: saveData, encoding: .utf8) == "{\"save\": true}")
    let prestigeData = try Data(contentsOf: sm.prestigeFileURL)
    #expect(String(data: prestigeData, encoding: .utf8) == "{\"prestige\": true}")
}

@Test func restoreWorksWithoutPrestigeFile() throws {
    let localDir = try makeTempDir()
    let cloudDir = try makeTempDir()
    let sm = SaveManager(baseDirectoryURL: localDir)

    let backupDir = cloudDir
        .appendingPathComponent("Documents")
        .appendingPathComponent("SaveBackup")
    try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
    try Data("{\"save\": true}".utf8).write(to: backupDir.appendingPathComponent("save.json"))

    let manager = iCloudBackupManager(
        containerURL: cloudDir, saveManager: sm, defaults: try makeTestDefaults()
    )
    let success = try manager.restoreFromCloud()
    #expect(success)

    #expect(!FileManager.default.fileExists(atPath: sm.prestigeFileURL.path))
}
