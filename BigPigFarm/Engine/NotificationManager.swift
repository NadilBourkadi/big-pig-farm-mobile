/// NotificationManager — Bridges game events to the toast UI layer.
///
/// Receives events from GameState.logEvent, checks NotificationPreferences,
/// applies burst throttling, and maintains a capped FIFO queue of visible toasts.
///
/// Maps from: notifications.py (Python source — toast filtering and batching)
import Foundation
import Observation

// MARK: - NotificationManager

@Observable
@MainActor
final class NotificationManager: @unchecked Sendable {

    // MARK: - Configuration

    /// Maximum visible toasts at any time. Oldest evicted when exceeded.
    let maxVisibleToasts: Int

    /// Duration (seconds) before a toast auto-dismisses.
    let autoDismissDelay: TimeInterval

    /// Window (seconds) within which same-category events are batched.
    let throttleWindow: TimeInterval

    // MARK: - Observable State

    /// Currently visible toasts. Observed by the toast overlay UI.
    private(set) var visibleToasts: [ToastItem] = []

    /// When true, suppresses all toast creation (offline catch-up mode).
    /// Events still flow to GameState.events for the Almanac log.
    var isSuppressed: Bool = false

    /// User notification preferences (loaded from UserDefaults).
    var preferences: NotificationPreferences

    // MARK: - Throttling State

    /// Pending events during the throttle window, keyed by category.
    private var pendingBatch: [NotificationCategory: [String]] = [:]

    /// Scheduled task that flushes the pending batch after the throttle window.
    private var throttleTask: Task<Void, Never>?

    /// Scheduled auto-dismiss tasks keyed by toast ID.
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Init

    init(
        preferences: NotificationPreferences = .load(),
        maxVisibleToasts: Int = 3,
        autoDismissDelay: TimeInterval = 3.0,
        throttleWindow: TimeInterval = 0.3
    ) {
        self.preferences = preferences
        self.maxVisibleToasts = maxVisibleToasts
        self.autoDismissDelay = autoDismissDelay
        self.throttleWindow = throttleWindow
    }

    // MARK: - Public API

    /// Handle an event from GameState.logEvent. Checks preferences, applies
    /// throttling, and enqueues toast(s) if appropriate.
    func handleEvent(message: String, eventType: String) {
        guard !isSuppressed else { return }

        let category = NotificationCategory.from(eventType: eventType)
        guard preferences.isEnabled(category) else { return }

        pendingBatch[category, default: []].append(message)

        if throttleTask == nil {
            throttleTask = Task { [weak self] in
                guard let window = self?.throttleWindow else { return }
                try? await Task.sleep(for: .seconds(window))
                self?.flushBatch()
            }
        }
    }

    /// Manually dismiss a specific toast (e.g., user swipe).
    func dismiss(_ toastID: UUID) {
        visibleToasts.removeAll { $0.id == toastID }
        cancelAutoDismiss(for: toastID)
    }

    /// Process any pending events immediately, bypassing the throttle timer.
    /// Useful before backgrounding (to avoid losing pending notifications)
    /// and in tests (to avoid timing-dependent assertions).
    func flush() {
        throttleTask?.cancel()
        guard !pendingBatch.isEmpty else { return }
        flushBatch()
    }

    /// Dismiss all visible toasts immediately.
    func dismissAll() {
        for toast in visibleToasts {
            cancelAutoDismiss(for: toast.id)
        }
        visibleToasts.removeAll()
    }

    // MARK: - Throttle Flush

    /// Flush the pending batch for all categories, creating summary or individual toasts.
    private func flushBatch() {
        throttleTask = nil
        let snapshot = pendingBatch
        pendingBatch = [:]

        for (category, messages) in snapshot {
            let toast: ToastItem
            if messages.count == 1 {
                toast = ToastItem(message: messages[0], category: category)
            } else {
                toast = ToastItem(
                    message: Self.summaryMessage(category: category, count: messages.count),
                    category: category
                )
            }
            enqueueToast(toast)
        }
    }

    // MARK: - Queue Management

    /// Enqueue a single toast. Enforces the max-visible cap (FIFO eviction).
    private func enqueueToast(_ toast: ToastItem) {
        visibleToasts.append(toast)

        while visibleToasts.count > maxVisibleToasts {
            let evicted = visibleToasts.removeFirst()
            cancelAutoDismiss(for: evicted.id)
        }

        scheduleAutoDismiss(for: toast.id)
    }

    // MARK: - Auto-Dismiss

    /// Schedule auto-dismiss for a toast after the configured delay.
    private func scheduleAutoDismiss(for toastID: UUID) {
        dismissTasks[toastID] = Task { [weak self] in
            guard let delay = self?.autoDismissDelay else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }
            self.visibleToasts.removeAll { $0.id == toastID }
            self.dismissTasks[toastID] = nil
        }
    }

    /// Cancel the auto-dismiss timer for a toast.
    private func cancelAutoDismiss(for toastID: UUID) {
        dismissTasks[toastID]?.cancel()
        dismissTasks[toastID] = nil
    }

    // MARK: - Summary Messages

    /// Generate a batched summary message for multiple same-category events.
    static func summaryMessage(category: NotificationCategory, count: Int) -> String {
        switch category {
        case .births: "\(count) pigs born"
        case .deaths: "\(count) pigs died"
        case .sales: "\(count) pigs sold"
        case .breeding: "\(count) breeding events"
        case .discoveries: "\(count) new discoveries"
        case .purchases: "\(count) purchases"
        case .contracts: "\(count) contract events"
        case .system: "\(count) system alerts"
        }
    }
}
