/// ConfigTests — Tests for GameConfig, GameConfigBehavior, and GameConfigTiers.
/// Covers value parity with Python source, logical constraints, and cross-namespace invariants.
import Testing
@testable import BigPigFarm

// MARK: - Behavior Value Parity (spot-checks against Python BehaviorConfig)

@Test func behaviorSeparationThresholds() {
    #expect(GameConfig.Behavior.separationBothMoving == 1.0)
    #expect(GameConfig.Behavior.separationOneMoving == 2.0)
    #expect(GameConfig.Behavior.minPigDistance == 3.0)
}

@Test func behaviorBlockingDistances() {
    #expect(GameConfig.Behavior.blockingDefault == 2.5)
    #expect(GameConfig.Behavior.blockingBothMoving == 1.5)
    #expect(GameConfig.Behavior.blockingFacilityUse == 1.5)
    #expect(GameConfig.Behavior.separationFacilityUse == 1.0)
}

@Test func behaviorFacilityInteraction() {
    #expect(GameConfig.Behavior.occupancyRadius == 2.0)
    #expect(GameConfig.Behavior.facilityNearbyRadius == 6.0)
    #expect(GameConfig.Behavior.facilityHeadingRadius == 3.0)
    #expect(GameConfig.Behavior.crowdingPenalty == 25.0)
    #expect(GameConfig.Behavior.facilityDistanceWeight == 2.0)
    #expect(GameConfig.Behavior.scoringRandomVariance == 3.0)
    #expect(GameConfig.Behavior.uncrowdedChance == 0.3)
    #expect(GameConfig.Behavior.resourceConsumeRate == 0.15)
    #expect(GameConfig.Behavior.facilityBonusScale == 10.0)
}

@Test func behaviorBlockedTimings() {
    #expect(GameConfig.Behavior.blockedTimeAlternative == 2.0)
    #expect(GameConfig.Behavior.blockedTimeGiveUp == 5.0)
    #expect(GameConfig.Behavior.failedCooldownCycles == 3)
}

@Test func behaviorDecisionThresholds() {
    #expect(GameConfig.Behavior.energySleepThreshold == 40)
    #expect(GameConfig.Behavior.emergencyWakeEnergy == 15)
    #expect(GameConfig.Behavior.boredomPlayThreshold == 30)
    #expect(GameConfig.Behavior.boredomKeepPlaying == 20)
}

@Test func behaviorPersonalityProbabilities() {
    #expect(GameConfig.Behavior.lazySleepChance == 0.3)
    #expect(GameConfig.Behavior.playfulPlayChance == 0.4)
    #expect(GameConfig.Behavior.socialSocializeChance == 0.3)
    #expect(GameConfig.Behavior.wanderChance == 0.8)
    #expect(GameConfig.Behavior.noPlayFacilityPlayChance == 0.1)
}

@Test func behaviorWandering() {
    #expect(GameConfig.Behavior.wanderAttempts == 8)
    #expect(GameConfig.Behavior.wanderMaxDistance == 30)
    #expect(GameConfig.Behavior.wanderDensityRadius == 10.0)
    #expect(GameConfig.Behavior.wanderDensityPenalty == 2.0)
    #expect(GameConfig.Behavior.simpleWanderMinSteps == 6)
    #expect(GameConfig.Behavior.simpleWanderMaxSteps == 14)
}

@Test func behaviorPathfindingLimits() {
    #expect(GameConfig.Behavior.maxFacilityPathfindDistance == 100)
    #expect(GameConfig.Behavior.maxFacilityCandidates == 4)
    #expect(GameConfig.Behavior.straightLineMaxDistance == 6)
}

@Test func behaviorMovementModifiers() {
    #expect(GameConfig.Behavior.tiredSpeedMult == 0.5)
    #expect(GameConfig.Behavior.babySpeedMult == 0.7)
    #expect(GameConfig.Behavior.dodgeMaxStep == 1.0)
    #expect(GameConfig.Behavior.waypointReached == 0.1)
}

@Test func behaviorCourtshipAndMisc() {
    #expect(GameConfig.Behavior.courtshipTogetherSeconds == 4.0)
    #expect(GameConfig.Behavior.courtshipHappinessBoost == 5.0)
    #expect(GameConfig.Behavior.contentDecisionInterval == 8.0)
    #expect(GameConfig.Behavior.biomeAffinityPenalty == 30.0)
    #expect(GameConfig.Behavior.roomOvercrowdingPenalty == 10.0)
    #expect(GameConfig.Behavior.idleDriftRadius == 5.0)
    #expect(GameConfig.Behavior.biomeWanderBiasOutside == 3.0)
    #expect(GameConfig.Behavior.biomeWanderBiasInside == 1.5)
}

// MARK: - Behavior Logical Constraints

