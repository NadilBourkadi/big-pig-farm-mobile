/// EconomyTests -- Tests for Currency and Market subsystems.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Test Helpers

/// Make an adult common pig with full health.
func makeAdultPig(name: String = "Test", rarity: Rarity = .common) -> GuineaPig {
    var pig = GuineaPig.create(name: name, gender: .female)
    pig.ageDays = 10.0
    pig.phenotype = Phenotype(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: rarity
    )
    pig.needs.health = 100.0
    return pig
}

/// Make a contract requiring the given color (easy difficulty by default).
func makeContract(
    color: BaseColor = .black,
    pattern: Pattern? = nil,
    intensity: ColorIntensity? = nil,
    roan: RoanType? = nil,
    biome: BiomeType? = nil,
    difficulty: ContractDifficulty = .easy,
    reward: Int = 500,
    gameDay: Int = 1,
    fulfilled: Bool = false
) -> BreedingContract {
    BreedingContract(
        requiredColor: color,
        requiredPattern: pattern,
        requiredIntensity: intensity,
        requiredRoan: roan,
        requiredBiome: biome,
        difficulty: difficulty,
        reward: reward,
        deadlineDay: gameDay + 20,
        createdDay: gameDay,
        fulfilled: fulfilled
    )
}

// MARK: - Currency: formatMoney

@Test func formatMoneySmallValue() {
    #expect(Currency.formatMoney(500) == "500")
}

@Test func formatMoneyThousandExact() {
    #expect(Currency.formatMoney(1000) == "1.0K")
}

@Test func formatMoneyThousands() {
    #expect(Currency.formatMoney(1500) == "1.5K")
}

@Test func formatMoneyMillions() {
    #expect(Currency.formatMoney(2_300_000) == "2.3M")
}

@Test func formatMoney999() {
    #expect(Currency.formatMoney(999) == "999")
}

@Test func formatCurrencyPrefix() {
    #expect(Currency.formatCurrency(1500) == "Sq1.5K")
}

// MARK: - Currency: Money Management

@Test @MainActor func canAffordReturnsTrueWhenSufficient() {
    let state = makeGameState()
    state.money = 100
    #expect(Currency.canAfford(state: state, amount: 100))
}

@Test @MainActor func canAffordReturnsFalseWhenInsufficient() {
    let state = makeGameState()
    state.money = 50
    #expect(!Currency.canAfford(state: state, amount: 100))
}

@Test @MainActor func addMoneyIncreasesBalance() {
    let state = makeGameState()
    state.money = 0
    Currency.addMoney(state: state, amount: 200)
    #expect(state.money == 200)
}

@Test @MainActor func spendMoneyDeductsWhenAffordable() {
    let state = makeGameState()
    state.money = 100
    let result = Currency.spendMoney(state: state, amount: 50)
    #expect(result)
    #expect(state.money == 50)
}

@Test @MainActor func spendMoneyReturnsFalseWhenInsufficient() {
    let state = makeGameState()
    state.money = 30
    let result = Currency.spendMoney(state: state, amount: 50)
    #expect(!result)
    #expect(state.money == 30)
}

// MARK: - Market: Pig Valuation

@Test @MainActor func calculateValueCommonAdultFullHealth() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .common)
    #expect(Market.calculatePigValue(pig: pig, state: state) == 25)
}

@Test @MainActor func calculateValueUncommonAdult() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .uncommon)
    // 25 * 1.5 = 37.5 → truncated to 37
    #expect(Market.calculatePigValue(pig: pig, state: state) == 37)
}

@Test @MainActor func calculateValueBabyPig() {
    let state = makeGameState()
    var pig = makeAdultPig(rarity: .common)
    pig.ageDays = 0.0 // baby
    // 25 * 0.5 = 12.5 → truncated to 12
    #expect(Market.calculatePigValue(pig: pig, state: state) == 12)
}

@Test @MainActor func calculateValueSeniorPig() {
    let state = makeGameState()
    var pig = makeAdultPig(rarity: .common)
    pig.ageDays = 35.0 // senior (> 30)
    // 25 * 0.8 = 20
    #expect(Market.calculatePigValue(pig: pig, state: state) == 20)
}

@Test @MainActor func calculateValueAppliesHealthFloor() {
    let state = makeGameState()
    var pig = makeAdultPig(rarity: .common)
    pig.needs.health = 10.0 // below 50%, floor applies
    // max(0.5, 0.1) = 0.5 → 25 * 0.5 = 12.5 → 12
    #expect(Market.calculatePigValue(pig: pig, state: state) == 12)
}

@Test @MainActor func calculateValueMinimumIsOne() {
    // Even with extreme conditions the floor is 1
    let state = makeGameState()
    var pig = makeAdultPig(rarity: .common)
    pig.ageDays = 0.0 // baby
    pig.needs.health = 0.0 // floor to 0.5 in healthMult
    // 25 * 0.5 (baby) * 0.5 (health floor) = 6.25 → 6, not < 1
    let value = Market.calculatePigValue(pig: pig, state: state)
    #expect(value >= 1)
}

