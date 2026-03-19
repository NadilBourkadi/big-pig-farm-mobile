/// DebugLoggerTests — Tests for structured debug logging system.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - DebugLogger Tests

@Suite("DebugLogger", .serialized)
@MainActor
struct DebugLoggerTests {

    /// Create a fresh logger with an isolated temp directory for each test.
    /// Closes any previously open instance (including the app's own bootstrap)
    /// so we redirect to a clean temp database.
    private func makeLogger() -> (DebugLogger, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DebugLoggerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let logger = DebugLogger.shared
        logger.close()
        logger.open(baseURL: dir)
        return (logger, dir)
    }

    private func cleanup(_ logger: DebugLogger, dir: URL) {
        logger.close()
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Buffer and Flush

    @Test("Log appends to buffer and flush persists to SQLite")
    func bufferAndFlush() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(category: .behavior, level: .info, message: "pig changed state")
        logger.log(category: .breeding, level: .info, message: "courtship started")
        logger.flush()

        let events = await logger.query(limit: 10)
        #expect(events.count == 2)
        #expect(events.contains { $0.message == "pig changed state" })
        #expect(events.contains { $0.message == "courtship started" })
    }

    // MARK: - Query Filtering

    @Test("Query by category returns only matching events")
    func queryByCategory() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(category: .behavior, level: .info, message: "behavior event")
        logger.log(category: .breeding, level: .info, message: "breeding event")
        logger.log(category: .behavior, level: .info, message: "another behavior")
        logger.flush()

        let behaviorEvents = await logger.query(category: .behavior)
        #expect(behaviorEvents.count == 2)
        #expect(behaviorEvents.allSatisfy { $0.category == .behavior })

