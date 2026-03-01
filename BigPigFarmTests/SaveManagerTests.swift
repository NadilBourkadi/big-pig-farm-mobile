/// SaveManagerTests -- Tests for JSON persistence (SaveManager, CodableSnapshot, SaveMigration).
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Test Helper

/// Returns a SaveManager pointing to a unique temporary directory.
/// Each test gets its own isolated directory so tests never interfere with each other.
@MainActor
private func makeTempSaveManager() -> SaveManager {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return SaveManager(baseDirectoryURL: tempDir)
}

// MARK: - hasSave / Delete

@Test @MainActor func hasSaveReturnsFalseWhenEmpty() {
    let manager = makeTempSaveManager()
    #expect(manager.hasSave() == false)
}

@Test @MainActor func loadReturnsNilWhenNoSave() {
    let manager = makeTempSaveManager()
    #expect(manager.load() == nil)
}

@Test @MainActor func deleteSaveRemovesBothFiles() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    try manager.save(state)
    // Save a second time so a .bak file exists
    try manager.save(state)
    #expect(manager.hasSave() == true)
    #expect(FileManager.default.fileExists(atPath: manager.backupFileURL.path) == true)
    manager.deleteSave()
    #expect(manager.hasSave() == false)
    #expect(FileManager.default.fileExists(atPath: manager.backupFileURL.path) == false)
}

// MARK: - Roundtrip: Basic State

@Test @MainActor func roundtripEmptyState() throws {
    let manager = makeTempSaveManager()
    let original = makeGameState()
    try manager.save(original)
    let loaded = try #require(manager.load())
    #expect(loaded.pigCount == 0)
    #expect(loaded.money == original.money)
    #expect(loaded.farmTier == 1)
}

@Test @MainActor func roundtripPreservesMoney() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    state.money = 9_999
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.money == 9_999)
}

@Test @MainActor func roundtripPreservesGameTime() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    state.gameTime.advance(minutes: 600) // Advance 10 hours
    let expectedDay = state.gameTime.day
    let expectedHour = state.gameTime.hour
    let expectedMinute = state.gameTime.minute
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.gameTime.day == expectedDay)
    #expect(loaded.gameTime.hour == expectedHour)
    #expect(loaded.gameTime.minute == expectedMinute)
}

// MARK: - Roundtrip: Pigs

@Test @MainActor func roundtripWithPigs() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    var pig1 = GuineaPig.create(name: "Biscuit", gender: .female)
    pig1.position = Position(x: 10.0, y: 8.0)
    var pig2 = GuineaPig.create(name: "Waffles", gender: .male)
    pig2.position = Position(x: 15.0, y: 12.0)
    state.addGuineaPig(pig1)
    state.addGuineaPig(pig2)
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.pigCount == 2)
    let loadedPig1 = try #require(loaded.getGuineaPig(pig1.id))
    #expect(loadedPig1.name == "Biscuit")
    #expect(loadedPig1.position.x == pig1.position.x)
    #expect(loadedPig1.position.y == pig1.position.y)
    let loadedPig2 = try #require(loaded.getGuineaPig(pig2.id))
    #expect(loadedPig2.name == "Waffles")
}

// MARK: - Roundtrip: Facilities

@Test @MainActor func roundtripWithFacilities() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    let food = Facility.create(type: .foodBowl, x: 5, y: 5)
    let water = Facility.create(type: .waterBottle, x: 10, y: 5)
    _ = state.addFacility(food)
    _ = state.addFacility(water)
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.getFacilitiesList().count == 2)
    let loadedFood = try #require(loaded.getFacility(food.id))
    #expect(loadedFood.facilityType == .foodBowl)
    #expect(loadedFood.positionX == 5)
    #expect(loadedFood.positionY == 5)
}

// MARK: - Roundtrip: Collections

@Test @MainActor func roundtripPreservesPigdex() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    _ = state.pigdex.registerPhenotype(key: "agouti:solid:normal:none", gameDay: 1)
    _ = state.pigdex.registerPhenotype(key: "black:solid:normal:none", gameDay: 2)
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.pigdex.discoveredCount == 2)
    #expect(loaded.pigdex.isDiscovered("agouti:solid:normal:none") == true)
}

@Test @MainActor func roundtripPreservesSocialAffinity() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    let id1 = UUID()
    let id2 = UUID()
    state.incrementAffinity(id1, id2)
    state.incrementAffinity(id1, id2)
    let key = GameState.affinityKey(id1, id2)
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.socialAffinity[key] == 2)
}

@Test @MainActor func roundtripPreservesPurchasedUpgrades() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    state.purchasedUpgrades = ["auto_feed", "double_capacity"]
    try manager.save(state)
    let loaded = try #require(manager.load())
    #expect(loaded.purchasedUpgrades.contains("auto_feed") == true)
    #expect(loaded.purchasedUpgrades.contains("double_capacity") == true)
    #expect(loaded.purchasedUpgrades.count == 2)
}

// MARK: - Backup and Corruption

@Test @MainActor func backupFileCreatedOnSecondSave() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    try manager.save(state)
    #expect(FileManager.default.fileExists(atPath: manager.backupFileURL.path) == false)
    try manager.save(state)
    #expect(FileManager.default.fileExists(atPath: manager.backupFileURL.path) == true)
}

@Test @MainActor func corruptedPrimaryFallsBackToBackup() throws {
    let manager = makeTempSaveManager()

    // First save — this becomes the backup on the second save
    let state = makeGameState()
    state.money = 42
    try manager.save(state)

    // Second save — first save becomes .bak, second save is primary
    state.money = 99
    try manager.save(state)

    // Corrupt the primary save file
    try Data("CORRUPTED_DATA".utf8).write(to: manager.saveFileURL)

    // Load should fall back to .bak (money == 42)
    let loaded = try #require(manager.load())
    #expect(loaded.money == 42)
}

// MARK: - Schema Version

@Test @MainActor func saveEnvelopeSchemaVersionIsOne() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    try manager.save(state)
    let rawData = try Data(contentsOf: manager.saveFileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(SaveEnvelope.self, from: rawData)
    #expect(envelope.schemaVersion == 1)
}

// MARK: - encodeToJSON

@Test @MainActor func encodeToJSONProducesValidEnvelope() throws {
    let state = makeGameState()
    state.money = 777
    let data = try state.encodeToJSON()
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(SaveEnvelope.self, from: data)
    #expect(envelope.schemaVersion == SaveManager.schemaVersion)
    #expect(envelope.snapshot.money == 777)
    #expect(envelope.snapshot.farmTier == 1)
}

// MARK: - Migration: clampOrphanedPigs

@Test @MainActor func clampOrphanedPigsMovesOffWallCells() {
    let state = makeGameState()
    // Place a pig on a wall cell (border of the starter area, which is at x=0,y=0)
    var pig = GuineaPig.create(name: "Clipper", gender: .female)
    pig.position = Position(x: 0.0, y: 0.0)  // (0,0) is a wall cell
    state.guineaPigs[pig.id] = pig

    SaveMigration.clampOrphanedPigs(state)

    let moved = state.getGuineaPig(pig.id)!
    let x = Int(moved.position.x)
    let y = Int(moved.position.y)
    #expect(state.farm.isWalkable(x, y) == true)
}
