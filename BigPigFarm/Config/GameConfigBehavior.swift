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
        /// Cycles before a pig re-seeks a full/empty facility it just arrived at.
        /// Separate from failedCooldownCycles (path-blocked) for independent tuning.
        static let arrivalFailedCooldownCycles: Int = 3

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

        // MARK: - Livelock prevention (escalating backoff + social commitment)

        /// Multiplier applied to the base arrival-failure cooldown per consecutive
        /// failure. Cooldown grows as: base, base*mult, base*mult*mult, … capped
        /// at `arrivalFailureMaxCooldownCycles`. With base=3, mult=2: 3, 6, 12, 20, 20, …
        static let arrivalFailureEscalationMult: Int = 2

        /// Maximum cycles a pig can wait before retrying after repeated arrival
        /// failures. Caps the exponential growth so pigs don't get stuck forever.
        static let arrivalFailureMaxCooldownCycles: Int = 20

        /// After this many consecutive arrival failures of the same facility type,
        /// the pig escalates to the unreachable-backoff path for that need (the
        /// same path used when no facility is pathfindable). Default 2: try once,
        /// escalate after the second failure regardless of facility count.
        static let arrivalFailureEscalateThreshold: Int = 2

        /// Minimum decision cycles a pig commits to socializing once dispatched.
        /// Prevents partner-flipping when nearby pigs are wandering past each other.
        /// 4 cycles ≈ 8 seconds of game time at the 2-second decision interval.
        static let socializingMinCommitmentCycles: Int = 4

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

        // MARK: - Treat movement personality modifiers

        /// Greedy pigs rush to food: +50% speed when seeking treats.
        static let greedyTreatSpeedMult: Double = 1.5
        /// Brave explorers move slightly faster toward treats.
        static let braveTreatSpeedMult: Double = 1.2
        /// Lazy pigs are sluggish: −30% speed when seeking treats.
        static let lazyTreatSpeedMult: Double = 0.7
        /// Shy pigs hesitate before starting to move toward a treat (game-minutes).
        static let shyTreatReactionDelay: Double = 2.0
        /// Playful pigs bounce vertically while seeking treats (scene points amplitude).
        static let playfulTreatBounceAmplitude: Double = 3.0
        /// Full bounce cycle period in seconds.
        static let playfulTreatBouncePeriod: Double = 0.3
        static let dodgeMaxStep: Double = 1.0
        static let waypointReached: Double = 0.1

        // MARK: - Social seeking

        static let socialSeekRadius: Double = 30.0

        // MARK: - Campfire night attraction

        static let campfireAttractionRadius: Double = 10.0

        // MARK: - Overlap handling

        static let overlapEpsilon: Double = 0.01
        static let separationPadding: Double = 0.1
        static let pathVectorEpsilon: Double = 0.01

        // MARK: - Activity log

        static let maxBehaviorLogEntries: Int = 30
    }
}
