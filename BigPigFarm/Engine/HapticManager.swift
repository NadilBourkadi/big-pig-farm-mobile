import UIKit

/// Provides haptic feedback for key game events.
///
/// All methods are safe to call from any context — they dispatch
/// to the main actor internally, since UIKit haptic APIs require
/// main-thread access.
enum HapticManager {
    // MARK: - Feedback Generators

    /// Light impact for routine events (pig selected, menu opened).
    @MainActor
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    /// Medium impact for meaningful events (purchase, sale).
    @MainActor
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    /// Heavy impact for major events (birth, pigdex discovery).
    @MainActor
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

    /// Notification feedback for success and error outcomes.
    @MainActor
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Event Methods

    /// Pig tapped/selected in the farm scene.
    @MainActor
    static func pigSelected() {
        lightImpact.impactOccurred()
    }

    /// Facility or perk purchased from the shop.
    @MainActor
    static func purchase() {
        mediumImpact.impactOccurred()
    }

    /// Pig sold at market or auto-sold.
    @MainActor
    static func pigSold() {
        mediumImpact.impactOccurred()
    }

    /// New pig born.
    @MainActor
    static func birth() {
        heavyImpact.impactOccurred()
    }

    /// New phenotype discovered in the pigdex.
    @MainActor
    static func pigdexDiscovery() {
        notification.notificationOccurred(.success)
    }

    /// Breeding contract completed.
    @MainActor
    static func contractCompleted() {
        notification.notificationOccurred(.success)
    }

    /// Error or failure (insufficient funds, invalid placement).
    @MainActor
    static func error() {
        notification.notificationOccurred(.error)
    }
}
