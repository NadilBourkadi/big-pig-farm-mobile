/// Tests for NotificationManager — toast queue, throttling, suppression, auto-dismiss.
import Testing
@testable import BigPigFarmCore
import Foundation

// MARK: - Helper

/// Create a NotificationManager with test-friendly defaults.
/// Uses a long auto-dismiss (10s) by default so it doesn't interfere with assertions.
@MainActor
private func makeManager(
    preset: NotificationPreset = .all,
    maxVisible: Int = 3,
    dismissDelay: TimeInterval = 10.0,
    throttleWindow: TimeInterval = 0.3
) -> NotificationManager {
    NotificationManager(
        preferences: .from(preset: preset),
        maxVisibleToasts: maxVisible,
        autoDismissDelay: dismissDelay,
        throttleWindow: throttleWindow
    )
}

// MARK: - Preference Filtering

@Test @MainActor
func disabledCategoryProducesNoToast() {
    let manager = makeManager(preset: .minimal) // Only deaths + system
    manager.handleEvent(message: "Pig born", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.isEmpty)
}

@Test @MainActor
func enabledCategoryProducesToast() {
    let manager = makeManager(preset: .all)
    manager.handleEvent(message: "Pig born", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.count == 1)
    #expect(manager.visibleToasts[0].message == "Pig born")
    #expect(manager.visibleToasts[0].category == .births)
}

@Test @MainActor
func minimalPresetAllowsDeathsAndSystem() {
    let manager = makeManager(preset: .minimal)

    manager.handleEvent(message: "Pig died", eventType: "death")
    manager.flush()
    #expect(manager.visibleToasts.count == 1)

    manager.handleEvent(message: "Welcome", eventType: "info")
    manager.flush()
    #expect(manager.visibleToasts.count == 2)
}

// MARK: - Queue Cap

@Test @MainActor
func queueCapEvictsOldest() {
    let manager = makeManager(maxVisible: 3)

    // Flush individually to avoid batching
    manager.handleEvent(message: "Event 1", eventType: "birth")
    manager.flush()
    manager.handleEvent(message: "Event 2", eventType: "death")
    manager.flush()
    manager.handleEvent(message: "Event 3", eventType: "sale")
    manager.flush()
    manager.handleEvent(message: "Event 4", eventType: "purchase")
    manager.flush()

    #expect(manager.visibleToasts.count == 3)
    let messages = manager.visibleToasts.map(\.message)
    #expect(!messages.contains("Event 1")) // Oldest evicted
    #expect(messages.contains("Event 4")) // Newest kept
}

@Test @MainActor
func queueCapAtExactLimit() {
    let manager = makeManager(maxVisible: 3)

    manager.handleEvent(message: "Event 1", eventType: "birth")
    manager.flush()
    manager.handleEvent(message: "Event 2", eventType: "death")
    manager.flush()
    manager.handleEvent(message: "Event 3", eventType: "sale")
    manager.flush()

    #expect(manager.visibleToasts.count == 3)
}

// MARK: - Auto-Dismiss

