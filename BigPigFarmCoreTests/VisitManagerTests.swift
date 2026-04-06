/// VisitManagerTests — Tests for visit detection, reunion boost, and streak tracking.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Visit Detection

@Test @MainActor func detectVisitAfterOneHour() {
    let state = GameState()
    state.lastBackgroundDate = Date().addingTimeInterval(-3700)
    #expect(VisitManager.detectVisit(state: state))
}

@Test @MainActor func detectVisitReturnsFalseWhenTooShort() {
    let state = GameState()
    state.lastBackgroundDate = Date().addingTimeInterval(-1800) // 30 min
    #expect(!VisitManager.detectVisit(state: state))
}

@Test @MainActor func detectVisitReturnsFalseWhenNilDates() {
    let state = GameState()
    state.lastBackgroundDate = nil
    state.lastSave = nil
    #expect(!VisitManager.detectVisit(state: state))
}

@Test @MainActor func detectVisitFallsBackToLastSave() {
    let state = GameState()
    state.lastBackgroundDate = nil
    state.lastSave = Date().addingTimeInterval(-7200) // 2 hours
    #expect(VisitManager.detectVisit(state: state))
}

@Test @MainActor func detectVisitExactlyAtThreshold() {
    let state = GameState()
    let threshold = GameConfig.Prestige.reunionMinOfflineSeconds
    state.lastBackgroundDate = Date().addingTimeInterval(-threshold)
    #expect(VisitManager.detectVisit(state: state))
}

@Test @MainActor func detectVisitJustBelowThreshold() {
    let state = GameState()
    let threshold = GameConfig.Prestige.reunionMinOfflineSeconds
    state.lastBackgroundDate = Date().addingTimeInterval(-threshold + 1)
    #expect(!VisitManager.detectVisit(state: state))
}

// MARK: - Reunion Boost (Standard)

@Test @MainActor func visitReunionBoostUsesStandardByDefault() {
    let state = GameState()
    VisitManager.applyReunionBoost(state: state)
    let boost = state.prestigeState.activeReunionBoost!
    #expect(boost.durationSeconds == GameConfig.Prestige.reunionDurationSeconds)
    #expect(boost.breedingChanceBonus == GameConfig.Prestige.reunionBreedingBonus)
}

@Test @MainActor func visitReunionBoostExpiredDoesNotContributeBonus() {
    var prestige = PrestigeState()
    let past = Date().addingTimeInterval(-2000) // well past 30 min
    prestige.activeReunionBoost = ReunionBoost.standard(at: past)
    #expect(VisitManager.breedingBonus(prestige: prestige) == 0)
    #expect(VisitManager.saleMultiplier(prestige: prestige) == 1.0)
}

// MARK: - Reunion Boost Application

@Test @MainActor func applyReunionBoostIncreasesHappiness() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.happiness = 50.0
    state.addGuineaPig(pig)

    VisitManager.applyReunionBoost(state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.happiness == 50.0 + GameConfig.Prestige.reunionHappinessBoost)
}

@Test @MainActor func applyReunionBoostClampsTo100() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.happiness = 95.0
    state.addGuineaPig(pig)

    VisitManager.applyReunionBoost(state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.happiness == 100.0)
}

@Test @MainActor func applyReunionBoostSetsActiveBoostOnPrestige() {
    let state = GameState()
    #expect(state.prestigeState.activeReunionBoost == nil)

    VisitManager.applyReunionBoost(state: state)

    #expect(state.prestigeState.activeReunionBoost != nil)
    #expect(state.prestigeState.activeReunionBoost!.isActive())
}

@Test @MainActor func applyReunionBoostUsesEnhancedWithReunionSpirit() {
    let state = GameState()
    state.prestigeState.purchasedUpgrades.insert(.reunionSpirit)

    VisitManager.applyReunionBoost(state: state)

    let boost = state.prestigeState.activeReunionBoost!
    #expect(boost.durationSeconds == GameConfig.Prestige.reunionEnhancedDurationSeconds)
    #expect(boost.happinessBoost == GameConfig.Prestige.reunionEnhancedHappinessBoost)
}

// MARK: - Visit Streak

@Test @MainActor func recordVisitFirstVisitSetsStreakTo1() {
    let state = GameState()
    VisitManager.recordVisit(state: state)
    #expect(state.prestigeState.visitStreak.currentStreak == 1)
}

@Test @MainActor func recordVisitConsecutiveDaysIncrementsStreak() {
    let state = GameState()
    // Visits on different calendar days but within the 24h streak window
    let day1 = Calendar.current.startOfDay(for: Date()).addingTimeInterval(23 * 3600) // 11 PM
    let day2 = day1.addingTimeInterval(9 * 3600) // 8 AM next day (9h later, within 24h)

    VisitManager.recordVisit(state: state, now: day1)
    #expect(state.prestigeState.visitStreak.currentStreak == 1)

    VisitManager.recordVisit(state: state, now: day2)
    #expect(state.prestigeState.visitStreak.currentStreak == 2)
}

