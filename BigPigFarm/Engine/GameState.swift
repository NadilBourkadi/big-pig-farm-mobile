/// GameState -- Root observable state container for the entire game.
/// Maps from: game/game_state.py
import Foundation
import Observation

// MARK: - Data Types (Doc 02 scope)

/// Tracks in-game time progression.
struct GameTime: Codable, Sendable {
    var day: Int = 1
    var hour: Int = 8
    var minute: Int = 0
    var lastUpdate = Date()
    var totalGameMinutes: Double = 0.0

    var isDaytime: Bool { 6 <= hour && hour < 20 }

    var timeOfDay: String {
        if hour < 6 { return "Night" }
        if hour < 12 { return "Morning" }
        if hour < 18 { return "Afternoon" }
        if hour < 20 { return "Evening" }
        return "Night"
    }

    var displayTime: String {
        String(format: "Day %d %02d:%02d", day, hour, minute)
    }

    /// Advance game time by the given number of minutes.
    mutating func advance(minutes: Double) {
        totalGameMinutes += minutes
        var totalMinutes = Double(minute) + minutes
        var totalHours = Double(hour)
        var totalDays = day

        totalHours += (totalMinutes / 60).rounded(.down)
        totalMinutes = totalMinutes.truncatingRemainder(dividingBy: 60)

        totalDays += Int(totalHours / 24)
        totalHours = totalHours.truncatingRemainder(dividingBy: 24)

        day = totalDays
        hour = Int(totalHours)
        minute = Int(totalMinutes)
        lastUpdate = Date()
    }

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
        case lastUpdate = "last_update"
        case totalGameMinutes = "total_game_minutes"
    }
}

/// A single event log entry for the event feed.
struct EventLog: Identifiable, Codable, Sendable {
    /// Transient identity for SwiftUI ForEach — not persisted (excluded from CodingKeys).
    let id = UUID()
    let timestamp: Date
    let gameDay: Int
    let message: String
    let eventType: String   // "info", "birth", "death", "sale", "purchase"

    enum CodingKeys: String, CodingKey {
        case timestamp
        case gameDay = "game_day"
        case message
        case eventType = "event_type"
    }
}

/// A breeding pair of male and female pig IDs.
struct BreedingPair: Codable, Sendable {
    let maleId: UUID
    let femaleId: UUID

    enum CodingKeys: String, CodingKey {
        case maleId = "male_id"
        case femaleId = "female_id"
    }
}

// MARK: - GameState (Doc 04 scope)

/// The central game state, observed by both SwiftUI and SpriteKit layers.
///
/// `@unchecked Sendable` is safe because every stored property is only ever
/// read or written while isolated to `@MainActor`. Do NOT add `nonisolated`
/// methods that access mutable state.
@Observable
@MainActor
final class GameState: @unchecked Sendable {
    // MARK: - Core Collections

    /// All guinea pigs keyed by UUID. O(1) lookup.
    var guineaPigs: [UUID: GuineaPig] = [:]

    /// All facilities keyed by UUID. O(1) lookup.
    var facilities: [UUID: Facility] = [:]

    // MARK: - Cached List Snapshots

    private var pigsListCache: [GuineaPig]?
    private var facilitiesListCache: [Facility]?
    private var facilitiesByTypeCache: [FacilityType: [Facility]]?

    // MARK: - World

    var farm = FarmGrid.createStarter()

    // MARK: - Economy

    var money: Int = GameConfig.Economy.startingMoney

    // MARK: - Time

    var gameTime = GameTime()
    var speed: GameSpeed = .normal
    var isPaused: Bool = false

    // MARK: - Session Tracking

    var sessionStart = Date()
    var lastSave: Date?

    // MARK: - Event Log

    var events: [EventLog] = []
    let maxEvents: Int = 100

    // MARK: - Collections

    var pigdex = Pigdex()
    var contractBoard = ContractBoard()