@Test @MainActor func calculateValueBreakdownTotalMatchesSingle() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .common)
    let breakdown = Market.calculatePigValueBreakdown(pig: pig, state: state)
    #expect(breakdown.total == Market.calculatePigValue(pig: pig, state: state))
}

@Test @MainActor func calculateValueBreakdownFieldsCorrect() {
    let state = makeGameState()
    let pig = makeAdultPig(rarity: .common)
    let breakdown = Market.calculatePigValueBreakdown(pig: pig, state: state)
    #expect(breakdown.base == 25)
    #expect(breakdown.rarityMultiplier == 1.0)
    #expect(breakdown.ageMultiplier == 1.0)
    #expect(breakdown.perkMultiplier == 1.0)
    #expect(breakdown.groomingMultiplier == 1.0)
}

@Test @MainActor func calculateValueMarketConnectionsPerk() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("market_connections")
    let pig = makeAdultPig(rarity: .common)
    // 25 * 1.1 = 27.5 → 27
    #expect(Market.calculatePigValue(pig: pig, state: state) == 27)
}

@Test @MainActor func calculateValuePremiumBrandingOnRare() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("premium_branding")
    let pig = makeAdultPig(rarity: .rare)
    // 25 * 2.5 * 1.2 = 75
    #expect(Market.calculatePigValue(pig: pig, state: state) == 75)
}

@Test @MainActor func calculateValuePremiumBrandingIgnoredOnCommon() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("premium_branding")
    let pig = makeAdultPig(rarity: .common)
    // premium_branding only applies to rare+; no bonus
    #expect(Market.calculatePigValue(pig: pig, state: state) == 25)
}

// MARK: - Market: sellPig

@Test @MainActor func sellPigRemovesPigFromState() {
    let state = makeGameState()
    let pig = makeAdultPig()
    state.addGuineaPig(pig)

    Market.sellPig(state: state, pig: pig)

    #expect(state.guineaPigs.isEmpty)
}

@Test @MainActor func sellPigAddsMoney() {
    let state = makeGameState()
    state.money = 0
    let pig = makeAdultPig()
    state.addGuineaPig(pig)

    Market.sellPig(state: state, pig: pig)

    #expect(state.money > 0)
}

@Test @MainActor func sellPigIncrementsTotalPigsSold() {
    let state = makeGameState()
    let pig = makeAdultPig()
    state.addGuineaPig(pig)

    Market.sellPig(state: state, pig: pig)

    #expect(state.totalPigsSold == 1)
}

@Test @MainActor func sellPigWithContractAppliesBonus() {
    let state = makeGameState()
    let contract = makeContract(color: .black, reward: 1000)
    state.contractBoard.activeContracts = [contract]
    state.money = 0

    let pig = makeAdultPig(rarity: .common)
    state.addGuineaPig(pig)

    let result = Market.sellPig(state: state, pig: pig)

    #expect(result.contractBonus == 1000)
    #expect(result.total == 25 + 1000)
    #expect(state.contractBoard.activeContracts.isEmpty)
    #expect(state.contractBoard.completedContracts == 1)
}

@Test @MainActor func sellPigWithTradeNetworkBoostsBonusByFactor() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("trade_network")
    let contract = makeContract(color: .black, reward: 1000)
    state.contractBoard.activeContracts = [contract]

    let pig = makeAdultPig(rarity: .common)
    state.addGuineaPig(pig)

    let result = Market.sellPig(state: state, pig: pig)

    // 1000 * 1.25 = 1250
    #expect(result.contractBonus == 1250)
}

@Test @MainActor func sellPigNoContractMatchGivesZeroBonus() {
    let state = makeGameState()
    let contract = makeContract(color: .chocolate, reward: 1000)
    state.contractBoard.activeContracts = [contract]

    var pig = makeAdultPig(rarity: .common)
    pig.phenotype = Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common)
    state.addGuineaPig(pig)

    let result = Market.sellPig(state: state, pig: pig)

    #expect(result.contractBonus == 0)
    #expect(!state.contractBoard.activeContracts.isEmpty)
}

// MARK: - Market: getMarketInfo

@Test @MainActor func getMarketInfoCorrectPigCount() {
    let state = makeGameState()
    state.addGuineaPig(makeAdultPig(name: "Alice"))
    state.addGuineaPig(makeAdultPig(name: "Bob"))

    let info = Market.getMarketInfo(state: state)

    #expect(info.pigCount == 2)
}

@Test @MainActor func getMarketInfoEmptyHerd() {
    let state = makeGameState()
    let info = Market.getMarketInfo(state: state)
    #expect(info.totalValue == 0)
    #expect(info.pigCount == 0)
    #expect(info.mostValuable == nil)
}
