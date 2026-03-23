/// GameConfig -- All balance constants organized in enum namespaces.
/// Maps from: data/config.py
import Foundation

/// Top-level namespace for all game balance constants.
/// Uses caseless enums as namespaces (Swift convention for pure constants).
enum GameConfig {
    enum Time {
        static let realSecondsPerGameMinute: Double = 1.0
        static let gameMinutesPerHour: Int = 60
        static let gameHoursPerDay: Int = 24
        static let dayStartHour: Int = 6
        static let nightStartHour: Int = 20
    }

    enum Needs {
        // Decay rates per game hour
        static let hungerDecay: Double = 0.6
        static let thirstDecay: Double = 0.8
        static let energyDecay: Double = 0.6
        // Thresholds
        static let criticalThreshold: Int = 20
        static let lowThreshold: Int = 40
        static let highThreshold: Int = 70
        static let satisfactionThreshold: Int = 90
        // Health
        static let healthDrainHunger: Double = 0.3
        static let healthDrainThirst: Double = 0.5
        static let healthPassiveRecovery: Double = 1.0
        static let healthSleepRecovery: Double = 1.5
        // Recovery amounts
        static let foodRecovery: Double = 40.0
        static let waterRecovery: Double = 50.0
        static let sleepRecoveryPerHour: Double = 25.0
        static let playHappinessBoost: Double = 15.0
        static let socialHappinessBoost: Double = 10.0
        // Boredom
        static let boredomDecay: Double = 2.0
        static let boredomExtraHappinessThreshold: Int = 70
        static let boredomExtraHappinessDrain: Double = 1.0
        static let boredomPlayRecovery: Double = 15.0
        static let playEnergyCost: Double = 1.0
        static let socialRecovery: Double = 10.0
        // Social
        static let socialRadius: Double = 8.0
        static let socialBoostPerPig: Double = 3.0
        static let socialBoostCap: Double = 8.0
        static let socialDecayWithPigs: Double = 0.5
        static let socialDecayAlone: Double = 2.0
        // Happiness
        static let eatingHappinessBoost: Double = 2.0
        static let happinessContentmentRecovery: Double = 2.0
        static let hungerHappinessDrain: Double = 2.0
        static let thirstHappinessDrain: Double = 2.5
        static let energyHappinessDrain: Double = 1.5
        // Personality modifiers
        static let greedyHungerMult: Double = 1.5
        static let lazyEnergyMult: Double = 0.7
        static let playfulBoredomMult: Double = 1.5
        static let socialSocialMult: Double = 1.3
        static let shySocialMult: Double = 0.5
        // Wellbeing weights
        static let wellbeingHungerWeight: Double = 0.25
        static let wellbeingThirstWeight: Double = 0.25
        static let wellbeingEnergyWeight: Double = 0.15
        static let wellbeingHappinessWeight: Double = 0.20
        static let wellbeingHealthWeight: Double = 0.15
    }

    enum Breeding {
        static let minHappinessToBreed: Int = 70
        static let minAgeDays: Int = 3
        static let maxAgeDays: Int = 30
        static let gestationDays: Int = 2
        static let minLitterSize: Int = 1
        static let maxLitterSize: Int = 4
        static let recoveryDays: Int = 1
        static let breedingDistance: Double = 3.0
        static let baseBreedingChance: Double = 0.05
        static let breedingDenBonus: Double = 0.10
        static let highHappinessThreshold: Int = 80
        static let highHappinessBonus: Double = 0.05
        static let oldAgeDeathRate: Double = 0.1
        static let minBreedingPopulation: Int = 2
        static let affinityWeight: Double = 0.01
        static let maxAffinitySelectionBonus: Double = 0.05
        static let affinityChanceBonus: Double = 0.01
        static let maxAffinityChanceBonus: Double = 0.05
    }

