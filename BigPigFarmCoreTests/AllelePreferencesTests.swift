/// AllelePreferencesTests -- Tests for the Selective Advantage allele preference system.
import Foundation
import Testing

@testable import BigPigFarmCore

// MARK: - AllelePreferences Model Tests

@Suite("AllelePreferences Model")
struct AllelePreferencesModelTests {

    @Test("Defaults to noPreference on all 6 loci")
    func defaultsToNoPreference() {
        let prefs = AllelePreferences()
        #expect(prefs.eLocus == .noPreference)
        #expect(prefs.bLocus == .noPreference)
        #expect(prefs.sLocus == .noPreference)
        #expect(prefs.cLocus == .noPreference)
        #expect(prefs.rLocus == .noPreference)
        #expect(prefs.dLocus == .noPreference)
    }

    @Test("hasAnyPreference returns false when all default")
    func hasAnyPreferenceFalseWhenAllDefault() {
        let prefs = AllelePreferences()
        #expect(!prefs.hasAnyPreference)
    }

    @Test("hasAnyPreference returns true when one locus is set")
    func hasAnyPreferenceTrueWhenOneSet() {
        var prefs = AllelePreferences()
        prefs.eLocus = .dominant
        #expect(prefs.hasAnyPreference)
    }

    @Test("preference(forLocus:) returns correct value for each locus")
    func preferenceForLocusReturnsCorrectValue() {
        var prefs = AllelePreferences()
        prefs.eLocus = .dominant
        prefs.bLocus = .recessive
        prefs.sLocus = .dominant
        prefs.cLocus = .recessive
        prefs.rLocus = .dominant
        prefs.dLocus = .recessive

        #expect(prefs.preference(forLocus: "eLocus") == .dominant)
        #expect(prefs.preference(forLocus: "bLocus") == .recessive)
        #expect(prefs.preference(forLocus: "sLocus") == .dominant)
        #expect(prefs.preference(forLocus: "cLocus") == .recessive)
        #expect(prefs.preference(forLocus: "rLocus") == .dominant)
        #expect(prefs.preference(forLocus: "dLocus") == .recessive)
    }

    @Test("preference(forLocus:) returns noPreference for unknown locus")
    func preferenceForUnknownLocusReturnsDefault() {
        let prefs = AllelePreferences()
        #expect(prefs.preference(forLocus: "unknownLocus") == .noPreference)
    }

    @Test("Codable round-trip preserves all values")
    func codableRoundTrip() throws {
        var prefs = AllelePreferences()
        prefs.eLocus = .dominant
        prefs.bLocus = .recessive
        prefs.sLocus = .noPreference
        prefs.cLocus = .dominant
        prefs.rLocus = .recessive
        prefs.dLocus = .dominant

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AllelePreferences.self, from: data)
        #expect(decoded == prefs)
    }
}

// MARK: - PrestigeState Backward Compatibility Tests

@Suite("PrestigeState Backward Compatibility")
struct PrestigeStateBackwardCompatTests {

    @Test("Decodes without allelePreferences field (old save format)")
    func decodesWithoutAllelePreferencesField() throws {
        let json = """
        {
            "rosette_balance": 10,
            "purchased_upgrades": [],
            "farm_count": 2,
            "previous_pigdex_entries": [],
            "lifetime_stats": {
                "total_pigs_bred": 0,
                "total_squeaks_earned": 0,
                "total_pigs_sold": 0,
                "total_contracts_completed": 0,
                "total_facilities_built": 0
            },
            "visit_streak": {
                "current_streak": 0,
                "last_visit_date": null
            },
            "biome_mastery": {
                "pigs_bred_by_biome": []
            },
            "keepsake_perks": []
        }
        """
        let data = Data(json.utf8)
        let state = try JSONDecoder().decode(PrestigeState.self, from: data)
        #expect(state.rosetteBalance == 10)
        #expect(state.farmCount == 2)
        #expect(state.allelePreferences == AllelePreferences())
        #expect(!state.allelePreferences.hasAnyPreference)
    }

    @Test("Decodes with allelePreferences field present")
    func decodesWithAllelePreferencesField() throws {
        let json = """
        {
            "rosette_balance": 5,
            "purchased_upgrades": ["selective_advantage"],
            "farm_count": 3,
            "previous_pigdex_entries": [],
            "lifetime_stats": {
                "total_pigs_bred": 100,
                "total_squeaks_earned": 5000,
                "total_pigs_sold": 50,
                "total_contracts_completed": 10,
                "total_facilities_built": 5
            },
            "visit_streak": {
                "current_streak": 3,
                "last_visit_date": null
            },
            "biome_mastery": {
                "pigs_bred_by_biome": []
            },
            "keepsake_perks": [],
            "allele_preferences": {
                "e_locus": "dominant",
                "b_locus": "recessive",
                "s_locus": "no_preference",
                "c_locus": "no_preference",
                "r_locus": "dominant",
                "d_locus": "no_preference"
            }
        }
        """
        let data = Data(json.utf8)
        let state = try JSONDecoder().decode(PrestigeState.self, from: data)
        #expect(state.allelePreferences.eLocus == .dominant)
        #expect(state.allelePreferences.bLocus == .recessive)
        #expect(state.allelePreferences.rLocus == .dominant)
        #expect(state.allelePreferences.sLocus == .noPreference)
        #expect(state.allelePreferences.hasAnyPreference)
    }
}

