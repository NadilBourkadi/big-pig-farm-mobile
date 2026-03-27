/// TreatTypeDisplayTests — Tests for TreatType display and sprite properties.
import Testing

@testable import BigPigFarmCore

struct TreatTypeDisplayTests {

    @Test func spriteAssetNameMatchesRawValue() {
        #expect(TreatType.freshVeggies.spriteAssetName == "Sprites/Treats/treat_fresh_veggies")
        #expect(TreatType.fruitSlices.spriteAssetName == "Sprites/Treats/treat_fruit_slices")
        #expect(TreatType.herbBundle.spriteAssetName == "Sprites/Treats/treat_herb_bundle")
        #expect(TreatType.haySampler.spriteAssetName == "Sprites/Treats/treat_hay_sampler")
    }

    @Test func effectSummaryNonEmpty() {
        for type in TreatType.allCases {
            #expect(!type.effectSummary.isEmpty, "effectSummary should not be empty for \(type)")
        }
    }

    @Test func effectSummaryContent() {
        #expect(TreatType.freshVeggies.effectSummary.contains("hunger"))
        #expect(TreatType.fruitSlices.effectSummary.contains("happiness"))
        #expect(TreatType.herbBundle.effectSummary.contains("health"))
        #expect(TreatType.haySampler.effectSummary.contains("social"))
    }

    @Test func systemImageNameNonEmpty() {
        for type in TreatType.allCases {
            #expect(!type.systemImageName.isEmpty, "systemImageName should not be empty for \(type)")
        }
    }

    @Test func tierGatingValues() {
        #expect(TreatType.freshVeggies.requiredTier == 1)
        #expect(TreatType.fruitSlices.requiredTier == 2)
        #expect(TreatType.herbBundle.requiredTier == 3)
        #expect(TreatType.haySampler.requiredTier == 4)
    }

    @Test func treatTypesAreDistinct() {
        let names = TreatType.allCases.map(\.spriteAssetName)
        #expect(Set(names).count == TreatType.allCases.count, "All sprite asset names should be unique")

        let icons = TreatType.allCases.map(\.systemImageName)
        #expect(Set(icons).count == TreatType.allCases.count, "All system image names should be unique")
    }
}
