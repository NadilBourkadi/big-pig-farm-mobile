/// NotificationSettingsView — Preset picker and per-category notification toggles.
///
/// Manages which notification categories show toast notifications.
/// Changes save immediately to UserDefaults via NotificationPreferences.
import SwiftUI

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    /// App-wide notification preferences (not per-save). Uses UserDefaults.standard.
    @State private var preferences = NotificationPreferences.load()

    var body: some View {
        Form {
            pushNotificationsSection
            presetSection
            categoriesSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sections

extension NotificationSettingsView {
    private var pushNotificationsSection: some View {
        Section {
            Toggle(isOn: pushNotificationsBinding) {
                Label {
                    Text("Push Notifications")
                } icon: {
                    Image(systemName: "app.badge")
                        .foregroundStyle(.blue)
                }
            }

            Text("Receive notifications for births, low supplies, and contract deadlines when the app is closed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Push Notifications")
        }
    }

    private var presetSection: some View {
        Section {
            Picker("Preset", selection: presetPickerBinding) {
                ForEach(NotificationPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(Optional(preset))
                }
            }
            .pickerStyle(.segmented)

            Text(presetCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Preset")
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach(NotificationCategory.allCases, id: \.self) { category in
                categoryRow(category)
            }
        } header: {
            Text("Categories")
        }
    }
}

// MARK: - Row + Bindings

extension NotificationSettingsView {
    private func categoryRow(_ category: NotificationCategory) -> some View {
        Toggle(isOn: categoryBinding(for: category)) {
            Label {
                Text(category.displayName)
            } icon: {
                Image(systemName: category.iconName)
                    .foregroundStyle(category.color)
            }
        }
    }

    private func categoryBinding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { preferences.isEnabled(category) },
            set: { enabled in
                preferences.setEnabled(category, enabled: enabled)
                preferences.save()
            }
        )
    }

    private var pushNotificationsBinding: Binding<Bool> {
        Binding(
            get: { preferences.pushNotificationsEnabled },
            set: { enabled in
                preferences.pushNotificationsEnabled = enabled
                preferences.save()
            }
        )
    }

    private var presetPickerBinding: Binding<NotificationPreset?> {
        Binding(
            get: { preferences.activePreset },
            set: { newPreset in
                // Always non-nil — ForEach only tags non-nil presets.
                if let preset = newPreset {
                    preferences.apply(preset: preset)
                    preferences.save()
                }
            }
        )
    }

    private var presetCaption: String {
        if let preset = preferences.activePreset {
            return preset.summary
        }
        return "Custom configuration"
    }
}
