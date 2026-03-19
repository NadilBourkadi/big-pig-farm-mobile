/// Birth+Processing — Birth processing pipeline and pregnancy management.
import Foundation

extension Birth {

    // MARK: - Birth Processing

    // swiftlint:disable function_body_length
    /// Process a birth for a pig whose pregnancy has reached term.
    /// Returns true if babies were born, false if pregnancy was cancelled.
    @MainActor
    static func processBirth(mother: GuineaPig, gameState: GameState) -> Bool {
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
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.log(
            category: .birth, level: .info,
            message: "Birth: \(mother.name) -> \(litterSize) piglet(s)",
            pigId: mother.id, pigName: mother.name,
            payload: [
                "motherId": mother.id.uuidString,
                "fatherName": fatherName,
                "motherGenotype": mother.genotype.debugDescription,
                "fatherGenotype": fatherGenotype.debugDescription,
                "litterSize": String(litterSize),
                "babyNames": babyNames,
                "biome": birthArea?.biome.rawValue ?? "unknown",
            ]
        )
        for baby in babiesBorn {
            DebugLogger.shared.log(
                category: .birth, level: .info,
                message: "Born: \(baby.name) (\(baby.phenotype.displayName))",
                pigId: baby.id, pigName: baby.name,
                payload: [
                    "genotype": baby.genotype.debugDescription,
                    "color": baby.phenotype.baseColor.rawValue,
                    "pattern": baby.phenotype.pattern.rawValue,
                    "intensity": baby.phenotype.intensity.rawValue,
                    "rarity": baby.phenotype.rarity.rawValue,
                    "biome": birthArea?.biome.rawValue ?? "unknown",
                ]
            )
        }
        #endif
        return true
    }
    // swiftlint:enable function_body_length

    // MARK: - Mutation Parameters

    /// Compute per-locus mutation rates and directional targets based on biome and perks.
    @MainActor
    static func computeMutationParameters(
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

    // MARK: - Mother Reset

    /// Reset a mother pig's state after giving birth or pregnancy cancellation.
    @MainActor
    static func resetMother(_ mother: GuineaPig, gameState: GameState) {
        var updated = mother
        updated.isPregnant = false
        updated.pregnancyDays = 0.0
        updated.lastBirthAge = mother.ageDays
        updated.partnerId = nil
        updated.partnerGenotype = nil
        updated.partnerName = nil
        gameState.updateGuineaPig(updated)
    }

    // MARK: - Pregnancy Cancellation

    /// Cancel a pregnancy and log the reason.
    @MainActor
    static func cancelPregnancy(
        mother: GuineaPig,
        gameState: GameState,
        reason: String
    ) {
        resetMother(mother, gameState: gameState)
        gameState.logEvent(
            "\(mother.name)'s pregnancy was cancelled: \(reason).",
            eventType: "breeding"
        )
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.log(
            category: .birth, level: .warning,
            message: "Pregnancy cancelled: \(mother.name) (\(reason))",
            pigId: mother.id, pigName: mother.name,
            payload: ["reason": reason]
        )
        #endif
    }

    // MARK: - Breeding Filter

    /// Mark newborns that don't match the breeding program target for auto-sale.
    /// Skips the filter when the adult population is below the stock limit.
    @MainActor
    static func applyBreedingFilter(gameState: GameState, babies: [GuineaPig]) {
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
