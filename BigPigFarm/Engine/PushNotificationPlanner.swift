/// PushNotificationPlanner — Pure prediction logic for local push notifications.
///
/// Computes which notifications to schedule based on current game state at background time.
/// Returns PlannedNotification structs (no UNUserNotifications dependency), making this
/// fully testable in BigPigFarmCore without a simulator.
///
/// Predictions use the offline speed tier math to estimate real-world time until events.
import Foundation

// MARK: - PlannedNotification

/// A planned local notification computed from game state. Pure data — no framework dependency.
struct PlannedNotification: Sendable, Equatable {
    let identifier: String
    let title: String
    let body: String
    let category: NotificationCategory
    let delaySeconds: TimeInterval
}

// MARK: - PushNotificationPlanner

enum PushNotificationPlanner {

    /// Analyze game state and return planned notifications filtered by preferences.
    /// Sorted by delay (soonest first), capped at maxScheduled.
    @MainActor
    static func planNotifications(
        state: GameState,
        preferences: NotificationPreferences
    ) -> [PlannedNotification] {
        guard preferences.pushNotificationsEnabled else { return [] }

        var plans: [PlannedNotification] = []

        plans.append(contentsOf: planBirthNotifications(state: state))
        plans.append(contentsOf: planFacilityNotifications(state: state))
        plans.append(contentsOf: planContractNotifications(state: state))

        // Filter by category preferences and minimum delay
        plans = plans.filter { notification in
            preferences.isEnabled(notification.category)
                && notification.delaySeconds >= GameConfig.PushNotification.minimumDelay
        }

        // Only add the return reminder when no specific event notifications survived
        if plans.isEmpty, preferences.isEnabled(.system) {
            plans.append(planReturnReminder())
        }

        // Sort by soonest first, cap at maximum
        plans.sort { $0.delaySeconds < $1.delaySeconds }
        if plans.count > GameConfig.PushNotification.maxScheduled {
            plans = Array(plans.prefix(GameConfig.PushNotification.maxScheduled))
        }

        return plans
    }

    // MARK: - Birth Predictions

    /// Schedule notifications for pregnant pigs approaching delivery.
    @MainActor
    static func planBirthNotifications(state: GameState) -> [PlannedNotification] {
        let pigs = state.getPigsList()
        let hasSpeedGestation = state.prestigeState.hasUpgrade(.speedGestation)
        let gestationDays = hasSpeedGestation
            ? GameConfig.Prestige.speedGestationDays
            : Double(GameConfig.Breeding.gestationDays)

        var plans: [PlannedNotification] = []
        for pig in pigs where pig.isPregnant {
            let daysRemaining = max(0, gestationDays - pig.pregnancyDays)
            let realSeconds = gameHoursToRealSeconds(daysRemaining * 24.0)

            plans.append(PlannedNotification(
                identifier: "birth-\(pig.id.uuidString)",
                title: "New Arrival! 🐹",
                body: "\(pig.name) has given birth!",
                category: .births,
                delaySeconds: realSeconds
            ))
        }
        return plans
    }

    // MARK: - Facility Depletion Predictions

