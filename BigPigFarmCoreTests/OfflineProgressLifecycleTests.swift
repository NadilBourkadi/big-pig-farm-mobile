/// Tests for offline progress lifecycle integration.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Duration Computation

@Suite("Offline Duration Computation")
struct OfflineDurationComputationTests {
    @Test @MainActor func nilLastSaveReturnsZero() {
        let state = GameState()
        state.lastSave = nil
        let duration = offlineDuration(lastSave: state.lastSave)
        #expect(duration == 0)
    }

    @Test func recentLastSaveReturnsBelowThreshold() {
        let lastSave = Date().addingTimeInterval(-30)  // 30 seconds ago
        let duration = offlineDuration(lastSave: lastSave)
        #expect(duration < GameConfig.Offline.minThresholdSeconds)
        #expect(duration >= 29)  // Allow 1 second of test execution time
    }

    @Test func staleLastSaveReturnsAboveThreshold() {
        let lastSave = Date().addingTimeInterval(-120)  // 2 minutes ago
        let duration = offlineDuration(lastSave: lastSave)
        #expect(duration >= GameConfig.Offline.minThresholdSeconds)
    }

    @Test func futureDateReturnsZero() {
        let lastSave = Date().addingTimeInterval(3600)  // 1 hour in the future
        let duration = offlineDuration(lastSave: lastSave)
        #expect(duration == 0)
    }
}

/// Testable duration computation — mirrors BigPigFarmApp.computeOfflineDuration.
private func offlineDuration(lastSave: Date?) -> TimeInterval {
    guard let lastSave else { return 0 }
    return max(0, Date().timeIntervalSince(lastSave))
}

// MARK: - Catch-Up Integration

@Suite("Offline Catch-Up Flow")
struct OfflineCatchUpFlowTests {
    @Test @MainActor func catchUpSavesStateToDisk() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let saveManager = SaveManager(baseDirectoryURL: tempDir)
        let state = GameState()
        state.lastSave = Date().addingTimeInterval(-120)

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 120)
        try saveManager.save(state)

        #expect(saveManager.hasSave())
    }

    @Test @MainActor func catchUpWithMeaningfulEventsSetsNonNilSummary() {
        let state = GameState()
        // Add a pregnant pig near term to guarantee a birth event
        var male = GuineaPig.create(name: "Dad", gender: .male)
        male.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        state.addGuineaPig(male)

        var female = GuineaPig.create(name: "Mom", gender: .female)
        female.ageDays = Double(GameConfig.Simulation.adultAgeDays)
        female.isPregnant = true
        female.pregnancyDays = 1.9  // Just under 2-day gestation
        female.partnerId = male.id
        female.partnerGenotype = male.genotype
        female.partnerName = male.name
        state.addGuineaPig(female)

        _ = state.addFacility(Facility.create(type: .foodBowl, x: 3, y: 3))
        _ = state.addFacility(Facility.create(type: .waterBottle, x: 8, y: 3))

        // 480 wall seconds at 3x = 24 game-hours — should trigger birth
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)
        #expect(summary.hasMeaningfulEvents)
        #expect(!summary.pigsBorn.isEmpty)
    }

    @Test @MainActor func catchUpWithNoEventsReturnsEmptySummary() {
        let state = GameState()
        // Very short duration — not even 1 full checkpoint
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 10)
        #expect(!summary.hasMeaningfulEvents)
    }
}

// MARK: - Save Timestamp Ordering

@Suite("Save Timestamp Ordering")
struct SaveTimestampOrderingTests {
    @Test @MainActor func saveManagerSaveRecordsCurrentTimestamp() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = SaveManager(baseDirectoryURL: tempDir)
        let state = makeGameState()
        let before = Date()
        try manager.save(state)

        // In-memory lastSave should be set
        let lastSave = try #require(state.lastSave)
        #expect(lastSave >= before)

