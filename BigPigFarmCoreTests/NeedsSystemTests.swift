/// NeedsSystemTests — Unit tests for updateAllNeeds: decay, personality, recovery, and effects.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Test Helpers

/// Create a pig with known needs for deterministic testing.
@MainActor func makeNeedsPig(
    hunger: Double = 100.0,
    thirst: Double = 100.0,
    energy: Double = 100.0,
    happiness: Double = 75.0,
    health: Double = 100.0,
    social: Double = 50.0,
    boredom: Double = 0.0,
    traits: [Personality] = [],
    behaviorState: BehaviorState = .idle,
    position: Position = Position(x: 5, y: 5),
    preferredBiome: String? = nil
) -> GuineaPig {
    var pig = GuineaPig.create(name: "TestPig", gender: .female)
    pig.needs = Needs(
        hunger: hunger, thirst: thirst, energy: energy,
        happiness: happiness, health: health, social: social, boredom: boredom
    )
    pig.personality = traits
    pig.behaviorState = behaviorState
    pig.position = position
    pig.preferredBiome = preferredBiome
    return pig
}

/// One game hour in minutes.
let needsTestOneHour: Double = 60.0

// MARK: - Primary Decay

@Test @MainActor func hungerDecayOneHour() {
    let state = GameState()
    var pig = makeNeedsPig()
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(abs(pig.needs.hunger - (100.0 - GameConfig.Needs.hungerDecay)) < 0.01)
}

@Test @MainActor func thirstDecayOneHour() {
    let state = GameState()
    var pig = makeNeedsPig()
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(abs(pig.needs.thirst - (100.0 - GameConfig.Needs.thirstDecay)) < 0.01)
}

@Test @MainActor func energyDecayOneHour() {
    let state = GameState()
    var pig = makeNeedsPig()
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(abs(pig.needs.energy - (100.0 - GameConfig.Needs.energyDecay)) < 0.01)
}

// MARK: - Personality Modifiers

@Test @MainActor func greedyHungerDecayFaster() {
    let state = GameState()
    var pig = makeNeedsPig(traits: [.greedy])
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 100.0 - GameConfig.Needs.hungerDecay * GameConfig.Needs.greedyHungerMult
    #expect(abs(pig.needs.hunger - expected) < 0.01)
}

@Test @MainActor func lazyEnergyDecaySlower() {
    let state = GameState()
    var pig = makeNeedsPig(traits: [.lazy])
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 100.0 - GameConfig.Needs.energyDecay * GameConfig.Needs.lazyEnergyMult
    #expect(abs(pig.needs.energy - expected) < 0.01)
}

@Test @MainActor func playfulBoredomFaster() {
    let state = GameState()
    var pig = makeNeedsPig(traits: [.playful])
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = GameConfig.Needs.boredomDecay * GameConfig.Needs.playfulBoredomMult
    #expect(abs(pig.needs.boredom - expected) < 0.01)
}

@Test @MainActor func shyOverridesSocialModifier() {
    let state = GameState()
    var pig = makeNeedsPig(social: 80.0, traits: [.shy, .social])
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    // Shy pig alone: social -= 2.0 * 0.5 = 1.0/hr
    let expected = 80.0 - GameConfig.Needs.socialDecayAlone * GameConfig.Needs.shySocialMult
    #expect(abs(pig.needs.social - expected) < 0.01)
}

// MARK: - Contentment Recovery

@Test @MainActor func happinessRecoveryWhenNeedsMet() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 80.0, thirst: 80.0, energy: 50.0, happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.happiness > 50.0)
}

@Test @MainActor func noContentmentRecoveryWhenHungerLow() {
    let state = GameState()
    // hunger=15 → after decay 14.4, below critical(20) → happiness drain applies
    var pig = makeNeedsPig(hunger: 15.0, thirst: 80.0, energy: 50.0, happiness: 50.0)
    let startHappiness = pig.needs.happiness
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.happiness < startHappiness)
}

@Test @MainActor func noContentmentRecoveryWhenEnergyBelowCritical() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 80.0, thirst: 80.0, energy: 15.0, happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    // Energy below critical(20) → no contentment, plus energy happiness drain
    #expect(pig.needs.happiness < 50.0 + GameConfig.Needs.happinessContentmentRecovery)
}

// MARK: - Critical Need Happiness Drain

@Test @MainActor func criticalHungerDrainsHappiness() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 10.0, thirst: 100.0, energy: 100.0, happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.happiness < 50.0)
}

@Test @MainActor func criticalThirstDrainsHappiness() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 100.0, thirst: 10.0, energy: 100.0, happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.happiness < 50.0)
}

@Test @MainActor func criticalEnergyDrainsHappiness() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 100.0, thirst: 100.0, energy: 10.0, happiness: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.happiness < 50.0)
}

