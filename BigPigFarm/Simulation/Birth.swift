/// Birth — Pregnancy tracking, birth events, and aging.
/// Maps from: simulation/birth.py
import Foundation

// MARK: - MutationParameters

/// Computed mutation configuration for a birth event.
private struct MutationParameters: Sendable {
    var mutationRate: Double
    var locusRates: [String: Double]?
    var directionalTargets: [String: String]?
    var directionalRate: Double
}

// MARK: - Birth

/// Stateless namespace for pregnancy advancement, birth processing, and pig aging.
enum Birth {

    // MARK: - Public API

    /// Check for and process births from pigs whose pregnancy has reached term.
    /// Returns the number of births that occurred this tick.
    @MainActor
    static func checkBirths(gameState: GameState) -> Int {
        var birthCount = 0
        let pregnantPigs = gameState.getPigsList().filter(\.isPregnant)
        for pig in pregnantPigs where pig.pregnancyDays >= Double(GameConfig.Breeding.gestationDays) {
            if processBirth(mother: pig, gameState: gameState) {
                birthCount += 1
            }
        }
        return birthCount
    }

    /// Advance pregnancy progress for all pregnant pigs by the elapsed game hours.
    /// Speed Breeding perk: pregnancy days accumulate 1.333× faster.
    @MainActor
    static func advancePregnancies(gameState: GameState, gameHours: Double) {
        var gameDays = gameHours / 24.0
        if gameState.hasUpgrade("speed_breeding") {
            gameDays *= 1.333
        }
        for var pig in gameState.getPigsList() where pig.isPregnant {
            pig.pregnancyDays += gameDays
            gameState.updateGuineaPig(pig)
        }
    }

    /// Age all pigs by the elapsed game hours. Removes pigs that die of old age.
    /// Baby pigs near a nursery age faster (growth bonus from facilityInfo).
    /// Returns the list of pigs that died this tick.
    @MainActor
    static func ageAllPigs(gameState: GameState, gameHours: Double) -> [GuineaPig] {
        let gameDays = gameHours / 24.0
        let nurseryPoints = gameState.getFacilitiesByType(.nursery).flatMap(\.interactionPoints)
        let growthBonus = facilityInfo[.nursery]?.growthBonus ?? 0.0
        var deaths: [GuineaPig] = []

        for var pig in gameState.getPigsList() {
            var agingDays = gameDays

            if pig.isBaby && nurseryPoints.contains(where: {
                abs(Int(pig.position.x) - $0.x) + abs(Int(pig.position.y) - $0.y) <= 3
            }) {
                agingDays = gameDays * (1.0 + growthBonus)
            }

            pig.ageDays += agingDays
            gameState.updateGuineaPig(pig)

            if pig.ageDays >= Double(GameConfig.Simulation.maxAgeDays) {
                if Double.random(in: 0.0..<1.0) < GameConfig.Breeding.oldAgeDeathRate * gameDays {
                    deaths.append(pig)
                }
            }
        }

        for pig in deaths {
            _ = gameState.removeGuineaPig(pig.id)
            gameState.logEvent(
                "\(pig.name) passed away peacefully at age \(Int(pig.ageDays)) days.",
                eventType: "death"
            )
        }

        return deaths
    }

