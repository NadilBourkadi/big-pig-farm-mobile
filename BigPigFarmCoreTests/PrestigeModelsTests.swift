/// PrestigeModelsTests — Tests for all prestige data model types.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - ShowroomUpgrade Tests

@Test func showroomUpgradeHas23Cases() {
    #expect(ShowroomUpgrade.allCases.count == 23)
}

@Test func showroomUpgradeTier1Has5Cases() {
    let tier1 = ShowroomUpgrade.allCases.filter { $0.tier == .newcomer }
    #expect(tier1.count == 5)
}

@Test func showroomUpgradeTier2Has6Cases() {
    let tier2 = ShowroomUpgrade.allCases.filter { $0.tier == .apprentice }
    #expect(tier2.count == 6)
}

@Test func showroomUpgradeTier3Has6Cases() {
    let tier3 = ShowroomUpgrade.allCases.filter { $0.tier == .expert }
    #expect(tier3.count == 6)
}

@Test func showroomUpgradeTier4Has6Cases() {
    let tier4 = ShowroomUpgrade.allCases.filter { $0.tier == .master }
    #expect(tier4.count == 6)
}

@Test func showroomUpgradeTotalCostIs372() {
    let total = ShowroomUpgrade.allCases.reduce(0) { $0 + $1.cost }
    #expect(total == 372)
}

@Test func showroomUpgradeTier1TotalIs15() {
    let total = ShowroomUpgrade.allCases
        .filter { $0.tier == .newcomer }
        .reduce(0) { $0 + $1.cost }
    #expect(total == 15)
}

@Test func showroomUpgradeTier2TotalIs37() {
    let total = ShowroomUpgrade.allCases
        .filter { $0.tier == .apprentice }
        .reduce(0) { $0 + $1.cost }
    #expect(total == 37)
}

@Test func showroomUpgradeTier3TotalIs90() {
    let total = ShowroomUpgrade.allCases
        .filter { $0.tier == .expert }
        .reduce(0) { $0 + $1.cost }
    #expect(total == 90)
}

@Test func showroomUpgradeTier4TotalIs230() {
    let total = ShowroomUpgrade.allCases
        .filter { $0.tier == .master }
        .reduce(0) { $0 + $1.cost }
    #expect(total == 230)
}

@Test func showroomUpgradeSpotCheckCosts() {
    #expect(ShowroomUpgrade.expandedHutch.cost == 3)
    #expect(ShowroomUpgrade.rapidRecovery.cost == 2)
    #expect(ShowroomUpgrade.keepsakeSlot.cost == 50)
    #expect(ShowroomUpgrade.selectiveAdvantage.cost == 45)
    #expect(ShowroomUpgrade.treatPouch.cost == 5)
    #expect(ShowroomUpgrade.reunionSpirit.cost == 12)
}

@Test func showroomUpgradeRoundTripJSON() throws {
    let original: Set<ShowroomUpgrade> = [.expandedHutch, .twinSpark, .keepsakeSlot]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Set<ShowroomUpgrade>.self, from: data)
    #expect(decoded == original)
}

@Test func showroomUpgradeSnakeCaseRawValues() {
    #expect(ShowroomUpgrade.expandedHutch.rawValue == "expanded_hutch")
    #expect(ShowroomUpgrade.fertileGround.rawValue == "fertile_ground")
    #expect(ShowroomUpgrade.geneticImprinting.rawValue == "genetic_imprinting")
    #expect(ShowroomUpgrade.keepsakeSlot.rawValue == "keepsake_slot")
}

@Test func showroomUpgradeDisplayNames() {
    #expect(ShowroomUpgrade.expandedHutch.displayName == "Expanded Hutch")
    #expect(ShowroomUpgrade.goldenTouch.displayName == "Golden Touch")
}

// MARK: - RosetteCalculator Tests

@Test func rosetteCalculatorFirstPrestige() {
    let input = RosetteInput(
        lifetimeSqueaks: 50_000, newPigdexEntries: 25,
        uniquePhenotypesInHerd: 15, contractsCompleted: 4,
        hasLegendaryPig: false, visitStreakBonusRosettes: 0)
    #expect(RosetteCalculator.calculate(input) == 10)
}