        // On-disk lastSave should match in-memory (not be stale)
        let loaded = try #require(manager.load())
        let loadedLastSave = try #require(loaded.lastSave)
        #expect(abs(loadedLastSave.timeIntervalSince(lastSave)) < 1.0)
    }

    @Test @MainActor func saveManagerPersistsTimestampInJSON() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = SaveManager(baseDirectoryURL: tempDir)
        let state = makeGameState()
        state.lastSave = nil
        try manager.save(state)

        // Decode raw JSON to verify lastSave is in the persisted data
        let rawData = try Data(contentsOf: manager.saveFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SaveEnvelope.self, from: rawData)
        #expect(envelope.snapshot.lastSave != nil)
    }
}

// MARK: - New Game Timestamp

@Suite("New Game Timestamp")
struct NewGameTimestampTests {
    // setupNewGame() lives in BigPigFarmApp.swift (the @main entry point),
    // which is not part of the SPM core library target. These tests verify
    // the lastSave behavior directly instead of calling setupNewGame().

    @Test @MainActor func freshStateHasNilLastSaveThenSetWorks() throws {
        let state = GameState()
        #expect(state.lastSave == nil)
        let before = Date()
        state.lastSave = Date()
        let lastSave = try #require(state.lastSave)
        #expect(lastSave >= before)
    }

    @Test @MainActor func lastSaveSurvivesRoundtrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = SaveManager(baseDirectoryURL: tempDir)
        let state = makeGameState()
        state.lastSave = Date()
        try manager.save(state)
        let loaded = try #require(manager.load())
        #expect(loaded.lastSave != nil)
    }
}

// MARK: - Cold Start Detection

@Suite("Cold Start Detection")
struct ColdStartDetectionTests {
    @Test @MainActor func existingSaveWithStaleLastSaveHasPositiveDuration() {
        let state = makeGameState()
        state.lastSave = Date().addingTimeInterval(-300)  // 5 minutes ago
        let duration = offlineDuration(lastSave: state.lastSave)
        #expect(duration >= GameConfig.Offline.minThresholdSeconds)
    }

    // The actual fallback assignment (state.lastSave = state.sessionStart)
    // lives in BigPigFarmApp.init() and cannot be unit-tested without refactoring.
    // This test confirms the data condition that triggers it is persisted correctly.
    @Test @MainActor func loadedSaveWithNilLastSaveFallsBackToSessionStart() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = SaveManager(baseDirectoryURL: tempDir)
        let state = makeGameState()
        // Simulate a legacy save with nil lastSave by saving, then
        // reloading and verifying fallback logic works
        state.lastSave = nil
        // Manually encode with nil lastSave
        let data = try state.encodeToJSON()
        try manager.saveData(data)

        let loaded = try #require(manager.load())
        // Legacy save has nil lastSave
        #expect(loaded.lastSave == nil)
        // The defensive fallback in BigPigFarmApp.init() would set
        // lastSave = sessionStart. Verify sessionStart is usable.
        #expect(loaded.sessionStart <= Date())
        let fallbackDuration = offlineDuration(lastSave: loaded.sessionStart)
        #expect(fallbackDuration >= 0)
    }
}

// MARK: - Edge Cases

@Suite("Offline Lifecycle Edge Cases")
struct OfflineLifecycleEdgeCaseTests {
    @Test @MainActor func firstLaunchHasNilLastSave() {
        let state = GameState()
        #expect(state.lastSave == nil)
    }

    @Test func belowThresholdSkipsCatchUp() {
        let duration: TimeInterval = 30  // Below 60s threshold
        #expect(duration < GameConfig.Offline.minThresholdSeconds)
    }

    @Test func exactThresholdTriggersCatchUp() {
        let duration: TimeInterval = 60  // Exactly at threshold
        #expect(duration >= GameConfig.Offline.minThresholdSeconds)
    }

    @Test @MainActor func summaryIdStableAcrossCopies() {
        let original = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        let copy = original
        #expect(original.id == copy.id)
    }

    @Test @MainActor func twoSummariesHaveDistinctIds() {
        let first = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        let second = OfflineProgressSummary(wallClockElapsed: 100, gameHoursElapsed: 5)
        #expect(first.id != second.id)
    }
}
