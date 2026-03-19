/// Protocols — Narrow context protocols decoupling simulation subsystems from GameState.
/// Maps from: game/facades.py
import Foundation

// MARK: - Intermediate Protocols

/// Read-only upgrade queries, shared by 8 of 10 context protocols.
@MainActor
protocol UpgradeQueryContext: AnyObject {
    func hasUpgrade(_ upgradeID: String) -> Bool
}

/// Read-only pig queries: list all pigs and look up by ID.
@MainActor
protocol PigQueryContext: AnyObject {
    func getPigsList() -> [GuineaPig]
    func getGuineaPig(_ pigID: UUID) -> GuineaPig?
}

/// Event logging for simulation subsystems.
@MainActor
protocol EventLoggingContext: AnyObject {
    func logEvent(_ message: String, eventType: String)
}

// MARK: - NeedsContext

/// Read-only access to farm grid, pig list, and upgrades for the needs system.
/// Pig list access lets NeedsSystem evaluate social comfort from nearby pigs.
/// Inherits `getGuineaPig(_:)` from `PigQueryContext` — currently unused by NeedsSystem
/// but harmless read-only widening that avoids splitting PigQueryContext for one method.
///
/// `@MainActor` because `GameState` (the sole conformer) is actor-isolated.
/// All simulation runs on `@MainActor` via the tick loop, so this is safe.
@MainActor
protocol NeedsContext: PigQueryContext, UpgradeQueryContext {
    var farm: FarmGrid { get }
}

// MARK: - BreedingContext

/// Breeding pair management for the breeding system.
@MainActor
protocol BreedingContext: PigQueryContext, UpgradeQueryContext, EventLoggingContext {
    var breedingPair: BreedingPair? { get set }
    var breedingProgram: BreedingProgram { get set }
    var contractBoard: ContractBoard { get set }
    var gameTime: GameTime { get }
    var isAtCapacity: Bool { get }
    func clearBreedingPair()
    func getAffinity(_ id1: UUID, _ id2: UUID) -> Int
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func setBreedingPair(maleID: UUID, femaleID: UUID)
}

// MARK: - BirthContext

/// Birth processing, aging, and pigdex registration.
@MainActor
protocol BirthContext: PigQueryContext, UpgradeQueryContext, EventLoggingContext {
    var breedingProgram: BreedingProgram { get set }
    var capacity: Int { get }
    var farm: FarmGrid { get }
    var gameTime: GameTime { get }
    var isAtCapacity: Bool { get }
    var pigCount: Int { get }
    var pigdex: Pigdex { get set }
    var totalPigsBorn: Int { get set }
    func addGuineaPig(_ pig: GuineaPig)
    func addMoney(_ amount: Int)
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func removeGuineaPig(_ pigID: UUID) -> GuineaPig?
}

// MARK: - CullingContext

/// Surplus pig management and selling.
/// Inherits `getGuineaPig(_:)` from `PigQueryContext` — currently unused by Culling
/// but harmless read-only widening that avoids splitting PigQueryContext for one method.
@MainActor
protocol CullingContext: PigQueryContext, EventLoggingContext {
    var breedingProgram: BreedingProgram { get }
    var contractBoard: ContractBoard { get }
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
}

// MARK: - CurrencyContext

/// Read/write access to money for currency operations.
@MainActor
protocol CurrencyContext: AnyObject {
    var money: Int { get }
    func addMoney(_ amount: Int)
    @discardableResult func spendMoney(_ amount: Int) -> Bool
}

// MARK: - AdoptionContext

/// Adoption eligibility and spawn position checks.
@MainActor
protocol AdoptionContext: UpgradeQueryContext {
    var farm: FarmGrid { get set }
    var isAtCapacity: Bool { get }
}

// MARK: - MarketContext

/// Pig valuation, sale, and contract fulfillment.
@MainActor
protocol MarketContext: CurrencyContext, PigQueryContext, UpgradeQueryContext, EventLoggingContext {
    var contractBoard: ContractBoard { get set }
    var farm: FarmGrid { get }
    var totalPigsSold: Int { get set }
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func removeGuineaPig(_ pigID: UUID) -> GuineaPig?
}

// MARK: - UpgradesContext

/// Perk purchase and immediate-effect application.
@MainActor
protocol UpgradesContext: CurrencyContext, UpgradeQueryContext, EventLoggingContext {
    var farmTier: Int { get }
    var purchasedUpgrades: Set<String> { get set }
    func getFacilitiesList() -> [Facility]
    func updateFacility(_ facility: Facility)
}

// MARK: - ShopContext

/// Facility purchase/sale, tier upgrades, and room expansion.
@MainActor
protocol ShopContext: CurrencyContext, PigQueryContext, UpgradeQueryContext, EventLoggingContext {
    var contractBoard: ContractBoard { get }
    var farm: FarmGrid { get set }
    var farmTier: Int { get set }
    var pigdex: Pigdex { get }
    var totalPigsBorn: Int { get }
    func addFacility(_ facility: Facility) -> Bool
    func getFacilitiesList() -> [Facility]
    @discardableResult func removeFacility(_ facilityID: UUID) -> Facility?
    func updateFacility(_ facility: Facility)
    func updateGuineaPig(_ pig: GuineaPig)
}

// MARK: - ContractGeneratorContext

/// Upgrade queries for contract generation. Named alias kept for call-site clarity
/// and future extension — ContractGenerationSystem may need additional members here
/// without affecting unrelated contexts.
@MainActor
protocol ContractGeneratorContext: UpgradeQueryContext {}

// MARK: - GameState Conformance

extension GameState: NeedsContext {}
extension GameState: BreedingContext {}
extension GameState: BirthContext {}
extension GameState: CullingContext {}
extension GameState: CurrencyContext {}
extension GameState: AdoptionContext {}
extension GameState: MarketContext {}
extension GameState: UpgradesContext {}
extension GameState: ShopContext {}
extension GameState: ContractGeneratorContext {}
