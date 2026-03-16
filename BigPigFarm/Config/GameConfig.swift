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
        static let recoveryDays: Int = 2
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
        // Facility costs (all 17)
        static let foodBowlCost: Int = 20
        static let waterBottleCost: Int = 20
        static let hideoutCost: Int = 60
        static let hayRackCost: Int = 80
        static let exerciseWheelCost: Int = 150
        static let tunnelCost: Int = 200
        static let feastTableCost: Int = 350
        static let groomingStationCost: Int = 500
        static let playAreaCost: Int = 600
        static let geneticsLabCost: Int = 1000
        static let campfireCost: Int = 1200
        static let therapyGardenCost: Int = 1500
        static let breedingDenCost: Int = 3000
        static let nurseryCost: Int = 5000
        static let veggieGardenCost: Int = 5000
        static let hotSpringCost: Int = 15000
        static let stageCost: Int = 150000
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
        static let commonReward: Int = 10
        static let uncommonReward: Int = 20
        static let rareReward: Int = 35
        static let veryRareReward: Int = 50
        static let legendaryReward: Int = 100
        static let milestone25Reward: Int = 250
        static let milestone50Reward: Int = 750
        static let milestone75Reward: Int = 2000
        static let milestone100Reward: Int = 10000
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
        /// Game-time multiplier for offline progress (matches GameSpeed.normal.rawValue).
        static let speedMultiplier: Int = 3
        /// Game-hours per checkpoint in the fast-forward loop.
        static let checkpointGameHours: Double = 1.0
        /// Fraction of real-time consumption applied to facilities offline.
        /// 0.25 = pigs consume at 25% of normal rate (they eat sometimes, not constantly).
        static let consumptionRateMultiplier: Double = 0.25
        /// Health floor when facilities are empty. Pigs suffer but survive.
        static let healthMercyFloor: Double = 10.0
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
}
