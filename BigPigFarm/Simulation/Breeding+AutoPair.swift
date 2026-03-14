/// Breeding+AutoPair — Auto-pairing strategies for the breeding program.
import Foundation

extension Breeding {

    // MARK: - Auto-Pairing Entry Point

    /// Auto-pair the best breeding pair based on the breeding program strategy.
    @MainActor
    static func autoPairFromProgram(gameState: GameState) {
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

    // MARK: - Target Probability Strategy

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

    // MARK: - Diversity Strategy

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
