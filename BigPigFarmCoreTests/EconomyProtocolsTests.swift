/// EconomyProtocolsTests -- Verify GameState conforms to all Economy context protocols
/// and Economy functions work through protocol existentials (including lightweight stubs).
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Stubs

/// Minimal CurrencyContext stub for testing Currency functions in isolation.
@MainActor
final class StubCurrencyContext: CurrencyContext {
    var money: Int

    init(money: Int = 1000) {
        self.money = money
    }

    func addMoney(_ amount: Int) {
        money += amount
    }

    @discardableResult
    func spendMoney(_ amount: Int) -> Bool {
        guard money >= amount else { return false }
        money -= amount
        return true
    }
}

/// Minimal AdoptionContext stub for testing Adoption functions in isolation.
@MainActor
final class StubAdoptionContext: AdoptionContext {
    var farm: FarmGrid
    var isAtCapacity: Bool
    var upgrades: Set<String>

    init(isAtCapacity: Bool = false, upgrades: Set<String> = []) {
        self.farm = FarmGrid.createStarter()
        self.isAtCapacity = isAtCapacity
        self.upgrades = upgrades
    }

    func hasUpgrade(_ upgradeID: String) -> Bool {
        upgrades.contains(upgradeID)
    }
}

/// Minimal ContractGeneratorContext stub.
@MainActor
final class StubContractGeneratorContext: ContractGeneratorContext {
    var upgrades: Set<String>

    init(upgrades: Set<String> = []) {
        self.upgrades = upgrades
    }

    func hasUpgrade(_ upgradeID: String) -> Bool {
        upgrades.contains(upgradeID)
    }
}

// MARK: - CurrencyContext Conformance

@Test @MainActor func currencyContextMoneyReadable() {
    let state = GameState()
    let context: any CurrencyContext = state
    #expect(context.money == GameConfig.Economy.startingMoney)
}

@Test @MainActor func currencyContextAddMoney() {
    let state = GameState()
    let context: any CurrencyContext = state
    let initial = context.money
    context.addMoney(50)
    #expect(context.money == initial + 50)
    #expect(state.money == initial + 50)
}

@Test @MainActor func currencyContextSpendMoney() {
    let state = GameState()
    let context: any CurrencyContext = state
    let initial = context.money
    let success = context.spendMoney(10)
    #expect(success)
    #expect(context.money == initial - 10)
}

@Test @MainActor func currencyContextSpendMoneyInsufficientFunds() {
    let state = GameState()
    let context: any CurrencyContext = state
    let success = context.spendMoney(state.money + 1)
    #expect(!success)
}

// MARK: - AdoptionContext Conformance

@Test @MainActor func adoptionContextIsAtCapacity() {
    let state = GameState()
    let context: any AdoptionContext = state
    #expect(!context.isAtCapacity)
}

@Test @MainActor func adoptionContextFarmAccessible() {
    let state = GameState()
    let context: any AdoptionContext = state
    #expect(context.farm.width > 0)
}

@Test @MainActor func adoptionContextHasUpgrade() {
    let state = GameState()
    let context: any AdoptionContext = state
    #expect(!context.hasUpgrade("adoption_discount"))
    state.purchasedUpgrades.insert("adoption_discount")
    #expect(context.hasUpgrade("adoption_discount"))
}

// MARK: - MarketContext Conformance

@Test @MainActor func marketContextContractBoardWritable() {
    let state = GameState()
    let context: any MarketContext = state
    #expect(context.contractBoard.activeContracts.isEmpty)
    let contract = BreedingContract(requiredColor: .black, reward: 100, deadlineDay: 10)
    context.contractBoard.activeContracts.append(contract)
    #expect(state.contractBoard.activeContracts.count == 1)
}

@Test @MainActor func marketContextTotalPigsSoldWritable() {
    let state = GameState()
    let context: any MarketContext = state
    #expect(context.totalPigsSold == 0)
    context.totalPigsSold = 5
    #expect(state.totalPigsSold == 5)
}

@Test @MainActor func marketContextInheritsCurrency() {
    let state = GameState()
    let context: any MarketContext = state
    // MarketContext inherits CurrencyContext — verify money access works
    #expect(context.money == GameConfig.Economy.startingMoney)
    context.addMoney(100)
    #expect(state.money == GameConfig.Economy.startingMoney + 100)
}

// MARK: - UpgradesContext Conformance

@Test @MainActor func upgradesContextFarmTierReadable() {
    let state = GameState()
    let context: any UpgradesContext = state
    #expect(context.farmTier == 1)
}

@Test @MainActor func upgradesContextPurchasedUpgradesWritable() {
    let state = GameState()
    let context: any UpgradesContext = state
    #expect(context.purchasedUpgrades.isEmpty)
    context.purchasedUpgrades.insert("test_perk")
    #expect(state.purchasedUpgrades.contains("test_perk"))
}

