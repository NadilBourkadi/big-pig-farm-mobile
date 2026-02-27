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
