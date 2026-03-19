#if DEBUG || INTERNAL
/// DebugLoggerSQLite — SQLite helpers for DebugLogger background operations.
///
/// All methods are nonisolated and called from the serial flushQueue.
/// Separated from DebugLogger.swift for file length compliance.
import Foundation
import SQLite3

// MARK: - SQLiteHelpers

/// Static helpers for SQLite operations on the background queue.
/// Access is serialized by DebugLogger's serial flushQueue — no data races.
enum SQLiteHelpers {

    static func writeBatch(
        _ batch: [BufferedEvent],
        db: OpaquePointer,
        insertStatement: OpaquePointer?
    ) {
        guard let stmt = insertStatement else { return }
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        for event in batch {
            sqlite3_reset(stmt)
            sqlite3_bind_double(stmt, 1, event.timestamp.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 2, Int64(event.gameDay))
            bindText(stmt, index: 3, value: event.category.rawValue)
            sqlite3_bind_int64(stmt, 4, Int64(event.level.rawValue))
            bindText(stmt, index: 5, value: event.message)
            bindOptionalText(stmt, index: 6, value: event.pigId?.uuidString)
            bindOptionalText(stmt, index: 7, value: event.pigName)
            bindOptionalText(stmt, index: 8, value: event.payload)
            sqlite3_step(stmt)
        }
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    static func rotateIfNeeded(
        db: OpaquePointer,
        countStatement: OpaquePointer?,
        maxRows: Int
    ) {
        guard let stmt = countStatement else { return }
        sqlite3_reset(stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return }
        let count = Int(sqlite3_column_int64(stmt, 0))
        guard count > maxRows else { return }
        let deleteCount = count - maxRows
        let sql = """
            DELETE FROM debug_events WHERE id IN \
            (SELECT id FROM debug_events ORDER BY id ASC LIMIT \(deleteCount))
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    static func executeQuery(
        db: OpaquePointer,
        category: DebugCategory?,
        level: DebugLevel?,
        pigId: UUID?,
        sinceGameDay: Int?,
        untilGameDay: Int?,
        limit: Int,
        offset: Int
    ) -> [DebugEvent] {
        let (sql, bindings) = buildQuerySQL(
            category: category, level: level, pigId: pigId,
            sinceGameDay: sinceGameDay, untilGameDay: untilGameDay,
            limit: limit, offset: offset
        )
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }
        applyBindings(stmt: stmt, bindings: bindings)
        return readEvents(stmt: stmt)
    }

    static func queryCategories(
        db: OpaquePointer
    ) -> [(category: String, count: Int)] {
        var results: [(String, Int)] = []
        let sql = """
            SELECT category, COUNT(*) FROM debug_events \
            GROUP BY category ORDER BY COUNT(*) DESC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let catPtr = sqlite3_column_text(stmt, 0) {
                let cat = String(cString: catPtr)
                let count = Int(sqlite3_column_int64(stmt, 1))
                results.append((cat, count))
            }
        }
        return results
    }

    // MARK: - Query Building

    private static func buildQuerySQL(
        category: DebugCategory?,
        level: DebugLevel?,
        pigId: UUID?,
        sinceGameDay: Int?,
        untilGameDay: Int?,
        limit: Int,
        offset: Int
    ) -> (String, [(Int32, Any)]) {
        var conditions: [String] = []
        var bindings: [(Int32, Any)] = []
        var idx: Int32 = 1

        if let category {
            conditions.append("category = ?")
            bindings.append((idx, category.rawValue)); idx += 1
        }
        if let level {
            conditions.append("level >= ?")
            bindings.append((idx, level.rawValue)); idx += 1
        }
        if let pigId {
            conditions.append("pig_id = ?")
            bindings.append((idx, pigId.uuidString)); idx += 1
        }
        if let sinceGameDay {
            conditions.append("game_day >= ?")
            bindings.append((idx, sinceGameDay)); idx += 1
        }
        if let untilGameDay {
            conditions.append("game_day <= ?")
            bindings.append((idx, untilGameDay)); idx += 1
        }

        let columns = "id, timestamp, game_day, category, level, " +
            "message, pig_id, pig_name, payload"
        var sql = "SELECT \(columns) FROM debug_events"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY id DESC"
        if limit < Int.max { sql += " LIMIT \(limit)" }
        if offset > 0 { sql += " OFFSET \(offset)" }
        return (sql, bindings)
    }

    private static func applyBindings(
        stmt: OpaquePointer?,
        bindings: [(Int32, Any)]
    ) {
        guard let stmt else { return }
        for (index, value) in bindings {
            if let text = value as? String {
                bindText(stmt, index: index, value: text)
            } else if let intVal = value as? Int {
                sqlite3_bind_int64(stmt, index, Int64(intVal))
            }
        }
    }

    private static func readEvents(
        stmt: OpaquePointer?
    ) -> [DebugEvent] {
        var events: [DebugEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let event = DebugEvent(
                id: sqlite3_column_int64(stmt, 0),
                timestamp: Date(
                    timeIntervalSince1970: sqlite3_column_double(stmt, 1)
                ),
                gameDay: Int(sqlite3_column_int64(stmt, 2)),
                category: DebugCategory(
                    rawValue: columnText(stmt, 3)
                ) ?? .simulation,
                level: DebugLevel(
                    rawValue: Int(sqlite3_column_int(stmt, 4))
                ) ?? .info,
                message: columnText(stmt, 5),
                pigId: columnOptionalText(stmt, 6).flatMap {
                    UUID(uuidString: $0)
                },
                pigName: columnOptionalText(stmt, 7),
                payload: columnOptionalText(stmt, 8)
            )
            events.append(event)
        }
        return events
    }

    // MARK: - Text Helpers

    private static func bindText(
        _ stmt: OpaquePointer, index: Int32, value: String
    ) {
        sqlite3_bind_text(
            stmt, index, (value as NSString).utf8String, -1, nil
        )
    }

    private static func bindOptionalText(
        _ stmt: OpaquePointer, index: Int32, value: String?
    ) {
        if let value {
            bindText(stmt, index: index, value: value)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static func columnText(
        _ stmt: OpaquePointer?, _ index: Int32
    ) -> String {
        if let ptr = sqlite3_column_text(stmt, index) {
            return String(cString: ptr)
        }
        return ""
    }

    private static func columnOptionalText(
        _ stmt: OpaquePointer?, _ index: Int32
    ) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
              let ptr = sqlite3_column_text(stmt, index) else {
            return nil
        }
        return String(cString: ptr)
    }
}
#endif
