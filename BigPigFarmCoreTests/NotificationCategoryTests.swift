/// Tests for NotificationCategory, NotificationPreset, and NotificationPreferences.
import Testing
@testable import BigPigFarmCore
import Foundation

// MARK: - NotificationCategory Tests

@Test func categoryCountIs8() {
    #expect(NotificationCategory.allCases.count == 8)
}

@Test func allCategoriesHaveIconNames() {
    for category in NotificationCategory.allCases {
        #expect(!category.iconName.isEmpty)
    }
}

@Test func allCategoriesHaveDisplayNames() {
    for category in NotificationCategory.allCases {
        #expect(!category.displayName.isEmpty)
    }
}

@Test func allCategoriesHaveImportanceTiers() {
    for category in NotificationCategory.allCases {
        #expect((1...3).contains(category.defaultImportance))
    }
}

// MARK: - Event Type Mapping

@Test func eventTypeMappingBirth() {
    #expect(NotificationCategory.from(eventType: "birth") == .births)
}

@Test func eventTypeMappingDeath() {
    #expect(NotificationCategory.from(eventType: "death") == .deaths)
}

@Test func eventTypeMappingSale() {
    #expect(NotificationCategory.from(eventType: "sale") == .sales)
}

@Test func eventTypeMappingBreeding() {
    #expect(NotificationCategory.from(eventType: "breeding") == .breeding)
}

@Test func eventTypeMappingFilter() {
    #expect(NotificationCategory.from(eventType: "filter") == .breeding)
}

@Test func eventTypeMappingPigdex() {
    #expect(NotificationCategory.from(eventType: "pigdex") == .discoveries)
}

@Test func eventTypeMappingMutation() {
    #expect(NotificationCategory.from(eventType: "mutation") == .discoveries)
}

@Test func eventTypeMappingPurchase() {
    #expect(NotificationCategory.from(eventType: "purchase") == .purchases)
}

@Test func eventTypeMappingAdoption() {
    #expect(NotificationCategory.from(eventType: "adoption") == .purchases)
}

@Test func eventTypeMappingContract() {
    #expect(NotificationCategory.from(eventType: "contract") == .contracts)
}

@Test func eventTypeMappingInfo() {
    #expect(NotificationCategory.from(eventType: "info") == .system)
}

@Test func eventTypeMappingFarmBell() {
    #expect(NotificationCategory.from(eventType: "farm_bell") == .system)
}

@Test func eventTypeMappingAcclimation() {
    #expect(NotificationCategory.from(eventType: "acclimation") == .system)
}

@Test func eventTypeMappingUnknownFallsBackToSystem() {
    #expect(NotificationCategory.from(eventType: "nonexistent") == .system)
    #expect(NotificationCategory.from(eventType: "") == .system)
}

// MARK: - NotificationPreset Tests

@Test func minimalPresetEnablesDeathsAndSystem() {
    let enabled = NotificationPreset.minimal.enabledCategories
    #expect(enabled == [.deaths, .system])
}

@Test func standardPresetEnables5Categories() {
    let enabled = NotificationPreset.standard.enabledCategories
    #expect(enabled == [.births, .deaths, .sales, .contracts, .system])
}

@Test func detailedPresetEnables7Categories() {
    let enabled = NotificationPreset.detailed.enabledCategories
    #expect(enabled == [.births, .deaths, .sales, .contracts, .system,
                        .breeding, .discoveries])
    #expect(!enabled.contains(.purchases))
}

@Test func allPresetEnablesEverything() {
    let enabled = NotificationPreset.all.enabledCategories
    #expect(enabled == Set(NotificationCategory.allCases))
}

@Test func standardIsSupersetOfMinimal() {
    #expect(NotificationPreset.standard.enabledCategories
        .isSuperset(of: NotificationPreset.minimal.enabledCategories))
}

@Test func detailedIsSupersetOfStandard() {
    #expect(NotificationPreset.detailed.enabledCategories
        .isSuperset(of: NotificationPreset.standard.enabledCategories))
}

@Test func allIsSupersetOfDetailed() {
    #expect(NotificationPreset.all.enabledCategories
        .isSuperset(of: NotificationPreset.detailed.enabledCategories))
}

@Test func allPresetsHaveDisplayNames() {
    for preset in NotificationPreset.allCases {
        #expect(!preset.displayName.isEmpty)
    }
}