@Test func rosetteCalculatorSecondPrestige() {
    let input = RosetteInput(
        lifetimeSqueaks: 150_000, newPigdexEntries: 20,
        uniquePhenotypesInHerd: 25, contractsCompleted: 8,
        hasLegendaryPig: false, visitStreakBonusRosettes: 0)
    #expect(RosetteCalculator.calculate(input) == 13)
}

@Test func rosetteCalculatorLatePrestige() {
    let input = RosetteInput(
        lifetimeSqueaks: 500_000, newPigdexEntries: 15,
        uniquePhenotypesInHerd: 40, contractsCompleted: 15,
        hasLegendaryPig: true, visitStreakBonusRosettes: 0)
    #expect(RosetteCalculator.calculate(input) == 23)
}

@Test func rosetteCalculatorEndgamePrestige() {
    let input = RosetteInput(
        lifetimeSqueaks: 2_000_000, newPigdexEntries: 5,
        uniquePhenotypesInHerd: 50, contractsCompleted: 25,
        hasLegendaryPig: true, visitStreakBonusRosettes: 0)
    #expect(RosetteCalculator.calculate(input) == 35)
}

@Test func rosetteCalculatorWithStreakBonus() {
    let input = RosetteInput(
        lifetimeSqueaks: 50_000, newPigdexEntries: 25,
        uniquePhenotypesInHerd: 15, contractsCompleted: 4,
        hasLegendaryPig: false, visitStreakBonusRosettes: 5)
    #expect(RosetteCalculator.calculate(input) == 15)
}

@Test func rosetteBreakdownMatchesTotal() {
    let input = RosetteInput(
        lifetimeSqueaks: 500_000, newPigdexEntries: 15,
        uniquePhenotypesInHerd: 40, contractsCompleted: 15,
        hasLegendaryPig: true, visitStreakBonusRosettes: 0)
    let bd = RosetteCalculator.breakdown(input)
    #expect(bd.total == RosetteCalculator.calculate(input))
    #expect(bd.baseRosettes == 10)
    #expect(bd.pigdexBonus == 3)
    #expect(bd.diversityBonus == 4)
    #expect(bd.contractBonus == 5)
    #expect(bd.rarityBonus == 1)
    #expect(bd.streakBonus == 0)
}

@Test func rosetteCalculatorZeroInput() {
    let input = RosetteInput(
        lifetimeSqueaks: 0, newPigdexEntries: 0,
        uniquePhenotypesInHerd: 0, contractsCompleted: 0,
        hasLegendaryPig: false, visitStreakBonusRosettes: 0)
    #expect(RosetteCalculator.calculate(input) == 0)
}

// MARK: - VisitStreak Tests

@Test func visitStreakInitialValues() {
    let streak = VisitStreak()
    #expect(streak.currentStreak == 0)
    #expect(streak.lastVisitDate == nil)
    #expect(streak.streakExpiresAt == nil)
}

@Test func visitStreakFirstVisit() {
    var streak = VisitStreak()
    let now = Date()
    let count = streak.recordVisit(at: now)
    #expect(count == 1)
    #expect(streak.currentStreak == 1)
    #expect(streak.lastVisitDate == now)
}

@Test func visitStreakConsecutiveVisit() {
    var streak = VisitStreak()
    let now = Date()
    streak.recordVisit(at: now)
    let later = now.addingTimeInterval(12 * 3600) // 12 hours later
    let count = streak.recordVisit(at: later)
    #expect(count == 2)
    #expect(streak.currentStreak == 2)
}

@Test func visitStreakBrokenAfter24h() {
    var streak = VisitStreak()
    let now = Date()
    streak.recordVisit(at: now)
    let tooLate = now.addingTimeInterval(25 * 3600) // 25 hours later
    let count = streak.recordVisit(at: tooLate)
    #expect(count == 1)
    #expect(streak.currentStreak == 1)
}

@Test func visitStreakExactly24hBreaks() {
    var streak = VisitStreak()
    let now = Date()
    streak.recordVisit(at: now)
    let exact24h = now.addingTimeInterval(86_400) // exactly 24h
    // At exactly 24h the window has expired (< not <=)
    #expect(!streak.isStreakActive(at: exact24h))
    let count = streak.recordVisit(at: exact24h)
    #expect(count == 1)
}

