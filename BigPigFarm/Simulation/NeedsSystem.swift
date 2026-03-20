/// NeedsSystem — Need decay, recovery, urgency evaluation, and wellbeing scoring.
/// Maps from: simulation/needs.py
import Foundation

/// Updates pig need levels each tick based on personality, biome, upgrades, and behavior state.
///
/// All decay/recovery rates are per **game hour**. The `gameMinutes` parameter is divided
/// by 60 to convert to hours before applying any rate.
enum NeedsSystem {

    // MARK: - Public API

    /// Update all needs for a single guinea pig based on elapsed game time.
    ///
    /// Order of operations (matches Python `update_all_needs`):
    /// 1–3. Personality modifiers → primary decay → contentment recovery
    /// 4–5. Biome bonus, Climate Control perk
    /// 6–8. Critical drains, Enrichment perk, boredom
    /// 9.   Social proximity effects
    /// 10.  Health drain/recovery
    /// 11.  Behavior-specific recovery
    /// 12.  Clamp all to 0...100
    @MainActor
    static func updateAllNeeds(
        pig: inout GuineaPig,
        gameMinutes: Double,
        state: any NeedsContext,
        nearbyCount: Int
    ) {
        let hours = gameMinutes / 60.0
        let modifiers = computeModifiers(pig: pig, state: state)
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        let hungerBefore = pig.needs.hunger
        let thirstBefore = pig.needs.thirst
        #endif

        // 1–2. Primary decay with personality modifiers
        pig.needs.hunger -= GameConfig.Needs.hungerDecay * hours * modifiers.hunger
        pig.needs.thirst -= GameConfig.Needs.thirstDecay * hours
        pig.needs.energy -= GameConfig.Needs.energyDecay * hours * modifiers.energy

        // 3–5. Happiness bonuses (contentment, biome, climate)
        applyHappinessRecovery(pig: &pig, hours: hours, state: state)

        // 6–8. Happiness drains (critical needs, boredom)
        applyHappinessDrains(pig: &pig, hours: hours, boredomModifier: modifiers.boredom)

        // 9. Social proximity effects
        applySocialEffects(
            pig: &pig, hours: hours,
            nearbyCount: nearbyCount, socialModifier: modifiers.social
        )

        // 10. Health drain/recovery
        applyHealthEffects(pig: &pig, hours: hours, state: state)

        // 11. Behavior-specific recovery
        applyBehaviorRecovery(pig: &pig, gameMinutes: gameMinutes, state: state)

        // 12. Clamp
        pig.needs.clampAll()

        #if (DEBUG || INTERNAL) && canImport(UIKit)
        // Only log on transition into critical (not every tick it remains critical)
        let criticalThreshold = Double(GameConfig.Needs.criticalThreshold)
        if pig.needs.hunger < criticalThreshold && hungerBefore >= criticalThreshold {
            DebugLogger.shared.log(
                category: .needs, level: .warning,
                message: "\(pig.name): critical hunger (\(Int(pig.needs.hunger)))",
                pigId: pig.id, pigName: pig.name,
                payload: ["need": "hunger", "value": String(Int(pig.needs.hunger))]
            )
        }
        if pig.needs.thirst < criticalThreshold && thirstBefore >= criticalThreshold {
            DebugLogger.shared.log(
                category: .needs, level: .warning,
                message: "\(pig.name): critical thirst (\(Int(pig.needs.thirst)))",
                pigId: pig.id, pigName: pig.name,
                payload: ["need": "thirst", "value": String(Int(pig.needs.thirst))]
            )
        }
        #endif
    }

    /// Determine the most urgent unmet need for the behavior AI decision tree.
    ///
    /// Two-pass priority scan:
    /// - Pass 1: Critical/low thresholds in priority order (thirst > hunger > energy > happiness > social).
    /// - Pass 2: All needs below `highThreshold` (70).
    /// - Returns `"none"` if all needs are above `highThreshold`.
    static func getMostUrgentNeed(_ pig: GuineaPig) -> String {
        let critical = Double(GameConfig.Needs.criticalThreshold)
        let low = Double(GameConfig.Needs.lowThreshold)
        let high = Double(GameConfig.Needs.highThreshold)

        let priorities: [NeedPriority] = [
            NeedPriority(name: "thirst", value: pig.needs.thirst, threshold: critical),
            NeedPriority(name: "hunger", value: pig.needs.hunger, threshold: critical),
            NeedPriority(name: "energy", value: pig.needs.energy, threshold: low),
            NeedPriority(name: "happiness", value: pig.needs.happiness, threshold: low),
            NeedPriority(name: "social", value: pig.needs.social, threshold: low),
        ]

        // Pass 1: check against specific thresholds
        for entry in priorities where entry.value < entry.threshold {
            return entry.name
        }

        // Pass 2: check against high threshold
        for entry in priorities where entry.value < high {
            return entry.name
        }

        return "none"
    }