        let breedingEvents = await logger.query(category: .breeding)
        #expect(breedingEvents.count == 1)
    }

    @Test("Query by level returns events at or above threshold")
    func queryByLevel() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(category: .simulation, level: .verbose, message: "verbose event")
        logger.log(category: .simulation, level: .info, message: "info event")
        logger.log(category: .simulation, level: .warning, message: "warning event")
        logger.flush()

        let infoAndAbove = await logger.query(level: .info)
        #expect(infoAndAbove.count == 2)

        let warningOnly = await logger.query(level: .warning)
        #expect(warningOnly.count == 1)
    }

    @Test("Query by pigId returns only events for that pig")
    func queryByPigId() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        let pigA = UUID()
        let pigB = UUID()
        logger.log(category: .behavior, level: .info, message: "pig A moved", pigId: pigA, pigName: "Albert")
        logger.log(category: .behavior, level: .info, message: "pig B moved", pigId: pigB, pigName: "Betty")
        logger.log(category: .behavior, level: .info, message: "pig A ate", pigId: pigA, pigName: "Albert")
        logger.flush()

        let pigAEvents = await logger.query(pigId: pigA)
        #expect(pigAEvents.count == 2)
        #expect(pigAEvents.allSatisfy { $0.pigId == pigA })
    }

    @Test("Query with limit truncates results")
    func queryWithLimit() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        for i in 0..<10 {
            logger.log(category: .simulation, level: .info, message: "event \(i)")
        }
        logger.flush()

        let limited = await logger.query(limit: 3)
        #expect(limited.count == 3)
    }

    @Test("Query by game day range returns matching events")
    func queryByGameDay() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.setGameDay(1)
        logger.log(category: .simulation, level: .info, message: "day 1 event")
        logger.setGameDay(2)
        logger.log(category: .simulation, level: .info, message: "day 2 event")
        logger.setGameDay(3)
        logger.log(category: .simulation, level: .info, message: "day 3 event")
        logger.flush()

        let day2Only = await logger.query(sinceGameDay: 2, untilGameDay: 2)
        #expect(day2Only.count == 1)
        #expect(day2Only[0].gameDay == 2)
    }

    // MARK: - Level Gating

    @Test("Events below minimumLevel are discarded at log site")
    func levelGating() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.minimumLevel = .info
        logger.log(category: .simulation, level: .verbose, message: "should be dropped")
        logger.log(category: .simulation, level: .info, message: "should be kept")
        logger.flush()

        let events = await logger.query()
        #expect(events.count == 1)
        #expect(events[0].message == "should be kept")

        // Reset for other tests
        logger.minimumLevel = .verbose
    }

    // MARK: - Log Rotation

    @Test("Rotation deletes oldest events when exceeding maxRows")
    func logRotation() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.maxRows = 50
        for i in 0..<100 {
            logger.log(category: .simulation, level: .info, message: "event \(i)")
        }
        logger.flush()

        // Allow rotation to complete
        try? await Task.sleep(for: .milliseconds(200))

        let events = await logger.query(limit: 200)
        #expect(events.count <= 50)
        // Most recent events should be kept (highest IDs)
        if let first = events.first {
            #expect(first.message.contains("99") || first.message.contains("98"))
        }

        // Reset for other tests
        logger.maxRows = 50_000
    }

    // MARK: - Categories

    @Test("Categories returns correct counts per category")
    func categoriesQuery() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(category: .behavior, level: .info, message: "b1")
        logger.log(category: .behavior, level: .info, message: "b2")
        logger.log(category: .behavior, level: .info, message: "b3")
        logger.log(category: .breeding, level: .info, message: "br1")
        logger.log(category: .birth, level: .info, message: "bi1")
        logger.flush()

        let cats = await logger.categories()
        let behaviorCount = cats.first { $0.category == "behavior" }?.count
        let breedingCount = cats.first { $0.category == "breeding" }?.count
        #expect(behaviorCount == 3)
        #expect(breedingCount == 1)
    }

    // MARK: - Export

    @Test("Export JSON returns all events as valid JSON")
    func exportJSON() async throws {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(category: .economy, level: .info, message: "sold pig", payload: ["value": "150"])
        logger.flush()

        let data = await logger.exportJSON()
        let decoded = try JSONDecoder().decode([DebugEvent].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].category == .economy)
    }

    // MARK: - Persistence

    @Test("Data persists across close and reopen")
    func persistenceAcrossReopen() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DebugLoggerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let logger = DebugLogger.shared
        logger.close()  // Close app-bootstrapped instance first
        logger.open(baseURL: dir)
        logger.log(category: .simulation, level: .info, message: "persisted event")
        logger.flush()
        logger.close()

        // Reopen same database
        logger.open(baseURL: dir)
        let events = await logger.query()
        #expect(events.count >= 1)
        #expect(events.contains { $0.message == "persisted event" })
        logger.close()
    }

    // MARK: - Edge Cases

    @Test("Query on empty database returns empty array")
    func emptyDatabaseQuery() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        let events = await logger.query()
        #expect(events.isEmpty)
    }

    @Test("Payload with special characters serializes correctly")
    func specialCharacterPayload() async {
        let (logger, dir) = makeLogger()
        defer { cleanup(logger, dir: dir) }

        logger.log(
            category: .breeding, level: .info,
            message: "test \"quotes\" and 'apostrophes'",
            payload: ["name": "Bär 🐻", "note": "it's a \"test\""]
        )
        logger.flush()

        let events = await logger.query()
        #expect(events.count == 1)
        #expect(events[0].message.contains("quotes"))
        if let payload = events[0].payload {
            #expect(payload.contains("Bär"))
        }
    }

    // MARK: - DebugCategory Mapping

    @Test("DebugCategory.from maps eventType strings correctly")
    func categoryFromEventType() {
        #expect(DebugCategory.from(eventType: "birth") == .birth)
        #expect(DebugCategory.from(eventType: "mutation") == .birth)
        #expect(DebugCategory.from(eventType: "breeding") == .breeding)
        #expect(DebugCategory.from(eventType: "death") == .culling)
        #expect(DebugCategory.from(eventType: "sale") == .economy)
        #expect(DebugCategory.from(eventType: "purchase") == .economy)
        #expect(DebugCategory.from(eventType: "info") == .simulation)
        #expect(DebugCategory.from(eventType: "unknown_type") == .simulation)
    }

    // MARK: - DebugLevel Comparison

    @Test("DebugLevel comparison works correctly")
    func levelComparison() {
        #expect(DebugLevel.verbose < .info)
        #expect(DebugLevel.info < .warning)
        #expect(DebugLevel.warning >= .info)
        #expect(DebugLevel.verbose < .warning)
    }
}