@Test func visitStreakJustBefore24h() {
    var streak = VisitStreak()
    let now = Date()
    streak.recordVisit(at: now)
    let justBefore = now.addingTimeInterval(86_400 - 1) // 23h59m59s
    #expect(streak.isStreakActive(at: justBefore))
    let count = streak.recordVisit(at: justBefore)
    #expect(count == 2)
}

@Test func visitStreakBonusTreats() {
    var streak = VisitStreak()
    streak.currentStreak = 2
    #expect(streak.bonusTreats == 0)
    streak.currentStreak = 3
    #expect(streak.bonusTreats == 1)
    streak.currentStreak = 6
    #expect(streak.bonusTreats == 1)
    streak.currentStreak = 7
    #expect(streak.bonusTreats == 2)
    streak.currentStreak = 30
    #expect(streak.bonusTreats == 2)
}

@Test func visitStreakBonusRosettes() {
    var streak = VisitStreak()
    streak.currentStreak = 6
    #expect(streak.bonusRosettes == 0)
    streak.currentStreak = 7
    #expect(streak.bonusRosettes == 1)
    streak.currentStreak = 13
    #expect(streak.bonusRosettes == 1)
    streak.currentStreak = 14
    #expect(streak.bonusRosettes == 2)
    streak.currentStreak = 29
    #expect(streak.bonusRosettes == 2)
    streak.currentStreak = 30
    #expect(streak.bonusRosettes == 5)
}

@Test func visitStreakBreedingBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 1
    #expect(streak.breedingChanceBonus == 0)
    streak.currentStreak = 2
    #expect(streak.breedingChanceBonus == 0.05)
}

@Test func visitStreakSaleBonus() {
    var streak = VisitStreak()
    streak.currentStreak = 4
    #expect(streak.saleValueBonus == 0)
    streak.currentStreak = 5
    #expect(streak.saleValueBonus == 0.10)
}

@Test func visitStreakTimeRemaining() {
    var streak = VisitStreak()
    let now = Date()
    streak.recordVisit(at: now)
    let halfwayThrough = now.addingTimeInterval(43_200) // 12h later
    let remaining = streak.timeRemainingSeconds(at: halfwayThrough)
    #expect(remaining == 43_200)
}

@Test func visitStreakCodableRoundTrip() throws {
    var original = VisitStreak()
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    original.recordVisit(at: t0)
    original.recordVisit(at: t0.addingTimeInterval(3600))
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(VisitStreak.self, from: data)
    #expect(decoded.currentStreak == original.currentStreak)
    #expect(decoded.lastVisitDate?.timeIntervalSince1970
            == original.lastVisitDate?.timeIntervalSince1970)
}

// MARK: - TreatType Tests

@Test func treatTypeHas4Cases() {
    #expect(TreatType.allCases.count == 4)
}

@Test func treatTypeRawValues() {
    #expect(TreatType.freshVeggies.rawValue == "fresh_veggies")
    #expect(TreatType.fruitSlices.rawValue == "fruit_slices")
    #expect(TreatType.herbBundle.rawValue == "herb_bundle")
    #expect(TreatType.haySampler.rawValue == "hay_sampler")
}

@Test func treatTypeFreshVeggiesEffects() {
    let info = TreatType.freshVeggies.info
    #expect(info.hungerBoost == 30)
    #expect(info.happinessBoost == 10)
    #expect(info.healthBoost == 0)
    #expect(info.requiredTier == 1)
}

@Test func treatTypeFruitSlicesEffects() {
    let info = TreatType.fruitSlices.info
    #expect(info.happinessBoost == 25)
    #expect(info.breedingChanceBoost == 0.05)
    #expect(info.breedingBoostDurationHours == 2)
    #expect(info.requiredTier == 2)
}

@Test func treatTypeHerbBundleEffects() {
    let info = TreatType.herbBundle.info
    #expect(info.healthBoost == 15)
    #expect(info.needDecayReduction == 0.20)
    #expect(info.needDecayDurationHours == 2)
    #expect(info.requiredTier == 3)
}

@Test func treatTypeHaySamplerEffects() {
    let info = TreatType.haySampler.info
    #expect(info.socialBoost == 20)
    #expect(info.socialRadius == 4)
    #expect(info.requiredTier == 4)
}

