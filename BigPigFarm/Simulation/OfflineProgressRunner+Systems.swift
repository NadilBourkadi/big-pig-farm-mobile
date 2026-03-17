/// OfflineProgressRunner+Systems — Needs, breeding, and acclimation for offline catch-up.
import Foundation

extension OfflineProgressRunner {

    // MARK: - Needs

    @MainActor
    static func decayAndEquilibrateNeeds(state: GameState, hours: Double) {
        let pigs = state.getPigsList()
        let pigCount = pigs.count

        for var pig in pigs {
            decayPrimaryNeeds(pig: &pig, hours: hours)
            applyHappinessEffects(pig: &pig, hours: hours)
            applySocialEffects(pig: &pig, hours: hours, pigCount: pigCount)
            applyHealthEffects(pig: &pig, hours: hours, state: state)
            equilibrateNeeds(pig: &pig, state: state, hours: hours)
            pig.needs.clampAll()
            state.updateGuineaPig(pig)
        }
    }

    /// Personality trait modifiers (greedy, lazy, playful) are intentionally
    /// omitted offline. All pigs decay at the average rate for simplicity.
    private static func decayPrimaryNeeds(pig: inout GuineaPig, hours: Double) {
        pig.needs.hunger -= GameConfig.Needs.hungerDecay * hours
        pig.needs.thirst -= GameConfig.Needs.thirstDecay * hours
        pig.needs.energy -= GameConfig.Needs.energyDecay * hours
        pig.needs.boredom += GameConfig.Needs.boredomDecay * hours
    }

    private static func applyHappinessEffects(pig: inout GuineaPig, hours: Double) {
        let critical = Double(GameConfig.Needs.criticalThreshold)
        if pig.needs.hunger < critical {
            pig.needs.happiness -= GameConfig.Needs.hungerHappinessDrain * hours
        }
        if pig.needs.thirst < critical {
            pig.needs.happiness -= GameConfig.Needs.thirstHappinessDrain * hours
        }
        if pig.needs.energy < critical {
            pig.needs.happiness -= GameConfig.Needs.energyHappinessDrain * hours
        }
        if pig.needs.boredom > Double(GameConfig.Needs.boredomExtraHappinessThreshold) {
            pig.needs.happiness -= GameConfig.Needs.boredomExtraHappinessDrain * hours
        }
        // Contentment recovery when primary needs are OK
        let low = Double(GameConfig.Needs.lowThreshold)
        if pig.needs.hunger >= low && pig.needs.thirst >= low
            && pig.needs.energy >= critical {
            pig.needs.happiness += GameConfig.Needs.happinessContentmentRecovery * hours
        }
    }

    /// Social: decay + recovery. With multiple pigs on the farm, apply a moderate
    /// proximity boost to simulate natural encounters during offline time. Without
    /// this, social inevitably hits 0 on long absences because decay runs every
    /// checkpoint but real-time proximity-based recovery is skipped.
    private static func applySocialEffects(pig: inout GuineaPig, hours: Double, pigCount: Int) {
        if pigCount > 1 {
            pig.needs.social -= GameConfig.Needs.socialDecayWithPigs * hours
            // Assume pigs encounter ~2 others per hour on average while offline
            let offlineNearbyCount = min(pigCount - 1, 2)
            let boost = min(
                Double(offlineNearbyCount) * GameConfig.Needs.socialBoostPerPig,
                GameConfig.Needs.socialBoostCap
            ) * hours
            pig.needs.social += boost
        } else {
            pig.needs.social -= GameConfig.Needs.socialDecayAlone * hours
        }
    }

    @MainActor
    private static func applyHealthEffects(
        pig: inout GuineaPig, hours: Double, state: GameState
    ) {
        let critical = Double(GameConfig.Needs.criticalThreshold)
        if pig.needs.hunger < critical {
            pig.needs.health -= GameConfig.Needs.healthDrainHunger * hours
        }
        if pig.needs.thirst < critical {
            pig.needs.health -= GameConfig.Needs.healthDrainThirst * hours
        }
        if pig.needs.hunger >= critical && pig.needs.thirst >= critical {
            var recovery = GameConfig.Needs.healthPassiveRecovery
            if state.hasUpgrade("pig_spa") { recovery *= 2.0 }
            pig.needs.health += recovery * hours
        }
        // Mercy rule: pigs suffer but survive when facilities are empty
        pig.needs.health = max(pig.needs.health, GameConfig.Offline.healthMercyFloor)
    }

