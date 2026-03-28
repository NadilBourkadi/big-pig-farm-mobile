/// UpgradeDisplayState — Visual state of a Showroom upgrade card.
/// Shared by ShowroomUpgradeCard and ShowroomUpgradeDetail.

/// Resolved display state for a single Showroom upgrade.
enum UpgradeDisplayState: Sendable {
    case purchased
    case affordable
    case unaffordable

    static func resolve(
        upgrade: ShowroomUpgrade,
        prestigeState: PrestigeState
    ) -> Self {
        if prestigeState.hasUpgrade(upgrade) {
            return .purchased
        } else if prestigeState.rosetteBalance >= upgrade.cost {
            return .affordable
        } else {
            return .unaffordable
        }
    }
}