    enum Economy {
        static let startingMoney: Int = 100
        static let startingPigs: Int = 2
        static let commonPigValue: Int = 25
        static let uncommonMultiplier: Double = 1.5
        static let rareMultiplier: Double = 2.5
        static let veryRareMultiplier: Double = 4.0
        static let legendaryMultiplier: Double = 10.0
        // Adoption cost: intentionally 2× the common pig sale value (25) to prevent buy/sell exploits.
        static let adoptionBaseCost: Int = 50
        // Facility costs (all 17) — retuned for prestige pacing (Section 7E)
        static let foodBowlCost: Int = 50
        static let waterBottleCost: Int = 50
        static let hideoutCost: Int = 150
        static let hayRackCost: Int = 250
        static let exerciseWheelCost: Int = 500
        static let tunnelCost: Int = 750
        static let feastTableCost: Int = 1_500
        static let groomingStationCost: Int = 2_000
        static let playAreaCost: Int = 2_500
        static let geneticsLabCost: Int = 5_000
        static let campfireCost: Int = 6_000
        static let therapyGardenCost: Int = 8_000
        static let breedingDenCost: Int = 15_000
        static let nurseryCost: Int = 25_000
        static let veggieGardenCost: Int = 25_000
        static let hotSpringCost: Int = 100_000
        static let stageCost: Int = 1_000_000
    }

    enum Simulation {
        static let ticksPerSecond: Int = 10
        static let baseMoveSpeed: Double = 1.0
        static let maxPathfindingIterations: Int = 1500
        static let decisionIntervalSeconds: Double = 2.0
        static let babyAgeDays: Int = 0
        static let adultAgeDays: Int = 3
        static let seniorAgeDays: Int = 30
        static let maxAgeDays: Int = 45
    }

    enum Genetics {
        static let mutationRate: Double = 0.02
        static let mutationRateWithLab: Double = 0.03
        static let directionalMutationRate: Double = 0.06
        static let directionalMutationRateWithLab: Double = 0.09
    }

    enum Bloodline {
        static let bloodlinePigChance: Double = 0.5
        static let adoptionRefreshDays: Int = 5
    }

    enum Pigdex {
        // Discovery rewards — retuned for prestige pacing (Section 7G)
        static let commonReward: Int = 100
        static let uncommonReward: Int = 300
        static let rareReward: Int = 800
        static let veryRareReward: Int = 2_000
        static let legendaryReward: Int = 5_000
        // Milestone rewards (% of total phenotypes discovered)
        static let milestone25Reward: Int = 5_000
        static let milestone50Reward: Int = 15_000
        static let milestone75Reward: Int = 50_000
        static let milestone100Reward: Int = 250_000
    }

    enum Contracts {
        static let maxActiveContracts: Int = 4
        static let refreshIntervalDays: Int = 10
        static let expiryDays: Int = 20
        static let easyRewardMin: Int = 500
        static let easyRewardMax: Int = 1000
        static let mediumRewardMin: Int = 2000
        static let mediumRewardMax: Int = 4000
        static let hardRewardMin: Int = 5000
        static let hardRewardMax: Int = 10000
        static let expertRewardMin: Int = 12000
        static let expertRewardMax: Int = 20000
        static let legendaryRewardMin: Int = 20000
        static let legendaryRewardMax: Int = 40000
    }

    enum Biome {
        static let preferredBiomeHappinessBonus: Double = 1.5
        static let biomeMutationBoost: Double = 0.08
        static let biomeContractRewardBonus: Double = 0.50
        static let biomeContractChance: Double = 0.3
        static let acclimationDays: Double = 3.0
        static let colorMatchAffinityReduction: Double = 0.6
        static let colorMatchAcclimationMultiplier: Double = 0.5
    }

    enum FacilityInteraction {
        static let adjacencyDistance: Int = 1
        static let defaultHideoutCapacity: Int = 2
    }

    enum Offline {
        /// Minimum wall-clock seconds away before catch-up triggers.
        static let minThresholdSeconds: Double = 60
        /// Maximum wall-clock seconds of offline time to simulate.
        static let maxDurationSeconds: Double = 86_400  // 24 real hours
        /// Game-hours per checkpoint in the fast-forward loop.
        static let checkpointGameHours: Double = 1.0
        /// Fraction of real-time consumption applied to facilities offline.
        /// 0.40 = pigs consume at 40% of normal rate.
        static let consumptionRateMultiplier: Double = 0.40
        /// Health floor when facilities are empty. Pigs suffer but survive.
        static let healthMercyFloor: Double = 10.0

        /// A single tier in the diminishing-returns offline speed curve.
        struct SpeedTier: Sendable {
            /// Upper bound of this tier in real-time hours (exclusive).
            let realHoursCeiling: Double
            /// Multiplier: 1 real hour in this tier produces `multiplier` game hours.
            let multiplier: Double
        }