    /// Register a newborn pig's phenotype in the pigdex.
    /// Awards Squeaks for new discoveries; checks milestones.
    /// Lucky Clover perk: 10% chance of bonus 50–200 Squeaks on discovery.
    @MainActor
    static func registerPigInPigdex(gameState: GameState, pig: GuineaPig) {
        let key = phenotypeKey(pig.phenotype)
        var pigdex = gameState.pigdex
        let isNew = pigdex.registerPhenotype(key: key, gameDay: gameState.gameTime.day)

        if isNew {
            let rarity = keyToRarity(key)
            let reward = getDiscoveryReward(rarity)
            gameState.addMoney(reward)
            gameState.logEvent(
                "Pigdex: \(pig.phenotype.displayName) discovered! (\(rarity.rawValue.capitalized)) +\(reward) Squeaks",
                eventType: "pigdex"
            )
            HapticManager.pigdexDiscovery()

            if gameState.hasUpgrade("lucky_clover"),
               Double.random(in: 0.0..<1.0) < 0.10 {
                let bonus = Int.random(in: 50...200)
                gameState.addMoney(bonus)
                gameState.logEvent(
                    "Lucky Clover! Bonus +\(bonus) Squeaks for \(pig.phenotype.displayName)!",
                    eventType: "pigdex"
                )
            }

            let milestones = pigdex.checkMilestones()
            for threshold in milestones {
                let milestoneReward = getMilestoneReward(threshold)
                pigdex.claimMilestone(threshold)
                gameState.addMoney(milestoneReward)
                gameState.logEvent(
                    "Pigdex Milestone: \(threshold)% complete! +\(milestoneReward) Squeaks",
                    eventType: "pigdex"
                )
            }
        }

        gameState.pigdex = pigdex
    }

    // MARK: - Private Helpers

    // swiftlint:disable function_body_length
    /// Process a birth for a pig whose pregnancy has reached term.
    /// Returns true if babies were born, false if pregnancy was cancelled.
    @MainActor
    private static func processBirth(mother: GuineaPig, gameState: GameState) -> Bool {
        if gameState.isAtCapacity {
            cancelPregnancy(mother: mother, gameState: gameState, reason: "farm is at capacity")
            return false
        }

        let father = mother.partnerId.flatMap { gameState.getGuineaPig($0) }
        let fatherGenotype = mother.partnerGenotype ?? father?.genotype
        let fatherName = mother.partnerName ?? father?.name ?? "Unknown"
        let fatherId = mother.partnerId

        guard let fatherGenotype else {
            cancelPregnancy(mother: mother, gameState: gameState, reason: "father's genetics unavailable")
            return false
        }

        var maxLitter = GameConfig.Breeding.maxLitterSize
        if gameState.hasUpgrade("litter_boost") { maxLitter += 1 }
        var litterSize = Int.random(in: GameConfig.Breeding.minLitterSize...maxLitter)
        litterSize = min(litterSize, gameState.capacity - gameState.pigCount)
        if litterSize <= 0 {
            cancelPregnancy(mother: mother, gameState: gameState, reason: "farm is at capacity")
            return false
        }

        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        let hasAccelerator = gameState.hasUpgrade("genetic_accelerator")
        let params = computeMutationParameters(
            mother: mother, hasLab: hasLab, hasAccelerator: hasAccelerator, gameState: gameState
        )

        let birthArea = gameState.farm.getAreaAt(Int(mother.position.x), Int(mother.position.y))
        let birthAreaId = birthArea?.id
        var existingNames = Set(gameState.getPigsList().map(\.name))
        var babiesBorn: [GuineaPig] = []

        for _ in 0..<litterSize {
            let breedResult = breed(
                mother.genotype, fatherGenotype,
                mutationRate: params.mutationRate,
                locusRates: params.locusRates,
                directionalTargets: params.directionalTargets,
                directionalRate: params.directionalRate
            )
            let gender: Gender = Bool.random() ? .male : .female
            let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
            let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)
            existingNames.insert(name)

            var baby = GuineaPig.create(
                name: name, gender: gender, genotype: breedResult.genotype,
                position: Position(
                    x: mother.position.x + Double.random(in: -1.0...1.0),
                    y: mother.position.y + Double.random(in: -1.0...1.0)
                ),
                ageDays: 0.0,
                motherId: mother.id, fatherId: fatherId,
                motherName: mother.name, fatherName: fatherName
            )
            baby.birthAreaId = birthAreaId
            baby.currentAreaId = birthAreaId
            baby.preferredBiome = birthArea?.biome.rawValue ?? mother.preferredBiome

            gameState.addGuineaPig(baby)
            gameState.totalPigsBorn += 1
            babiesBorn.append(baby)

            if !breedResult.mutations.isEmpty {
                let desc = breedResult.mutations.joined(separator: ", ")
                gameState.logEvent("\(baby.name) was born with a mutation! (\(desc))", eventType: "mutation")
            }
            registerPigInPigdex(gameState: gameState, pig: baby)
        }

