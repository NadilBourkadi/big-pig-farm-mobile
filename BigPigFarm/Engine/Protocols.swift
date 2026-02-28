/// Protocols — Narrow context protocols decoupling simulation subsystems from GameState.
/// Maps from: game/facades.py
import Foundation

// MARK: - NeedsContext

/// Read-only access to farm grid, pig list, and upgrades for the needs system.
/// Pig list access lets NeedsSystem evaluate social comfort from nearby pigs.
///
/// `@MainActor` because `GameState` (the sole conformer) is actor-isolated.
/// All simulation runs on `@MainActor` via the tick loop, so this is safe.
@MainActor
protocol NeedsContext: AnyObject {
    var farm: FarmGrid { get }
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
}

// MARK: - BreedingContext

/// Breeding pair management for the breeding system.
@MainActor
protocol BreedingContext: AnyObject {
    var breedingPair: BreedingPair? { get set }
    var breedingProgram: BreedingProgram { get set }
    var contractBoard: ContractBoard { get set }
    var gameTime: GameTime { get }
    var isAtCapacity: Bool { get }
    func clearBreedingPair()
    func getAffinity(_ id1: UUID, _ id2: UUID) -> Int
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func getGuineaPig(_ pigID: UUID) -> GuineaPig?
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
    func logEvent(_ message: String, eventType: String)
    func setBreedingPair(maleID: UUID, femaleID: UUID)
}

// MARK: - BirthContext

/// Birth processing, aging, and pigdex registration.
@MainActor
protocol BirthContext: AnyObject {
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
    func getGuineaPig(_ pigID: UUID) -> GuineaPig?
    func getPigsList() -> [GuineaPig]
    func hasUpgrade(_ upgradeID: String) -> Bool
    func logEvent(_ message: String, eventType: String)
    func removeGuineaPig(_ pigID: UUID) -> GuineaPig?
}

// MARK: - CullingContext

/// Surplus pig management and selling.
@MainActor
protocol CullingContext: AnyObject {
    var breedingProgram: BreedingProgram { get }
    var contractBoard: ContractBoard { get }
    func getFacilitiesByType(_ type: FacilityType) -> [Facility]
    func getPigsList() -> [GuineaPig]
    func logEvent(_ message: String, eventType: String)
}

// MARK: - GameState Conformance

extension GameState: NeedsContext {}
extension GameState: BreedingContext {}
extension GameState: BirthContext {}
extension GameState: CullingContext {}
