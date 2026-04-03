/// iCloudBackupManager — One-way iCloud backup with manual restore.
///
/// Local save is always primary. Cloud copy is recovery-only.
/// Reuses the same iCloud container as DebugLogger+iCloud
/// (iCloud.com.nadilbourkadi.bigpigfarm).
///
/// Maps from: N/A (new for mobile)
import Foundation

// MARK: - iCloudBackupManager

struct iCloudBackupManager: @unchecked Sendable {
    static let containerIdentifier = "iCloud.com.nadilbourkadi.bigpigfarm"
    static let backupDirectoryName = "SaveBackup"

    let containerURL: URL?
    let saveManager: SaveManager
    let defaults: UserDefaults

    var isAvailable: Bool { containerURL != nil }

    // MARK: - Container Resolution

    /// Resolve the ubiquity container URL on a background thread.
    /// Must be called early at app launch — blocks while iOS sets up
    /// the local container directory.
    static func resolveContainerURL() async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let url = FileManager.default.url(
                    forUbiquityContainerIdentifier: containerIdentifier
                )
                continuation.resume(returning: url)
            }
        }
    }

    // MARK: - Backup

    /// Copy local save files to the iCloud ubiquity container.
    /// Fire-and-forget — errors are logged, not thrown.
    func backupToCloud() {
        guard let containerURL else { return }
        let backupDir = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent(Self.backupDirectoryName)
        let fm = FileManager.default
        let saveSource = saveManager.saveFileURL
        let prestigeSource = saveManager.prestigeFileURL

        DispatchQueue.global(qos: .utility).async {
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            } catch {
                print("[iCloudBackup] Failed to create backup directory: \(error)")
                return
            }

            Self.copyFile(
                from: saveSource,
                to: backupDir.appendingPathComponent(SaveManager.saveFileName),
                label: "save"
            )
            Self.copyFile(
                from: prestigeSource,
                to: backupDir.appendingPathComponent(SaveManager.prestigeFileName),
                label: "prestige"
            )

            var state = iCloudBackupState.load(from: defaults)
            state.lastBackupDate = Date()
            state.save(to: defaults)
        }
    }

    // MARK: - Restore

    /// Whether a cloud backup exists that can be restored.
    func hasCloudBackup() -> Bool {
        guard let backupDir else { return false }
        return FileManager.default.fileExists(
            atPath: backupDir.appendingPathComponent(SaveManager.saveFileName).path
        )
    }

    /// Read the cloud backup's modification date.
    func cloudBackupDate() -> Date? {
        guard let backupDir else { return nil }
        let cloudSave = backupDir.appendingPathComponent(SaveManager.saveFileName)
        let attrs = try? FileManager.default.attributesOfItem(atPath: cloudSave.path)
        return attrs?[.modificationDate] as? Date
    }

    /// Copy the cloud save to the local save location, replacing the local save.
    /// Returns true on success. The caller is responsible for reloading GameState.
    func restoreFromCloud() throws -> Bool {
        guard let backupDir else { return false }
        let fm = FileManager.default
        let cloudSave = backupDir.appendingPathComponent(SaveManager.saveFileName)
        guard fm.fileExists(atPath: cloudSave.path) else { return false }

        try? fm.removeItem(at: saveManager.saveFileURL)
        try fm.copyItem(at: cloudSave, to: saveManager.saveFileURL)

        let cloudPrestige = backupDir.appendingPathComponent(SaveManager.prestigeFileName)
        if fm.fileExists(atPath: cloudPrestige.path) {
            try? fm.removeItem(at: saveManager.prestigeFileURL)
            try fm.copyItem(at: cloudPrestige, to: saveManager.prestigeFileURL)
        }

        return true
    }
}

// MARK: - Private Helpers

private extension iCloudBackupManager {
    var backupDir: URL? {
        containerURL?
            .appendingPathComponent("Documents")
            .appendingPathComponent(Self.backupDirectoryName)
    }

    static func copyFile(from source: URL, to destination: URL, label: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        do {
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
        } catch {
            print("[iCloudBackup] Failed to copy \(label): \(error)")
        }
    }
}
