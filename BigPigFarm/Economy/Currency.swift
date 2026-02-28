/// Currency -- Currency formatting and display utilities.
/// Maps from: economy/currency.py
import Foundation

/// Formats currency values for display in the UI.
enum Currency {
    /// Format number for display: "1.5K", "2.3M", or plain number.
    static func formatMoney(_ amount: Int) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", Double(amount) / 1_000_000)
        } else if amount >= 1000 {
            return String(format: "%.1fK", Double(amount) / 1000)
        }
        return "\(amount)"
    }

    /// Format with "Sq" prefix: "Sq1.5K".
    static func formatCurrency(_ amount: Int) -> String {
        "Sq\(formatMoney(amount))"
    }

    // MARK: - Money Management

    /// Add money to the game state and update total earnings.
    @discardableResult
    @MainActor
    static func addMoney(state: GameState, amount: Int) -> Int {
        state.addMoney(amount)
        return amount
    }

    /// Spend money from the game state. Returns false if insufficient funds.
    @discardableResult
    @MainActor
    static func spendMoney(state: GameState, amount: Int) -> Bool {
        state.spendMoney(amount)
    }

    /// Check if the game state can afford the given amount.
    @MainActor
    static func canAfford(state: GameState, amount: Int) -> Bool {
        state.money >= amount
    }
}
