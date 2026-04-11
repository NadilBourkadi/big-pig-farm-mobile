/// PushNotificationScheduler — Thin bridge to UNUserNotificationCenter.
///
/// Converts PlannedNotification structs (from PushNotificationPlanner) into
/// UNNotificationRequests and submits them. App-only — not included in BigPigFarmCore
/// because it requires the UserNotifications framework.
import Foundation
import UserNotifications

enum PushNotificationScheduler {

    /// Request notification authorization from the user. Call once at app launch.
    /// Returns true if authorization was granted.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Schedule an array of planned notifications via UNUserNotificationCenter.
    /// Replaces any existing notification with the same identifier.
    static func schedule(_ plans: [PlannedNotification]) {
        let center = UNUserNotificationCenter.current()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.threadIdentifier = "com.bigpigfarm.\(plan.category.rawValue)"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, plan.delaySeconds),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    /// Cancel all pending Big Pig Farm notifications.
    /// Called when the app returns to foreground (in-app toasts take over).
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
