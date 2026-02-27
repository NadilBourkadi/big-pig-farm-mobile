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
