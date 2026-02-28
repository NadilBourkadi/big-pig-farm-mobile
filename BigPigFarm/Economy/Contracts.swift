/// Contracts -- Breeding contract data types for phenotype orders.
/// Maps from: economy/contracts.py
import Foundation

// MARK: - ContractDifficulty

/// Contract difficulty tier, determines trait requirements and reward range.
enum ContractDifficulty: String, Codable, CaseIterable, Sendable {
    case easy        // Color only
    case medium      // Color + pattern
    case hard        // Color + pattern + intensity
    case expert      // All 4 traits
    case legendary   // All 4 traits + roan
}

// MARK: - BreedingContract

/// A breeding contract requesting a specific phenotype.
struct BreedingContract: Identifiable, Codable, Sendable {
    let id: UUID
    var description: String = ""
    var requiredColor: BaseColor?
    var requiredPattern: Pattern?
    var requiredIntensity: ColorIntensity?
    var requiredRoan: RoanType?
    var requiredBiome: BiomeType?
    var difficulty: ContractDifficulty = .easy
    var reward: Int = 50
    var deadlineDay: Int = 0
    var createdDay: Int = 0
    var fulfilled: Bool = false

    /// Human-readable description of breeding hints.
    var breedingHint: String {
        var hints: [String] = []
        if requiredColor == .cream {
            hints.append("Golden + Chocolate bloodlines")
        } else if requiredColor == .golden {
            hints.append("Golden bloodline (Tier 2)")
        } else if requiredColor == .chocolate {
            hints.append("Chocolate bloodline")
        } else if requiredColor == .blue {
            hints.append("Breed in Alpine biome (Dilution)")
        } else if requiredColor == .lilac {
            hints.append("Chocolate bloodline + Alpine biome")
        } else if requiredColor == .saffron {
            hints.append("Golden bloodline + Alpine biome")
        } else if requiredColor == .smoke {
            hints.append("Golden + Chocolate + Alpine biome")
        }

        if requiredPattern == .dutch || requiredPattern == .dalmatian {
            hints.append("Spotted bloodline")
        }
        if requiredIntensity == .chinchilla || requiredIntensity == .himalayan {
            hints.append("Silver bloodline (Tier 2)")
        }
        if requiredRoan == .roan {
            hints.append("Roan bloodline (Tier 3)")
        }
        return hints.joined(separator: " + ")
    }

    /// Human-readable description of requirements.
    var requirementsText: String {
        var parts: [String] = []
        if let roan = requiredRoan, roan == .roan {
            parts.append("Roan")
        }
        if let intensity = requiredIntensity, intensity != .full {
            parts.append(intensity.rawValue.capitalized)
        }
        if let pattern = requiredPattern, pattern != .solid {
            parts.append(pattern.rawValue.capitalized)
        }
        if let color = requiredColor {
            parts.append(color.rawValue.capitalized)
        }
        if requiredBiome != nil {
            if let biome = requiredBiome, let info = biomes[biome] {
                parts.append("(born in \(info.displayName))")
            }
        }
        return parts.isEmpty ? "Any pig" : parts.joined(separator: " ")
    }

    init(
        id: UUID = UUID(),
        description: String = "",
        requiredColor: BaseColor? = nil,
        requiredPattern: Pattern? = nil,
        requiredIntensity: ColorIntensity? = nil,
        requiredRoan: RoanType? = nil,
        requiredBiome: BiomeType? = nil,
        difficulty: ContractDifficulty = .easy,
        reward: Int = 50,
        deadlineDay: Int = 0,
        createdDay: Int = 0,
        fulfilled: Bool = false
    ) {
        self.id = id
        self.description = description
        self.requiredColor = requiredColor
        self.requiredPattern = requiredPattern
        self.requiredIntensity = requiredIntensity
        self.requiredRoan = requiredRoan
        self.requiredBiome = requiredBiome
        self.difficulty = difficulty
        self.reward = reward
        self.deadlineDay = deadlineDay
        self.createdDay = createdDay
        self.fulfilled = fulfilled
    }

