/// Birth+Processing — Birth processing pipeline and pregnancy management.
import Foundation

extension Birth {

    // MARK: - Birth Processing

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

        let litterSize = computeLitterSize(gameState: gameState)
        if litterSize <= 0 {
            cancelPregnancy(mother: mother, gameState: gameState, reason: "farm is at capacity")
            return false
        }

        let birthContext = BirthContext(
            mother: mother, father: father, fatherGenotype: fatherGenotype,
            fatherName: fatherName, fatherId: fatherId, litterSize: litterSize,
            gameState: gameState
        )

        let babiesBorn = generateLitter(context: birthContext)

        applyBreedingFilter(gameState: gameState, babies: babiesBorn)
        resetMother(mother, gameState: gameState)

        logBirthEvents(
            mother: mother, babiesBorn: babiesBorn, litterSize: litterSize,
            fatherName: fatherName, fatherGenotype: fatherGenotype,
            birthArea: gameState.farm.getAreaAt(Int(mother.position.x), Int(mother.position.y)),
            gameState: gameState
        )
        return true
    }

    /// Context object holding all parameters needed to generate a litter.
    private struct BirthContext {
        let mother: GuineaPig
        let father: GuineaPig?
        let fatherGenotype: Genotype
        let fatherName: String
        let fatherId: UUID?
        let litterSize: Int
        let gameState: GameState
    }

    /// Compute the final litter size accounting for upgrades and capacity.
    @MainActor
    private static func computeLitterSize(gameState: GameState) -> Int {
        let prestige = gameState.prestigeState
        var maxLitter = GameConfig.Breeding.maxLitterSize
        if gameState.hasUpgrade("litter_boost") { maxLitter += 1 }
        let minLitter = prestige.hasUpgrade(.prolificLine)
            ? GameConfig.Prestige.prolificLineMinLitter
            : GameConfig.Breeding.minLitterSize
        var litterSize = Int.random(in: minLitter...maxLitter)
        // Twin Spark adds one beyond the normal max (stacks with litter_boost by design)
        if prestige.hasUpgrade(.twinSpark),
           Double.random(in: 0.0..<1.0) < GameConfig.Prestige.twinSparkChance {
            litterSize += 1
        }
        return min(litterSize, gameState.capacity - gameState.pigCount)
    }

    /// Generate all babies for the litter, applying prestige upgrades.
    @MainActor
    private static func generateLitter(context: BirthContext) -> [GuineaPig] {
        let gameState = context.gameState
        let mother = context.mother
        let prestige = gameState.prestigeState

        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        let hasAccelerator = gameState.hasUpgrade("genetic_accelerator")
        let params = computeMutationParameters(
            mother: mother, hasLab: hasLab, hasAccelerator: hasAccelerator, gameState: gameState
        )

        let birthArea = gameState.farm.getAreaAt(Int(mother.position.x), Int(mother.position.y))
        let birthAreaId = birthArea?.id
        var existingNames = Set(gameState.getPigsList().map(\.name))
        var babiesBorn: [GuineaPig] = []

        let lockedLoci = collectLockedLoci(
            mother: mother, father: context.father, prestige: prestige
        )
        let allelePreferences: AllelePreferences? = prestige.hasUpgrade(.selectiveAdvantage)
            ? prestige.allelePreferences : nil
        let phenotypeRecallActive = prestige.hasUpgrade(.phenotypeRecall)
        let allPigdexKeys: [String] = phenotypeRecallActive
            ? Array(Set(gameState.pigdex.discovered.keys)
                .union(gameState.prestigeState.previousPigdexEntries))
            : []

        for _ in 0..<context.litterSize {
            var breedResult = breed(
                mother.genotype, context.fatherGenotype,
                mutationRate: params.mutationRate,
                locusRates: params.locusRates,
                directionalTargets: params.directionalTargets,
                directionalRate: params.directionalRate,
                lockedLoci: lockedLoci,
                allelePreferences: allelePreferences
            )

            breedResult = applyPhenotypeRecall(
                result: breedResult, active: phenotypeRecallActive, pigdexKeys: allPigdexKeys
            )

            let baby = createBaby(
                breedResult: breedResult, mother: mother, fatherId: context.fatherId,
                fatherName: context.fatherName, birthArea: birthArea, birthAreaId: birthAreaId,
                existingNames: &existingNames, gameState: gameState
            )
            babiesBorn.append(baby)
        }

        return babiesBorn
    }

    /// Collect locked loci for Genetic Imprinting.
    @MainActor
    private static func collectLockedLoci(
        mother: GuineaPig, father: GuineaPig?, prestige: PrestigeState
    ) -> [(locusName: String, parentGenotype: Genotype)]? {
        guard prestige.hasUpgrade(.geneticImprinting) else { return nil }
        var locked: [(locusName: String, parentGenotype: Genotype)] = []
        if let locus = mother.imprintedLocus {
            locked.append((locus, mother.genotype))
        }
        if let father, let locus = father.imprintedLocus {
            locked.append((locus, father.genotype))
        }
        return locked.isEmpty ? nil : locked
    }

    /// Apply Phenotype Recall override if active and triggered.
    private static func applyPhenotypeRecall(
        result: BreedResult, active: Bool, pigdexKeys: [String]
    ) -> BreedResult {
        guard active, !pigdexKeys.isEmpty,
              Double.random(in: 0.0..<1.0) < GameConfig.Prestige.phenotypeRecallChance,
              let targetKey = pigdexKeys.randomElement(),
              let recalledGenotype = canonicalGenotype(forPhenotypeKey: targetKey) else {
            return result
        }
        return BreedResult(genotype: recalledGenotype, mutations: result.mutations)
    }

    /// Create a single baby pig, register it in the game state and pigdex.
    @MainActor
    private static func createBaby(
        breedResult: BreedResult, mother: GuineaPig, fatherId: UUID?,
        fatherName: String, birthArea: FarmArea?, birthAreaId: UUID?,
        existingNames: inout Set<String>, gameState: GameState
    ) -> GuineaPig {
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

        if !breedResult.mutations.isEmpty {
            let desc = breedResult.mutations.joined(separator: ", ")
            gameState.logEvent("\(baby.name) was born with a mutation! (\(desc))", eventType: "mutation")
        }
        registerPigInPigdex(gameState: gameState, pig: baby)

        if let biome = birthArea?.biome {
            gameState.prestigeState.biomeMastery.recordBirth(in: biome)
        }

        return baby
    }

    /// Log birth events to the game log and debug logger.
    @MainActor
    private static func logBirthEvents(
        mother: GuineaPig, babiesBorn: [GuineaPig], litterSize: Int,
        fatherName: String, fatherGenotype: Genotype,
        birthArea: FarmArea?, gameState: GameState
    ) {
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
    }

    // Mutation parameter computation is in Birth+Mutations.swift.

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
