/// NeedsBehaviorAndQueryTests — Tests for behavior recovery, urgency, facility lookup, and wellbeing.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Biome & Perk Bonuses

@Test @MainActor func preferredBiomeHappinessBonus() {
    let state = GameState()
    var pig = makeNeedsPig(
        happiness: 50.0, position: Position(x: 5, y: 5), preferredBiome: "meadow"
    )
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 50.0 + GameConfig.Needs.happinessContentmentRecovery
        + GameConfig.Biome.preferredBiomeHappinessBonus
    #expect(abs(pig.needs.happiness - expected) < 0.01)
}

@Test @MainActor func climateControlPerkBonus() {
    let state = GameState()
    state.purchasedUpgrades.insert("climate_control")
    var pig = makeNeedsPig(happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 50.0 + GameConfig.Needs.happinessContentmentRecovery + 0.3
    #expect(abs(pig.needs.happiness - expected) < 0.01)
}

// MARK: - Behavior Recovery

@Test @MainActor func eatingRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 20.0, happiness: 50.0, behaviorState: .eating)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    // eating: hunger += 80.0/hr (40 * 2), decay -= 0.6/hr → net +79.4
    let expected = 20.0 - GameConfig.Needs.hungerDecay + GameConfig.Needs.foodRecovery * 2
    #expect(abs(pig.needs.hunger - expected) < 0.01)
}

@Test @MainActor func drinkingRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(thirst: 20.0, behaviorState: .drinking)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = min(
        100.0,
        20.0 - GameConfig.Needs.thirstDecay + GameConfig.Needs.waterRecovery * 2
    )
    #expect(abs(pig.needs.thirst - expected) < 0.01)
}

@Test @MainActor func sleepingRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(energy: 50.0, health: 80.0, behaviorState: .sleeping)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expectedEnergy = 50.0 - GameConfig.Needs.energyDecay
        + GameConfig.Needs.sleepRecoveryPerHour
    #expect(abs(pig.needs.energy - expectedEnergy) < 0.01)
    // health: passive recovery(1.0) + sleep recovery(1.5) = 2.5
    let expectedHealth = 80.0 + GameConfig.Needs.healthPassiveRecovery
        + GameConfig.Needs.healthSleepRecovery
    #expect(abs(pig.needs.health - expectedHealth) < 0.01)
}

@Test @MainActor func sleepingWithPremiumBedding() {
    let state = GameState()
    state.purchasedUpgrades.insert("premium_bedding")
    var pig = makeNeedsPig(energy: 50.0, behaviorState: .sleeping)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 50.0 - GameConfig.Needs.energyDecay
        + GameConfig.Needs.sleepRecoveryPerHour * 1.25
    #expect(abs(pig.needs.energy - expected) < 0.01)
}

@Test @MainActor func playingRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(
        energy: 80.0, happiness: 50.0, boredom: 50.0, behaviorState: .playing
    )
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expectedBoredom = 50.0 + GameConfig.Needs.boredomDecay
        - GameConfig.Needs.boredomPlayRecovery
    #expect(abs(pig.needs.boredom - expectedBoredom) < 0.01)
}

@Test @MainActor func socializingRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(happiness: 50.0, social: 50.0, behaviorState: .socializing)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    // social: decay alone(-2.0) + socializing recovery(+10.0) = +8.0
    let expectedSocial = 50.0 - GameConfig.Needs.socialDecayAlone
        + GameConfig.Needs.socialRecovery
    #expect(abs(pig.needs.social - expectedSocial) < 0.01)
}

// MARK: - getMostUrgentNeed

@Test @MainActor func mostUrgentThirstCritical() {
    let pig = makeNeedsPig(hunger: 50.0, thirst: 10.0)
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "thirst")
}

@Test @MainActor func mostUrgentHungerCritical() {
    let pig = makeNeedsPig(hunger: 10.0, thirst: 50.0)
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "hunger")
}

@Test @MainActor func mostUrgentEnergyLow() {
    let pig = makeNeedsPig(hunger: 50.0, thirst: 50.0, energy: 30.0)
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "energy")
}

@Test @MainActor func mostUrgentModeratelyLow() {
    let pig = makeNeedsPig(
        hunger: 80.0, thirst: 60.0, energy: 80.0, happiness: 80.0, social: 80.0
    )
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "thirst")
}

@Test @MainActor func mostUrgentNoneWhenAllHigh() {
    let pig = makeNeedsPig(
        hunger: 80.0, thirst: 80.0, energy: 80.0, happiness: 80.0, social: 80.0
    )
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "none")
}