    enum CodingKeys: String, CodingKey {
        case id, description
        case requiredColor = "required_color"
        case requiredPattern = "required_pattern"
        case requiredIntensity = "required_intensity"
        case requiredRoan = "required_roan"
        case requiredBiome = "required_biome"
        case difficulty, reward
        case deadlineDay = "deadline_day"
        case createdDay = "created_day"
        case fulfilled
    }
}

// MARK: - ContractBoard

/// Manages active breeding contracts.
struct ContractBoard: Codable, Sendable {
    var activeContracts: [BreedingContract] = []
    var completedContracts: Int = 0
    var totalContractEarnings: Int = 0
    var lastRefreshDay: Int = 0

    /// Remove fulfilled contracts from active list.
    mutating func removeFulfilled() {
        activeContracts.removeAll { $0.fulfilled }
    }

    /// Remove and return expired contracts.
    mutating func checkExpiry(gameDay: Int) -> [BreedingContract] {
        let expired = activeContracts.filter {
            gameDay > $0.deadlineDay && !$0.fulfilled
        }
        activeContracts.removeAll { contract in
            expired.contains { $0.id == contract.id }
        }
        return expired
    }

    /// Check if contracts should be refreshed.
    func needsRefresh(gameDay: Int) -> Bool {
        gameDay - lastRefreshDay >= GameConfig.Contracts.refreshIntervalDays
    }

    enum CodingKeys: String, CodingKey {
        case activeContracts = "active_contracts"
        case completedContracts = "completed_contracts"
        case totalContractEarnings = "total_contract_earnings"
        case lastRefreshDay = "last_refresh_day"
    }
}

// MARK: - BreedingContract Matching

extension BreedingContract {
    /// Returns true if this unfulfilled contract's requirements are all met by the pig.
    func matchesPig(_ pig: GuineaPig, farm: FarmGrid? = nil) -> Bool {
        guard !fulfilled else { return false }
        if let required = requiredColor, pig.phenotype.baseColor != required { return false }
        if let required = requiredPattern, pig.phenotype.pattern != required { return false }
        if let required = requiredIntensity, pig.phenotype.intensity != required { return false }
        if let required = requiredRoan, pig.phenotype.roan != required { return false }
        if let requiredBiome {
            guard let birthAreaId = pig.birthAreaId,
                  let farm,
                  let area = farm.getAreaByID(birthAreaId),
                  area.biome == requiredBiome else { return false }
        }
        return true
    }
}

// MARK: - ContractBoard Fulfillment

extension ContractBoard {
    /// Check active contracts for a match on the pig. Fulfills the first match found,
    /// updates completion stats, and returns the fulfilled contract (or nil).
    mutating func checkAndFulfill(_ pig: GuineaPig, farm: FarmGrid? = nil) -> BreedingContract? {
        for index in activeContracts.indices {
            guard activeContracts[index].matchesPig(pig, farm: farm) else { continue }
            activeContracts[index].fulfilled = true
            completedContracts += 1
            totalContractEarnings += activeContracts[index].reward
            return activeContracts[index]
        }
        return nil
    }
}

// MARK: - ContractGenerator

/// Generates breeding contracts scaled to the current farm tier and biome availability.
enum ContractGenerator {
    private static let colorTierRequirements: [BaseColor: Int] = [
        .black: 1, .chocolate: 1, .golden: 1, .cream: 2,
        .blue: 3, .lilac: 3, .saffron: 3, .smoke: 4,
    ]
    private static let patternTierRequirements: [Pattern: Int] = [
        .solid: 1, .dutch: 1, .dalmatian: 1,
    ]
    private static let intensityTierRequirements: [ColorIntensity: Int] = [
        .full: 1, .chinchilla: 2, .himalayan: 2,
    ]
    private static let roanTierRequirements: [RoanType: Int] = [
        .none: 1, .roan: 3,
    ]

