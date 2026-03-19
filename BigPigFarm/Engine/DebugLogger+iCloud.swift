#if DEBUG || INTERNAL
/// DebugLogger+iCloud — iCloud Drive sync for offline debug log access.
///
/// Copies the SQLite database to the app's iCloud ubiquity container so
/// agents on the Mac can query it without the app running or the phone
/// being on the same network.
import Foundation
import SQLite3

extension DebugLogger {
    /// Initialize the iCloud container on a background thread.
    /// Must be called early at app launch — Apple requires this to set up
    /// the local container directory. The resolved URL is cached for later
    /// use by syncToiCloud().
    func initializeiCloudContainer() {
        DispatchQueue.global(qos: .utility).async {
            let url = FileManager.default.url(
                forUbiquityContainerIdentifier:
                    "iCloud.com.nadilbourkadi.bigpigfarm"
            )
            Task { @MainActor in
                self.iCloudContainerURL = url
                if url != nil {
                    print("[DebugLogger] iCloud container ready")
                } else {
                    print("[DebugLogger] iCloud unavailable")
                }
            }
        }
    }

    /// Checkpoint the WAL and copy the database to iCloud Drive.
    /// Called on background transition and periodic auto-save.
    func syncToiCloud() {
        guard isOpen, let db else { return }
        guard let containerURL = iCloudContainerURL else { return }
        // Checkpoint WAL to merge pending writes into the main file
        sqlite3_wal_checkpoint_v2(
            db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil
        )
        guard let dbPath = databasePath else { return }
        let cloudDir = containerURL.appendingPathComponent("Documents")
        let cloudFile = cloudDir.appendingPathComponent("debug.sqlite")
        let sourceURL = URL(fileURLWithPath: dbPath)
        // Copy on a background thread to avoid blocking the main thread
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            try? fm.createDirectory(
                at: cloudDir, withIntermediateDirectories: true
            )
            try? fm.removeItem(at: cloudFile)
            try? fm.copyItem(at: sourceURL, to: cloudFile)
        }
    }
}
#endif
