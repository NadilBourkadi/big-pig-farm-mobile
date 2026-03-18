/// Birth — Pregnancy tracking, birth events, and aging.
/// Maps from: simulation/birth.py
import Foundation

// MARK: - MutationParameters

/// Computed mutation configuration for a birth event.
struct MutationParameters: Sendable {
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
            #if canImport(UIKit)
            HapticManager.pigdexDiscovery()
            #endif

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
}
