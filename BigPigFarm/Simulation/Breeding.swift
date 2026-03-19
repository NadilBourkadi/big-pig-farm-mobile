/// Breeding — Pair selection and courtship behavior.
/// Maps from: simulation/breeding.py
import Foundation

/// Stateless namespace for breeding pair evaluation and pregnancy initiation.
enum Breeding {

    // MARK: - State (throttle)

    /// Last game day a "no eligible pigs" warning was logged for auto-pair.
    /// Prevents log spam when the farm has no eligible breeders.
    @MainActor static var lastBreedingWarningDay: Int = -1

    // MARK: - Public API

    /// Scan all pigs for valid breeding opportunities.
    ///
    /// Runs in three stages each tick:
    /// 1. Process any births due this tick (always runs).
    /// 2. Process the manually set breeding pair if one exists (always runs).
    /// 3. Run auto-pairing + spontaneous breeding when `runExpensive` is true
    ///    (throttled by the caller to every 10 ticks).
    ///
    /// Returns the number of births that occurred.
    @MainActor
    static func checkBreedingOpportunities(
        gameState: GameState,
        runExpensive: Bool
    ) -> Int {
        // Stage 1: Births
        let birthCount = Birth.checkBirths(gameState: gameState)

        // Stage 2: Manual breeding pair
        checkManualBreeding(gameState: gameState)

        // Stage 3: Auto-pairing and spontaneous breeding (throttled)
        if runExpensive {
            autoPairFromProgram(gameState: gameState)
            checkForNewBreeding(gameState: gameState)
        }

        return birthCount
    }

    /// Called when courtship completes — starts the actual pregnancy.
    /// Stores the father's genotype and name on the mother at conception;
    /// this ensures birth works even if the father is later sold.
    /// Clears courtship state on both pigs. The caller must write both back
    /// via `gameState.updateGuineaPig(_:)`.
    @MainActor
    static func startPregnancyFromCourtship(
        male: inout GuineaPig,
        female: inout GuineaPig,
        gameState: GameState
    ) {
        female.isPregnant = true
        female.pregnancyDays = 0.0
        female.partnerId = male.id
        female.partnerGenotype = male.genotype
        female.partnerName = male.name
        clearCourtship(pig: &male)
        clearCourtship(pig: &female)
        gameState.logEvent(
            "\(male.name) and \(female.name) are expecting!",
            eventType: "breeding"
        )
        #if DEBUG && canImport(UIKit)
        DebugLogger.shared.log(
            category: .breeding, level: .info,
            message: "Pregnancy: \(male.name) + \(female.name)",
            pigId: female.id, pigName: female.name,
            payload: [
                "maleId": male.id.uuidString,
                "maleName": male.name,
                "femaleId": female.id.uuidString,
                "femaleName": female.name,
            ]
        )
        #endif
    }

    /// Clear all courtship tracking fields from a pig.
    /// Resets `behaviorState` to `.idle` if currently `.courting`.
    static func clearCourtship(pig: inout GuineaPig) {
        pig.courtingPartnerId = nil
        pig.courtingInitiator = false
        pig.courtingTimer = 0.0
        if pig.behaviorState == .courting {
            pig.behaviorState = .idle
        }
        pig.targetDescription = nil
    }

    // MARK: - Manual Breeding

    /// Process the player-set breeding pair if conditions are met.
    @MainActor
    private static func checkManualBreeding(gameState: GameState) {
        guard let pair = gameState.breedingPair else { return }

        guard let male = gameState.getGuineaPig(pair.maleId),
              let female = gameState.getGuineaPig(pair.femaleId) else {
            gameState.logEvent("Breeding pair is no longer available.", eventType: "breeding")
            gameState.clearBreedingPair()
            return
        }

        guard !isPermanentlyUnbreedable(male), !isPermanentlyUnbreedable(female) else {
            gameState.logEvent(
                "Breeding pair cancelled: \(male.name) or \(female.name) cannot breed.",
                eventType: "breeding"
            )
            gameState.clearBreedingPair()
            return
        }

        // Female already pregnant (auto-bred between ticks)
        if female.isPregnant {
            gameState.clearBreedingPair()
            return
        }

        // Wait if either pig isn't ready yet
        guard male.canBreed, female.canBreed else { return }
        guard male.behaviorState != .courting, female.behaviorState != .courting else { return }

        initiateCourtship(male: male, female: female, gameState: gameState)
        gameState.clearBreedingPair()
    }

    // MARK: - Spontaneous Breeding