    /// Facility types that can address a specific need, in priority order.
    ///
    /// Returns `nil` for unknown need names (including `"none"`).
    static func getTargetFacilityForNeed(_ need: String) -> [FacilityType]? {
        switch need {
        case "hunger": return [.hayRack, .feastTable, .foodBowl]
        case "thirst": return [.waterBottle]
        case "energy": return [.hideout]
        case "happiness": return [.playArea, .exerciseWheel, .tunnel]
        case "social": return [.playArea]
        default: return nil
        }
    }

    /// Overall wellbeing score (0–100) as a weighted average of key needs.
    ///
    /// Social is excluded — it is addressed indirectly via happiness.
    static func calculateOverallWellbeing(_ pig: GuineaPig) -> Double {
        pig.needs.hunger * GameConfig.Needs.wellbeingHungerWeight
            + pig.needs.thirst * GameConfig.Needs.wellbeingThirstWeight
            + pig.needs.energy * GameConfig.Needs.wellbeingEnergyWeight
            + pig.needs.happiness * GameConfig.Needs.wellbeingHappinessWeight
            + pig.needs.health * GameConfig.Needs.wellbeingHealthWeight
    }

    /// Pre-compute nearby pig counts using O(n²/2) all-pairs distance check.
    ///
    /// Prefer the spatial-grid overload in the tick loop for O(n*k) performance.
    /// This overload remains for tests and contexts without a spatial grid.
    static func precomputeNearbyCounts(
        pigs: [GuineaPig],
        radius: Double = GameConfig.Needs.socialRadius
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for pig in pigs {
            counts[pig.id] = 0
        }
        let radiusSquared = radius * radius

        for i in 0..<pigs.count {
            for j in (i + 1)..<pigs.count {
                let dx = pigs[i].position.x - pigs[j].position.x
                let dy = pigs[i].position.y - pigs[j].position.y
                if dx * dx + dy * dy <= radiusSquared {
                    counts[pigs[i].id, default: 0] += 1
                    counts[pigs[j].id, default: 0] += 1
                }
            }
        }
        return counts
    }

    // MARK: - Private Types

    private struct NeedPriority {
        let name: String
        let value: Double
        let threshold: Double
    }

    private struct Modifiers {
        let hunger: Double
        let energy: Double
        let boredom: Double
        let social: Double
    }

    // MARK: - Private Helpers

    /// Compute personality-based rate modifiers and apply perk adjustments.
    @MainActor
    private static func computeModifiers(
        pig: GuineaPig, state: any NeedsContext
    ) -> Modifiers {
        let hunger = pig.hasTrait(.greedy)
            ? GameConfig.Needs.greedyHungerMult : 1.0
        let energy = pig.hasTrait(.lazy)
            ? GameConfig.Needs.lazyEnergyMult : 1.0
        var boredom = pig.hasTrait(.playful)
            ? GameConfig.Needs.playfulBoredomMult : 1.0

        // Shy overrides social (matches Python: shy check overwrites socialModifier)
        let social: Double
        if pig.hasTrait(.shy) {
            social = GameConfig.Needs.shySocialMult
        } else if pig.hasTrait(.social) {
            social = GameConfig.Needs.socialSocialMult
        } else {
            social = 1.0
        }

        // Enrichment Program perk slows boredom growth by 20%
        if state.hasUpgrade("enrichment_program") {
            boredom *= 0.8
        }

        return Modifiers(hunger: hunger, energy: energy, boredom: boredom, social: social)
    }

    /// Contentment recovery, preferred biome bonus, and Climate Control perk.
    @MainActor
    private static func applyHappinessRecovery(
        pig: inout GuineaPig, hours: Double, state: any NeedsContext
    ) {
        // Asymmetric thresholds: hunger/thirst use lowThreshold, energy uses criticalThreshold
        let hungerOK = pig.needs.hunger >= Double(GameConfig.Needs.lowThreshold)
        let thirstOK = pig.needs.thirst >= Double(GameConfig.Needs.lowThreshold)
        let energyOK = pig.needs.energy >= Double(GameConfig.Needs.criticalThreshold)
        if hungerOK && thirstOK && energyOK {
            pig.needs.happiness += GameConfig.Needs.happinessContentmentRecovery * hours
        }

        // Preferred biome bonus
        if let preferredBiome = pig.preferredBiome {
            let biome = state.farm.getBiomeAt(Int(pig.position.x), Int(pig.position.y))
            if biome?.rawValue == preferredBiome {
                pig.needs.happiness += GameConfig.Biome.preferredBiomeHappinessBonus * hours
            }
        }

        // Climate Control perk
        if state.hasUpgrade("climate_control") {
            pig.needs.happiness += 0.3 * hours
        }
    }

