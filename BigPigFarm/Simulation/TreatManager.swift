/// TreatManager — Treat capacity, cooldown, and delivery mechanics.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

/// Stateless namespace for treat delivery during farm visits.
enum TreatManager {

    /// Maximum Euclidean distance (in grid cells) for treat delivery radius.
    static let deliveryRadius: Double = 6.0

    // MARK: - Cooldown

    /// Whether the treat session is on cooldown (4 real hours between sessions).
    static func isOnCooldown(prestige: PrestigeState, now: Date = Date()) -> Bool {
        guard let lastSession = prestige.visitStreak.lastVisitDate else { return false }
        return now.timeIntervalSince(lastSession) < GameConfig.Prestige.visitCooldownSeconds
    }

    // MARK: - Delivery

    /// Deliver a treat at a target position. Feeds up to 4 nearest pigs within radius.
    /// Decrements remainingTreatsThisVisit. Returns IDs of pigs that received the treat.
    /// Returns empty array if no treats remain or no pigs are in range.
    @MainActor
    static func deliverTreat(
        type: TreatType,
        at target: Position,
        state: GameState
    ) -> [UUID] {
        guard state.remainingTreatsThisVisit > 0 else { return [] }

        let radiusSquared = deliveryRadius * deliveryRadius
        let nearbyPigs = state.getPigsList()
            .filter { pig in
                let dx = pig.position.x - target.x
                let dy = pig.position.y - target.y
                return dx * dx + dy * dy <= radiusSquared
            }
            .sorted { pig1, pig2 in
                let d1 = distanceSquared(pig1.position, target)
                let d2 = distanceSquared(pig2.position, target)
                return d1 < d2
            }
            .prefix(GameConfig.Prestige.treatsPerScatter)

        guard !nearbyPigs.isEmpty else { return [] }

        state.remainingTreatsThisVisit -= 1
        var fedPigIds: [UUID] = []

        state.withBatchUpdate {
            for pig in nearbyPigs {
                var updated = pig
                applyTreatEffects(type: type, pig: &updated)
                state.updateGuineaPig(updated)
                fedPigIds.append(pig.id)
            }
        }

        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.log(
            category: .simulation, level: .info,
            message: "Treat delivered: \(type.displayName) to \(fedPigIds.count) pigs, "
                + "\(state.remainingTreatsThisVisit) remaining"
        )
        #endif

        return fedPigIds
    }

    // MARK: - Treat Effects

    /// Apply a treat's instant effects to a pig's needs.
    /// Note: timed buffs (fruitSlices breedingChanceBoost, herbBundle needDecayReduction)
    /// require per-pig timer fields and are deferred to a follow-up task.
    private static func applyTreatEffects(type: TreatType, pig: inout GuineaPig) {
        let info = type.info
        pig.needs.hunger = min(100, pig.needs.hunger + info.hungerBoost)
        pig.needs.happiness = min(100, pig.needs.happiness + info.happinessBoost)
        pig.needs.health = min(100, pig.needs.health + info.healthBoost)
        pig.needs.social = min(100, pig.needs.social + info.socialBoost)
    }

    // MARK: - Private Helpers

    private static func distanceSquared(_ a: Position, _ b: Position) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