@Test func recordVisitSameDayDoesNotIncrementStreak() {
    var streak = VisitStreak()
    let morning = Calendar.current.startOfDay(for: Date()).addingTimeInterval(8 * 3600)
    let evening = morning.addingTimeInterval(10 * 3600) // same day, 10h later

    streak.recordVisit(at: morning)
    #expect(streak.currentStreak == 1)

    streak.recordVisit(at: evening)
    #expect(streak.currentStreak == 1) // still 1 — same calendar day
    #expect(streak.lastVisitDate == evening) // but lastVisitDate refreshed
}

@Test func recordVisitSameDayMultipleTimesStaysAt1() {
    var streak = VisitStreak()
    let base = Calendar.current.startOfDay(for: Date()).addingTimeInterval(6 * 3600)

    streak.recordVisit(at: base)
    streak.recordVisit(at: base.addingTimeInterval(3600))
    streak.recordVisit(at: base.addingTimeInterval(7200))
    streak.recordVisit(at: base.addingTimeInterval(10800))

    #expect(streak.currentStreak == 1) // four visits, still day 1
}

@Test func recordVisitCrossDayThenSameDayDeduplicates() {
    var streak = VisitStreak()
    // day1 at 11 PM, day2 at 8 AM next day (within 24h window, different calendar day)
    let day1 = Calendar.current.startOfDay(for: Date()).addingTimeInterval(23 * 3600)
    let day2 = day1.addingTimeInterval(9 * 3600) // 8 AM next day
    let day2Later = day2.addingTimeInterval(6 * 3600) // 2 PM same day

    streak.recordVisit(at: day1)
    #expect(streak.currentStreak == 1)

    streak.recordVisit(at: day2)
    #expect(streak.currentStreak == 2)

    streak.recordVisit(at: day2Later) // same day as day2
    #expect(streak.currentStreak == 2) // no double increment
}

@Test @MainActor func recordVisitAfter24hResetsStreak() {
    let state = GameState()
    let now = Date()
    VisitManager.recordVisit(state: state, now: now)
    #expect(state.prestigeState.visitStreak.currentStreak == 1)

    let later = now.addingTimeInterval(25 * 3600) // 25 hours later
    VisitManager.recordVisit(state: state, now: later)
    #expect(state.prestigeState.visitStreak.currentStreak == 1)
}

// MARK: - Streak Bonuses

@Test func streakDay2BreedingBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 2
    #expect(streak.breedingChanceBonus == GameConfig.Prestige.streakDay2BreedingBonus)
}

@Test func streakDay1NoBreedingBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 1
    #expect(streak.breedingChanceBonus == 0)
}

@Test func streakDay5SaleBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 5
    #expect(streak.saleValueBonus == GameConfig.Prestige.streakDay5SaleBonus)
}

@Test func streakDay4NoSaleBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 4
    #expect(streak.saleValueBonus == 0)
}

@Test func streakBonusTreatsDay3() {
    var streak = VisitStreak()
    streak.currentStreak = 3
    #expect(streak.bonusTreats == 1)
}

@Test func streakBonusTreatsDay7() {
    var streak = VisitStreak()
    streak.currentStreak = 7
    #expect(streak.bonusTreats == 2)
}

@Test func streakBonusRosettesDay7() {
    var streak = VisitStreak()
    streak.currentStreak = 7
    #expect(streak.bonusRosettes == 1)
}

@Test func streakBonusRosettesDay14() {
    var streak = VisitStreak()
    streak.currentStreak = 14
    #expect(streak.bonusRosettes == 2)
}

@Test func streakBonusRosettesDay30() {
    var streak = VisitStreak()
    streak.currentStreak = 30
    #expect(streak.bonusRosettes == 5)
}

// MARK: - Treat Capacity

@Test @MainActor func treatCapacityBase() {
    let state = GameState()
    #expect(state.prestigeState.treatsPerVisit == GameConfig.Prestige.baseTreatsPerVisit)
}

@Test @MainActor func treatCapacityWithTreatPouch() {
    let state = GameState()
    state.prestigeState.purchasedUpgrades.insert(.treatPouch)
    #expect(state.prestigeState.treatsPerVisit
        == GameConfig.Prestige.baseTreatsPerVisit + GameConfig.Prestige.treatPouchBonusTreats)
}

@Test @MainActor func treatCapacityWithStreakDay3() {
    let state = GameState()
    state.prestigeState.visitStreak.currentStreak = 3
    #expect(state.prestigeState.treatsPerVisit == GameConfig.Prestige.baseTreatsPerVisit + 1)
}

