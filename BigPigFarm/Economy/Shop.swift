/// Shop -- Shop item data types for the in-game store.
/// Maps from: economy/shop.py
import Foundation

// MARK: - ShopCategory

/// Shop item categories for organizing the store interface.
enum ShopCategory: String, Codable, CaseIterable, Sendable {
    case facilities
    case perks
    case upgrades
    case decorations
    case adoption
}

// MARK: - ShopItem

/// An item available for purchase in the shop.
struct ShopItem: Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    let facilityType: FacilityType?
    var unlocked: Bool = true
    let requiredTier: Int
}

// MARK: - Shop Items Table

/// All 17 facility shop items. Populated from SHOP_ITEMS in Python.
let shopItems: [ShopItem] = [
    ShopItem(id: "food_bowl", name: "Food Bowl",
             description: "Feeds pigs to reduce hunger. Capacity: 100 units. Size: 2x1. Refill cost: 5 Squeaks.",
             cost: GameConfig.Economy.foodBowlCost, category: .facilities,
             facilityType: .foodBowl, requiredTier: 1),
    ShopItem(id: "water_bottle", name: "Water Bottle",
             description: "Hydrates pigs to reduce thirst. Capacity: 100 units. Size: 1x2. Refill cost: 2 Squeaks.",
             cost: GameConfig.Economy.waterBottleCost, category: .facilities,
             facilityType: .waterBottle, requiredTier: 1),
    ShopItem(id: "hay_rack", name: "Hay Rack",
             description: "Alternative food source with +5% health bonus. Size: 2x1.",
             cost: GameConfig.Economy.hayRackCost, category: .facilities,
             facilityType: .hayRack, requiredTier: 2),
    ShopItem(id: "hideout", name: "Hideout",
             description: "Pigs sleep here to restore energy. +10% happiness bonus. Fits 2 pigs. Size: 3x2.",
             cost: GameConfig.Economy.hideoutCost, category: .facilities,
             facilityType: .hideout, requiredTier: 1),
    ShopItem(id: "exercise_wheel", name: "Exercise Wheel",
             description: "Pigs play here to reduce boredom. +5% health bonus. Size: 2x2.",
             cost: GameConfig.Economy.exerciseWheelCost, category: .facilities,
             facilityType: .exerciseWheel, requiredTier: 2),
    ShopItem(id: "tunnel", name: "Tunnel System",
             description: "Pigs play here to reduce boredom. +15% happiness bonus. Size: 3x1.",
             cost: GameConfig.Economy.tunnelCost, category: .facilities,
             facilityType: .tunnel, requiredTier: 2),
    ShopItem(id: "play_area", name: "Play Area",
             description: "Pigs play and socialize here. +20% social bonus. Size: 3x2.",
             cost: GameConfig.Economy.playAreaCost, category: .facilities,
             facilityType: .playArea, requiredTier: 3),
    ShopItem(id: "breeding_den", name: "Breeding Den",
             description: "+15% breeding success rate. Size: 2x2.",
             cost: GameConfig.Economy.breedingDenCost, category: .facilities,
             facilityType: .breedingDen, requiredTier: 4),
    ShopItem(id: "nursery", name: "Nursery",
             description: "Newborn pigs grow 20% faster near a nursery. Fits 4 pigs. Size: 3x2.",
             cost: GameConfig.Economy.nurseryCost, category: .facilities,
             facilityType: .nursery, requiredTier: 4),
    ShopItem(id: "veggie_garden", name: "Veggie Garden",
             description: "Produces 10 food units per day, auto-refilling nearby food bowls. Size: 2x2.",
             cost: GameConfig.Economy.veggieGardenCost, category: .facilities,
             facilityType: .veggieGarden, requiredTier: 4),
    ShopItem(id: "grooming_station", name: "Grooming Station",
             description: "Pigs that use this sell for +15% more at market. Size: 2x1.",
             cost: GameConfig.Economy.groomingStationCost, category: .facilities,
             facilityType: .groomingStation, requiredTier: 3),
    ShopItem(id: "genetics_lab", name: "Genetics Lab",
             description: "Reveals carrier alleles and boosts mutation rate. Size: 3x2.",
             cost: GameConfig.Economy.geneticsLabCost, category: .facilities,
             facilityType: .geneticsLab, requiredTier: 3),
    ShopItem(id: "feast_table", name: "Feast Table",
             description: "Communal eating spot. Capacity: 300 food units. Size: 5x5.",
             cost: GameConfig.Economy.feastTableCost, category: .facilities,
             facilityType: .feastTable, requiredTier: 2),
    ShopItem(id: "campfire", name: "Campfire",
             description: "Nighttime gathering spot for social and happiness recovery. Size: 5x5.",
             cost: GameConfig.Economy.campfireCost, category: .facilities,
             facilityType: .campfire, requiredTier: 3),
    ShopItem(id: "therapy_garden", name: "Therapy Garden",
             description: "Unhappy pigs recover happiness and health here. Size: 5x5.",
             cost: GameConfig.Economy.therapyGardenCost, category: .facilities,
             facilityType: .therapyGarden, requiredTier: 3),
    ShopItem(id: "hot_spring", name: "Hot Spring",
             description: "Multi-need sleep -- energy, happiness, health, and social recovery. Size: 6x6.",
             cost: GameConfig.Economy.hotSpringCost, category: .facilities,
             facilityType: .hotSpring, requiredTier: 4),
    ShopItem(id: "stage", name: "Stage",
             description: "Performer entertains nearby pigs with AoE happiness and social. Size: 6x6.",
             cost: GameConfig.Economy.stageCost, category: .facilities,
             facilityType: .stage, requiredTier: 5),
]

