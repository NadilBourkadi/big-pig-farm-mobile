/// Tests for PushNotificationPlanner — pure prediction logic for local push notifications.
import Testing
@testable import BigPigFarmCore
import Foundation

// MARK: - Birth Predictions

@Test @MainActor func birthNotificationForPregnantPig() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 5.0  // halfway through gestation
    state.addGuineaPig(pig)

    let plans = PushNotificationPlanner.planBirthNotifications(state: state)

    #expect(plans.count == 1)
    #expect(plans[0].category == .births)
    #expect(plans[0].identifier == "birth-\(pig.id.uuidString)")
    #expect(plans[0].body.contains("Mama"))
    // 5 days remaining * 24 hours / 90 average speed * 3600 = 4800 seconds
    let expectedDelay = (5.0 * 24.0 / 90.0) * 3600.0
    #expect(abs(plans[0].delaySeconds - expectedDelay) < 1.0)
}

@Test @MainActor func noBirthNotificationWhenNotPregnant() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Pig", gender: .female)
    state.addGuineaPig(pig)

    let plans = PushNotificationPlanner.planBirthNotifications(state: state)

    #expect(plans.isEmpty)
}

@Test @MainActor func multipleBirthNotificationsForMultiplePregnantPigs() {
    let state = GameState()
    for i in 0..<3 {
        var pig = GuineaPig.create(name: "Pig\(i)", gender: .female)
        pig.isPregnant = true
        pig.pregnancyDays = Double(i * 3)
        state.addGuineaPig(pig)
    }

    let plans = PushNotificationPlanner.planBirthNotifications(state: state)

    #expect(plans.count == 3)
}

@Test @MainActor func birthNotificationNearDeliveryHasShortDelay() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Almost", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 9.5  // 0.5 days remaining
    state.addGuineaPig(pig)

    let plans = PushNotificationPlanner.planBirthNotifications(state: state)

    #expect(plans.count == 1)
    // 0.5 days * 24 hours / 90 speed * 3600 = 480 seconds
    let expectedDelay = (0.5 * 24.0 / 90.0) * 3600.0
    #expect(abs(plans[0].delaySeconds - expectedDelay) < 1.0)
}

// MARK: - Facility Depletion Predictions

@Test @MainActor func facilityWarningForLowStock() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Piggy", gender: .male)
    state.addGuineaPig(pig)

    var facility = Facility.create(type: .foodBowl, x: 2, y: 2)
    facility.currentAmount = 50.0  // 25% of 200 capacity
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    #expect(!plans.isEmpty)
    #expect(plans[0].category == .system)
    #expect(plans[0].title.contains("Food Bowl"))
}

@Test @MainActor func noFacilityWarningWhenFullyStocked() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Piggy", gender: .male)
    state.addGuineaPig(pig)

    let facility = Facility.create(type: .foodBowl, x: 2, y: 2)
    // Default is full (currentAmount == capacity)
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    // Full stock should still produce a plan (it's just very far in the future)
    // It will be filtered by minimum delay in the main method
    #expect(!plans.isEmpty)
    #expect(plans[0].delaySeconds > GameConfig.PushNotification.minimumDelay)
}

@Test @MainActor func emptyFacilityGetsImmediateWarning() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Piggy", gender: .male)
    state.addGuineaPig(pig)

    var facility = Facility.create(type: .foodBowl, x: 2, y: 2)
    facility.currentAmount = 0
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    #expect(plans.count == 1)
    #expect(plans[0].delaySeconds == GameConfig.PushNotification.minimumDelay)
    #expect(plans[0].title.contains("Empty"))
}

@Test @MainActor func noFacilityWarningWithNoPigs() {
    let state = GameState()
    var facility = Facility.create(type: .foodBowl, x: 2, y: 2)
    facility.currentAmount = 10.0
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    #expect(plans.isEmpty)
}

@Test @MainActor func nonDepletableFacilityProducesNoWarning() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Piggy", gender: .male)
    state.addGuineaPig(pig)

    // Hideout has refillCost == 0, meaning it's not depletable
    let facility = Facility.create(type: .hideout, x: 2, y: 2)
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    #expect(plans.isEmpty)
}

// MARK: - Contract Deadline Predictions

