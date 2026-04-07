/// SettingsView — App settings with notification preferences, iCloud backup, and farm reset.
/// In Debug/Internal builds, includes a debug section for testing.
import SwiftUI

// MARK: - SettingsView

/// Settings screen accessible from AlmanacView's gear button.
/// Contains notification settings (via NavigationLink), iCloud backup/restore,
/// and a destructive farm reset option with two-step confirmation.
struct SettingsView: View {
    let gameState: GameState
    let onResetFarm: () -> Void
    let backupManager: iCloudBackupManager?
    let onRestoreFromCloud: () -> Void
    @State private var showResetConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var restoreError: String?
    @State private var backupState = iCloudBackupState.load()
    /// SettingsView is the only writer for AudioSettings, so a one-shot
    /// load at view init is sufficient — no .onAppear refresh needed.
    @State private var audioSettings = AudioSettings.load()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                soundSection

                iCloudBackupSection

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Farm", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently delete all progress and start a new farm.")
                }

                #if DEBUG || INTERNAL
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset Farm?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    dismiss()
                    onResetFarm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This will permanently delete all progress including pigs, money, " +
                    "Pigdex discoveries, and contracts. This cannot be undone."
                )
            }
            .confirmationDialog(
                "Restore from iCloud?",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    performRestore()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let date = backupManager?.cloudBackupDate() {
                    Text(
                        "This will replace your current farm with the cloud backup from " +
                        "\(date.formatted(date: .abbreviated, time: .shortened)). " +
                        "This cannot be undone."
                    )
                } else {
                    Text(
                        "This will replace your current farm with the cloud backup. " +
                        "This cannot be undone."
                    )
                }
            }
            .alert("Restore Failed", isPresented: .init(
                get: { restoreError != nil },
                set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK") { restoreError = nil }
            } message: {
                if let error = restoreError {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Sound Section

private extension SettingsView {
    var soundSection: some View {
        Section {
            Toggle(isOn: soundEnabledBinding) {
                Label("Sound Effects", systemImage: "speaker.wave.2")
            }
        } header: {
            Text("Sound")
        }
    }

    var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { audioSettings.isEnabled },
            set: { newValue in
                audioSettings.isEnabled = newValue
                audioSettings.save()
                AudioManager.reloadSettings()
            }
        )
    }
}

// MARK: - iCloud Backup Section

private extension SettingsView {
    var iCloudBackupSection: some View {
        Section {
            if let manager = backupManager, manager.isAvailable {
                HStack {
                    Label("Last Backup", systemImage: "clock")
                    Spacer()
                    Text(lastBackupLabel)
                        .foregroundStyle(.secondary)
                }

                Button {
                    manager.backupToCloud()
                    backupState.lastBackupDate = Date()
                } label: {
                    Label("Back Up Now", systemImage: "icloud.and.arrow.up")
                }

                Button {
                    showRestoreConfirmation = true
                } label: {
                    Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(!manager.hasCloudBackup())
            } else {
                HStack {
                    Label("iCloud Backup", systemImage: "icloud.slash")
                    Spacer()
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("iCloud Backup")
        } footer: {
            if backupManager?.isAvailable == true {
                Text(
                    "Your farm is backed up to iCloud automatically. " +
                    "Use Restore to recover from a backup on this or another device."
                )
            } else {
                Text("Sign in to iCloud in Settings to enable cloud backup.")
            }
        }
    }

    var lastBackupLabel: String {
        guard let date = backupState.lastBackupDate else {
            return "Never"
        }
        return date.formatted(.relative(presentation: .named))
    }

    func performRestore() {
        guard let manager = backupManager else { return }
        do {
            let success = try manager.restoreFromCloud()
            if success {
                dismiss()
                onRestoreFromCloud()
            } else {
                restoreError = "No cloud backup found."
            }
        } catch {
            restoreError = error.localizedDescription
        }
    }
}

// MARK: - Debug Section

#if DEBUG || INTERNAL
private extension SettingsView {
    var debugSection: some View {
        Section {
            Button {
                gameState.remainingTreatsThisVisit = gameState.prestigeState.treatsPerVisit
            } label: {
                Label(
                    "Refill Treats (\(gameState.prestigeState.treatsPerVisit))",
                    systemImage: "leaf.fill"
                )
            }

            Button {
                gameState.addMoney(10_000)
            } label: {
                Label("Add 10,000 Squeaks", systemImage: "dollarsign.circle")
            }

            Stepper(value: Binding(
                get: { gameState.farmTier },
                set: { gameState.farmTier = $0 }
            ), in: 1...4) {
                Label("Farm Tier: \(gameState.farmTier)", systemImage: "star.fill")
            }

            Button {
                var state = CoachMarkState.load()
                state.resetAll()
                state.save()
            } label: {
                Label("Reset Coach Marks", systemImage: "lightbulb.slash")
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Internal build only. These controls are stripped from Release.")
        }
    }
}
#endif
