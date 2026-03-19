#if DEBUG || INTERNAL
/// DebugLogger+iCloud — iCloud Drive sync for offline debug log access.
///
/// Copies the SQLite database to the app's iCloud ubiquity container so
/// agents on the Mac can query it without the app running or the phone
/// being on the same network.
import Foundation
import SQLite3

extension DebugLogger {
    /// Checkpoint the WAL and copy the database to iCloud Drive.
    /// Called on background transition and periodic auto-save.
    func syncToiCloud() {
        guard isOpen, let db else { return }
        // Checkpoint WAL to merge pending writes into the main file
        sqlite3_wal_checkpoint_v2(
            db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil
        )
        guard let dbPath = databasePath else { return }
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier:
                "iCloud.com.nadilbourkadi.bigpigfarm"
        ) else {
            return  // iCloud not available
        }
        let cloudDir = containerURL.appendingPathComponent("Documents")
        let cloudFile = cloudDir.appendingPathComponent("debug.sqlite")
        let fm = FileManager.default
        try? fm.createDirectory(
            at: cloudDir, withIntermediateDirectories: true
        )
        let sourceURL = URL(fileURLWithPath: dbPath)
        try? fm.removeItem(at: cloudFile)
        try? fm.copyItem(at: sourceURL, to: cloudFile)
    }
}
#endif