    /// Check if any eligible pigs should start breeding spontaneously.
    /// Stops after the first successful courtship initiation per expensive check.
    @MainActor
    private static func checkForNewBreeding(gameState: GameState) {
        let pigs = gameState.getPigsList()
        let eligibleFemales = pigs.filter {
            $0.gender == .female && $0.canBreed && !$0.isPregnant && $0.behaviorState != .courting
        }
        let eligibleMales = pigs.filter {
            $0.gender == .male && $0.canBreed && $0.behaviorState != .courting
        }

        for female in eligibleFemales {
            for male in eligibleMales where canBreedTogether(male: male, female: female, gameState: gameState) {
                if attemptBreeding(male: male, female: female, gameState: gameState) {
                    return
                }
            }
        }
    }

    // MARK: - Breeding Eligibility

    /// True if a pig is permanently unable to breed (senior or manually locked).
    private static func isPermanentlyUnbreedable(_ pig: GuineaPig) -> Bool {
        pig.isSenior || pig.breedingLocked
    }

    /// True if a male and female can breed together.
    /// Both must be eligible, within breedingDistance, and not closely related.
    @MainActor
    private static func canBreedTogether(
        male: GuineaPig,
        female: GuineaPig,
        gameState: GameState
    ) -> Bool {
        guard male.gender == .male, female.gender == .female else { return false }
        guard male.canBreed, female.canBreed else { return false }
        guard !female.isPregnant else { return false }
        guard !areCloselyRelated(male, female) else { return false }
        let distance = male.position.distanceTo(female.position)
        return distance <= GameConfig.Breeding.breedingDistance
    }

    /// True if two pigs are parent/child or share a mother or father.
    /// Internal (not private) so OfflineProgressRunner can reuse this predicate.
    static func areCloselyRelated(_ pig1: GuineaPig, _ pig2: GuineaPig) -> Bool {
        // Parent-child
        if let m1 = pig1.motherId, m1 == pig2.id { return true }
        if let f1 = pig1.fatherId, f1 == pig2.id { return true }
        if let m2 = pig2.motherId, m2 == pig1.id { return true }
        if let f2 = pig2.fatherId, f2 == pig1.id { return true }
        // Full siblings (same non-nil mother or father)
        if let m1 = pig1.motherId, let m2 = pig2.motherId, m1 == m2 { return true }
        if let f1 = pig1.fatherId, let f2 = pig2.fatherId, f1 == f2 { return true }
        return false
    }

    // MARK: - Courtship Initiation

    /// Roll a breeding chance and initiate courtship if successful.
    /// Returns true if courtship was initiated.
    @MainActor
    private static func attemptBreeding(
        male: GuineaPig,
        female: GuineaPig,
        gameState: GameState
    ) -> Bool {
        var chance = GameConfig.Breeding.baseBreedingChance

        if gameState.hasUpgrade("fertility_herbs") { chance += 0.05 }
        if !gameState.getFacilitiesByType(.breedingDen).isEmpty {
            chance += GameConfig.Breeding.breedingDenBonus
        }
        let avgHappiness = (male.needs.happiness + female.needs.happiness) / 2.0
        if avgHappiness > Double(GameConfig.Breeding.highHappinessThreshold) {
            chance += GameConfig.Breeding.highHappinessBonus
        }
        let affinity = gameState.getAffinity(male.id, female.id)
        chance += min(Double(affinity) * GameConfig.Breeding.affinityChanceBonus,
                      GameConfig.Breeding.maxAffinityChanceBonus)

        guard Double.random(in: 0.0..<1.0) < chance else { return false }

        initiateCourtship(male: male, female: female, gameState: gameState)
        return true
    }

    /// Set both pigs into the `.courting` state and point the male toward the female.
    /// Clears any current movement targets so BehaviorController can pathfind to partner.
    @MainActor
    private static func initiateCourtship(
        male: GuineaPig,
        female: GuineaPig,
        gameState: GameState
    ) {
        var updatedMale = male
        updatedMale.behaviorState = .courting
        updatedMale.courtingPartnerId = female.id
        updatedMale.courtingInitiator = true
        updatedMale.courtingTimer = 0.0
        updatedMale.path = []
        updatedMale.targetPosition = nil
        updatedMale.targetFacilityId = nil
        updatedMale.targetDescription = "courting \(female.name)"

        var updatedFemale = female
        updatedFemale.behaviorState = .courting
        updatedFemale.courtingPartnerId = male.id
        updatedFemale.courtingInitiator = false
        updatedFemale.courtingTimer = 0.0
        updatedFemale.path = []
        updatedFemale.targetPosition = nil
        updatedFemale.targetFacilityId = nil
        updatedFemale.targetDescription = "courting \(male.name)"

        gameState.updateGuineaPig(updatedMale)
        gameState.updateGuineaPig(updatedFemale)
        gameState.logEvent(
            "\(male.name) is courting \(female.name)!",
            eventType: "breeding"
        )
    }
}