@Test func allPresetsHaveSummaries() {
    for preset in NotificationPreset.allCases {
        #expect(!preset.summary.isEmpty)
    }
}

@Test func matchingDetectsKnownPresets() {
    for preset in NotificationPreset.allCases {
        let prefs = NotificationPreferences.from(preset: preset)
        #expect(NotificationPreset.matching(categoryEnabled: prefs.categoryEnabled) == preset)
    }
}

@Test func matchingEmptyDictMatchesAllPreset() {
    // Missing keys default to true, so empty == all enabled
    #expect(NotificationPreset.matching(categoryEnabled: [:]) == .all)
}

@Test func matchingReturnsNilForCustomConfig() {
    // Enable only births — matches no preset
    var toggles: [NotificationCategory: Bool] = [:]
    for category in NotificationCategory.allCases {
        toggles[category] = (category == .births)
    }
    #expect(NotificationPreset.matching(categoryEnabled: toggles) == nil)
}

// MARK: - NotificationPreferences Tests

@Test func isEnabledDefaultsToTrueForMissingKey() {
    let prefs = NotificationPreferences(categoryEnabled: [:])
    for category in NotificationCategory.allCases {
        #expect(prefs.isEnabled(category))
    }
}

@Test func setEnabledTogglesCategory() {
    var prefs = NotificationPreferences.from(preset: .all)
    #expect(prefs.isEnabled(.births))
    prefs.setEnabled(.births, enabled: false)
    #expect(!prefs.isEnabled(.births))
    prefs.setEnabled(.births, enabled: true)
    #expect(prefs.isEnabled(.births))
}

@Test func applyPresetOverwritesAllToggles() {
    var prefs = NotificationPreferences.from(preset: .all)
    prefs.apply(preset: .minimal)
    #expect(prefs.isEnabled(.deaths))
    #expect(prefs.isEnabled(.system))
    #expect(!prefs.isEnabled(.births))
    #expect(!prefs.isEnabled(.sales))
    #expect(!prefs.isEnabled(.breeding))
    #expect(!prefs.isEnabled(.discoveries))
    #expect(!prefs.isEnabled(.purchases))
    #expect(!prefs.isEnabled(.contracts))
}

@Test func customToggleAfterPreset() {
    var prefs = NotificationPreferences.from(preset: .standard)
    #expect(prefs.activePreset == .standard)
    prefs.setEnabled(.breeding, enabled: true)
    // No longer matches standard (which doesn't include breeding)
    #expect(prefs.activePreset != .standard)
}

@Test func activePresetDetection() {
    let prefs = NotificationPreferences.from(preset: .minimal)
    #expect(prefs.activePreset == .minimal)
}

@Test func activePresetNilForCustom() {
    var prefs = NotificationPreferences.from(preset: .standard)
    prefs.setEnabled(.breeding, enabled: true)
    prefs.setEnabled(.contracts, enabled: false)
    #expect(prefs.activePreset == nil)
}

@Test func fromPresetCreatesCorrectToggles() {
    let prefs = NotificationPreferences.from(preset: .standard)
    let standardCategories: Set<NotificationCategory> = [.births, .deaths, .sales, .contracts, .system]
    for category in NotificationCategory.allCases {
        #expect(prefs.isEnabled(category) == standardCategories.contains(category))
    }
}

// MARK: - UserDefaults Persistence

@Test func userDefaultsRoundTrip() throws {
    let suiteName = "NotificationCategoryTests.roundTrip"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }

    var original = NotificationPreferences.from(preset: .minimal)
    original.setEnabled(.births, enabled: true)
    original.save(to: suite)

    let loaded = NotificationPreferences.load(from: suite)
    #expect(loaded == original)
}

@Test func loadReturnsStandardWhenNoSavedData() throws {
    let suiteName = "NotificationCategoryTests.noData"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }

    let loaded = NotificationPreferences.load(from: suite)
    #expect(loaded == NotificationPreferences.from(preset: .standard))
}

@Test func loadReturnsStandardOnCorruptData() throws {
    let suiteName = "NotificationCategoryTests.corrupt"
    let suite = try #require(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }

    suite.set(Data("not-json".utf8), forKey: "notificationPreferences")
    let loaded = NotificationPreferences.load(from: suite)
    #expect(loaded == NotificationPreferences.from(preset: .standard))
}
