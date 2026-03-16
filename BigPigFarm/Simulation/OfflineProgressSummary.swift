/// OfflineProgressSummary — Accumulates events during offline fast-forward.
import Foundation

/// Collects births, deaths, sales, and other events that occurred during
/// offline catch-up. Displayed to the player in a summary popup (Bead wx9).
struct OfflineProgressSummary: Sendable, Identifiable {
    let id = UUID()
    let wallClockElapsed: TimeInterval
    let gameHoursElapsed: Double

    struct BornPig: Sendable {
        let name: String
        let phenotype: String
    }

    struct DeadPig: Sendable {
        let name: String
        let ageDays: Int
    }

    struct SoldPig: Sendable {
        let name: String
        let value: Int
    }

    struct Pregnancy: Sendable {
        let maleName: String
        let femaleName: String
    }

    var pigsBorn: [BornPig] = []
    var pigsDied: [DeadPig] = []
    var pigsSold: [SoldPig] = []
    var pregnanciesStarted: [Pregnancy] = []
    var pigdexDiscoveries: [String] = []

    var totalMoneyEarned: Int = 0
    var facilitiesEmptied: Int = 0

    var hasMeaningfulEvents: Bool {
        !pigsBorn.isEmpty || !pigsDied.isEmpty || !pigsSold.isEmpty
        || !pregnanciesStarted.isEmpty || !pigdexDiscoveries.isEmpty
        || totalMoneyEarned != 0 || facilitiesEmptied > 0
    }
}