@Test @MainActor func treatCapacityWithStreakDay7() {
    let state = GameState()
    state.prestigeState.visitStreak.currentStreak = 7
    #expect(state.prestigeState.treatsPerVisit == GameConfig.Prestige.baseTreatsPerVisit + 2)
}

@Test @MainActor func treatCapacityCombined() {
    let state = GameState()
    state.prestigeState.purchasedUpgrades.insert(.treatPouch)
    state.prestigeState.visitStreak.currentStreak = 7
    let expected = GameConfig.Prestige.baseTreatsPerVisit
        + GameConfig.Prestige.treatPouchBonusTreats + 2
    #expect(state.prestigeState.treatsPerVisit == expected)
}

@Test @MainActor func resetTreatCapacitySetsRemainingToFull() {
    let state = GameState()
    state.remainingTreatsThisVisit = 0
    VisitManager.resetTreatCapacity(state: state)
    #expect(state.remainingTreatsThisVisit == state.prestigeState.treatsPerVisit)
}

// MARK: - Process Visit (full pipeline)

@Test @MainActor func processVisitReturnsTrueOnValidVisit() {
    let state = GameState()
    state.lastBackgroundDate = Date().addingTimeInterval(-7200)
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.happiness = 50.0
    state.addGuineaPig(pig)

    let result = VisitManager.processVisit(state: state)
    #expect(result)
    #expect(state.prestigeState.visitStreak.currentStreak == 1)
    #expect(state.prestigeState.activeReunionBoost != nil)
    #expect(state.remainingTreatsThisVisit == state.prestigeState.treatsPerVisit)
}

@Test @MainActor func processVisitReturnsFalseWhenNoAbsence() {
    let state = GameState()
    state.lastBackgroundDate = Date().addingTimeInterval(-60) // 1 minute
    #expect(!VisitManager.processVisit(state: state))
}

// MARK: - Bonus Queries

@Test @MainActor func breedingBonusWithActiveBoostAndStreak() {
    var prestige = PrestigeState()
    prestige.activeReunionBoost = ReunionBoost.standard()
    prestige.visitStreak.currentStreak = 2

    let bonus = VisitManager.breedingBonus(prestige: prestige)
    let expected = GameConfig.Prestige.reunionBreedingBonus
        + GameConfig.Prestige.streakDay2BreedingBonus
    #expect(bonus == expected)
}

@Test @MainActor func breedingBonusWithExpiredBoost() {
    var prestige = PrestigeState()
    prestige.activeReunionBoost = ReunionBoost.standard(
        at: Date().addingTimeInterval(-2000)
    )
    prestige.visitStreak.currentStreak = 1

    let bonus = VisitManager.breedingBonus(prestige: prestige)
    #expect(bonus == 0)
}

@Test @MainActor func saleMultiplierWithActiveBoostAndStreak() {
    var prestige = PrestigeState()
    prestige.activeReunionBoost = ReunionBoost.standard()
    prestige.visitStreak.currentStreak = 5

    let mult = VisitManager.saleMultiplier(prestige: prestige)
    let expected = 1.0 + GameConfig.Prestige.reunionSaleBonus
        + GameConfig.Prestige.streakDay5SaleBonus
    #expect(mult == expected)
}

@Test @MainActor func saleMultiplierNoBonus() {
    let prestige = PrestigeState()
    let mult = VisitManager.saleMultiplier(prestige: prestige)
    #expect(mult == 1.0)
}

// MARK: - Cooldown Gating

@Test @MainActor func processVisitSkipsTreatRefillWhenOnCooldown() {
    let state = GameState()
    let now = Date()
    // First visit: 2 hours ago (sets lastVisitDate)
    state.lastBackgroundDate = now.addingTimeInterval(-7200)
    VisitManager.processVisit(state: state, now: now.addingTimeInterval(-7200 + 3601))

    // Second visit: now, only 1h since last visit (under 4h cooldown)
    state.lastBackgroundDate = now.addingTimeInterval(-3700)
    state.remainingTreatsThisVisit = 0
    let result = VisitManager.processVisit(state: state, now: now)
    #expect(result) // visit still processes (boost + streak)
    #expect(state.remainingTreatsThisVisit == 0) // treats NOT refilled (cooldown)
}

@Test @MainActor func processVisitRefillsTreatsAfterCooldownExpires() {
    let state = GameState()
    let now = Date()
    // Last visit was 5 hours ago (cooldown expired)
    state.prestigeState.visitStreak.lastVisitDate = now.addingTimeInterval(-18000)
    state.lastBackgroundDate = now.addingTimeInterval(-7200)
    state.remainingTreatsThisVisit = 0
    VisitManager.processVisit(state: state, now: now)
    #expect(state.remainingTreatsThisVisit == state.prestigeState.treatsPerVisit)
}