@Test @MainActor func upgradesContextLogEvent() {
    let state = GameState()
    let context: any UpgradesContext = state
    context.logEvent("Perk purchased", eventType: "purchase")
    #expect(state.events.count == 1)
    #expect(state.events[0].eventType == "purchase")
}

// MARK: - ShopContext Conformance

@Test @MainActor func shopContextFarmTierWritable() {
    let state = GameState()
    let context: any ShopContext = state
    context.farmTier = 3
    #expect(state.farmTier == 3)
}

@Test @MainActor func shopContextFarmWritable() {
    let state = GameState()
    let context: any ShopContext = state
    #expect(context.farm.width > 0)
    // Verify set works (needed for GridExpansion.addRoom)
    var farm = context.farm
    farm.tier = 2
    context.farm = farm
    #expect(state.farm.tier == 2)
}

@Test @MainActor func shopContextTotalPigsBornReadable() {
    let state = GameState()
    let context: any ShopContext = state
    #expect(context.totalPigsBorn == 0)
}

@Test @MainActor func shopContextInheritsCurrency() {
    let state = GameState()
    let context: any ShopContext = state
    let initial = context.money
    context.addMoney(200)
    #expect(state.money == initial + 200)
}

// MARK: - ContractGeneratorContext Conformance

@Test @MainActor func contractGeneratorContextHasUpgrade() {
    let state = GameState()
    let context: any ContractGeneratorContext = state
    #expect(!context.hasUpgrade("contract_negotiator"))
    state.purchasedUpgrades.insert("contract_negotiator")
    #expect(context.hasUpgrade("contract_negotiator"))
}

// MARK: - Stub-Based Economy Function Tests

@Test @MainActor func currencyAddMoneyWithStub() {
    let stub = StubCurrencyContext(money: 500)
    Currency.addMoney(state: stub, amount: 100)
    #expect(stub.money == 600)
}

@Test @MainActor func currencySpendMoneyWithStub() {
    let stub = StubCurrencyContext(money: 500)
    let success = Currency.spendMoney(state: stub, amount: 200)
    #expect(success)
    #expect(stub.money == 300)
}

@Test @MainActor func currencySpendMoneyInsufficientWithStub() {
    let stub = StubCurrencyContext(money: 50)
    let success = Currency.spendMoney(state: stub, amount: 100)
    #expect(!success)
    #expect(stub.money == 50)
}

@Test @MainActor func currencyCanAffordWithStub() {
    let stub = StubCurrencyContext(money: 100)
    #expect(Currency.canAfford(state: stub, amount: 100))
    #expect(!Currency.canAfford(state: stub, amount: 101))
}

@Test @MainActor func adoptionEligibilityWithStub() {
    let eligible = StubAdoptionContext(isAtCapacity: false)
    #expect(Adoption.isEligibleForAdoption(state: eligible) == nil)

    let full = StubAdoptionContext(isAtCapacity: true)
    #expect(Adoption.isEligibleForAdoption(state: full) != nil)
}

@Test @MainActor func adoptionCostWithDiscountStub() {
    let pig = GuineaPig.create(name: "Tester", gender: .female)

    let noDiscount = StubAdoptionContext(upgrades: [])
    let fullCost = Adoption.calculateAdoptionCost(pig, state: noDiscount)

    let withDiscount = StubAdoptionContext(upgrades: ["adoption_discount"])
    let discountedCost = Adoption.calculateAdoptionCost(pig, state: withDiscount)

    #expect(discountedCost < fullCost)
}

@Test @MainActor func contractGeneratorWithStub() {
    let stub = StubContractGeneratorContext(upgrades: ["contract_negotiator"])
    let contracts = ContractGenerator.generateContracts(
        farmTier: 2,
        gameDay: 1,
        availableBiomes: [.meadow],
        gameState: stub
    )
    // contract_negotiator adds +1 to max contracts
    #expect(!contracts.isEmpty)
}

@Test @MainActor func contractGeneratorVipWithStub() {
    let noVip = StubContractGeneratorContext(upgrades: [])
    let contracts1 = ContractGenerator.generateContracts(
        farmTier: 5,
        gameDay: 1,
        availableBiomes: [.meadow],
        gameState: noVip
    )
    // Without vip_contracts, no legendary difficulty should appear
    let hasLegendary1 = contracts1.contains { $0.difficulty == .legendary }

    let withVip = StubContractGeneratorContext(upgrades: ["vip_contracts"])
    // Generate many contracts to increase chance of legendary
    var sawLegendary = false
    for _ in 0..<50 {
        let contracts = ContractGenerator.generateContracts(
            farmTier: 5,
            gameDay: 1,
            availableBiomes: [.meadow],
            gameState: withVip
        )
        if contracts.contains(where: { $0.difficulty == .legendary }) {
            sawLegendary = true
            break
        }
    }

    #expect(!hasLegendary1)
    #expect(sawLegendary)
}