@Test func separationThresholdsAreOrdered() {
    // Both-moving < one-moving < stationary (tighter when both are in motion)
    #expect(GameConfig.Behavior.separationBothMoving
            < GameConfig.Behavior.separationOneMoving)
    #expect(GameConfig.Behavior.separationOneMoving
            < GameConfig.Behavior.minPigDistance)
}

@Test func blockedTimesAreOrdered() {
    // Try alternative before giving up
    #expect(GameConfig.Behavior.blockedTimeAlternative
            < GameConfig.Behavior.blockedTimeGiveUp)
}

@Test func criticalCooldownIsLessThanNormal() {
    #expect(GameConfig.Behavior.criticalFailedCooldownCycles
            < GameConfig.Behavior.failedCooldownCycles)
}

@Test func unreachableCriticalIsLessThanNormal() {
    #expect(GameConfig.Behavior.unreachableCriticalCycles
            < GameConfig.Behavior.unreachableBackoffCycles)
}

@Test func probabilitiesAreInUnitRange() {
    let probabilities: [Double] = [
        GameConfig.Behavior.lazySleepChance,
        GameConfig.Behavior.playfulPlayChance,
        GameConfig.Behavior.socialSocializeChance,
        GameConfig.Behavior.wanderChance,
        GameConfig.Behavior.noPlayFacilityPlayChance,
        GameConfig.Behavior.uncrowdedChance,
        GameConfig.Behavior.biomeHomingChance,
    ]
    for probability in probabilities {
        #expect(probability >= 0.0 && probability <= 1.0)
    }
}

@Test func epsilonsArePositive() {
    #expect(GameConfig.Behavior.overlapEpsilon > 0)
    #expect(GameConfig.Behavior.pathVectorEpsilon > 0)
    #expect(GameConfig.Behavior.separationPadding > 0)
}

@Test func biomeWanderBiasesAreOrdered() {
    // Outside bias higher than inside bias to encourage homing
    #expect(GameConfig.Behavior.biomeWanderBiasOutside
            > GameConfig.Behavior.biomeWanderBiasInside)
}

@Test func wanderStepRangeIsValid() {
    #expect(GameConfig.Behavior.simpleWanderMinSteps
            < GameConfig.Behavior.simpleWanderMaxSteps)
    #expect(GameConfig.Behavior.simpleWanderMinSteps > 0)
}

// MARK: - Non-Behavior Config Tests

@Test func needsThresholdsAreOrdered() {
    // critical < low < high < satisfaction
    #expect(GameConfig.Needs.criticalThreshold < GameConfig.Needs.lowThreshold)
    #expect(GameConfig.Needs.lowThreshold < GameConfig.Needs.highThreshold)
    #expect(GameConfig.Needs.highThreshold < GameConfig.Needs.satisfactionThreshold)
}

@Test func breedingAgeRangeIsValid() {
    #expect(GameConfig.Breeding.minAgeDays < GameConfig.Breeding.maxAgeDays)
    #expect(GameConfig.Breeding.minAgeDays > 0)
    #expect(GameConfig.Breeding.minLitterSize <= GameConfig.Breeding.maxLitterSize)
    #expect(GameConfig.Breeding.minLitterSize >= 1)
}

@Test func economyMultipliersAreIncreasing() {
    #expect(GameConfig.Economy.uncommonMultiplier
            < GameConfig.Economy.rareMultiplier)
    #expect(GameConfig.Economy.rareMultiplier
            < GameConfig.Economy.veryRareMultiplier)
    #expect(GameConfig.Economy.veryRareMultiplier
            < GameConfig.Economy.legendaryMultiplier)
}

@Test func tierUpgradesProgressCorrectly() {
    // Each tier should cost more and allow more rooms
    for i in 1..<tierUpgrades.count {
        let prev = tierUpgrades[i - 1]
        let curr = tierUpgrades[i]
        #expect(curr.tier > prev.tier)
        #expect(curr.cost >= prev.cost)
        #expect(curr.maxRooms >= prev.maxRooms)
        #expect(curr.capacityPerRoom >= prev.capacityPerRoom)
    }
}

@Test func timeRealSecondsPerGameMinuteMatchesPython() {
    // Python source: REAL_SECONDS_PER_GAME_MINUTE = 1.0
    // At 1x speed, 1 real second = 1 game minute.
    #expect(GameConfig.Time.realSecondsPerGameMinute == 1.0)
}

@Test func simulationTimingDefaults() {
    #expect(GameConfig.Simulation.ticksPerSecond == 10)
    #expect(GameConfig.Simulation.baseMoveSpeed == 1.0)
    #expect(GameConfig.Simulation.decisionIntervalSeconds == 2.0)
    #expect(GameConfig.Simulation.babyAgeDays < GameConfig.Simulation.adultAgeDays)
    #expect(GameConfig.Simulation.adultAgeDays < GameConfig.Simulation.seniorAgeDays)
    #expect(GameConfig.Simulation.seniorAgeDays < GameConfig.Simulation.maxAgeDays)
}
