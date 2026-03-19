/// DebugLogger — Structured queryable debug logging with SQLite storage.
///
/// Buffers events in memory on @MainActor, flushes to SQLite on a background
/// serial queue every ~1 second. The simulation thread never touches the disk.
///
/// Query via the async query() method or through the DebugServer HTTP interface.
import Foundation
import SQLite3

// MARK: - DebugLevel

/// Severity level for debug events. Comparable for threshold filtering.
enum DebugLevel: Int, Codable, Sendable, Comparable, CaseIterable {
    case verbose = 0  // High-frequency sampled data (position, needs snapshots)
    case info = 1     // State transitions, decisions, significant events
    case warning = 2  // Anomalies, fallback paths, unexpected conditions

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .verbose: "verbose"
        case .info: "info"
        case .warning: "warning"
        }
    }
}

// MARK: - DebugCategory

/// Event categories matching simulation subsystems.
enum DebugCategory: String, Codable, Sendable, CaseIterable {
    case behavior
    case breeding
    case birth
    case needs
    case culling
    case economy
    case simulation
    case facility

    /// Map existing GameState eventType strings to debug categories.
    static func from(eventType: String) -> Self {
        switch eventType {
        case "birth", "mutation": .birth
        case "breeding", "filter": .breeding
        case "death": .culling
        case "sale", "purchase", "contract", "adoption": .economy
        case "acclimation", "farm_bell", "pigdex", "info": .simulation
        default: .simulation
        }
    }
}

// MARK: - DebugEvent

/// A single structured debug log entry.
struct DebugEvent: Codable, Sendable {
    let id: Int64
    let timestamp: Date
    let gameDay: Int
    let category: DebugCategory
    let level: DebugLevel
    let message: String
    let pigId: UUID?
    let pigName: String?
    let payload: String?  // JSON-encoded key-value pairs
}

// MARK: - BufferedEvent

/// In-memory event before SQLite insertion (no row ID yet).
struct BufferedEvent: Sendable {
    let timestamp: Date
    let gameDay: Int
    let category: DebugCategory
    let level: DebugLevel
    let message: String
    let pigId: UUID?
    let pigName: String?
    let payload: String?
}

// MARK: - DebugLogger

/// Singleton structured debug logger.
///
/// `log()` is called from @MainActor simulation code — appends to an in-memory
/// array with zero I/O. A background DispatchQueue flushes the buffer to SQLite
/// in a single transaction every ~1 second.
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    // MARK: - Configuration

    /// Minimum level to record. Events below this are discarded at the call site.
    var minimumLevel: DebugLevel = .verbose

    /// Maximum number of rows before rotation deletes the oldest events.
    var maxRows: Int = 50_000

    // MARK: - State

    private var buffer: [BufferedEvent] = []
    private var db: OpaquePointer?
    private let flushQueue = DispatchQueue(
        label: "com.bigpigfarm.debuglogger", qos: .utility
    )
    private var flushTimer: Timer?
    private(set) var isOpen = false
    private var currentGameDay: Int = 0

    // Pre-compiled statements
    private var insertStatement: OpaquePointer?
    private var countStatement: OpaquePointer?

    private init() {}

    // MARK: - Lifecycle

    /// Open the SQLite database in the documents directory.
    func open(baseURL: URL? = nil) {
        guard !isOpen else { return }
        let dirURL = baseURL ?? FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let dbURL = dirURL.appendingPathComponent("debug.sqlite")
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
            print("[DebugLogger] Failed to open database")
            return
        }
        isOpen = true
        configurePragmas()
        createTable()
        prepareStatements()
        startFlushTimer()
    }

    /// Flush any remaining events and close the database.
    func close() {
        guard isOpen else { return }
        flushTimer?.invalidate()
        flushTimer = nil
        flushSync()
        finalizeStatements()
        sqlite3_close(db)
        db = nil
        isOpen = false
    }

    // MARK: - Logging

    /// Log a debug event. Fast path: appends to in-memory buffer only.
    func log(
        category: DebugCategory,
        level: DebugLevel,
        message: String,
        pigId: UUID? = nil,
        pigName: String? = nil,
        payload: [String: String]? = nil
    ) {
        guard isOpen, level >= minimumLevel else { return }
        let payloadJSON: String?
        if let payload, !payload.isEmpty {
            payloadJSON = encodePayload(payload)
        } else {
            payloadJSON = nil
        }
        buffer.append(BufferedEvent(
            timestamp: Date(),
            gameDay: currentGameDay,
            category: category,
            level: level,
            message: message,
            pigId: pigId,
            pigName: pigName,
            payload: payloadJSON
        ))
    }

    /// Update the current game day (called each tick).
    func setGameDay(_ day: Int) {
        currentGameDay = day
    }

    /// Force an immediate synchronous flush of the buffer to SQLite.
    func flush() {
        flushSync()
    }

    /// Path to the SQLite database file, for direct access or export.
    var databasePath: String? {
        guard isOpen, let db else { return nil }
        return String(cString: sqlite3_db_filename(db, nil))
    }
}

