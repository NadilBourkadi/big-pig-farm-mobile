/// Market -- Pig selling result data type.
/// Maps from: economy/market.py
import Foundation

// MARK: - SaleResult

/// Result of selling a guinea pig, with value breakdown.
struct SaleResult: Sendable {
    let baseValue: Int
    let contractBonus: Int
    let matchedContract: BreedingContract?

    var total: Int { baseValue + contractBonus }
}