@Test @MainActor func contractDeadlineReminderScheduled() {
    let state = GameState()
    // Set game time to day 5
    state.gameTime.advance(minutes: 5.0 * 24.0 * 60.0)

    let contract = BreedingContract(
        requiredColor: .black,
        deadlineDay: 10  // 5 days from current day
    )
    state.contractBoard.activeContracts = [contract]

    let plans = PushNotificationPlanner.planContractNotifications(state: state)

    #expect(plans.count == 1)
    #expect(plans[0].category == .contracts)
    #expect(plans[0].identifier == "contract-\(contract.id.uuidString)")
}

@Test @MainActor func fulfilledContractProducesNoReminder() {
    let state = GameState()
    state.gameTime.advance(minutes: 5.0 * 24.0 * 60.0)

    let contract = BreedingContract(
        requiredColor: .black,
        deadlineDay: 10,
        fulfilled: true
    )
    state.contractBoard.activeContracts = [contract]

    let plans = PushNotificationPlanner.planContractNotifications(state: state)

    #expect(plans.isEmpty)
}

@Test @MainActor func expiredContractProducesNoReminder() {
    let state = GameState()
    // Day 15 — contract deadline was day 10
    state.gameTime.advance(minutes: 15.0 * 24.0 * 60.0)

    let contract = BreedingContract(
        requiredColor: .black,
        deadlineDay: 10
    )
    state.contractBoard.activeContracts = [contract]

    let plans = PushNotificationPlanner.planContractNotifications(state: state)

    #expect(plans.isEmpty)
}

@Test @MainActor func imminentContractGetsMinimumDelay() {
    let state = GameState()
    // GameTime is 1-indexed: advance 8 days → day = 1 + 8 = 9
    // Contract expires day 10 (1 day remaining = 24 game hours)
    // At 90 speed, 24 gh = 24/90*3600 = 960 real seconds
    // 960 - 7200 (lead time) = negative → should get minimumDelay
    state.gameTime.advance(minutes: 8.0 * 24.0 * 60.0)

    let contract = BreedingContract(
        requiredColor: .black,
        deadlineDay: 10
    )
    state.contractBoard.activeContracts = [contract]

    let plans = PushNotificationPlanner.planContractNotifications(state: state)

    #expect(plans.count == 1)
    #expect(plans[0].delaySeconds == GameConfig.PushNotification.minimumDelay)
}

// MARK: - Return Reminder

@Test func returnReminderAlwaysPresent() {
    let plan = PushNotificationPlanner.planReturnReminder()

    #expect(plan.identifier == "return-reminder")
    #expect(plan.category == .system)
    #expect(plan.delaySeconds == GameConfig.PushNotification.returnReminderDelay)
}

// MARK: - Preference Filtering

@Test @MainActor func disabledCategoryFiltersOutNotifications() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 5.0
    state.addGuineaPig(pig)

    var preferences = NotificationPreferences.from(preset: .standard)
    preferences.setEnabled(.births, enabled: false)

    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    // Birth notification should be filtered; return reminder (system) should remain
    let birthPlans = plans.filter { $0.category == .births }
    #expect(birthPlans.isEmpty)
}

@Test @MainActor func mainToggleOffReturnsEmpty() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 5.0
    state.addGuineaPig(pig)

    var preferences = NotificationPreferences.from(preset: .standard)
    preferences.pushNotificationsEnabled = false

    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    #expect(plans.isEmpty)
}

// MARK: - Cap Enforcement

@Test @MainActor func capsAtMaxScheduledNotifications() {
    let state = GameState()
    // Create 25 pregnant pigs (exceeds maxScheduled of 20)
    for i in 0..<25 {
        var pig = GuineaPig.create(name: "Pig\(i)", gender: .female)
        pig.isPregnant = true
        pig.pregnancyDays = Double(i % 10)
        state.addGuineaPig(pig)
    }

    let preferences = NotificationPreferences.from(preset: .standard)
    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    #expect(plans.count <= GameConfig.PushNotification.maxScheduled)
}

// MARK: - Minimum Delay Enforcement

@Test @MainActor func minimumDelayFiltersBriefTransitions() {
    let state = GameState()
    // Pig at 99.9% pregnancy — will predict very short delay
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 9.99  // ~0.01 days left → ~0.96 seconds real time
    state.addGuineaPig(pig)

    let preferences = NotificationPreferences.from(preset: .standard)
    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    // Birth notification with <5min delay should be filtered out
    let birthPlans = plans.filter { $0.category == .births }
    #expect(birthPlans.isEmpty)
}

