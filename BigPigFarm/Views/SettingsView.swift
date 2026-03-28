/// SettingsView — App settings with notification preferences and farm reset.
/// In Debug/Internal builds, includes a debug section for testing.
import SwiftUI

// MARK: - SettingsView

/// Settings screen accessible from AlmanacView's gear button.
/// Contains notification settings (via NavigationLink) and a destructive
/// farm reset option with two-step confirmation.
struct SettingsView: View {
    let gameState: GameState
    let onResetFarm: () -> Void
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
