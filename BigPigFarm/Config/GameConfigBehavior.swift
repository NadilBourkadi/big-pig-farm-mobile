/// GameConfigBehavior -- Behavior AI tuning constants (~56 values).
/// Maps from: data/config.py (BehaviorConfig frozen dataclass)
import Foundation

extension GameConfig {
    enum Behavior {
        // MARK: - Separation thresholds

        static let separationBothMoving: Double = 1.0
        static let separationOneMoving: Double = 2.0
        static let minPigDistance: Double = 3.0

        // MARK: - Movement blocking

        static let blockingDefault: Double = 2.5
        static let blockingBothMoving: Double = 1.5
        static let blockingFacilityUse: Double = 1.5
        static let separationFacilityUse: Double = 1.0

        // MARK: - Facility interaction

        static let occupancyRadius: Double = 2.0
        static let facilityNearbyRadius: Double = 6.0
        static let facilityHeadingRadius: Double = 3.0
        static let crowdingPenalty: Double = 25.0
        static let facilityDistanceWeight: Double = 2.0
        static let scoringRandomVariance: Double = 3.0
        static let uncrowdedChance: Double = 0.3

        // MARK: - Blocked behavior

        static let blockedTimeAlternative: Double = 2.0
        static let blockedTimeGiveUp: Double = 5.0
        static let failedCooldownCycles: Int = 3

        // MARK: - Decision thresholds

        static let energySleepThreshold: Int = 40
        static let emergencyWakeEnergy: Int = 15
        static let boredomPlayThreshold: Int = 30
        static let boredomKeepPlaying: Int = 20

        // MARK: - Resource consumption

        static let resourceConsumeRate: Double = 0.15
        static let facilityBonusScale: Double = 10.0

        // MARK: - Personality probabilities

        static let lazySleepChance: Double = 0.3
        static let playfulPlayChance: Double = 0.4
        static let socialSocializeChance: Double = 0.3
        static let wanderChance: Double = 0.8
        static let noPlayFacilityPlayChance: Double = 0.1

        // MARK: - Wandering

        static let wanderAttempts: Int = 8
        static let wanderMaxDistance: Int = 30
        static let wanderDensityRadius: Double = 10.0
        static let wanderDensityPenalty: Double = 2.0
        static let simpleWanderMinSteps: Int = 6
        static let simpleWanderMaxSteps: Int = 14

        // MARK: - Pathfinding limits

        static let maxFacilityPathfindDistance: Int = 100
        static let maxFacilityCandidates: Int = 4
        static let straightLineMaxDistance: Int = 6

        // MARK: - Content pig throttle

        static let contentDecisionInterval: Double = 8.0

        // MARK: - Critical retry

        static let criticalFailedCooldownCycles: Int = 1

        // MARK: - Unreachable backoff

        static let unreachableBackoffCycles: Int = 5
        static let unreachableCriticalCycles: Int = 2

        // MARK: - Biome affinity

        static let biomeAffinityPenalty: Double = 30.0

        // MARK: - Room overcrowding

        static let roomOvercrowdingPenalty: Double = 10.0

        // MARK: - Idle drift

        static let idleDriftRadius: Double = 5.0

        // MARK: - Biome-aware wandering

        static let biomeWanderBiasOutside: Double = 3.0
        static let biomeWanderBiasInside: Double = 1.5
        static let biomeHomingChance: Double = 0.7

        // MARK: - Courtship

        static let courtshipTogetherSeconds: Double = 4.0
        static let courtshipHappinessBoost: Double = 5.0

        // MARK: - Movement modifiers

        static let tiredSpeedMult: Double = 0.5
        static let babySpeedMult: Double = 0.7
        static let dodgeMaxStep: Double = 1.0
        static let waypointReached: Double = 0.1

        // MARK: - Campfire night attraction

        static let campfireAttractionRadius: Double = 10.0

        // MARK: - Overlap handling

        static let overlapEpsilon: Double = 0.01
        static let separationPadding: Double = 0.1
        static let pathVectorEpsilon: Double = 0.01
    }
}
