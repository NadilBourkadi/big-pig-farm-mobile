/// VisitManager — Visit detection, reunion boost, and streak tracking.
/// Maps from: design-prestige-and-progression.md Section 6
import Foundation

/// Stateless namespace for visit mechanics triggered on app foreground transitions.
enum VisitManager {

    // MARK: - Visit Processing

    /// Full visit pipeline: detect → boost → streak → treats.
    /// Called from BigPigFarmApp when the app returns from background.
    /// Returns true if a visit was detected and processed.
    ///
    /// Note: the 4-hour cooldown (`visitCooldownSeconds`) gates treat refills only,
    /// not the reunion boost or streak. A player returning after 1 hour always gets
    /// the boost and streak increment, but treats only refill if the cooldown has elapsed.
    @MainActor
    @discardableResult
    static func processVisit(state: GameState, now: Date = Date()) -> Bool {
        guard detectVisit(state: state, now: now) else { return false }

        applyReunionBoost(state: state, now: now)

        // Check cooldown BEFORE recordVisit, which overwrites lastVisitDate with now.
        let treatsAllowed = !TreatManager.isOnCooldown(prestige: state.prestigeState, now: now)

        recordVisit(state: state, now: now)

        if treatsAllowed {
            resetTreatCapacity(state: state)
        }

        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.log(
            category: .simulation, level: .info,
            message: "Visit detected: streak=\(state.prestigeState.visitStreak.currentStreak), "
                + "treats=\(state.remainingTreatsThisVisit)"
        )
        #endif

        return true
    }

    // MARK: - Visit Detection

    /// Check whether the app has been away long enough to qualify as a visit.
    /// Uses lastBackgroundDate if available (warm return), falls back to lastSave (cold start).
    @MainActor
    static func detectVisit(state: GameState, now: Date = Date()) -> Bool {
        let reference = state.lastBackgroundDate ?? state.lastSave
        guard let ref = reference else { return false }
        return now.timeIntervalSince(ref) >= GameConfig.Prestige.reunionMinOfflineSeconds
    }

    // MARK: - Reunion Boost

    /// Create and apply a reunion boost to all pigs.
    /// Uses enhanced boost if Reunion Spirit upgrade is owned.
    @MainActor
    static func applyReunionBoost(state: GameState, now: Date = Date()) {
        let hasReunionSpirit = state.prestigeState.hasUpgrade(.reunionSpirit)
        let boost = hasReunionSpirit
            ? ReunionBoost.enhanced(at: now)
            : ReunionBoost.standard(at: now)

        state.prestigeState.activeReunionBoost = boost

        state.withBatchUpdate {
            for (_, pig) in state.guineaPigs {
                var updated = pig
                updated.needs.happiness = min(100, updated.needs.happiness + boost.happinessBoost)
                state.updateGuineaPig(updated)
            }
        }

        state.logEvent(
            "Your pigs are happy to see you! (+\(Int(boost.happinessBoost)) happiness)",
            eventType: "info"
        )
    }

    // MARK: - Streak

    /// Record this visit in the streak tracker.
    @MainActor
    static func recordVisit(state: GameState, now: Date = Date()) {
        let newStreak = state.prestigeState.visitStreak.recordVisit(at: now)
        if newStreak >= 2 {
            state.logEvent(
                "Visit streak: Day \(newStreak)!",
                eventType: "info"
            )
        }
    }

    // MARK: - Treat Capacity

    /// Reset treat count to the full capacity for this visit.
    @MainActor
    static func resetTreatCapacity(state: GameState) {
        state.remainingTreatsThisVisit = state.prestigeState.treatsPerVisit
    }

    // MARK: - Bonus Queries

    /// Total breeding chance bonus from active reunion boost + visit streak.
    static func breedingBonus(prestige: PrestigeState, now: Date = Date()) -> Double {
        var bonus = 0.0
        if let boost = prestige.activeReunionBoost, boost.isActive(at: now) {
            bonus += boost.breedingChanceBonus
        }
        bonus += prestige.visitStreak.breedingChanceBonus
        return bonus
    }

    /// Total sale value multiplier from active reunion boost + visit streak.
    /// Bonuses stack additively: base 1.0 + reunion bonus + streak bonus.
    /// Returns 1.0 when no bonuses are active.
    static func saleMultiplier(prestige: PrestigeState, now: Date = Date()) -> Double {
        var mult = 1.0
        if let boost = prestige.activeReunionBoost, boost.isActive(at: now) {
            mult += boost.saleValueBonus
        }
        mult += prestige.visitStreak.saleValueBonus
        return mult
    }
}
