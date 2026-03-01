/// GameState+Codable — Persistence support for GameState.
/// Maps from: Spec 08 Section 3.
import Foundation

// MARK: - CodableSnapshot

/// A Sendable, Codable mirror of all GameState persistent fields.
/// Constructed by GameState.encodeToJSON() and consumed by GameState.fromSnapshot().
struct CodableSnapshot: Codable, Sendable {
    let guineaPigs: [UUID: GuineaPig]
    let facilities: [UUID: Facility]
    let farm: FarmGrid
    let money: Int
    let gameTime: GameTime
    let speed: GameSpeed
    let isPaused: Bool
    let sessionStart: Date
    let lastSave: Date?
    let events: [EventLog]
    let pigdex: Pigdex
    let contractBoard: ContractBoard
    let breedingProgram: BreedingProgram
    let breedingPair: BreedingPair?
    let socialAffinity: [String: Int]
    let farmTier: Int
    let purchasedUpgrades: Set<String>
    let totalPigsBorn: Int
    let totalPigsSold: Int
    let totalEarnings: Int

    enum CodingKeys: String, CodingKey {
        case guineaPigs = "guinea_pigs"
        case facilities
        case farm
        case money
        case gameTime = "game_time"
        case speed
        case isPaused = "is_paused"
        case sessionStart = "session_start"
        case lastSave = "last_save"
        case events
        case pigdex
        case contractBoard = "contract_board"
        case breedingProgram = "breeding_program"
        case breedingPair = "breeding_pair"
        case socialAffinity = "social_affinity"
        case farmTier = "farm_tier"
        case purchasedUpgrades = "purchased_upgrades"
        case totalPigsBorn = "total_pigs_born"
        case totalPigsSold = "total_pigs_sold"
        case totalEarnings = "total_earnings"
    }
}

// MARK: - SaveEnvelope

/// Versioned wrapper around CodableSnapshot for safe migration checks.
struct SaveEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let snapshot: CodableSnapshot

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case snapshot = "state"
    }
}

// MARK: - GameState Codable Support

extension GameState {
    /// Encode all persistent state to JSON.
    @MainActor
    func encodeToJSON() throws -> Data {
        let snapshot = CodableSnapshot(
            guineaPigs: guineaPigs,
            facilities: facilities,
            farm: farm,
            money: money,
            gameTime: gameTime,
            speed: speed,
            isPaused: isPaused,
            sessionStart: sessionStart,
            lastSave: lastSave,
            events: events,
            pigdex: pigdex,
            contractBoard: contractBoard,
            breedingProgram: breedingProgram,
            breedingPair: breedingPair,
            socialAffinity: socialAffinity,
            farmTier: farmTier,
            purchasedUpgrades: purchasedUpgrades,
            totalPigsBorn: totalPigsBorn,
            totalPigsSold: totalPigsSold,
            totalEarnings: totalEarnings
        )
        let envelope = SaveEnvelope(schemaVersion: SaveManager.schemaVersion, snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(envelope)
    }

    /// Restore game state from a decoded snapshot.
    @MainActor
    static func fromSnapshot(_ snapshot: CodableSnapshot) -> GameState {
        let state = GameState()
        state.guineaPigs = snapshot.guineaPigs
        state.facilities = snapshot.facilities
        state.farm = snapshot.farm
        state.money = snapshot.money
        state.gameTime = snapshot.gameTime
        state.speed = snapshot.speed
        state.isPaused = snapshot.isPaused
        state.sessionStart = snapshot.sessionStart
        state.lastSave = snapshot.lastSave
        state.events = snapshot.events
        state.pigdex = snapshot.pigdex
        state.contractBoard = snapshot.contractBoard
        state.breedingProgram = snapshot.breedingProgram
        state.breedingPair = snapshot.breedingPair
        state.socialAffinity = snapshot.socialAffinity
        state.farmTier = snapshot.farmTier
        state.purchasedUpgrades = snapshot.purchasedUpgrades
        state.totalPigsBorn = snapshot.totalPigsBorn
        state.totalPigsSold = snapshot.totalPigsSold
        state.totalEarnings = snapshot.totalEarnings
        return state
    }
}
