/// Shop — Shop items, purchase, and refund logic.
/// Maps from: economy/shop.py
import Foundation

// MARK: - ShopCategory

/// Shop item categories for organizing the store interface.
enum ShopCategory: String, Codable, CaseIterable, Sendable {
    case facilities
    case perks
    case upgrades
    case decorations
    case adoption
}

// MARK: - Stubs (implemented in later tasks)

/// Manages the in-game shop inventory, purchases, and refunds.
struct Shop: Sendable {
    // TODO: Implement in doc 04
}