    // MARK: - Breeding

    var breedingProgram = BreedingProgram()
    var breedingPair: BreedingPair?

    // MARK: - Social Affinity

    /// Tracks socialization history between pig pairs.
    /// Key: "smallerUUID:largerUUID", Value: completed socialization count (max 10).
    var socialAffinity: [String: Int] = [:]

    // MARK: - Progression

    var farmTier: Int = 1
    var purchasedUpgrades: Set<String> = []

    // MARK: - Statistics

    var totalPigsBorn: Int = 0
    var totalPigsSold: Int = 0
    var totalEarnings: Int = 0
}

// MARK: - GameState Mutation Methods

extension GameState {
    // MARK: - Guinea Pig Management

    func addGuineaPig(_ pig: GuineaPig) {
        guineaPigs[pig.id] = pig
        pigsListCache = nil
    }

    /// Update an existing pig in place and invalidate the list cache.
    /// Use instead of direct `guineaPigs[id] = pig` writes in the simulation tick.
    func updateGuineaPig(_ pig: GuineaPig) {
        guineaPigs[pig.id] = pig
        pigsListCache = nil
    }

    func removeGuineaPig(_ pigID: UUID) -> GuineaPig? {
        guard let pig = guineaPigs.removeValue(forKey: pigID) else { return nil }
        pigsListCache = nil
        let pigStr = pigID.uuidString
        socialAffinity = socialAffinity.filter { key, _ in
            !key.contains(pigStr)
        }
        return pig
    }

    func getGuineaPig(_ pigID: UUID) -> GuineaPig? {
        guineaPigs[pigID]
    }

    func getPigsList() -> [GuineaPig] {
        if let cached = pigsListCache { return cached }
        let list = Array(guineaPigs.values)
        pigsListCache = list
        return list
    }

    // MARK: - Facility Management

    func addFacility(_ facility: Facility) -> Bool {
        guard farm.placeFacility(facility) else { return false }
        facilities[facility.id] = facility
        facilitiesListCache = nil
        facilitiesByTypeCache = nil
        return true
    }

    func removeFacility(_ facilityID: UUID) -> Facility? {
        guard let facility = facilities.removeValue(forKey: facilityID) else { return nil }
        // TODO(5jp): If FarmGrid.removeFacility gains error handling, restore on failure
        farm.removeFacility(facility)
        facilitiesListCache = nil
        facilitiesByTypeCache = nil
        return facility
    }

    func getFacility(_ facilityID: UUID) -> Facility? {
        facilities[facilityID]
    }

    func getFacilitiesByType(_ type: FacilityType) -> [Facility] {
        if facilitiesByTypeCache == nil {
            var cache: [FacilityType: [Facility]] = [:]
            for facility in facilities.values {
                cache[facility.facilityType, default: []].append(facility)
            }
            facilitiesByTypeCache = cache
        }
        return facilitiesByTypeCache?[type] ?? []
    }

    func getFacilitiesList() -> [Facility] {
        if let cached = facilitiesListCache { return cached }
        let list = Array(facilities.values)
        facilitiesListCache = list
        return list
    }

    /// Update an existing facility in place and invalidate caches.
    func updateFacility(_ facility: Facility) {
        facilities[facility.id] = facility
        facilitiesListCache = nil
        facilitiesByTypeCache = nil
    }

    // MARK: - Economy

    func addMoney(_ amount: Int) {
        money += amount
        if amount > 0 { totalEarnings += amount }
    }

    func spendMoney(_ amount: Int) -> Bool {
        guard money >= amount else { return false }
        money -= amount
        return true
    }

    // MARK: - Events