// MARK: - Querying

extension DebugLogger {
    /// Query events with optional filters.
    func query(
        category: DebugCategory? = nil,
        level: DebugLevel? = nil,
        pigId: UUID? = nil,
        sinceGameDay: Int? = nil,
        untilGameDay: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async -> [DebugEvent] {
        guard isOpen, let db else { return [] }
        nonisolated(unsafe) let safeDB = db
        return await withCheckedContinuation { cont in
            flushQueue.async {
                let events = SQLiteHelpers.executeQuery(
                    db: safeDB,
                    category: category, level: level,
                    pigId: pigId,
                    sinceGameDay: sinceGameDay,
                    untilGameDay: untilGameDay,
                    limit: limit, offset: offset
                )
                cont.resume(returning: events)
            }
        }
    }

    /// Count of events per category.
    func categories() async -> [(category: String, count: Int)] {
        guard isOpen, let db else { return [] }
        nonisolated(unsafe) let safeDB = db
        return await withCheckedContinuation { cont in
            flushQueue.async {
                let results = SQLiteHelpers.queryCategories(db: safeDB)
                cont.resume(returning: results)
            }
        }
    }

    /// Export all events as JSON data.
    func exportJSON() async -> Data {
        guard isOpen, let db else { return Data("[]".utf8) }
        nonisolated(unsafe) let safeDB = db
        return await withCheckedContinuation { cont in
            flushQueue.async {
                let events = SQLiteHelpers.executeQuery(
                    db: safeDB,
                    category: nil, level: nil, pigId: nil,
                    sinceGameDay: nil, untilGameDay: nil,
                    limit: Int.max, offset: 0
                )
                let encoder = JSONEncoder()
                let data = (try? encoder.encode(events)) ?? Data("[]".utf8)
                cont.resume(returning: data)
            }
        }
    }
}

// MARK: - Private — Setup & Flush

extension DebugLogger {
    private func configurePragmas() {
        execute("PRAGMA journal_mode = WAL")
        execute("PRAGMA synchronous = NORMAL")
    }

    private func createTable() {
        execute("""
            CREATE TABLE IF NOT EXISTS debug_events (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp   REAL    NOT NULL,
                game_day    INTEGER NOT NULL,
                category    TEXT    NOT NULL,
                level       INTEGER NOT NULL,
                message     TEXT    NOT NULL,
                pig_id      TEXT,
                pig_name    TEXT,
                payload     TEXT
            )
        """)
        execute("""
            CREATE INDEX IF NOT EXISTS idx_events_category_level \
            ON debug_events (category, level)
        """)
        execute("""
            CREATE INDEX IF NOT EXISTS idx_events_pig_id \
            ON debug_events (pig_id) WHERE pig_id IS NOT NULL
        """)
        execute("""
            CREATE INDEX IF NOT EXISTS idx_events_timestamp \
            ON debug_events (timestamp)
        """)
        execute("""
            CREATE INDEX IF NOT EXISTS idx_events_game_day \
            ON debug_events (game_day)
        """)
    }

    private func prepareStatements() {
        let insertSQL = """
            INSERT INTO debug_events \
            (timestamp, game_day, category, level, message, pig_id, pig_name, payload) \
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil)
        let countSQL = "SELECT COUNT(*) FROM debug_events"
        sqlite3_prepare_v2(db, countSQL, -1, &countStatement, nil)
    }

    private func finalizeStatements() {
        if let stmt = insertStatement { sqlite3_finalize(stmt) }
        if let stmt = countStatement { sqlite3_finalize(stmt) }
        insertStatement = nil
        countStatement = nil
    }

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.flushSync() }
        }
    }

    private func flushSync() {
        guard !buffer.isEmpty, let db else { return }
        let batch = buffer
        buffer.removeAll(keepingCapacity: true)
        let insertStmt = insertStatement
        let countStmt = countStatement
        let maxRows = maxRows
        nonisolated(unsafe) let safeDB = db
        nonisolated(unsafe) let safeInsert = insertStmt
        nonisolated(unsafe) let safeCount = countStmt
        flushQueue.async {
            SQLiteHelpers.writeBatch(
                batch, db: safeDB, insertStatement: safeInsert
            )
            SQLiteHelpers.rotateIfNeeded(
                db: safeDB, countStatement: safeCount, maxRows: maxRows
            )
        }
    }

    private func execute(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func encodePayload(_ dict: [String: String]) -> String? {
        guard let data = try? JSONEncoder().encode(dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