@Test func treatTypeCodableRoundTrip() throws {
    let original = TreatType.herbBundle
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TreatType.self, from: data)
    #expect(decoded == original)
}

// MARK: - BiomeMastery Tests

@Test func biomeMasteryInitiallyEmpty() {
    let mastery = BiomeMastery()
    for biome in BiomeType.allCases {
        #expect(mastery.pigsBred(in: biome) == 0)
        #expect(!mastery.isMastered(biome))
    }
}

@Test func biomeMasteryRecordBirth() {
    var mastery = BiomeMastery()
    mastery.recordBirth(in: .meadow)
    mastery.recordBirth(in: .meadow)
    mastery.recordBirth(in: .alpine)
    #expect(mastery.pigsBred(in: .meadow) == 2)
    #expect(mastery.pigsBred(in: .alpine) == 1)
}

@Test func biomeMasteryNotMasteredBelow10() {
    var mastery = BiomeMastery()
    for _ in 0..<9 {
        mastery.recordBirth(in: .garden)
    }
    #expect(!mastery.isMastered(.garden))
}

@Test func biomeMasteryMasteredAt10() {
    var mastery = BiomeMastery()
    for _ in 0..<10 {
        mastery.recordBirth(in: .garden)
    }
    #expect(mastery.isMastered(.garden))
}

@Test func biomeMasteryProgress() {
    var mastery = BiomeMastery()
    #expect(mastery.masteryProgress(for: .tropical) == 0.0)
    for _ in 0..<5 {
        mastery.recordBirth(in: .tropical)
    }
    #expect(mastery.masteryProgress(for: .tropical) == 0.5)
    for _ in 0..<10 {
        mastery.recordBirth(in: .tropical)
    }
    // 15 bred, capped at 1.0
    #expect(mastery.masteryProgress(for: .tropical) == 1.0)
}

@Test func biomeMasteryMasteredBiomes() {
    var mastery = BiomeMastery()
    for _ in 0..<10 {
        mastery.recordBirth(in: .meadow)
        mastery.recordBirth(in: .crystal)
    }
    let mastered = mastery.masteredBiomes
    #expect(mastered.contains(.meadow))
    #expect(mastered.contains(.crystal))
    #expect(!mastered.contains(.alpine))
}

@Test func biomeMasteryCodableRoundTrip() throws {
    var original = BiomeMastery()
    for _ in 0..<5 {
        original.recordBirth(in: .meadow)
    }
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BiomeMastery.self, from: data)
    #expect(decoded.pigsBred(in: .meadow) == 5)
}

// MARK: - ReunionBoost Tests

@Test func reunionBoostStandardValues() {
    let now = Date()
    let boost = ReunionBoost.standard(at: now)
    #expect(boost.durationSeconds == 1800)
    #expect(boost.happinessBoost == 15.0)
    #expect(boost.breedingChanceBonus == 0.10)
    #expect(boost.saleValueBonus == 0.10)
}

@Test func reunionBoostEnhancedValues() {
    let now = Date()
    let boost = ReunionBoost.enhanced(at: now)
    #expect(boost.durationSeconds == 3600)
    #expect(boost.happinessBoost == 22.0)
    #expect(boost.breedingChanceBonus == 0.15)
    #expect(boost.saleValueBonus == 0.15)
}

@Test func reunionBoostIsActive() {
    let now = Date()
    let boost = ReunionBoost.standard(at: now)
    let during = now.addingTimeInterval(900) // 15 min later
    #expect(boost.isActive(at: during))
}

@Test func reunionBoostExpired() {
    let now = Date()
    let boost = ReunionBoost.standard(at: now)
    let after = now.addingTimeInterval(1801) // just past 30 min
    #expect(!boost.isActive(at: after))
}

@Test func reunionBoostTimeRemaining() {
    let now = Date()
    let boost = ReunionBoost.standard(at: now)
    let during = now.addingTimeInterval(600) // 10 min later
    #expect(boost.timeRemainingSeconds(at: during) == 1200)
    let after = now.addingTimeInterval(2000)
    #expect(boost.timeRemainingSeconds(at: after) == 0)
}

