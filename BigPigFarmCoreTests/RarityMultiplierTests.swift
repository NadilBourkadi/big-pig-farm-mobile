import Testing

@testable import BigPigFarmCore

@Suite("Rarity multiplier")
struct RarityMultiplierTests {

    @Test func commonMultiplierIsOne() {
        #expect(Rarity.common.multiplier == 1.0)
    }

    @Test func uncommonMultiplierIsOnePointFive() {
        #expect(Rarity.uncommon.multiplier == 1.5)
    }

    @Test func rareMultiplierIsTwoPointFive() {
        #expect(Rarity.rare.multiplier == 2.5)
    }

    @Test func veryRareMultiplierIsFour() {
        #expect(Rarity.veryRare.multiplier == 4.0)
    }

    @Test func legendaryMultiplierIsTen() {
        #expect(Rarity.legendary.multiplier == 10.0)
    }

    @Test func allCasesHavePositiveMultiplier() {
        for rarity in Rarity.allCases {
            #expect(rarity.multiplier > 0.0)
        }
    }

    @Test func multiplierIncreasesWithRarity() {
        let ordered: [Rarity] = [.common, .uncommon, .rare, .veryRare, .legendary]
        for i in 1..<ordered.count {
            #expect(ordered[i].multiplier > ordered[i - 1].multiplier)
        }
    }
}