    /// Simplified behavior substitute: if a need is low and a matching facility
    /// has stock, apply recovery and consume from the facility at a reduced rate
    /// (25% of real-time). When all facilities of a type are empty, recovery stops.
    @MainActor
    private static func equilibrateNeeds(
        pig: inout GuineaPig, state: GameState, hours: Double
    ) {
        let low = Double(GameConfig.Needs.lowThreshold)
        let rate = GameConfig.Offline.consumptionRateMultiplier

        if pig.needs.thirst < low {
            let cost = GameConfig.Needs.waterRecovery * hours * rate
            if consumeFromFacilities(types: [.waterBottle], amount: cost, state: state) {
                pig.needs.thirst += GameConfig.Needs.waterRecovery * hours
            }
        }
        if pig.needs.hunger < low {
            let cost = GameConfig.Needs.foodRecovery * hours * rate
            if consumeFromFacilities(types: [.foodBowl, .hayRack, .feastTable], amount: cost, state: state) {
                pig.needs.hunger += GameConfig.Needs.foodRecovery * hours
            }
        }
        // Energy and happiness don't consume — hideouts and play areas are infinite-use
        if pig.needs.energy < low && hasFacilityType([.hideout], in: state) {
            pig.needs.energy += GameConfig.Needs.sleepRecoveryPerHour * hours
        }
        if pig.needs.happiness < low && hasFacilityType([.playArea, .exerciseWheel], in: state) {
            pig.needs.happiness += GameConfig.Needs.playHappinessBoost * hours
            pig.needs.boredom -= GameConfig.Needs.boredomPlayRecovery * hours
        }
    }

    /// Try to consume `amount` from the first non-empty facility of the given types.
    /// Returns true if any consumption occurred (facility had stock).
    @MainActor
    @discardableResult
    private static func consumeFromFacilities(
        types: [FacilityType], amount: Double, state: GameState
    ) -> Bool {
        for type in types {
            for facility in state.getFacilitiesByType(type) where !facility.isEmpty {
                var mutable = facility
                let consumed = mutable.consume(amount)
                state.updateFacility(mutable)
                return consumed > 0
            }
        }
        return false
    }

    @MainActor
    private static func hasFacilityType(_ types: [FacilityType], in state: GameState) -> Bool {
        types.contains { !state.getFacilitiesByType($0).isEmpty }
    }

    // MARK: - Acclimation

    @MainActor
    static func advanceAcclimation(state: GameState, hours: Double) {
        for var pig in state.getPigsList() {
            guard pig.preferredBiome != nil
                || pig.acclimationTimer > 0.0
                || pig.acclimatingBiome != nil else { continue }
            var biomeString: String?
            if let areaId = pig.currentAreaId {
                biomeString = state.farm.getAreaByID(areaId)?.biome.rawValue
            }
            let oldBiome = pig.preferredBiome
            Acclimation.updateAcclimation(
                pig: &pig, currentBiome: biomeString, hoursPerTick: hours
            )
            if pig.preferredBiome != oldBiome {
                state.logEvent(
                    "\(pig.name) acclimated to the \(pig.preferredBiome ?? "unknown") biome!",
                    eventType: "acclimation"
                )
            }
            state.updateGuineaPig(pig)
        }
    }

    // MARK: - Offline Breeding

    /// Simplified breeding: skip proximity check and courtship walk, roll chance
    /// directly, cap 1 new pregnancy per checkpoint.
    ///
    /// Breeding chance formula duplicated from Breeding.attemptBreeding (private).
    /// If the formula in Breeding.swift changes, update rollBreedingChance too.
    @MainActor
    static func runOfflineBreeding(
        state: GameState,
        summary: inout OfflineProgressSummary
    ) {
        guard !state.isAtCapacity else { return }

        let pigs = state.getPigsList()
        var eligibleFemales = pigs.filter {
            $0.gender == .female && $0.canBreed && !$0.isPregnant
                && $0.behaviorState != .courting
        }
        let eligibleMales = pigs.filter {
            $0.gender == .male && $0.canBreed && $0.behaviorState != .courting
        }

        guard !eligibleFemales.isEmpty, !eligibleMales.isEmpty else { return }
        eligibleFemales.shuffle()

        for female in eligibleFemales {
            for male in eligibleMales.shuffled() {
                guard !Breeding.areCloselyRelated(male, female) else { continue }
                if rollBreedingChance(male: male, female: female, state: state) {
                    guard var freshMale = state.getGuineaPig(male.id),
                          var freshFemale = state.getGuineaPig(female.id) else { continue }
                    Breeding.startPregnancyFromCourtship(
                        male: &freshMale, female: &freshFemale, gameState: state
                    )
                    state.updateGuineaPig(freshMale)
                    state.updateGuineaPig(freshFemale)
                    summary.pregnanciesStarted.append(
                        .init(maleName: male.name, femaleName: female.name)
                    )
                    return
                }
            }
        }
    }

    @MainActor
    private static func rollBreedingChance(
        male: GuineaPig, female: GuineaPig, state: GameState
    ) -> Bool {
        var chance = GameConfig.Breeding.baseBreedingChance
        if state.hasUpgrade("fertility_herbs") { chance += 0.05 }
        if !state.getFacilitiesByType(.breedingDen).isEmpty {
            chance += GameConfig.Breeding.breedingDenBonus
        }
        let avgHappiness = (male.needs.happiness + female.needs.happiness) / 2.0
        if avgHappiness > Double(GameConfig.Breeding.highHappinessThreshold) {
            chance += GameConfig.Breeding.highHappinessBonus
        }
        let affinity = state.getAffinity(male.id, female.id)
        chance += min(
            Double(affinity) * GameConfig.Breeding.affinityChanceBonus,
            GameConfig.Breeding.maxAffinityChanceBonus
        )
        return Double.random(in: 0.0..<1.0) < chance
    }

}
