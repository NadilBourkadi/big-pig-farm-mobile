/// GuineaPig -- Core pig entity with needs, position, personality, and behavior state.
/// Maps from: entities/guinea_pig.py
import Foundation

// MARK: - Gender

/// Biological sex of a guinea pig.
enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

// MARK: - AgeGroup

/// Lifecycle stage based on age (no juvenile stage in the source game).
enum AgeGroup: String, Codable, CaseIterable, Sendable {
    case baby
    case adult
    case senior
}

// MARK: - BehaviorState

/// Active behavior state for the AI decision tree.
enum BehaviorState: String, Codable, CaseIterable, Sendable {
    case idle
    case wandering
    case eating
    case drinking
    case playing
    case sleeping
    case socializing
    case courting
}

// MARK: - Personality

/// Personality traits that modify behavior weights.
enum Personality: String, Codable, CaseIterable, Sendable {
    case greedy     // +50% hunger decay, eats more
    case lazy       // -30% energy decay, sleeps more
    case playful    // +50% boredom decay, uses toys more
    case shy        // Avoids other pigs, prefers hideouts
    case social     // Seeks other pigs, happiness from groups
    case brave      // Explores more, less hideout time
    case picky      // Prefers high-quality facilities
}

// MARK: - Position

/// Physical position on the farm grid (sub-cell precision).
struct Position: Codable, Sendable, Hashable {
    var x: Double = 0.0
    var y: Double = 0.0

    /// Euclidean distance to another position.
    func distanceTo(_ other: Self) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Integer grid cell coordinate.
    var gridPosition: GridPosition {
        GridPosition(x: Int(x), y: Int(y))
    }
}

// MARK: - Needs

/// Guinea pig need levels (0.0-100.0).
struct Needs: Codable, Sendable {
    var hunger: Double = 100.0      // 0-100
    var thirst: Double = 100.0
    var energy: Double = 100.0
    var happiness: Double = 75.0
    var health: Double = 100.0
    var social: Double = 50.0
    var boredom: Double = 0.0       // 0 = not bored, 100 = very bored

    /// Clamp all values to 0.0-100.0.
    mutating func clampAll() {
        hunger = min(100.0, max(0.0, hunger))
        thirst = min(100.0, max(0.0, thirst))
        energy = min(100.0, max(0.0, energy))
        happiness = min(100.0, max(0.0, happiness))
        health = min(100.0, max(0.0, health))
        social = min(100.0, max(0.0, social))
        boredom = min(100.0, max(0.0, boredom))
    }
}

// MARK: - GuineaPig

