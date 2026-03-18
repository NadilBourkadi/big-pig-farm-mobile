/// ToastItem — A single notification shown in the toast overlay.
///
/// Pure value type used by NotificationManager's visible queue and consumed
/// by the toast overlay UI (ToastView / ToastOverlayView).
import Foundation

struct ToastItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let message: String
    let category: NotificationCategory
    let timestamp: Date

    init(
        id: UUID = UUID(),
        message: String,
        category: NotificationCategory,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.category = category
        self.timestamp = timestamp
    }
}