// MARK: - RoomUpgradeInfo

/// Metadata about the next available room expansion, bundled for the ShopView.
struct RoomUpgradeInfo: Sendable {
    let name: String
    let cost: Int
    let width: Int
    let height: Int
    let capacity: Int
}

// MARK: - Shop Logic

/// Stateless namespace for shop purchase, sell, and tier upgrade logic.
enum Shop {
    // MARK: - Items

    /// All shop items, filtered by category and marked locked/unlocked by farm tier.
    static func getShopItems(category: ShopCategory? = nil, farmTier: Int = 1) -> [ShopItem] {
        var items = shopItems
        if let category {
            items = items.filter { $0.category == category }
        }
        return items
            .map { item in
                var copy = item
                copy.unlocked = item.requiredTier <= farmTier
                return copy
            }
            .sorted { $0.requiredTier < $1.requiredTier }
    }

    /// Purchase a facility shop item at the given grid position.
    @discardableResult
    @MainActor
    static func purchaseItem(
        state: GameState,
        item: ShopItem,
        position: GridPosition?
    ) -> Bool {
        guard item.requiredTier <= state.farmTier else { return false }
        // Spend money first so the grid placement cannot succeed without payment.
        guard Currency.spendMoney(state: state, amount: item.cost) else { return false }

        if let facilityType = item.facilityType, let position {
            var facility = Facility.create(type: facilityType, x: position.x, y: position.y)
            if state.hasUpgrade("bulk_feeders") && Upgrades.isFoodWaterType(facilityType) {
                facility.maxAmount *= 2
                facility.currentAmount *= 2
            }
            if !state.addFacility(facility) {
                // Grid placement failed — refund the cost.
                Currency.addMoney(state: state, amount: item.cost)
                return false
            }
        }

        return true
    }

    /// Remove a facility from the farm and refund its original shop cost.
    @discardableResult
    @MainActor
    static func sellFacility(state: GameState, facility: Facility) -> Int {
        let refund = getFacilityCost(facilityType: facility.facilityType)
        _ = state.removeFacility(facility.id)
        Currency.addMoney(state: state, amount: refund)
        return refund
    }

    /// Original shop cost of a facility type (used for refund calculations).
    static func getFacilityCost(facilityType: FacilityType) -> Int {
        shopItems.first { $0.facilityType == facilityType }?.cost ?? 0
    }

    // MARK: - Tier Upgrades

    /// The next tier upgrade the farm can work toward, or nil if at max tier.
    @MainActor
    static func getNextTierUpgrade(state: GameState) -> TierUpgrade? {
        tierUpgrades.first { $0.tier == state.farmTier + 1 }
    }

    /// Check which requirements for the given tier upgrade are currently satisfied.
    @MainActor
    static func checkTierRequirements(
        state: GameState,
        upgrade: TierUpgrade
    ) -> [String: Bool] {
        [
            "pigs_born": state.totalPigsBorn >= upgrade.requiredPigsBorn,
            "pigdex": state.pigdex.discoveredCount >= upgrade.requiredPigdex,
            "contracts": state.contractBoard.completedContracts >= upgrade.requiredContracts,
            "money": state.money >= upgrade.cost,
        ]
    }

    /// Purchase a farm tier upgrade when all requirements are met.
    @discardableResult
    @MainActor
    static func purchaseTierUpgrade(state: GameState) -> Bool {
        guard let upgrade = getNextTierUpgrade(state: state) else { return false }
        let reqs = checkTierRequirements(state: state, upgrade: upgrade)
        guard reqs.values.allSatisfy({ $0 }) else { return false }
        guard Currency.spendMoney(state: state, amount: upgrade.cost) else { return false }
        state.farmTier = upgrade.tier
        state.farm.tier = upgrade.tier
        state.logEvent("Farm upgraded to Tier \(upgrade.tier): \(upgrade.name)!", eventType: "purchase")
        return true
    }

    /// Total cost to purchase a new room of the given biome (base room cost + biome cost).
    @MainActor
    static func getRoomTotalCost(state: GameState, biome: BiomeType) -> Int {
        guard let nextRoom = state.farm.nextRoomCost else { return 0 }
        let biomeCost = biomes[biome]?.cost ?? 0
        return nextRoom.cost + biomeCost
    }

