import Testing
@testable import BigPigFarmCore

/// Tests for the PigNames name generation system.
struct PigNamesTests {

    // MARK: - Name Arrays

    @Test func allNamesArrayEqualsSumOfSubArrays() {
        let expectedCount =
            PigNames.cuteNames.count
            + PigNames.foodNames.count
            + PigNames.colorNames.count
            + PigNames.personalityNames.count
            + PigNames.famousNames.count
        #expect(PigNames.allNames.count == expectedCount)
    }

    @Test func nameArraysAreNotEmpty() {
        #expect(!PigNames.cuteNames.isEmpty)
        #expect(!PigNames.foodNames.isEmpty)
        #expect(!PigNames.colorNames.isEmpty)
        #expect(!PigNames.personalityNames.isEmpty)
        #expect(!PigNames.famousNames.isEmpty)
        #expect(!PigNames.malePrefixes.isEmpty)
        #expect(!PigNames.femalePrefixes.isEmpty)
        #expect(!PigNames.neutralPrefixes.isEmpty)
        #expect(!PigNames.suffixes.isEmpty)
    }

    @Test func genderPrefixesAreDistinctSets() {
        let maleSet = Set(PigNames.malePrefixes)
        let femaleSet = Set(PigNames.femalePrefixes)
        let neutralSet = Set(PigNames.neutralPrefixes)

        // Male and female prefix sets should have no overlap
        #expect(maleSet.isDisjoint(with: femaleSet))
        // Neutral should be disjoint from both gendered sets
        #expect(neutralSet.isDisjoint(with: maleSet))
        #expect(neutralSet.isDisjoint(with: femaleSet))
    }

    // MARK: - Name Generation

    @Test func generateNameReturnsNonEmptyString() {
        let name = PigNames.generateName()
        #expect(!name.isEmpty)
    }

    @Test func generateNameWithoutOptionsReturnsBaseName() {
        // Without title or suffix, the name should be one of allNames
        // Run multiple times to account for randomness
        for _ in 0..<50 {
            let name = PigNames.generateName(includeTitle: false, includeSuffix: false)
            #expect(PigNames.allNames.contains(name))
        }
    }

    @Test func generateNameRespectsGenderPrefixes() {
        let allowedMale = Set(PigNames.malePrefixes + PigNames.neutralPrefixes)
        let allowedFemale = Set(PigNames.femalePrefixes + PigNames.neutralPrefixes)
        var titledMaleCount = 0
        var titledFemaleCount = 0

        for _ in 0..<500 {
            let maleName = PigNames.generateName(includeTitle: true, gender: .male)
            if maleName.contains(" "), let prefix = maleName.split(separator: " ").first {
                let prefixStr = String(prefix)
                // Only check names that actually got a title prefix
                if !PigNames.allNames.contains(maleName) {
                    #expect(allowedMale.contains(prefixStr),
                            "Male name '\(maleName)' has disallowed prefix '\(prefixStr)'")
                    titledMaleCount += 1
                }
            }

            let femaleName = PigNames.generateName(includeTitle: true, gender: .female)
            if femaleName.contains(" "), let prefix = femaleName.split(separator: " ").first {
                let prefixStr = String(prefix)
                if !PigNames.allNames.contains(femaleName) {
                    #expect(allowedFemale.contains(prefixStr),
                            "Female name '\(femaleName)' has disallowed prefix '\(prefixStr)'")
                    titledFemaleCount += 1
                }
            }
        }

        // With 500 iterations at 15% title chance, expect ~75 titled names.
        // Require at least 1 to confirm the title logic actually ran.
        #expect(titledMaleCount > 0, "Expected at least one titled male name in 500 attempts")
        #expect(titledFemaleCount > 0, "Expected at least one titled female name in 500 attempts")
    }

    // MARK: - Unique Name Generation

    @Test func uniqueNameGenerationProducesUniqueNames() {
        var existingNames = Set<String>()
        for _ in 0..<100 {
            let name = PigNames.generateUniqueName(existingNames: existingNames)
            #expect(!existingNames.contains(name))
            existingNames.insert(name)
        }
        #expect(existingNames.count == 100)
    }

    @Test func uniqueNameFallsBackToNumberedName() throws {
        // Use maxAttempts: 0 to skip the random loop entirely and force the numbered fallback
        let existingNames = Set(PigNames.allNames)
        let name = PigNames.generateUniqueName(existingNames: existingNames, maxAttempts: 0)
        // The fallback name should be "BaseName N" where N is a number
        let parts = name.split(separator: " ")
        #expect(parts.count >= 2, "Fallback name '\(name)' should have at least two parts")
        let lastPart = String(try #require(parts.last))
        #expect(Int(lastPart) != nil, "Fallback name '\(name)' should end with a number")
    }

    // MARK: - Array Counts (Parity with Python)

    @Test func nameCountsMatchPythonSource() {
        #expect(PigNames.malePrefixes.count == 8)
        #expect(PigNames.femalePrefixes.count == 7)
        #expect(PigNames.neutralPrefixes.count == 4)
        #expect(PigNames.cuteNames.count == 57)
        #expect(PigNames.foodNames.count == 20)
        #expect(PigNames.colorNames.count == 32)
        #expect(PigNames.personalityNames.count == 26)
        #expect(PigNames.famousNames.count == 18)
        #expect(PigNames.suffixes.count == 10)
        #expect(PigNames.allNames.count == 153)
    }
}