@Test func reunionBoostCodableRoundTrip() throws {
    let original = ReunionBoost.standard(at: Date(timeIntervalSince1970: 1_000_000))
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ReunionBoost.self, from: data)
    #expect(decoded.activatedAt.timeIntervalSince1970
            == original.activatedAt.timeIntervalSince1970)
    #expect(decoded.durationSeconds == original.durationSeconds)
    #expect(decoded.happinessBoost == original.happinessBoost)
}

// MARK: - PrestigeState Tests

@Test func prestigeStateDefaultValues() {
    let state = PrestigeState()
    #expect(state.rosetteBalance == 0)
    #expect(state.purchasedUpgrades.isEmpty)
    #expect(state.farmCount == 1)
    #expect(state.previousPigdexEntries.isEmpty)
    #expect(state.lifetimeStats.totalPigsBred == 0)
    #expect(state.visitStreak.currentStreak == 0)
    #expect(state.biomeMastery.masteredBiomes.isEmpty)
    #expect(state.keepsakePerks.isEmpty)
    #expect(state.activeReunionBoost == nil)
}

@Test func prestigeStatePurchaseUpgrade() {
    var state = PrestigeState()
    state.rosetteBalance = 10
    let success = state.purchaseUpgrade(.expandedHutch) // costs 3
    #expect(success)
    #expect(state.rosetteBalance == 7)
    #expect(state.hasUpgrade(.expandedHutch))
}

@Test func prestigeStatePurchaseInsufficientRosettes() {
    var state = PrestigeState()
    state.rosetteBalance = 1
    let success = state.purchaseUpgrade(.expandedHutch) // costs 3
    #expect(!success)
    #expect(state.rosetteBalance == 1)
    #expect(!state.hasUpgrade(.expandedHutch))
}

@Test func prestigeStatePurchaseDuplicate() {
    var state = PrestigeState()
    state.rosetteBalance = 100
    state.purchaseUpgrade(.twinSpark) // costs 4
    let duplicate = state.purchaseUpgrade(.twinSpark)
    #expect(!duplicate)
    #expect(state.rosetteBalance == 96) // only deducted once
}

@Test func prestigeStateHasUpgrade() {
    var state = PrestigeState()
    #expect(!state.hasUpgrade(.fertileGround))
    state.purchasedUpgrades.insert(.fertileGround)
    #expect(state.hasUpgrade(.fertileGround))
}

@Test func prestigeStateTreatsPerVisitBase() {
    let state = PrestigeState()
    #expect(state.treatsPerVisit == GameConfig.Prestige.baseTreatsPerVisit)
}

@Test func prestigeStateTreatsPerVisitWithPouch() {
    var state = PrestigeState()
    state.purchasedUpgrades.insert(.treatPouch)
    #expect(state.treatsPerVisit == GameConfig.Prestige.baseTreatsPerVisit
            + GameConfig.Prestige.treatPouchBonusTreats)
}

@Test func prestigeStateTreatsPerVisitWithStreak() {
    var state = PrestigeState()
    state.visitStreak.currentStreak = 7 // +2 bonus treats
    state.purchasedUpgrades.insert(.treatPouch) // +2 more
    #expect(state.treatsPerVisit == 2 + 2 + 2) // base + streak + pouch
}

@Test func prestigeStateCarryOverPigdex() {
    var state = PrestigeState()
    var pigdex = Pigdex()
    pigdex.discovered["black:solid:full:none"] = 1
    pigdex.discovered["cream:dutch:full:none"] = 5
    state.carryOverPigdex(pigdex)
    #expect(state.previousPigdexEntries.count == 2)
    #expect(state.previousPigdexEntries.contains("black:solid:full:none"))
    #expect(state.previousPigdexEntries.contains("cream:dutch:full:none"))
}

@Test func prestigeStateCarryOverPigdexEmpty() {
    var state = PrestigeState()
    state.previousPigdexEntries = ["existing:key:here:none"]
    state.carryOverPigdex(Pigdex())
    #expect(state.previousPigdexEntries.count == 1)
}