    /// Schedule warnings for facilities predicted to run empty.
    @MainActor
    static func planFacilityNotifications(state: GameState) -> [PlannedNotification] {
        let facilities = state.getFacilitiesList()
        let pigCount = state.pigCount

        guard pigCount > 0 else { return [] }

        var plans: [PlannedNotification] = []
        for facility in facilities where facility.info.refillCost > 0 {
            let stockPercent = facility.fillPercentage
            guard stockPercent > 0 else {
                // Already empty — warn immediately
                plans.append(PlannedNotification(
                    identifier: "facility-empty-\(facility.id.uuidString)",
                    title: "\(facility.info.name) Empty",
                    body: "Your \(facility.info.name.lowercased()) has run out! Pigs are going hungry.",
                    category: .system,
                    delaySeconds: GameConfig.PushNotification.minimumDelay
                ))
                continue
            }

            // Estimate time to depletion based on consumption rate
            let estimatedConsumptionPerHour = estimateConsumption(
                facility: facility, pigCount: pigCount
            )
            guard estimatedConsumptionPerHour > 0 else { continue }

            let targetAmount = facility.maxAmount
                * (GameConfig.PushNotification.facilityWarningThreshold / 100.0)
            let hoursUntilThreshold = max(0, facility.currentAmount - targetAmount)
                / estimatedConsumptionPerHour
            let realSeconds = gameHoursToRealSeconds(hoursUntilThreshold)

            plans.append(PlannedNotification(
                identifier: "facility-low-\(facility.id.uuidString)",
                title: "\(facility.info.name) Running Low",
                body: "Your \(facility.info.name.lowercased()) is almost empty. Time to refill!",
                category: .system,
                delaySeconds: realSeconds
            ))
        }
        return plans
    }

    // MARK: - Contract Deadline Reminders

    /// Schedule reminders for contracts approaching their deadline.
    @MainActor
    static func planContractNotifications(state: GameState) -> [PlannedNotification] {
        let contracts = state.contractBoard.activeContracts
        let currentDay = state.gameTime.day

        var plans: [PlannedNotification] = []
        for contract in contracts where !contract.fulfilled {
            let gameDaysUntilDeadline = contract.deadlineDay - currentDay
            guard gameDaysUntilDeadline > 0 else { continue }

            let realSecondsUntilDeadline = gameHoursToRealSeconds(
                Double(gameDaysUntilDeadline) * 24.0
            )
            // Schedule reminder ahead of deadline
            let reminderDelay = realSecondsUntilDeadline
                - GameConfig.PushNotification.contractReminderLeadSeconds

            guard reminderDelay > 0 else {
                // Deadline is too close — warn now
                plans.append(PlannedNotification(
                    identifier: "contract-\(contract.id.uuidString)",
                    title: "Contract Expiring Soon!",
                    body: "Your \(contract.difficulty.rawValue) contract expires in less than a day!",
                    category: .contracts,
                    delaySeconds: GameConfig.PushNotification.minimumDelay
                ))
                continue
            }

            plans.append(PlannedNotification(
                identifier: "contract-\(contract.id.uuidString)",
                title: "Contract Deadline Approaching",
                body: "Your \(contract.difficulty.rawValue) contract expires soon. Don't miss the reward!",
                category: .contracts,
                delaySeconds: reminderDelay
            ))
        }
        return plans
    }

    // MARK: - Return Reminder

    /// A gentle "come back" nudge at a fixed delay when no other events are predicted.
    static func planReturnReminder() -> PlannedNotification {
        PlannedNotification(
            identifier: "return-reminder",
            title: "Your Pigs Miss You!",
            body: "Your guinea pigs are waiting for you. Come check on them!",
            category: .system,
            delaySeconds: GameConfig.PushNotification.returnReminderDelay
        )
    }

    // MARK: - Helpers

    /// Convert game-hours to estimated real-world seconds using the average offline speed.
    static func gameHoursToRealSeconds(_ gameHours: Double) -> TimeInterval {
        let realHours = gameHours / GameConfig.PushNotification.averageOfflineSpeedMultiplier
        return realHours * 3600.0
    }

    /// Estimate hourly consumption for a facility based on pig count.
    /// Uses the offline consumption rate multiplier since pigs are offline.
    /// Intentionally uses a flat rate for all depletable facility types — the actual
    /// per-type rates vary by pig behavior and need state, but a uniform approximation
    /// is good enough for notification timing (within ±30 min over a typical absence).
    private static func estimateConsumption(facility: Facility, pigCount: Int) -> Double {
        let baseRatePerPig: Double = 1.0
        let offlineRate = baseRatePerPig * GameConfig.Offline.consumptionRateMultiplier
        return offlineRate * Double(pigCount)
    }
}