    // MARK: - Shop Extensions (ShopView support)

    /// Find the best available grid position to auto-place a newly purchased facility.
    /// Delegates to AutoArrange.findGridPosition, scanning areas largest-first.
    /// Returns nil if no valid position exists in any area.
    @MainActor
    static func findPlacementPosition(
        for facilityType: FacilityType,
        in state: GameState
    ) -> GridPosition? {
        let probe = Facility.create(type: facilityType, x: 0, y: 0)
        return AutoArrange.findGridPosition(for: probe, in: state.farm)
    }

    /// All upgrade perks whose required tier is at or below `farmTier`, sorted by tier.
    /// Returns all eligible perks regardless of purchase state — the caller renders
    /// "Owned" badges for perks already in `gameState.purchasedUpgrades`.
    static func getAvailablePerks(farmTier: Int) -> [UpgradeDefinition] {
        upgrades.values
            .filter { $0.requiredTier <= farmTier }
            .sorted { $0.requiredTier < $1.requiredTier }
    }

    /// Purchase a perk by ID. Deducts cost and records the perk in `state.purchasedUpgrades`.
    /// Returns true if the purchase succeeded. Delegates to Upgrades.purchasePerk.
    @discardableResult
    @MainActor
    static func purchasePerk(perkID: String, state: GameState) -> Bool {
        Upgrades.purchasePerk(state: state, upgradeId: perkID)
    }

    /// Metadata about the next room expansion, or nil when the farm is already at the
    /// maximum room count for its current tier or all 8 room slots are filled.
    /// `state.farmTier` is guaranteed to be in [1..5] by `purchaseTierUpgrade` — the
    /// fallback in `getTierUpgrade` (tier 1) will never silently apply in practice.
    @MainActor
    static func getFarmUpgradeInfo(state: GameState) -> RoomUpgradeInfo? {
        let currentTier = getTierUpgrade(tier: state.farmTier)
        guard state.farm.areas.count < currentTier.maxRooms else { return nil }
        guard let nextRoom = state.farm.nextRoomCost else { return nil }
        return RoomUpgradeInfo(
            name: nextRoom.name,
            cost: nextRoom.cost,
            width: currentTier.roomWidth,
            height: currentTier.roomHeight,
            capacity: currentTier.capacityPerRoom
        )
    }

    /// Base purchase cost of a facility type. Positional-argument alias for getFacilityCost,
    /// used at call sites that omit the label (e.g. `Shop.facilityCost(facility.facilityType)`).
    static func facilityCost(_ facilityType: FacilityType) -> Int {
        getFacilityCost(facilityType: facilityType)
    }

    // MARK: - Room Purchase

    /// Purchase a new room of the given biome. Deducts cost (base room + biome), expands
    /// the grid canvas, and shifts all entity positions to match the new layout.
    /// Returns true if purchase succeeded; false if at max rooms, insufficient funds,
    /// or grid expansion failed.
    @discardableResult
    @MainActor
    static func purchaseNewRoom(state: GameState, biome: BiomeType) -> Bool {
        guard getFarmUpgradeInfo(state: state) != nil else { return false }
        let totalCost = getRoomTotalCost(state: state, biome: biome)
        guard Currency.spendMoney(state: state, amount: totalCost) else { return false }
        guard let result = GridExpansion.addRoom(&state.farm, biome: biome) else {
            Currency.addMoney(state: state, amount: totalCost)
            return false
        }
        if result.offsetX != 0 || result.offsetY != 0 || !result.roomDeltas.isEmpty {
            shiftEntities(state: state, result: result)
        }
        let biomeName = biomes[biome]?.displayName ?? biome.rawValue.capitalized
        state.logEvent("New \(biomeName) room added!", eventType: "purchase")
        return true
    }

    // MARK: - Private Helpers

    /// Shift all pig and facility positions after a grid expansion.
    /// Applies the global entity offset plus any per-area repositioning delta.
    @MainActor
    private static func shiftEntities(state: GameState, result: AddRoomResult) {
        var pigs = state.getPigsList()
        for i in pigs.indices {
            let delta = pigs[i].currentAreaId.flatMap { result.roomDeltas[$0] }
                ?? GridPosition(x: 0, y: 0)
            let dx = Double(result.offsetX + delta.x)
            let dy = Double(result.offsetY + delta.y)
            pigs[i].position.x += dx
            pigs[i].position.y += dy
            pigs[i].targetPosition?.x += dx
            pigs[i].targetPosition?.y += dy
        }
        for pig in pigs { state.updateGuineaPig(pig) }

        var facilities = state.getFacilitiesList()
        for i in facilities.indices {
            let delta = facilities[i].areaId.flatMap { result.roomDeltas[$0] }
                ?? GridPosition(x: 0, y: 0)
            facilities[i].positionX += result.offsetX + delta.x
            facilities[i].positionY += result.offsetY + delta.y
        }
        for facility in facilities { state.updateFacility(facility) }
    }
}