/// The core guinea pig entity.
struct GuineaPig: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String

    // Genetics
    var genotype: Genotype
    var phenotype: Phenotype

    // Demographics
    var gender: Gender
    var birthTime: Date
    var ageDays: Double = 0.0

    // Traits
    var personality: [Personality] = []

    // State
    var needs = Needs()
    var behaviorState: BehaviorState = .idle
    var position = Position()

    // Movement
    var targetPosition: Position?
    var targetDescription: String?
    var targetFacilityId: UUID?
    var path: [GridPosition] = []

    // Breeding
    var isPregnant: Bool = false
    var pregnancyDays: Double = 0.0
    var partnerId: UUID?
    var partnerGenotype: Genotype?
    var partnerName: String?
    var lastBirthAge: Double?

    // Courtship
    var courtingPartnerId: UUID?
    var courtingInitiator: Bool = false
    var courtingTimer: Double = 0.0

    // Family
    var motherId: UUID?
    var fatherId: UUID?
    var motherName: String?
    var fatherName: String?

    // Breeding control
    var breedingLocked: Bool = false
    var markedForSale: Bool = false

    // Origin
    var originTag: String?

    // Area/biome tracking
    var currentAreaId: UUID?
    var birthAreaId: UUID?
    var preferredBiome: String?

    // Biome acclimation
    var acclimationTimer: Double = 0.0
    var acclimatingBiome: String?

    // MARK: - Computed Properties

    var ageGroup: AgeGroup {
        if ageDays < Double(GameConfig.Simulation.adultAgeDays) {
            return .baby
        } else if ageDays >= Double(GameConfig.Simulation.seniorAgeDays) {
            return .senior
        }
        return .adult
    }

    var isBaby: Bool { ageGroup == .baby }
    var isAdult: Bool { ageGroup == .adult }
    var isSenior: Bool { ageGroup == .senior }

    var canBreed: Bool { breedingBlockReason == nil }

    var breedingBlockReason: String? {
        if breedingLocked { return "Breeding locked" }
        if isBaby {
            let daysLeft = Double(GameConfig.Simulation.adultAgeDays) - ageDays
            return "Too young (\(String(format: "%.1f", daysLeft))d until adult)"
        }
        if isSenior { return "Too old (senior)" }
        if needs.happiness < Double(GameConfig.Breeding.minHappinessToBreed) {
            return "Unhappy (\(Int(needs.happiness))/\(GameConfig.Breeding.minHappinessToBreed))"
        }
        if isPregnant {
            let daysLeft = max(0, Double(GameConfig.Breeding.gestationDays) - pregnancyDays)
            return "Pregnant (\(String(format: "%.1f", daysLeft))d left)"
        }
        if gender == .female, let lastBirth = lastBirthAge {
            let recoveryLeft = Double(GameConfig.Breeding.recoveryDays) - (ageDays - lastBirth)
            if recoveryLeft > 0 {
                return "Recovering from birth (\(String(format: "%.1f", recoveryLeft))d left)"
            }
        }
        return nil
    }

    /// Display string for current behavior state.
    var displayState: String {
        switch behaviorState {
        case .idle: "idle"
        case .wandering: "walking"
        case .eating: "eating"
        case .drinking: "eating"   // Shares animation with eating
        case .playing: "happy"
        case .sleeping: "sleeping"
        case .socializing: "happy"
        case .courting: "happy"
        }
    }

    // MARK: - Methods

    func hasTrait(_ trait: Personality) -> Bool {
        personality.contains(trait)
    }

    /// Calculate the monetary value of this guinea pig.
    func getValue() -> Int {
        let baseValue = GameConfig.Economy.commonPigValue
        let multiplier: Double
        switch phenotype.rarity {
        case .common: multiplier = 1.0
        case .uncommon: multiplier = GameConfig.Economy.uncommonMultiplier
        case .rare: multiplier = GameConfig.Economy.rareMultiplier
        case .veryRare: multiplier = GameConfig.Economy.veryRareMultiplier
        case .legendary: multiplier = GameConfig.Economy.legendaryMultiplier
        }
        return Int(Double(baseValue) * multiplier)
    }

    /// Factory method with phenotype calculation and random personality.
    static func create(
        name: String,
        gender: Gender,
        genotype: Genotype? = nil,
        position: Position? = nil,
        ageDays: Double = 0.0,
        motherId: UUID? = nil,
        fatherId: UUID? = nil,
        motherName: String? = nil,
        fatherName: String? = nil
    ) -> Self {
        let resolvedGenotype = genotype ?? Genotype.randomCommon()
        let phenotype = calculatePhenotype(resolvedGenotype)

        // Assign 1-2 random personality traits
        let allTraits = Personality.allCases
        let numTraits = Int.random(in: 1...2)
        var selectedTraits: [Personality] = []
        var available = Array(allTraits)
        for _ in 0..<numTraits {
            if available.isEmpty { break }
            let index = Int.random(in: 0..<available.count)
            selectedTraits.append(available.remove(at: index))
        }

        return Self(
            id: UUID(),
            name: name,
            genotype: resolvedGenotype,
            phenotype: phenotype,
            gender: gender,
            birthTime: Date(),
            ageDays: ageDays,
            personality: selectedTraits,
            position: position ?? Position(),
            motherId: motherId,
            fatherId: fatherId,
            motherName: motherName,
            fatherName: fatherName
        )
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, genotype, phenotype, gender
        case birthTime = "birth_time"
        case ageDays = "age_days"
        case personality, needs
        case behaviorState = "behavior_state"
        case position
        case targetPosition = "target_position"
        case targetDescription = "target_description"
        case targetFacilityId = "target_facility_id"
        case path
        case isPregnant = "is_pregnant"
        case pregnancyDays = "pregnancy_days"
        case partnerId = "partner_id"
        case partnerGenotype = "partner_genotype"
        case partnerName = "partner_name"
        case lastBirthAge = "last_birth_age"
        case courtingPartnerId = "courting_partner_id"
        case courtingInitiator = "courting_initiator"
        case courtingTimer = "courting_timer"
        case motherId = "mother_id"
        case fatherId = "father_id"
        case motherName = "mother_name"
        case fatherName = "father_name"
        case breedingLocked = "breeding_locked"
        case markedForSale = "marked_for_sale"
        case originTag = "origin_tag"
        case currentAreaId = "current_area_id"
        case birthAreaId = "birth_area_id"
        case preferredBiome = "preferred_biome"
        case acclimationTimer = "acclimation_timer"
        case acclimatingBiome = "acclimating_biome"
    }
}