@Test @MainActor func multipleCriticalDrainStack() {
    let state = GameState()
    var singleCritical = makeNeedsPig(
        hunger: 10.0, thirst: 100.0, energy: 100.0, happiness: 50.0
    )
    var doubleCritical = makeNeedsPig(
        hunger: 10.0, thirst: 10.0, energy: 100.0, happiness: 50.0
    )
    NeedsSystem.updateAllNeeds(
        pig: &singleCritical, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    NeedsSystem.updateAllNeeds(
        pig: &doubleCritical, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(doubleCritical.needs.happiness < singleCritical.needs.happiness)
}

// MARK: - Boredom

@Test @MainActor func boredomIncreases() {
    let state = GameState()
    var pig = makeNeedsPig()
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(abs(pig.needs.boredom - GameConfig.Needs.boredomDecay) < 0.01)
}

@Test @MainActor func highBoredomDrainsExtraHappiness() {
    let state = GameState()
    var pig = makeNeedsPig(happiness: 50.0, boredom: 80.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let withoutBoredomDrain = 50.0 + GameConfig.Needs.happinessContentmentRecovery
    #expect(pig.needs.happiness < withoutBoredomDrain)
}

@Test @MainActor func enrichmentProgramSlowsBoredom() {
    let state = GameState()
    state.purchasedUpgrades.insert("enrichment_program")
    var pig = makeNeedsPig()
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = GameConfig.Needs.boredomDecay * 0.8
    #expect(abs(pig.needs.boredom - expected) < 0.01)
}

// MARK: - Social Need

@Test @MainActor func socialBoostFromNearbyPigs() {
    let state = GameState()
    var pig = makeNeedsPig(social: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 2
    )
    let expected = 50.0 + 6.0 - 0.5
    #expect(abs(pig.needs.social - expected) < 0.01)
}

@Test @MainActor func socialBoostCapped() {
    let state = GameState()
    var pig = makeNeedsPig(social: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 5
    )
    let expected = 50.0 + 8.0 - 0.5
    #expect(abs(pig.needs.social - expected) < 0.01)
}

@Test @MainActor func socialDecayWhenAlone() {
    let state = GameState()
    var pig = makeNeedsPig(social: 50.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 50.0 - GameConfig.Needs.socialDecayAlone
    #expect(abs(pig.needs.social - expected) < 0.01)
}

@Test @MainActor func shySocialDecayReduced() {
    let state = GameState()
    var pig = makeNeedsPig(social: 50.0, traits: [.shy])
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 50.0 - GameConfig.Needs.socialDecayAlone * GameConfig.Needs.shySocialMult
    #expect(abs(pig.needs.social - expected) < 0.01)
}

// MARK: - Health Effects

@Test @MainActor func healthDrainFromCriticalHunger() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 10.0, thirst: 100.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.health < 100.0)
}

@Test @MainActor func healthDrainFromCriticalThirst() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 100.0, thirst: 10.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.health < 100.0)
}

@Test @MainActor func healthPassiveRecovery() {
    let state = GameState()
    var pig = makeNeedsPig(health: 80.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 80.0 + GameConfig.Needs.healthPassiveRecovery
    #expect(abs(pig.needs.health - expected) < 0.01)
}

@Test @MainActor func pigSpaDoublesHealthRecovery() {
    let state = GameState()
    state.purchasedUpgrades.insert("pig_spa")
    var pig = makeNeedsPig(health: 80.0)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    let expected = 80.0 + GameConfig.Needs.healthPassiveRecovery * 2.0
    #expect(abs(pig.needs.health - expected) < 0.01)
}

// MARK: - Clamping

@Test @MainActor func needsClampedAtZero() {
    let state = GameState()
    var pig = makeNeedsPig(
        hunger: 0.1, thirst: 0.1, energy: 0.1, happiness: 0.1, social: 0.1
    )
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.hunger >= 0.0)
    #expect(pig.needs.thirst >= 0.0)
    #expect(pig.needs.energy >= 0.0)
    #expect(pig.needs.happiness >= 0.0)
    #expect(pig.needs.social >= 0.0)
}

@Test @MainActor func needsClampedAtHundred() {
    let state = GameState()
    var pig = makeNeedsPig(hunger: 99.0, behaviorState: .eating)
    NeedsSystem.updateAllNeeds(
        pig: &pig, gameMinutes: needsTestOneHour, state: state, nearbyCount: 0
    )
    #expect(pig.needs.hunger == 100.0)
}

// MARK: - Time Scaling

@Test @MainActor func subHourDecayScalesProportionally() {
    let state = GameState()
    var pig = makeNeedsPig()
    // 6 minutes = 0.1 hours
    NeedsSystem.updateAllNeeds(pig: &pig, gameMinutes: 6.0, state: state, nearbyCount: 0)
    let expected = 100.0 - GameConfig.Needs.hungerDecay * 0.1
    #expect(abs(pig.needs.hunger - expected) < 0.001)
}

// MARK: - Spatial Grid Proximity Counts

@Test func spatialPrecomputeMatchesBruteForce() {
    // Place pigs at known positions and verify both overloads agree.
    let positions: [(Double, Double)] = [
        (5, 5), (8, 5), (12, 5), (50, 50), (51, 50),
    ]
    var pigs: [GuineaPig] = []
    for pos in positions {
        var pig = GuineaPig.create(name: "P\(pigs.count)", gender: .female)
        pig.position = Position(x: pos.0, y: pos.1)
        pigs.append(pig)
    }
    let pigDict = Dictionary(uniqueKeysWithValues: pigs.map { ($0.id, $0) })

    var grid = SpatialGrid()
    grid.rebuild(pigs: pigs)

    let bruteForce = NeedsSystem.precomputeNearbyCounts(
        pigs: pigs, radius: GameConfig.Needs.socialRadius
    )
    let spatial = NeedsSystem.precomputeNearbyCounts(
        pigs: pigs, radius: GameConfig.Needs.socialRadius,
        spatialGrid: grid, pigDict: pigDict
    )

    for pig in pigs {
        #expect(
            bruteForce[pig.id] == spatial[pig.id],
            "Mismatch for \(pig.name): brute=\(bruteForce[pig.id] ?? -1) spatial=\(spatial[pig.id] ?? -1)"
        )
    }
}