    /// Generate a fresh set of contracts for the given farm state.
    @MainActor
    static func generateContracts(
        farmTier: Int,
        gameDay: Int,
        availableBiomes: [BiomeType],
        gameState: GameState
    ) -> [BreedingContract] {
        var maxContracts = GameConfig.Contracts.maxActiveContracts
        if gameState.hasUpgrade("contract_negotiator") { maxContracts += 1 }
        let numContracts = min(maxContracts, max(2, farmTier))

        var availableDifficulties: [ContractDifficulty] = []
        if farmTier >= 1 { availableDifficulties.append(.easy) }
        if farmTier >= 2 { availableDifficulties.append(.medium) }
        if farmTier >= 3 { availableDifficulties.append(.hard) }
        if farmTier >= 4 { availableDifficulties.append(.expert) }
        if farmTier >= 5 && gameState.hasUpgrade("vip_contracts") {
            availableDifficulties.append(.legendary)
        }

        return (0..<numContracts).map { _ in
            let difficulty = availableDifficulties.randomElement() ?? .easy
            return generateSingle(
                difficulty: difficulty,
                gameDay: gameDay,
                farmTier: farmTier,
                availableBiomes: availableBiomes
            )
        }
    }

    // MARK: - Private Helpers

    private static func filterByTier<T: Hashable>(
        _ values: [T],
        tierMap: [T: Int],
        farmTier: Int
    ) -> [T] {
        values.filter { (tierMap[$0] ?? 1) <= farmTier }
    }

    private static func generateSingle(
        difficulty: ContractDifficulty,
        gameDay: Int,
        farmTier: Int,
        availableBiomes: [BiomeType]
    ) -> BreedingContract {
        // Color is always required
        let availableColors = filterByTier(
            BaseColor.allCases, tierMap: colorTierRequirements, farmTier: farmTier
        )
        let requiredColor = availableColors.randomElement() ?? .black

        // Pattern required for medium+
        var requiredPattern: Pattern?
        if difficulty != .easy {
            let available = filterByTier(
                Pattern.allCases, tierMap: patternTierRequirements, farmTier: farmTier
            )
            requiredPattern = available.randomElement()
        }

        // Intensity required for hard+
        var requiredIntensity: ColorIntensity?
        if [.hard, .expert, .legendary].contains(difficulty) {
            let available = filterByTier(
                ColorIntensity.allCases, tierMap: intensityTierRequirements, farmTier: farmTier
            )
            requiredIntensity = available.randomElement()
        }

        // Roan required for expert+
        var requiredRoan: RoanType?
        if [.expert, .legendary].contains(difficulty) {
            let available = filterByTier(
                RoanType.allCases, tierMap: roanTierRequirements, farmTier: farmTier
            )
            requiredRoan = available.randomElement()
        }

        // Legendary always requires roan
        if difficulty == .legendary { requiredRoan = .roan }

        // Biome requirement: tier 3+, hard+ difficulty, 30% chance
        var requiredBiome: BiomeType?
        if farmTier >= 3
            && availableBiomes.count > 1
            && [.hard, .expert, .legendary].contains(difficulty)
            && Double.random(in: 0..<1) < GameConfig.Biome.biomeContractChance {
            requiredBiome = availableBiomes.randomElement()
        }

        var reward = Int.random(in: rewardRange(for: difficulty))
        if requiredBiome != nil {
            reward = Int(Double(reward) * (1 + GameConfig.Biome.biomeContractRewardBonus))
        }

        var contract = BreedingContract(
            requiredColor: requiredColor,
            requiredPattern: requiredPattern,
            requiredIntensity: requiredIntensity,
            requiredRoan: requiredRoan,
            requiredBiome: requiredBiome,
            difficulty: difficulty,
            reward: reward,
            deadlineDay: gameDay + GameConfig.Contracts.expiryDays,
            createdDay: gameDay
        )
        contract.description = "Deliver a \(contract.requirementsText) pig"
        return contract
    }

    private static func rewardRange(for difficulty: ContractDifficulty) -> ClosedRange<Int> {
        switch difficulty {
        case .easy:
            GameConfig.Contracts.easyRewardMin...GameConfig.Contracts.easyRewardMax
        case .medium:
            GameConfig.Contracts.mediumRewardMin...GameConfig.Contracts.mediumRewardMax
        case .hard:
            GameConfig.Contracts.hardRewardMin...GameConfig.Contracts.hardRewardMax
        case .expert:
            GameConfig.Contracts.expertRewardMin...GameConfig.Contracts.expertRewardMax
        case .legendary:
            GameConfig.Contracts.legendaryRewardMin...GameConfig.Contracts.legendaryRewardMax
        }
    }
}
