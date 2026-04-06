/// Tests for NotificationCategory per-event-type display methods (icon/color).
///
/// Lives in BigPigFarmTests because icon(for:) and color(for:) return SwiftUI Color,
/// which requires the Xcode app target (not the SPM package).
import Testing
import SwiftUI
@testable import BigPigFarm

// MARK: - Per-Event-Type Icon Tests

@Test func iconBirthMatchesCategory() {
    #expect(NotificationCategory.icon(for: "birth") == "gift.fill")
}

@Test func iconDeathMatchesCategory() {
    #expect(NotificationCategory.icon(for: "death") == "heart.slash.fill")
}

@Test func iconSaleMatchesCategory() {
    #expect(NotificationCategory.icon(for: "sale") == "dollarsign.circle.fill")
}

@Test func iconPurchaseMatchesCategory() {
    #expect(NotificationCategory.icon(for: "purchase") == "cart.fill")
}

@Test func iconBreedingMatchesCategory() {
    #expect(NotificationCategory.icon(for: "breeding") == "heart.fill")
}

@Test func iconMutationMatchesCategory() {
    #expect(NotificationCategory.icon(for: "mutation") == "sparkles")
}

@Test func iconContractMatchesCategory() {
    #expect(NotificationCategory.icon(for: "contract") == "doc.text.fill")
}

@Test func iconPigdexOverridesCategory() {
    // Pigdex uses book.fill (collection/catalog), not discoveries' sparkles
    #expect(NotificationCategory.icon(for: "pigdex") == "book.fill")
    #expect(NotificationCategory.icon(for: "pigdex") != NotificationCategory.discoveries.iconName)
}

@Test func iconAdoptionOverridesCategory() {
    // Adoption uses heart.circle.fill, not purchases' cart.fill
    #expect(NotificationCategory.icon(for: "adoption") == "heart.circle.fill")
    #expect(NotificationCategory.icon(for: "adoption") != NotificationCategory.purchases.iconName)
}

@Test func iconFilterFallsBackToBreedingCategory() {
    #expect(NotificationCategory.icon(for: "filter") == "heart.fill")
}

@Test func iconMilestoneFallsBackToDiscoveriesCategory() {
    #expect(NotificationCategory.icon(for: "milestone") == "sparkles")
}

@Test func iconPrestigeFallsBackToSystemCategory() {
    #expect(NotificationCategory.icon(for: "prestige") == "bell.fill")
}

@Test func iconUnknownFallsBackToCategory() {
    #expect(NotificationCategory.icon(for: "nonexistent") == "bell.fill")
}

// MARK: - Per-Event-Type Color Tests

@Test func colorBirthMatchesCategory() {
    #expect(NotificationCategory.color(for: "birth") == .green)
}

@Test func colorDeathMatchesCategory() {
    #expect(NotificationCategory.color(for: "death") == .red)
}

@Test func colorSaleMatchesCategory() {
    #expect(NotificationCategory.color(for: "sale") == .yellow)
}

@Test func colorPurchaseMatchesCategory() {
    #expect(NotificationCategory.color(for: "purchase") == .blue)
}

@Test func colorBreedingMatchesCategory() {
    #expect(NotificationCategory.color(for: "breeding") == .pink)
}

@Test func colorMutationMatchesCategory() {
    #expect(NotificationCategory.color(for: "mutation") == .purple)
}

@Test func colorContractMatchesCategory() {
    #expect(NotificationCategory.color(for: "contract") == .teal)
}

@Test func colorPigdexOverridesCategory() {
    // Pigdex uses orange (distinct from discoveries' purple)
    #expect(NotificationCategory.color(for: "pigdex") == .orange)
    #expect(NotificationCategory.color(for: "pigdex") != NotificationCategory.discoveries.color)
}

@Test func colorAdoptionOverridesCategory() {
    // Adoption uses indigo (distinct from purchases' blue)
    #expect(NotificationCategory.color(for: "adoption") == .indigo)
    #expect(NotificationCategory.color(for: "adoption") != NotificationCategory.purchases.color)
}

@Test func colorFilterFallsBackToBreedingCategory() {
    #expect(NotificationCategory.color(for: "filter") == .pink)
}

@Test func colorMilestoneFallsBackToDiscoveriesCategory() {
    #expect(NotificationCategory.color(for: "milestone") == .purple)
}

@Test func colorPrestigeFallsBackToSystemCategory() {
    #expect(NotificationCategory.color(for: "prestige") == .secondary)
}

@Test func colorUnknownFallsBackToCategory() {
    #expect(NotificationCategory.color(for: "nonexistent") == .secondary)
}