// MARK: - Sorting

@Test @MainActor func plansAreSortedBySoonestFirst() {
    let state = GameState()
    // Three pigs at different pregnancy stages
    for (i, days) in [2.0, 8.0, 5.0].enumerated() {
        var pig = GuineaPig.create(name: "Pig\(i)", gender: .female)
        pig.isPregnant = true
        pig.pregnancyDays = days
        state.addGuineaPig(pig)
    }

    let preferences = NotificationPreferences.from(preset: .standard)
    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    let birthPlans = plans.filter { $0.category == .births }
    // Pig at day 8 (2 days left) should come before pig at day 5 (5 days left),
    // which should come before pig at day 2 (8 days left)
    for i in 0..<(birthPlans.count - 1) {
        #expect(birthPlans[i].delaySeconds <= birthPlans[i + 1].delaySeconds)
    }
}

// MARK: - Empty State

@Test @MainActor func emptyGameStateProducesOnlyReturnReminder() {
    let state = GameState()
    let preferences = NotificationPreferences.from(preset: .standard)
    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    // Only the return reminder should pass the minimum delay filter
    let nonSystemPlans = plans.filter { $0.category != .system }
    #expect(nonSystemPlans.isEmpty)
}

// MARK: - Time Conversion Helpers

@Test func gameHoursToRealSecondsUsesAverageSpeed() {
    // 90 game-hours per real hour → 1 game-hour = 40 real seconds
    let result = PushNotificationPlanner.gameHoursToRealSeconds(90.0)
    #expect(abs(result - 3600.0) < 0.01)  // 90 gh / 90 speed = 1 hour = 3600 seconds
}

@Test func gameHoursToRealSecondsZeroInput() {
    let result = PushNotificationPlanner.gameHoursToRealSeconds(0)
    #expect(result == 0)
}

// MARK: - Facility Depletion Uses maxAmount for Threshold

@Test @MainActor func facilityDepletionUsesMaxAmountForThreshold() {
    let state = GameState()
    let pig = GuineaPig.create(name: "Piggy", gender: .male)
    state.addGuineaPig(pig)

    // Half-full facility: currentAmount=100, maxAmount=200
    var facility = Facility.create(type: .foodBowl, x: 2, y: 2)
    facility.currentAmount = 100.0
    _ = state.addFacility(facility)

    let plans = PushNotificationPlanner.planFacilityNotifications(state: state)

    #expect(plans.count == 1)
    // Target = 200 * 0.15 = 30. Amount to deplete = 100 - 30 = 70.
    // Rate = 1.0 * 0.40 * 1 pig = 0.4/hr
    // Hours = 70 / 0.4 = 175 game hours
    let expectedGameHours = 175.0
    let expectedRealSeconds = (expectedGameHours / 90.0) * 3600.0
    #expect(abs(plans[0].delaySeconds - expectedRealSeconds) < 1.0)
}

// MARK: - Return Reminder Gating

@Test @MainActor func returnReminderAbsentWhenOtherNotificationsExist() {
    let state = GameState()
    // Pregnant pig with enough time remaining (>5 min real) to survive the filter
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 5.0  // 5 days left → well above minimum delay
    state.addGuineaPig(pig)

    let preferences = NotificationPreferences.from(preset: .standard)
    let plans = PushNotificationPlanner.planNotifications(
        state: state, preferences: preferences
    )

    let returnReminders = plans.filter { $0.identifier == "return-reminder" }
    #expect(returnReminders.isEmpty)
}

// MARK: - Speed Gestation Upgrade

@Test @MainActor func birthNotificationUsesSpeedGestationWhenUpgraded() {
    let state = GameState()
    state.prestigeState.purchasedUpgrades.insert(.speedGestation)

    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 5.0
    state.addGuineaPig(pig)

    let plans = PushNotificationPlanner.planBirthNotifications(state: state)

    #expect(plans.count == 1)
    // With speedGestation: gestationDays = 7.5, daysLeft = 7.5 - 5 = 2.5
    let expectedDelay = (2.5 * 24.0 / 90.0) * 3600.0
    #expect(abs(plans[0].delaySeconds - expectedDelay) < 1.0)
}