        applyBreedingFilter(gameState: gameState, babies: babiesBorn)
        resetMother(mother, gameState: gameState)

        let babyNames = babiesBorn.map(\.name).joined(separator: ", ")
        gameState.logEvent(
            "\(mother.name) gave birth to \(litterSize) piglet(s): \(babyNames)",
            eventType: "birth"
        )
        return true
    }
    // swiftlint:enable function_body_length

    /// Compute per-locus mutation rates and directional targets based on biome and perks.
    @MainActor
    private static func computeMutationParameters(
        mother: GuineaPig,
        hasLab: Bool,
        hasAccelerator: Bool,
        gameState: GameState
    ) -> MutationParameters {
        var rate = hasLab ? GameConfig.Genetics.mutationRateWithLab : GameConfig.Genetics.mutationRate
        if hasAccelerator { rate *= 2.0 }

        let motherBiome = gameState.farm.getBiomeAt(Int(mother.position.x), Int(mother.position.y))
        var locusRates: [String: Double]?
        var directionalTargets: [String: String]?
        var directionalRate: Double = 0.0

        if let biomeType = motherBiome, let biomeInfo = biomes[biomeType] {
            if !biomeInfo.mutationBoostLoci.isEmpty {
                var rates: [String: Double] = [:]
                for (locus, boost) in biomeInfo.mutationBoostLoci where boost > 0 {
                    rates[locus] = rate + boost
                }
                if !rates.isEmpty { locusRates = rates }
            }
            if !biomeInfo.directionalAlleles.isEmpty {
                directionalTargets = biomeInfo.directionalAlleles
                directionalRate = hasLab
                    ? GameConfig.Genetics.directionalMutationRateWithLab
                    : GameConfig.Genetics.directionalMutationRate
                if hasAccelerator { directionalRate *= 2.0 }
            }
        }

        return MutationParameters(
            mutationRate: rate,
            locusRates: locusRates,
            directionalTargets: directionalTargets,
            directionalRate: directionalRate
        )
    }

    /// Reset a mother pig's state after giving birth or pregnancy cancellation.
    @MainActor
    private static func resetMother(_ mother: GuineaPig, gameState: GameState) {
        var updated = mother
        updated.isPregnant = false
        updated.pregnancyDays = 0.0
        updated.lastBirthAge = mother.ageDays
        updated.partnerId = nil
        updated.partnerGenotype = nil
        updated.partnerName = nil
        gameState.updateGuineaPig(updated)
    }

    /// Cancel a pregnancy and log the reason.
    @MainActor
    private static func cancelPregnancy(
        mother: GuineaPig,
        gameState: GameState,
        reason: String
    ) {
        resetMother(mother, gameState: gameState)
        gameState.logEvent(
            "\(mother.name)'s pregnancy was cancelled: \(reason).",
            eventType: "breeding"
        )
    }

    /// Mark newborns that don't match the breeding program target for auto-sale.
    /// Skips the filter when the adult population is below the stock limit.
    @MainActor
    private static func applyBreedingFilter(gameState: GameState, babies: [GuineaPig]) {
        let program = gameState.breedingProgram
        guard program.enabled else { return }

        let adults = gameState.getPigsList().filter { !$0.isBaby }
        let effectiveLimit = max(program.stockLimit, GameConfig.Breeding.minBreedingPopulation)
        guard adults.count > effectiveLimit else { return }

        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        var markedNames: [String] = []

        for baby in babies where !program.shouldKeepPig(baby, hasGeneticsLab: hasLab) {
            var marked = baby
            marked.markedForSale = true
            gameState.updateGuineaPig(marked)
            markedNames.append(baby.name)
        }

        if !markedNames.isEmpty {
            let summary = "\(markedNames.count)/\(babies.count) marked for sale: \(markedNames.joined(separator: ", "))"
            gameState.logEvent("Breeding program: \(summary)", eventType: "filter")
        }
    }
}
