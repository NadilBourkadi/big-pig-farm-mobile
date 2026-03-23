/// Adoption -- Adoption center business logic for generating and pricing pigs.
/// Maps from: ui/screens/adoption.py
import Foundation

/// Stateless namespace for adoption pricing, generation, and eligibility logic.
enum Adoption {

    // MARK: - Eligibility

    /// Check whether the farm can accept a new adopted pig.
    ///
    /// Returns `nil` if eligible, or a human-readable reason string if not.
    @MainActor
    static func isEligibleForAdoption(state: any AdoptionContext) -> String? {
        if state.isAtCapacity {
            return "Farm is at capacity! Upgrade or sell pigs."
        }
        return nil
    }

    // MARK: - Cost Calculation

    /// Calculate the adoption cost for a guinea pig.
    ///
    /// Formula: `baseCost × rarityMultiplier × bloodlineCostMultiplier × adoptionDiscount`
    ///
    /// Maps from: `calculate_adoption_cost()` in Python adoption.py.
    @MainActor
    static func calculateAdoptionCost(_ pig: GuineaPig, state: any AdoptionContext) -> Int {
        var cost = Double(GameConfig.Economy.adoptionBaseCost)
        cost *= pig.phenotype.rarity.multiplier
        if let originTag = pig.originTag {
            for bloodline in bloodlines.values where bloodline.displayName == originTag {
                cost *= bloodline.costMultiplier
                break
            }
        }
        if state.hasUpgrade("adoption_discount") {
            cost *= 0.85
        }
        return Int(cost)
    }

    // MARK: - Bloodline Queries

    /// Get all bloodlines available at the given farm tier.
    ///
    /// Delegates to the Models-layer free function in Bloodline.swift.
    static func availableBloodlines(farmTier: Int) -> [Bloodline] {
        getAvailableBloodlines(farmTier: farmTier)
    }

    // MARK: - Pig Generation

    /// Generate a single random guinea pig available for adoption.
    ///
    /// About 50% of generated pigs carry a bloodline allele, gated by farm tier.
    /// Pigs are created as adults (ageDays = 5.0).
    /// Pass an explicit `gender` to force male/female (used by emergency bailout).
    ///
    /// Maps from: `generate_adoption_pig()` in Python adoption.py.
    static func generateAdoptionPig(
        existingNames: Set<String>,
        farmTier: Int,
        gender: Gender? = nil
    ) -> GuineaPig {
        let gender: Gender = gender ?? (Bool.random() ? .male : .female)
        let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
        let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)

        var originTag: String?
        var genotype: Genotype?

        if Double.random(in: 0..<1) < GameConfig.Bloodline.bloodlinePigChance {
            if let bloodline = pickRandomBloodline(farmTier: farmTier) {
                genotype = generateBloodlinePigGenotype(bloodline)
                originTag = bloodline.displayName
            }
        }

        var pig = GuineaPig.create(name: name, gender: gender, genotype: genotype, ageDays: 5.0)
        pig.originTag = originTag
        return pig
    }

    /// Generate a batch of adoption pigs.
    ///
    /// Accumulates names across the batch to guarantee uniqueness within it.
    ///
    /// Maps from: `_generate_available_pigs()` in Python shop.py.
    static func generateAdoptionBatch(
        existingNames: Set<String>,
        farmTier: Int,
        count: Int
    ) -> [GuineaPig] {
        var usedNames = existingNames
        var pigs: [GuineaPig] = []
        for _ in 0..<count {
            let pig = generateAdoptionPig(existingNames: usedNames, farmTier: farmTier)
            usedNames.insert(pig.name)
            pigs.append(pig)
        }
        return pigs
    }

    // MARK: - Spawn Position

    /// Find a valid walkable spawn position for an adopted pig.
    ///
    /// Maps from: `_find_spawn_position()` in Python shop.py.
    @MainActor
    static func findSpawnPosition(in state: any AdoptionContext) -> GridPosition? {
        state.farm.findRandomWalkable()
    }

}
