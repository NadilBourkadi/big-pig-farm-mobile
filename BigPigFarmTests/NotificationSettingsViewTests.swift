/// Tests for NotificationSettingsView behavioral contracts.
///
/// These tests live in BigPigFarmTests (not BigPigFarmCoreTests) because they need
/// the SwiftUI-only NotificationCategory+Color extension from the app target.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Preset Selection

@Test func presetSelectionUpdatesAllToggles() {
    var prefs = NotificationPreferences.from(preset: .all)
    prefs.apply(preset: .minimal)
    for category in NotificationCategory.allCases {
        let expected = NotificationPreset.minimal.enabledCategories.contains(category)
        #expect(prefs.isEnabled(category) == expected,
                "\(category.displayName) should be \(expected) after minimal preset")
    }
}

// MARK: - Custom Detection

@Test func singleToggleChangeShowsCustom() {
    var prefs = NotificationPreferences.from(preset: .standard)
    #expect(prefs.activePreset == .standard)
    // .purchases is false in .standard; enabling it produces a non-matching state.
    prefs.setEnabled(.purchases, enabled: true)
    #expect(prefs.activePreset == nil)
}

@Test func manualTogglesMatchingPresetAutoSelects() {
    var prefs = NotificationPreferences(categoryEnabled: [:])
    for category in NotificationCategory.allCases {
        prefs.setEnabled(category, enabled: false)
    }
    prefs.setEnabled(.deaths, enabled: true)
    prefs.setEnabled(.system, enabled: true)
    #expect(prefs.activePreset == .minimal)
}

// MARK: - Color Extension Coverage

@Test func allCategoriesHaveColors() {
    for category in NotificationCategory.allCases {
        // Accessing .color verifies the SwiftUI extension covers all cases
        _ = category.color
    }
}

// MARK: - Write-Through Persistence

@Test func toggleWritesThroughToUserDefaults() throws {
    let suiteName = "NotificationSettingsViewTests.writeThrough"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }

    var prefs = NotificationPreferences.from(preset: .all)
    prefs.setEnabled(.births, enabled: false)
    prefs.save(to: suite)

    let reloaded = NotificationPreferences.load(from: suite)
    #expect(!reloaded.isEnabled(.births))
    #expect(reloaded.isEnabled(.deaths))
}

@Test func presetApplyWritesThroughToUserDefaults() throws {
    let suiteName = "NotificationSettingsViewTests.presetWriteThrough"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }

    var prefs = NotificationPreferences.from(preset: .all)
    prefs.apply(preset: .minimal)
    prefs.save(to: suite)

    let reloaded = NotificationPreferences.load(from: suite)
    #expect(reloaded.activePreset == .minimal)
    #expect(reloaded.isEnabled(.deaths))
    #expect(!reloaded.isEnabled(.births))
}