    /// Critical need happiness drain and boredom effects.
    private static func applyHappinessDrains(
        pig: inout GuineaPig, hours: Double, boredomModifier: Double
    ) {
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

        // Boredom increases over time; high boredom drains extra happiness
        pig.needs.boredom += GameConfig.Needs.boredomDecay * hours * boredomModifier
        if pig.needs.boredom > Double(GameConfig.Needs.boredomExtraHappinessThreshold) {
            pig.needs.happiness -= GameConfig.Needs.boredomExtraHappinessDrain * hours
        }
    }

    /// Social need: proximity-based boost vs isolation decay.
    private static func applySocialEffects(
        pig: inout GuineaPig, hours: Double,
        nearbyCount: Int, socialModifier: Double
    ) {
        if nearbyCount > 0 {
            let boost = min(
                Double(nearbyCount) * GameConfig.Needs.socialBoostPerPig,
                GameConfig.Needs.socialBoostCap
            ) * hours
            pig.needs.social += boost
            pig.needs.social -= GameConfig.Needs.socialDecayWithPigs * hours * socialModifier
        } else {
            pig.needs.social -= GameConfig.Needs.socialDecayAlone * hours * socialModifier
        }
    }

    /// Health drain from critical needs and passive recovery.
    @MainActor
    private static func applyHealthEffects(
        pig: inout GuineaPig, hours: Double, state: any NeedsContext
    ) {
        let critical = Double(GameConfig.Needs.criticalThreshold)
        if pig.needs.hunger < critical {
            pig.needs.health -= GameConfig.Needs.healthDrainHunger * hours
        }
        if pig.needs.thirst < critical {
            pig.needs.health -= GameConfig.Needs.healthDrainThirst * hours
        }

        // Passive recovery only when no primary need is critical
        if pig.needs.hunger >= critical && pig.needs.thirst >= critical {
            var recovery = GameConfig.Needs.healthPassiveRecovery
            if state.hasUpgrade("pig_spa") {
                recovery *= 2.0
            }
            pig.needs.health += recovery * hours
        }
    }

    /// Behavior-specific need recovery based on current behavior state.
    @MainActor
    private static func applyBehaviorRecovery(
        pig: inout GuineaPig, gameMinutes: Double, state: any NeedsContext
    ) {
        let hours = gameMinutes / 60.0

        switch pig.behaviorState {
        case .eating:
            pig.needs.hunger += GameConfig.Needs.foodRecovery * hours * 2
            pig.needs.happiness += GameConfig.Needs.eatingHappinessBoost * hours

        case .drinking:
            pig.needs.thirst += GameConfig.Needs.waterRecovery * hours * 2

        case .sleeping:
            var sleepRecovery = GameConfig.Needs.sleepRecoveryPerHour
            if state.hasUpgrade("premium_bedding") {
                sleepRecovery *= 1.25
            }
            pig.needs.energy += sleepRecovery * hours
            pig.needs.health += GameConfig.Needs.healthSleepRecovery * hours

        case .playing:
            pig.needs.happiness += GameConfig.Needs.playHappinessBoost * hours
            pig.needs.boredom -= GameConfig.Needs.boredomPlayRecovery * hours
            pig.needs.energy -= GameConfig.Needs.playEnergyCost * hours

        case .socializing:
            pig.needs.happiness += GameConfig.Needs.socialHappinessBoost * hours
            pig.needs.social += GameConfig.Needs.socialRecovery * hours

        case .idle, .wandering, .courting:
            break
        }
    }
}

// MARK: - Spatial Grid Proximity

extension NeedsSystem {
    /// Pre-compute nearby pig counts using the spatial grid for O(n*k) performance.
    ///
    /// Queries each pig's neighborhood via the spatial hash, replacing the
    /// O(n²/2) all-pairs loop. Results are identical to the brute-force version.
    static func precomputeNearbyCounts(
        pigs: [GuineaPig],
        radius: Double = GameConfig.Needs.socialRadius,
        spatialGrid: SpatialGrid,
        pigDict: [UUID: GuineaPig]
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for pig in pigs {
            let nearby = spatialGrid.getNearby(
                x: pig.position.x, y: pig.position.y,
                radius: radius, pigs: pigDict
            )
            // Subtract 1 for the pig itself (getNearby includes it).
            counts[pig.id] = max(0, nearby.count - 1)
        }
        return counts
    }
}