@Test @MainActor func mostUrgentThirstBeforeHunger() {
    let pig = makeNeedsPig(hunger: 10.0, thirst: 10.0)
    #expect(NeedsSystem.getMostUrgentNeed(pig) == "thirst")
}

// MARK: - getTargetFacilityForNeed

@Test @MainActor func facilityForHunger() {
    #expect(NeedsSystem.getTargetFacilityForNeed("hunger") == [.hayRack, .feastTable, .foodBowl])
}

@Test @MainActor func facilityForThirst() {
    #expect(NeedsSystem.getTargetFacilityForNeed("thirst") == [.waterBottle])
}

@Test @MainActor func facilityForEnergy() {
    #expect(NeedsSystem.getTargetFacilityForNeed("energy") == [.hideout])
}

@Test @MainActor func facilityForHappiness() {
    let result = NeedsSystem.getTargetFacilityForNeed("happiness")
    #expect(result == [.playArea, .exerciseWheel, .tunnel])
}

@Test @MainActor func facilityForSocial() {
    #expect(NeedsSystem.getTargetFacilityForNeed("social") == [.playArea])
}

@Test @MainActor func facilityForNoneReturnsNil() {
    #expect(NeedsSystem.getTargetFacilityForNeed("none") == nil)
}

@Test @MainActor func facilityForUnknownReturnsNil() {
    #expect(NeedsSystem.getTargetFacilityForNeed("xyz") == nil)
}

// MARK: - calculateOverallWellbeing

@Test @MainActor func wellbeingPerfectNeeds() {
    let pig = makeNeedsPig(
        hunger: 100.0, thirst: 100.0, energy: 100.0,
        happiness: 100.0, health: 100.0
    )
    #expect(abs(NeedsSystem.calculateOverallWellbeing(pig) - 100.0) < 0.01)
}

@Test @MainActor func wellbeingAllZero() {
    let pig = makeNeedsPig(
        hunger: 0.0, thirst: 0.0, energy: 0.0,
        happiness: 0.0, health: 0.0
    )
    #expect(abs(NeedsSystem.calculateOverallWellbeing(pig)) < 0.01)
}

@Test @MainActor func wellbeingWeightedCorrectly() {
    let pig = makeNeedsPig(
        hunger: 80.0, thirst: 60.0, energy: 40.0,
        happiness: 50.0, health: 90.0
    )
    let expected = 80.0 * 0.25 + 60.0 * 0.25 + 40.0 * 0.15 + 50.0 * 0.20 + 90.0 * 0.15
    #expect(abs(NeedsSystem.calculateOverallWellbeing(pig) - expected) < 0.01)
}

// MARK: - precomputeNearbyCounts

@Test @MainActor func nearbyCountsTwoPigsClose() {
    var pigA = GuineaPig.create(name: "A", gender: .male)
    pigA.position = Position(x: 5.0, y: 5.0)
    var pigB = GuineaPig.create(name: "B", gender: .female)
    pigB.position = Position(x: 6.0, y: 5.0)
    let counts = NeedsSystem.precomputeNearbyCounts(pigs: [pigA, pigB], radius: 8.0)
    #expect(counts[pigA.id] == 1)
    #expect(counts[pigB.id] == 1)
}

@Test @MainActor func nearbyCountsTwoPigsFar() {
    var pigA = GuineaPig.create(name: "A", gender: .male)
    pigA.position = Position(x: 0.0, y: 0.0)
    var pigB = GuineaPig.create(name: "B", gender: .female)
    pigB.position = Position(x: 50.0, y: 50.0)
    let counts = NeedsSystem.precomputeNearbyCounts(pigs: [pigA, pigB], radius: 8.0)
    #expect(counts[pigA.id] == 0)
    #expect(counts[pigB.id] == 0)
}

@Test @MainActor func nearbyCountsThreePigsPartial() {
    var pigA = GuineaPig.create(name: "A", gender: .male)
    pigA.position = Position(x: 5.0, y: 5.0)
    var pigB = GuineaPig.create(name: "B", gender: .female)
    pigB.position = Position(x: 6.0, y: 5.0)
    var pigC = GuineaPig.create(name: "C", gender: .male)
    pigC.position = Position(x: 50.0, y: 50.0)
    let counts = NeedsSystem.precomputeNearbyCounts(pigs: [pigA, pigB, pigC], radius: 8.0)
    #expect(counts[pigA.id] == 1)
    #expect(counts[pigB.id] == 1)
    #expect(counts[pigC.id] == 0)
}

@Test @MainActor func nearbyCountsEmptyList() {
    let counts = NeedsSystem.precomputeNearbyCounts(pigs: [], radius: 8.0)
    #expect(counts.isEmpty)
}
