/// GameState -- Root observable state container for the entire game.
/// Maps from: game/game_state.py
import Foundation
import Observation

// MARK: - Data Types (Doc 02 scope)

/// Tracks in-game time progression.
///
/// Day/hour/minute are derived from `totalGameMinutes` plus a base offset,
/// avoiding floating-point accumulation drift in the integer clock fields.
struct GameTime: Codable, Sendable {
    var lastUpdate = Date()
    var totalGameMinutes: Double = 0.0

    /// Absolute offset in minutes from the epoch (day 1, 00:00 = 0).
    /// Default 480 = day 1, 08:00. Recalculated when day/hour/minute are set directly.
    private var clockBaseMinutes: Double = 8 * 60

    init(day: Int = 1, hour: Int = 8, minute: Int = 0) {
        self.clockBaseMinutes = Double((day - 1) * 1440 + hour * 60 + minute)
    }

    // MARK: - Derived clock fields

    /// Total elapsed minutes (base + accumulated) as an integer.
    private var absoluteWholeMinutes: Int {
        // Tiny epsilon prevents near-miss truncation from float imprecision
        // (e.g. 59.99999998 → 59 instead of 60).
        Int(clockBaseMinutes + totalGameMinutes + 1e-9)
    }

    var day: Int {
        get { 1 + absoluteWholeMinutes / 1440 }
        set { setClockBase(day: newValue, hour: hour, minute: minute) }
    }

    var hour: Int {
        get { (absoluteWholeMinutes / 60) % 24 }
        set { setClockBase(day: day, hour: newValue, minute: minute) }
    }

    var minute: Int {
        get { absoluteWholeMinutes % 60 }
        set { setClockBase(day: day, hour: hour, minute: newValue) }
    }

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
        lastUpdate = Date()
    }

    /// Recalculate the base offset so the given day/hour/minute are reflected
    /// at the current totalGameMinutes.
    private mutating func setClockBase(day: Int, hour: Int, minute: Int) {
        let target = Double((day - 1) * 1440 + hour * 60 + minute)
        clockBaseMinutes = target - totalGameMinutes
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case day, hour, minute
        case lastUpdate = "last_update"
        case totalGameMinutes = "total_game_minutes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = try container.decode(Int.self, forKey: .day)
        let h = try container.decode(Int.self, forKey: .hour)
        let m = try container.decode(Int.self, forKey: .minute)
        totalGameMinutes = try container.decode(Double.self, forKey: .totalGameMinutes)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
        clockBaseMinutes = Double((d - 1) * 1440 + h * 60 + m) - totalGameMinutes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(totalGameMinutes, forKey: .totalGameMinutes)
        try container.encode(lastUpdate, forKey: .lastUpdate)
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