        /// Diminishing returns curve. Ordered by ascending realHoursCeiling.
        /// - Invariant: entries must be sorted ascending by `realHoursCeiling`;
        ///   `computeGameHours` produces incorrect results for unsorted input.
        /// 24h offline produces 35 game-hours instead of the old flat 4,320.
        static let speedTiers: [SpeedTier] = [
            SpeedTier(realHoursCeiling: 2, multiplier: 3.0),
            SpeedTier(realHoursCeiling: 6, multiplier: 2.0),
            SpeedTier(realHoursCeiling: 12, multiplier: 1.5),
            SpeedTier(realHoursCeiling: 24, multiplier: 1.0),
        ]
    }

    enum AutoArrange {
        static let horizontalGap: Int = 2
        static let verticalGap: Int = 3
        static let zoneMargin: Int = 1
        static let smallFarmThresholdW: Int = 22
        static let smallFarmThresholdH: Int = 22
        static let smallHorizontalGap: Int = 1
        static let smallVerticalGap: Int = 2
        static let neighborhoodUtilityFraction: Double = 0.2
        static let maxNeighborhoods: Int = 4
    }

    enum Prestige {
        // Rosette formula divisors
        static let rosetteBaseDivisor: Int = 5000
        static let rosettePigdexDivisor: Int = 5
        static let rosetteDiversityDivisor: Int = 10
        static let rosetteContractDivisor: Int = 3

        // Pig Show threshold
        static let pigShowLifetimeSqueaksThreshold: Int = 50_000

        // Visit mechanics
        static let visitCooldownSeconds: TimeInterval = 14_400    // 4 real hours
        static let reunionMinOfflineSeconds: TimeInterval = 3600   // 1 real hour
        static let streakWindowSeconds: TimeInterval = 86_400      // 24 hours

        // Reunion boost (standard)
        static let reunionDurationSeconds: TimeInterval = 1800     // 30 real minutes
        static let reunionHappinessBoost: Double = 15.0
        static let reunionBreedingBonus: Double = 0.10
        static let reunionSaleBonus: Double = 0.10

        // Reunion boost (enhanced — with Reunion Spirit upgrade)
        static let reunionEnhancedDurationSeconds: TimeInterval = 3600
        static let reunionEnhancedHappinessBoost: Double = 22.0
        static let reunionEnhancedBreedingBonus: Double = 0.15
        static let reunionEnhancedSaleBonus: Double = 0.15

        // Streak bonuses
        static let streakDay2BreedingBonus: Double = 0.05
        static let streakDay5SaleBonus: Double = 0.10

        // Treats
        static let baseTreatsPerVisit: Int = 2
        static let treatsPerScatter: Int = 4
        static let treatPouchBonusTreats: Int = 2

        // Biome mastery
        static let biomeMasteryThreshold: Int = 10
        static let biomeMasteryCostReduction: Double = 0.25
        static let biomeMasteryMutationBoost: Double = 0.02

        // Petting
        static let petHappinessBoost: Double = 10.0
        static let petSocialBoost: Double = 5.0
        static let enhancedPetHappinessBoost: Double = 20.0
        static let enhancedPetSocialBoost: Double = 10.0
        static let handFeedFavoriteHappinessPerHour: Double = 5.0
        static let handFeedFavoriteDurationHours: Double = 12.0

        // Facility check bonus
        static let visitRefillCapacityBonus: Double = 0.25

        // Showroom upgrade effect values
        static let expandedHutchCapacityBonus: Int = 2
        static let rapidRecoveryMultiplier: Double = 0.5
        static let earlyBloomerMinBreedingAge: Int = 2
        static let pigdexMomentumPerEntry: Double = 0.005
        static let pigdexMomentumCap: Double = 0.10
        static let twinSparkChance: Double = 0.10
        static let fertileGroundBreedingChance: Double = 0.10
        static let mutationCatalystRate: Double = 0.05
        static let enduringBondsMaxBreedingAge: Int = 40
        static let enduringBondsMaxAge: Int = 60
        static let phenotypeRecallChance: Double = 0.15
        static let biomeIntuitionMultiplier: Double = 2.0
        static let prolificLineMinLitter: Int = 2
        static let premiumGeneticsRarityMultiplier: Double = 1.5
        static let speedGestationDays: Double = 1.5
        static let goldenTouchSaleBonus: Double = 0.25
        static let legendaryLineageMultiplier: Double = 2.0
        static let keepsakeMaxSlots: Int = 3

        // Pigdex rediscovery
        static let rediscoveryRewardFraction: Double = 0.50
    }
}
