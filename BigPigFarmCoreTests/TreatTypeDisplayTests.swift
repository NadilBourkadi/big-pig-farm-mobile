/// TreatTypeDisplayTests — Tests for TreatType display and sprite properties.
import Testing

@testable import BigPigFarmCore

struct TreatTypeDisplayTests {

    @Test func spriteAssetNameMatchesRawValue() {
        #expect(TreatType.leafyGreens.spriteAssetName == "Sprites/Treats/treat_leafy_greens")
        #expect(TreatType.cucumber.spriteAssetName == "Sprites/Treats/treat_cucumber")
        #expect(TreatType.strawberries.spriteAssetName == "Sprites/Treats/treat_strawberries")
        #expect(TreatType.watermelon.spriteAssetName == "Sprites/Treats/treat_watermelon")
    }

    @Test func effectSummaryNonEmpty() {
        for type in TreatType.allCases {
            #expect(!type.effectSummary.isEmpty, "effectSummary should not be empty for \(type)")
        }
    }

    @Test func effectSummaryContent() {
        #expect(TreatType.leafyGreens.effectSummary.contains("hunger"))
        #expect(TreatType.cucumber.effectSummary.contains("happiness"))
        #expect(TreatType.strawberries.effectSummary.contains("health"))
        #expect(TreatType.watermelon.effectSummary.contains("social"))
    }

    @Test func systemImageNameNonEmpty() {
        for type in TreatType.allCases {
            #expect(!type.systemImageName.isEmpty, "systemImageName should not be empty for \(type)")
        }
    }

    @Test func tierGatingValues() {
        #expect(TreatType.leafyGreens.requiredTier == 1)
        #expect(TreatType.cucumber.requiredTier == 2)
        #expect(TreatType.strawberries.requiredTier == 3)
        #expect(TreatType.watermelon.requiredTier == 4)
    }

    @Test func treatTypesAreDistinct() {
        let names = TreatType.allCases.map(\.spriteAssetName)
        #expect(Set(names).count == TreatType.allCases.count, "All sprite asset names should be unique")

        let icons = TreatType.allCases.map(\.systemImageName)
        #expect(Set(icons).count == TreatType.allCases.count, "All system image names should be unique")
    }
}
