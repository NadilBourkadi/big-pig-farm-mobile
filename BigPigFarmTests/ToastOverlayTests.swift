/// Tests for toast overlay UI integration with NotificationManager.
///
/// Lives in BigPigFarmTests (not BigPigFarmCoreTests) because NotificationManager
/// is in the Xcode app target, not the SPM package.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - NotificationManager Integration

@Suite("Toast Overlay Integration")
@MainActor
struct ToastOverlayIntegrationTests {

    @Test func handleEventAddsVisibleToast() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.handleEvent(message: "A pig was born!", eventType: "birth")
        manager.flush()
        #expect(manager.visibleToasts.count == 1)
        #expect(manager.visibleToasts.first?.message == "A pig was born!")
        #expect(manager.visibleToasts.first?.category == .births)
    }

    @Test func dismissRemovesToast() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.handleEvent(message: "Test", eventType: "birth")
        manager.flush()
        let toastID = manager.visibleToasts[0].id
        manager.dismiss(toastID)
        #expect(manager.visibleToasts.isEmpty)
    }

    @Test func maxThreeVisibleToasts() {
        // Use .all preset so all categories pass the filter.
        let manager = NotificationManager(preferences: .from(preset: .all), throttleWindow: 0)
        manager.handleEvent(message: "One", eventType: "birth")
        manager.flush()
        manager.handleEvent(message: "Two", eventType: "death")
        manager.flush()
        manager.handleEvent(message: "Three", eventType: "sale")
        manager.flush()
        manager.handleEvent(message: "Four", eventType: "contract")
        manager.flush()
        #expect(manager.visibleToasts.count == 3)
        #expect(manager.visibleToasts.allSatisfy { $0.message != "One" })
    }

    @Test func suppressedBlocksToasts() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.isSuppressed = true
        manager.handleEvent(message: "Suppressed", eventType: "birth")
        manager.flush()
        #expect(manager.visibleToasts.isEmpty)
    }

    @Test func unsuppressedResumesToasts() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.isSuppressed = true
        manager.handleEvent(message: "Suppressed", eventType: "birth")
        manager.flush()
        manager.isSuppressed = false
        manager.handleEvent(message: "Visible", eventType: "birth")
        manager.flush()
        #expect(manager.visibleToasts.count == 1)
        #expect(manager.visibleToasts.first?.message == "Visible")
    }

    @Test func disabledCategoryFiltered() throws {
        let suiteName = "ToastOverlayTests.filter"
        let suite = try #require(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        var prefs = NotificationPreferences.from(preset: .all)
        prefs.setEnabled(.births, enabled: false)
        prefs.save(to: suite)

        let manager = NotificationManager(
            preferences: .load(from: suite),
            throttleWindow: 0
        )
        manager.handleEvent(message: "Birth event", eventType: "birth")
        manager.flush()
        #expect(manager.visibleToasts.isEmpty)
    }

    @Test func enabledCategoryPassesFilter() {
        let manager = NotificationManager(
            preferences: .from(preset: .all),
            throttleWindow: 0
        )
        manager.handleEvent(message: "Death event", eventType: "death")
        manager.flush()
        #expect(manager.visibleToasts.count == 1)
    }

    @Test func dismissNonexistentIDIsNoOp() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.dismiss(UUID())
        #expect(manager.visibleToasts.isEmpty)
    }

    @Test func dismissAllClearsQueue() {
        let manager = NotificationManager(throttleWindow: 0)
        manager.handleEvent(message: "One", eventType: "birth")
        manager.flush()
        manager.handleEvent(message: "Two", eventType: "death")
        manager.flush()
        manager.dismissAll()
        #expect(manager.visibleToasts.isEmpty)
    }

    @Test func gameStateLogEventBridgesToManager() {
        let state = GameState()
        let manager = NotificationManager(throttleWindow: 0)
        state.notificationManager = manager
        state.logEvent("Test birth", eventType: "birth")
        manager.flush()
        #expect(manager.visibleToasts.count == 1)
        #expect(manager.visibleToasts.first?.message == "Test birth")
    }
}
