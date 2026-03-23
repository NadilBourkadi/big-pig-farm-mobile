/// SettingsView — App settings with notification preferences and farm reset.
import SwiftUI

// MARK: - SettingsView

/// Settings screen accessible from AlmanacView's gear button.
/// Contains notification settings (via NavigationLink) and a destructive
/// farm reset option with two-step confirmation.
struct SettingsView: View {
    var onResetFarm: () -> Void
    @State private var showResetConfirmation = false
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
                    onResetFarm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all progress including pigs, money, Pigdex discoveries, and contracts. This cannot be undone.")
            }
        }
    }
}