// MARK: - Biased Inheritance Tests

@Suite("Biased Inheritance")
struct BiasedInheritanceTests {

    @Test("No preference falls back to random inheritance")
    func noPreferenceFallsBackToRandom() {
        let parent1 = AllelePair(first: "E", second: "e")
        let parent2 = AllelePair(first: "E", second: "e")
        var dominantCount = 0
        let trials = 10_000
        for _ in 0..<trials {
            let result = inheritAlleleWithPreference(
                parent1, parent2,
                preference: .noPreference, dominant: "E", recessive: "e"
            )
            if result.first == "E" { dominantCount += 1 }
        }
        let ratio = Double(dominantCount) / Double(trials)
        #expect(ratio > 0.35 && ratio < 0.65,
            "Expected ~50% dominant allele in first position, got \(ratio)")
    }

    @Test("Dominant preference biases toward dominant allele")
    func dominantPreferenceBiasesOutcome() {
        let parent1 = AllelePair(first: "E", second: "e")
        let parent2 = AllelePair(first: "E", second: "e")
        var dominantHomozygous = 0
        let trials = 10_000
        for _ in 0..<trials {
            let result = inheritAlleleWithPreference(
                parent1, parent2,
                preference: .dominant, dominant: "E", recessive: "e"
            )
            if result.first == "E" && result.second == "E" {
                dominantHomozygous += 1
            }
        }
        // With 80% bias from each heterozygous parent:
        // P(E from parent) = 0.80 + 0.20 * 0.50 = 0.90
        // P(EE) = 0.90 * 0.90 = 0.81
        let ratio = Double(dominantHomozygous) / Double(trials)
        #expect(ratio > 0.70, "Expected >70% EE offspring, got \(ratio)")
        #expect(ratio < 0.90, "Expected <90% EE offspring, got \(ratio)")
    }

    @Test("Recessive preference biases toward recessive allele")
    func recessivePreferenceBiasesOutcome() {
        let parent1 = AllelePair(first: "E", second: "e")
        let parent2 = AllelePair(first: "E", second: "e")
        var recessiveHomozygous = 0
        let trials = 10_000
        for _ in 0..<trials {
            let result = inheritAlleleWithPreference(
                parent1, parent2,
                preference: .recessive, dominant: "E", recessive: "e"
            )
            if result.first == "e" && result.second == "e" {
                recessiveHomozygous += 1
            }
        }
        // P(e from parent) = 0.80 + 0.20 * 0.50 = 0.90
        // P(ee) = 0.90 * 0.90 = 0.81
        let ratio = Double(recessiveHomozygous) / Double(trials)
        #expect(ratio > 0.70, "Expected >70% ee offspring, got \(ratio)")
        #expect(ratio < 0.90, "Expected <90% ee offspring, got \(ratio)")
    }

    @Test("Preference ignored when parent lacks target allele")
    func preferenceIgnoredWhenParentLacksTarget() {
        // Both parents are EE — no "e" allele available
        let parent1 = AllelePair(first: "E", second: "E")
        let parent2 = AllelePair(first: "E", second: "E")
        var allE = true
        for _ in 0..<1000 {
            let result = inheritAlleleWithPreference(
                parent1, parent2,
                preference: .recessive, dominant: "E", recessive: "e"
            )
            if result.first != "E" || result.second != "E" { allE = false }
        }
        #expect(allE, "Homozygous dominant parents should only produce E alleles")
    }

    @Test("breed() with allelePreferences biases offspring genotype")
    func breedWithPreferencesBiasesOffspring() {
        let parent1 = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "b"),
            sLocus: AllelePair(first: "S", second: "s"),
            cLocus: AllelePair(first: "C", second: "ch"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "d")
        )
        let parent2 = parent1

        var prefs = AllelePreferences()
        prefs.eLocus = .recessive

        var recessiveECount = 0
        let trials = 5000
        for _ in 0..<trials {
            let result = breed(parent1, parent2, allelePreferences: prefs)
            if result.genotype.eLocus.first == "e" && result.genotype.eLocus.second == "e" {
                recessiveECount += 1
            }
        }

        let ratio = Double(recessiveECount) / Double(trials)
        // Without preference: 25% ee. With 80% bias: P(e) = 0.90, P(ee) = 0.81.
        #expect(ratio > 0.70, "Expected significantly more ee than baseline 25%, got \(ratio)")
    }

    @Test("breed() without preferences produces baseline results")
    func breedWithoutPreferencesIsBaseline() {
        let parent1 = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "b"),
            sLocus: AllelePair(first: "S", second: "s"),
            cLocus: AllelePair(first: "C", second: "ch"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "d")
        )
        let parent2 = parent1

        var recessiveECount = 0
        let trials = 10_000
        for _ in 0..<trials {
            let result = breed(parent1, parent2)
            if result.genotype.eLocus.first == "e" && result.genotype.eLocus.second == "e" {
                recessiveECount += 1
            }
        }

        let ratio = Double(recessiveECount) / Double(trials)
        // Standard Mendelian: 25% ee from Ee x Ee
        #expect(ratio > 0.20 && ratio < 0.30,
            "Expected ~25% ee without preferences, got \(ratio)")
    }
}

