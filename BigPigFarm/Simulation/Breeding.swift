// Breeding — Pair selection and courtship behavior.
// Maps from: simulation/breeding.py
// swiftlint:disable file_length type_body_length
import Foundation

/// Stateless namespace for breeding pair evaluation and pregnancy initiation.
enum Breeding {

    // MARK: - Private State (throttle)

    /// Last game day a "no eligible pigs" warning was logged for auto-pair.
    /// Prevents log spam when the farm has no eligible breeders.
    nonisolated(unsafe) private static var lastBreedingWarningDay: Int = -1

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

    // MARK: - Auto-Pairing

    /// Auto-pair the best breeding pair based on the breeding program strategy.
    @MainActor
    private static func autoPairFromProgram(gameState: GameState) {
        guard gameState.breedingProgram.shouldAutoPair() else { return }
        guard gameState.breedingPair == nil else { return }

        let pigs = gameState.getPigsList()
        let males = pigs.filter {
            $0.gender == .male && $0.canBreed && !$0.breedingLocked && $0.behaviorState != .courting
        }
        let females = pigs.filter {
            $0.gender == .female && $0.canBreed && !$0.isPregnant
                && !$0.breedingLocked && $0.behaviorState != .courting
        }

        guard !males.isEmpty, !females.isEmpty else {
            let day = gameState.gameTime.day
            if day != lastBreedingWarningDay {
                lastBreedingWarningDay = day
                gameState.logEvent(
                    "Breeding program: no eligible pigs to pair.",
                    eventType: "breeding"
                )
            }
            return
        }

        let program = gameState.breedingProgram

        switch program.strategy {
        case .diversity:
            autoPairDiversity(gameState: gameState, males: males, females: females)
        case .target, .money:
            autoPairByTargetProbability(
                gameState: gameState,
                males: males,
                females: females,
                program: program
            )
        }
    }

    /// Pair pigs using analytical target probability for the breeding program targets.
    /// Also used for .money strategy (derives targets from active contracts).
    @MainActor
    private static func autoPairByTargetProbability(
        gameState: GameState,
        males: [GuineaPig],
        females: [GuineaPig],
        program: BreedingProgram
    ) {
        var targetColors = program.targetColors
        var targetPatterns = program.targetPatterns
        var targetIntensities = program.targetIntensities
        var targetRoan = program.targetRoan

        if program.strategy == .money && !program.hasTarget {
            for contract in gameState.contractBoard.activeContracts where !contract.fulfilled {
                if let color = contract.requiredColor { targetColors.insert(color) }
                if let pattern = contract.requiredPattern { targetPatterns.insert(pattern) }
                if let intensity = contract.requiredIntensity { targetIntensities.insert(intensity) }
                if let roan = contract.requiredRoan { targetRoan.insert(roan) }
            }
        }

        var bestScore = -1.0
        var bestMale: GuineaPig?
        var bestFemale: GuineaPig?

        for male in males {
            for female in females {
                let prob = calculateTargetProbability(
                    male.genotype, female.genotype,
                    targetColors: targetColors,
                    targetPatterns: targetPatterns,
                    targetIntensities: targetIntensities,
                    targetRoan: targetRoan
                )
                let affinity = gameState.getAffinity(male.id, female.id)
                let affinityBonus = prob > 0
                    ? min(Double(affinity) * GameConfig.Breeding.affinityWeight,
                          GameConfig.Breeding.maxAffinitySelectionBonus)
                    : 0.0
                let score = prob + affinityBonus

                if score > bestScore {
                    bestScore = score
                    bestMale = male
                    bestFemale = female
                }
            }
        }

        if let male = bestMale, let female = bestFemale, bestScore > 0 {
            gameState.setBreedingPair(maleID: male.id, femaleID: female.id)
            gameState.logEvent(
                "Breeding program: paired \(male.name) × \(female.name) (score: \(String(format: "%.2f", bestScore)))",
                eventType: "breeding"
            )
        }
    }

    /// Pair pigs for maximum genetic distance and rare-color production.
    @MainActor
    private static func autoPairDiversity(
        gameState: GameState,
        males: [GuineaPig],
        females: [GuineaPig]
    ) {
        let pigs = gameState.getPigsList()
        let colorCounts: [BaseColor: Int] = pigs.reduce(into: [:]) {
            $0[$1.phenotype.baseColor, default: 0] += 1
        }
        let avgCount = Double(pigs.count) / Double(BaseColor.allCases.count)
        let underrepresented = Set(colorCounts.filter { Double($0.value) < avgCount }.keys)
            .union(Set(BaseColor.allCases.filter { colorCounts[$0] == nil }))

        var bestScore = -1.0
        var bestMale: GuineaPig?
        var bestFemale: GuineaPig?

        for male in males {
            for female in females {
                let score = diversityPairScore(
                    male: male,
                    female: female,
                    underrepresented: underrepresented,
                    gameState: gameState
                )
                if score > bestScore {
                    bestScore = score
                    bestMale = male
                    bestFemale = female
                }
            }
        }

        if let male = bestMale, let female = bestFemale {
            gameState.setBreedingPair(maleID: male.id, femaleID: female.id)
            gameState.logEvent(
                "Breeding program: paired \(male.name) × \(female.name) for diversity",
                eventType: "breeding"
            )
        }
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
    private static func areCloselyRelated(_ pig1: GuineaPig, _ pig2: GuineaPig) -> Bool {
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

    // MARK: - Diversity Pair Scoring

    /// Score a male-female pair for genetic diversity and rare-color production potential.
    @MainActor
    private static func diversityPairScore(
        male: GuineaPig,
        female: GuineaPig,
        underrepresented: Set<BaseColor>,
        gameState: GameState
    ) -> Double {
        let colorLoci = ["eLocus", "bLocus", "dLocus"]
        var distance = 0.0
        for locusName in colorLoci {
            let malePair = male.genotype.allelePair(forLocus: locusName)
            let femalePair = female.genotype.allelePair(forLocus: locusName)
            if malePair.first != femalePair.first { distance += 1.0 }
            if malePair.second != femalePair.second { distance += 1.0 }
            let maleSet: Set<String> = [malePair.first, malePair.second]
            let femaleSet: Set<String> = [femalePair.first, femalePair.second]
            if maleSet != femaleSet { distance += 0.5 }
        }

        var rareBonus = 0.0
        if !underrepresented.isEmpty {
            let prob = calculateTargetProbability(
                male.genotype, female.genotype,
                targetColors: underrepresented,
                targetPatterns: [],
                targetIntensities: [],
                targetRoan: []
            )
            rareBonus = prob * 5.0
        }

        let affinity = gameState.getAffinity(male.id, female.id)
        let affinityBonus = min(
            Double(affinity) * GameConfig.Breeding.affinityWeight,
            GameConfig.Breeding.maxAffinitySelectionBonus
        )

        return distance + rareBonus + affinityBonus
    }

}
// swiftlint:enable file_length type_body_length