@Test @MainActor
func autoDismissRemovesToastAfterDelay() async {
    let manager = makeManager(dismissDelay: 0.05)
    manager.handleEvent(message: "Temporary", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.count == 1)

    // Poll until dismissed or timeout (1.5s max, 30x margin over 50ms delay)
    for _ in 0..<30 {
        if manager.visibleToasts.isEmpty { break }
        try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(manager.visibleToasts.isEmpty)
}

// MARK: - Burst Throttling

@Test @MainActor
func burstThrottlingBatchesSameCategoryEvents() {
    let manager = makeManager()

    // Send 3 birth events before flushing — they're in the same batch
    manager.handleEvent(message: "Pig A born", eventType: "birth")
    manager.handleEvent(message: "Pig B born", eventType: "birth")
    manager.handleEvent(message: "Pig C born", eventType: "birth")
    manager.flush()

    #expect(manager.visibleToasts.count == 1)
    #expect(manager.visibleToasts[0].message == "3 pigs born")
    #expect(manager.visibleToasts[0].category == .births)
}

@Test @MainActor
func mixedCategoriesInSameWindowStaySeparate() {
    let manager = makeManager()

    manager.handleEvent(message: "Pig A born", eventType: "birth")
    manager.handleEvent(message: "Pig B born", eventType: "birth")
    manager.handleEvent(message: "Sold Pig C", eventType: "sale")
    manager.flush()

    #expect(manager.visibleToasts.count == 2)

    let categories = Set(manager.visibleToasts.map(\.category))
    #expect(categories.contains(.births))
    #expect(categories.contains(.sales))

    let birthToast = manager.visibleToasts.first { $0.category == .births }
    #expect(birthToast?.message == "2 pigs born")
}

@Test @MainActor
func singleEventInBatchNotSummarized() {
    let manager = makeManager()

    manager.handleEvent(message: "Pig A born", eventType: "birth")
    manager.flush()

    #expect(manager.visibleToasts.count == 1)
    #expect(manager.visibleToasts[0].message == "Pig A born") // Original, not summary
}

// MARK: - Suppression

@Test @MainActor
func suppressionPreventsAllToasts() {
    let manager = makeManager()
    manager.isSuppressed = true

    manager.handleEvent(message: "Pig born", eventType: "birth")
    manager.handleEvent(message: "Pig died", eventType: "death")
    manager.handleEvent(message: "System alert", eventType: "info")
    manager.flush()

    #expect(manager.visibleToasts.isEmpty)
}

@Test @MainActor
func suppressionToggleMidStream() {
    let manager = makeManager()
    manager.isSuppressed = true

    manager.handleEvent(message: "Suppressed", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.isEmpty)

    manager.isSuppressed = false
    manager.handleEvent(message: "Visible", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.count == 1)
    #expect(manager.visibleToasts[0].message == "Visible")
}

// MARK: - Manual Dismiss

@Test @MainActor
func manualDismissRemovesToast() {
    let manager = makeManager()
    manager.handleEvent(message: "Dismissable", eventType: "birth")
    manager.flush()
    #expect(manager.visibleToasts.count == 1)

    let toastID = manager.visibleToasts[0].id
    manager.dismiss(toastID)
    #expect(manager.visibleToasts.isEmpty)
}

@Test @MainActor
func dismissAllClearsEverything() {
    let manager = makeManager()

    manager.handleEvent(message: "Event 1", eventType: "birth")
    manager.flush()
    manager.handleEvent(message: "Event 2", eventType: "death")
    manager.flush()
    manager.handleEvent(message: "Event 3", eventType: "sale")
    manager.flush()

    #expect(manager.visibleToasts.count == 3)
    manager.dismissAll()
    #expect(manager.visibleToasts.isEmpty)
}

// MARK: - Summary Messages

@Test @MainActor
func summaryMessagesForAllCategories() {
    #expect(NotificationManager.summaryMessage(category: .births, count: 3) == "3 pigs born")
    #expect(NotificationManager.summaryMessage(category: .deaths, count: 2) == "2 pigs died")
    #expect(NotificationManager.summaryMessage(category: .sales, count: 4) == "4 pigs sold")
    #expect(NotificationManager.summaryMessage(category: .breeding, count: 2) == "2 breeding events")
    #expect(NotificationManager.summaryMessage(category: .discoveries, count: 3) == "3 new discoveries")
    #expect(NotificationManager.summaryMessage(category: .purchases, count: 2) == "2 purchases")
    #expect(NotificationManager.summaryMessage(category: .contracts, count: 2) == "2 contract events")
    #expect(NotificationManager.summaryMessage(category: .system, count: 3) == "3 system alerts")
}

// MARK: - ToastItem

@Test
func toastItemEquality() {
    let id = UUID()
    let date = Date()
    let a = ToastItem(id: id, message: "Test", category: .births, timestamp: date)
    let b = ToastItem(id: id, message: "Test", category: .births, timestamp: date)
    #expect(a == b)
}

@Test
func toastItemInequality() {
    let a = ToastItem(message: "Test", category: .births)
    let b = ToastItem(message: "Test", category: .births)
    #expect(a != b) // Different UUIDs
}