// MARK: - Roan Safety Tests

@Suite("Roan Safety with Preferences")
struct RoanSafetyTests {

    @Test("Dominant roan preference never produces lethal RR")
    func dominantRoanPreferenceNeverProducesRR() {
        let parent1 = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
        let parent2 = parent1

        var prefs = AllelePreferences()
        prefs.rLocus = .dominant

        for _ in 0..<10_000 {
            let result = breed(parent1, parent2, allelePreferences: prefs)
            #expect(!result.genotype.rLocus.isHomozygous("R"),
                "Lethal RR genotype should never appear")
        }
    }

    @Test("Dominant roan preference produces more Rr than baseline")
    func dominantRoanPreferenceSkewsTowardRr() {
        let parent1 = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
        let parent2 = parent1

        var prefs = AllelePreferences()
        prefs.rLocus = .dominant

        var rrCount = 0 // Should be Rr (heterozygous with R)
        let trials = 10_000
        for _ in 0..<trials {
            let result = breed(parent1, parent2, allelePreferences: prefs)
            if result.genotype.rLocus.contains("R") {
                rrCount += 1
            }
        }

        let ratio = Double(rrCount) / Double(trials)
        // Baseline Rr from Rr x Rr = 50%. With dominant preference and
        // biased reroll, should be significantly higher.
        #expect(ratio > 0.60,
            "Expected >60% Rr with dominant roan preference, got \(ratio)")
    }
}

// MARK: - Auto-Pair Scoring Tests

@Suite("Preference Alignment Scoring")
struct PreferenceAlignmentScoringTests {

    @Test("No preferences gives zero bonus")
    func noPreferencesGivesZeroBonus() {
        let genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "b"),
            sLocus: AllelePair(first: "S", second: "s"),
            cLocus: AllelePair(first: "C", second: "ch"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "d")
        )
        let prefs = AllelePreferences()
        let bonus = testPreferenceAlignmentBonus(genotype, genotype, preferences: prefs)
        #expect(bonus == 0.0)
    }

    @Test("Aligned genotypes increase bonus")
    func alignedGenotypesIncreaseBonus() {
        // Both parents carry "e" — align with recessive preference
        let male = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
        let female = male

        var prefs = AllelePreferences()
        prefs.eLocus = .recessive

        let bonus = testPreferenceAlignmentBonus(male, female, preferences: prefs)
        #expect(bonus == 0.05, "One aligned locus should give 0.05 bonus")
    }

    @Test("Parents lacking preferred allele give no bonus")
    func parentsLackingPreferredAlleleGiveNoBonus() {
        // Both parents are EE — no "e" allele
        let genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )

        var prefs = AllelePreferences()
        prefs.eLocus = .recessive

        let bonus = testPreferenceAlignmentBonus(genotype, genotype, preferences: prefs)
        #expect(bonus == 0.0, "No bonus when parents lack the preferred allele")
    }

    @Test("Maximum bonus with all 6 loci aligned")
    func maximumBonusWithAllLociAligned() {
        // All heterozygous — every locus carries both alleles
        let genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "b"),
            sLocus: AllelePair(first: "S", second: "s"),
            cLocus: AllelePair(first: "C", second: "ch"),
            rLocus: AllelePair(first: "R", second: "r"),
            dLocus: AllelePair(first: "D", second: "d")
        )

        var prefs = AllelePreferences()
        prefs.eLocus = .dominant
        prefs.bLocus = .recessive
        prefs.sLocus = .dominant
        prefs.cLocus = .recessive
        prefs.rLocus = .dominant
        prefs.dLocus = .recessive

        let bonus = testPreferenceAlignmentBonus(genotype, genotype, preferences: prefs)
        #expect(abs(bonus - 0.30) < 0.001, "All 6 loci aligned should give 0.30 bonus, got \(bonus)")
    }
}

// MARK: - Test Helper

/// Mirror of Breeding.preferenceAlignmentBonus (private static).
/// KEEP IN SYNC with Breeding+ProgramAutoPair.swift if the scoring algorithm changes.
func testPreferenceAlignmentBonus(
    _ male: Genotype,
    _ female: Genotype,
    preferences: AllelePreferences
) -> Double {
    var bonus = 0.0
    for (locusName, dominant, recessive) in locusDefinitions {
        let pref = preferences.preference(forLocus: locusName)
        guard pref != .noPreference else { continue }
        let target = pref == .dominant ? dominant : recessive
        let malePair = male.allelePair(forLocus: locusName)
        let femalePair = female.allelePair(forLocus: locusName)
        if malePair.contains(target) && femalePair.contains(target) {
            bonus += 0.05
        }
    }
    return bonus
}