@Test func prestigeStateCarryOverPigdexIdempotent() {
    var state = PrestigeState()
    var pigdex = Pigdex()
    pigdex.discovered["black:solid:full:none"] = 1
    state.carryOverPigdex(pigdex)
    state.carryOverPigdex(pigdex) // second call should be no-op
    #expect(state.previousPigdexEntries.count == 1)
}

@Test func prestigeStateCarryOverPigdexPartialOverlap() {
    var state = PrestigeState()
    state.previousPigdexEntries = ["black:solid:full:none"]
    var pigdex = Pigdex()
    pigdex.discovered["black:solid:full:none"] = 1 // already exists
    pigdex.discovered["cream:dutch:full:none"] = 5  // new
    state.carryOverPigdex(pigdex)
    #expect(state.previousPigdexEntries.count == 2)
    #expect(state.previousPigdexEntries.contains("cream:dutch:full:none"))
}

@Test func prestigeStateAddRosettes() {
    var state = PrestigeState()
    state.addRosettes(10)
    #expect(state.rosetteBalance == 10)
    state.addRosettes(5)
    #expect(state.rosetteBalance == 15)
}

@Test func prestigeStateCodableRoundTrip() throws {
    var original = PrestigeState()
    original.rosetteBalance = 42
    original.purchasedUpgrades = [.expandedHutch, .twinSpark]
    original.farmCount = 3
    original.previousPigdexEntries = ["black:solid:full:none"]
    original.lifetimeStats.totalPigsBred = 500
    original.lifetimeStats.totalSqueaksEarned = 100_000
    original.keepsakePerks = ["auto_feeders"]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(PrestigeState.self, from: data)
    #expect(decoded.rosetteBalance == 42)
    #expect(decoded.purchasedUpgrades == [.expandedHutch, .twinSpark])
    #expect(decoded.farmCount == 3)
    #expect(decoded.previousPigdexEntries.contains("black:solid:full:none"))
    #expect(decoded.lifetimeStats.totalPigsBred == 500)
    #expect(decoded.keepsakePerks == ["auto_feeders"])
}

// MARK: - PrestigeConfig Tests

@Test func prestigeConfigRosetteFormulaConstants() {
    #expect(GameConfig.Prestige.rosetteBaseDivisor == 5000)
    #expect(GameConfig.Prestige.rosettePigdexDivisor == 5)
    #expect(GameConfig.Prestige.rosetteDiversityDivisor == 10)
    #expect(GameConfig.Prestige.rosetteContractDivisor == 3)
}

@Test func prestigeConfigVisitConstants() {
    #expect(GameConfig.Prestige.visitCooldownSeconds == 14_400)
    #expect(GameConfig.Prestige.streakWindowSeconds == 86_400)
    #expect(GameConfig.Prestige.reunionMinOfflineSeconds == 3600)
}

@Test func prestigeConfigReunionConstants() {
    #expect(GameConfig.Prestige.reunionDurationSeconds == 1800)
    #expect(GameConfig.Prestige.reunionHappinessBoost == 15.0)
    #expect(GameConfig.Prestige.reunionBreedingBonus == 0.10)
    #expect(GameConfig.Prestige.reunionSaleBonus == 0.10)
    #expect(GameConfig.Prestige.reunionEnhancedDurationSeconds == 3600)
}

@Test func prestigeConfigBiomeMasteryConstants() {
    #expect(GameConfig.Prestige.biomeMasteryThreshold == 10)
    #expect(GameConfig.Prestige.biomeMasteryCostReduction == 0.25)
    #expect(GameConfig.Prestige.biomeMasteryMutationBoost == 0.02)
}

@Test func prestigeConfigTreatConstants() {
    #expect(GameConfig.Prestige.baseTreatsPerVisit == 2)
    #expect(GameConfig.Prestige.treatsPerScatter == 4)
    #expect(GameConfig.Prestige.treatPouchBonusTreats == 2)
}

@Test func prestigeConfigUpgradeEffectConstants() {
    #expect(GameConfig.Prestige.expandedHutchCapacityBonus == 2)
    #expect(GameConfig.Prestige.twinSparkChance == 0.10)
    #expect(GameConfig.Prestige.fertileGroundBreedingChance == 0.10)
    #expect(GameConfig.Prestige.goldenTouchSaleBonus == 0.25)
    #expect(GameConfig.Prestige.keepsakeMaxSlots == 3)
}