    func logEvent(_ message: String, eventType: String = "info") {
        let event = EventLog(
            timestamp: Date(),
            gameDay: gameTime.day,
            message: message,
            eventType: eventType
        )
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    // MARK: - Computed Properties

    var pigCount: Int { guineaPigs.count }
    var capacity: Int { farm.capacity }
    var isAtCapacity: Bool { pigCount >= capacity }

    // MARK: - Breeding Pair

    func setBreedingPair(maleID: UUID, femaleID: UUID) {
        breedingPair = BreedingPair(maleId: maleID, femaleId: femaleID)
    }

    func clearBreedingPair() {
        breedingPair = nil
    }

    // MARK: - Social Affinity

    static func affinityKey(_ id1: UUID, _ id2: UUID) -> String {
        let id1Str = id1.uuidString
        let id2Str = id2.uuidString
        return id1Str < id2Str ? "\(id1Str):\(id2Str)" : "\(id2Str):\(id1Str)"
    }

    func getAffinity(_ id1: UUID, _ id2: UUID) -> Int {
        socialAffinity[Self.affinityKey(id1, id2)] ?? 0
    }

    func incrementAffinity(_ id1: UUID, _ id2: UUID) {
        let key = Self.affinityKey(id1, id2)
        socialAffinity[key] = min((socialAffinity[key] ?? 0) + 1, 10)
    }

    // MARK: - Upgrades

    func hasUpgrade(_ upgradeID: String) -> Bool {
        purchasedUpgrades.contains(upgradeID)
    }
}

// MARK: - Manual Refill

extension GameState {
    /// Count of facilities that are below max capacity and have a non-zero refill cost.
    var refillableCount: Int {
        facilities.values
            .filter { $0.info.refillCost > 0 && $0.currentAmount < $0.maxAmount }
            .count
    }

    /// Total Squeaks cost to top up all refillable facilities.
    /// Returns 0 when all such facilities are already full or none exist.
    var totalRefillCost: Int {
        facilities.values
            .filter { $0.info.refillCost > 0 && $0.currentAmount < $0.maxAmount }
            .reduce(0) { $0 + $1.info.refillCost }
    }

    /// True when at least one refillable facility is below capacity.
    var hasFacilitiesToRefill: Bool {
        refillableCount > 0
    }

    /// True when the player can afford the total refill cost.
    /// Returns false when there are no facilities to refill.
    var canAffordRefill: Bool {
        let cost = totalRefillCost
        return cost > 0 && money >= cost
    }

    /// True when there is at least one partially-drained refillable facility
    /// and the player can afford the total cost. Evaluates in a single O(n) pass;
    /// use this for UI disabled-state checks instead of combining refillableCount
    /// and totalRefillCost separately.
    var isRefillEnabled: Bool {
        var cost = 0
        var hasEligible = false
        for facility in facilities.values {
            guard facility.info.refillCost > 0, facility.currentAmount < facility.maxAmount else { continue }
            hasEligible = true
            cost += facility.info.refillCost
        }
        return hasEligible && money >= cost
    }

    /// Refill all eligible food and water facilities in one action.
    ///
    /// Deducts the total Squeaks cost from the player's balance atomically.
    /// Returns true on success, false when there is nothing to refill or
    /// the player cannot afford the total cost.
    @discardableResult
    func manualRefillAll() -> Bool {
        let eligible = facilities.values.filter {
            $0.info.refillCost > 0 && $0.currentAmount < $0.maxAmount
        }
        guard !eligible.isEmpty else { return false }
        let totalCost = eligible.reduce(0) { $0 + $1.info.refillCost }
        guard spendMoney(totalCost) else {
            logEvent("Not enough Squeaks to refill (need \(Currency.formatCurrency(totalCost)))",
                     eventType: "info")
            return false
        }
        for facility in eligible {
            var mutableFacility = facility
            mutableFacility.refill()
            updateFacility(mutableFacility)
        }
        let noun = eligible.count == 1 ? "facility" : "facilities"
        logEvent(
            "Refilled \(eligible.count) \(noun) (-\(Currency.formatCurrency(totalCost)))",
            eventType: "purchase"
        )
        return true
    }
}
