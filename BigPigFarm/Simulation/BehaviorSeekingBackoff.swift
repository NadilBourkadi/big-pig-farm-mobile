/// BehaviorSeekingBackoff — Backoff escalation helpers for facility seeking.
///
/// Bridges the gap between "no facility is pathfindable" (handled by the
/// existing unreachable-backoff system) and "facilities exist but are all
/// full/empty" (the livelock pattern these helpers detect and resolve).
import Foundation

extension BehaviorSeeking {
    /// Returns true if every facility type the pig might seek for this need has
    /// either: been failed at every facility of that type, OR exceeded the
    /// universal escalation threshold (`arrivalFailureEscalateThreshold`).
    /// When true, the pig should skip the seek loop and back off.
    @MainActor
    static func shouldEscalateToBackoff(
        controller: BehaviorController,
        pig: GuineaPig,
        facilityTypes: [FacilityType]
    ) -> Bool {
        let escalateThreshold = GameConfig.Behavior.arrivalFailureEscalateThreshold
        for facilityType in facilityTypes {
            let totalOfType = controller.gameState.getFacilitiesByType(facilityType).count
            if totalOfType == 0 { continue }
            let failuresForType = controller.facilityManager.getArrivalFailuresForType(
                pig.id, type: facilityType
            )
            // Still worth trying if we haven't failed at every facility AND
            // haven't hit the universal escalation threshold yet.
            if failuresForType < totalOfType && failuresForType < escalateThreshold {
                return false
            }
        }
        // At least one facility type exists, and the pig has exhausted them all.
        // (If no types exist at all, the seek loop's empty fallback handles it.)
        return facilityTypes.contains { !controller.gameState.getFacilitiesByType($0).isEmpty }
    }

    /// Set the unreachable-backoff for `need`, log it, and start wandering.
    /// Shared between the "no reachable facility" path and the bridge path.
    @MainActor
    static func applyUnreachableBackoff(
        controller: BehaviorController,
        pig: inout GuineaPig,
        need: String
    ) {
        let isCritical = getNeedValue(pig, need: need) < Double(GameConfig.Needs.criticalThreshold)
        let cycles = isCritical
            ? GameConfig.Behavior.unreachableCriticalCycles
            : GameConfig.Behavior.unreachableBackoffCycles
        controller.setUnreachableBackoff(pig.id, need: need, cycles: cycles)
        // Match cooldown to backoff duration so the failed set outlives the backoff
        controller.facilityManager.setFailedCooldown(pig.id, cycles)
        // Clear the per-type failure counter so the pig gets a clean slate
        // after the backoff expires — otherwise the bridge would re-fire on
        // the next seek attempt and the pig would be permanently locked out.
        controller.facilityManager.clearArrivalFailureCounters(pig.id)
        pig.logBehavior("No reachable \(need) facility, backing off")
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        logSeekFailure(pig: pig, need: need, isCritical: isCritical, cycles: cycles)
        #endif
        pig.targetDescription = nil
        BehaviorMovement.startWandering(controller: controller, pig: &pig)
    }
}
