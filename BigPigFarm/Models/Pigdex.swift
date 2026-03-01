/// Pigdex -- Collection tracker for discovered phenotype combinations.
/// Maps from: entities/pigdex.py
import Foundation

// MARK: - Constants

/// Total phenotype combinations: 8 colors x 3 patterns x 3 intensities x 2 roan = 144.
let totalPhenotypes = 144

/// Milestone thresholds as percentage of total discoveries.
let milestoneThresholds = [25, 50, 75, 100]

// MARK: - Pigdex

/// Tracks all phenotype combinations the player has discovered.
struct Pigdex: Codable, Sendable {
    var discovered: [String: Int] = [:]          // phenotypeKey -> game day
    var milestoneRewardsClaimed: [Int] = []

    var totalPossible: Int { totalPhenotypes }
    var discoveredCount: Int { discovered.count }

    var completionPercent: Double {
        if totalPossible == 0 { return 0.0 }
        return (Double(discoveredCount) / Double(totalPossible)) * 100
    }

    /// Register a new phenotype discovery. Returns true if it was new.
    mutating func registerPhenotype(key: String, gameDay: Int) -> Bool {
        if discovered[key] != nil { return false }
        discovered[key] = gameDay
        return true
    }

    /// Check for newly reached milestones. Returns list of newly reached percentages.
    func checkMilestones() -> [Int] {
        var newlyReached: [Int] = []
        for threshold in milestoneThresholds {
            if milestoneRewardsClaimed.contains(threshold) { continue }
            let required = Int(Double(totalPossible) * Double(threshold) / 100)
            if discoveredCount >= required {
                newlyReached.append(threshold)
            }
        }
        return newlyReached
    }

    /// Mark a milestone as claimed.
    mutating func claimMilestone(_ threshold: Int) {
        if !milestoneRewardsClaimed.contains(threshold) {
            milestoneRewardsClaimed.append(threshold)
        }
    }

    /// Check if a phenotype has been discovered.
    func isDiscovered(_ key: String) -> Bool {
        discovered[key] != nil
    }

    enum CodingKeys: String, CodingKey {
        case discovered
        case milestoneRewardsClaimed = "milestone_rewards_claimed"
    }
}

// MARK: - Free Functions

/// Generate a unique string key for a phenotype.
func phenotypeKey(_ phenotype: Phenotype) -> String {
    let color = phenotype.baseColor.rawValue
    let pattern = phenotype.pattern.rawValue
    let intensity = phenotype.intensity.rawValue
    let roan = phenotype.roan.rawValue
    return "\(color):\(pattern):\(intensity):\(roan)"
}

/// Generate a unique string key from individual trait parts.
func phenotypeKeyFromParts(
    baseColor: BaseColor, pattern: Pattern,
    intensity: ColorIntensity, roan: RoanType
) -> String {
    "\(baseColor.rawValue):\(pattern.rawValue):\(intensity.rawValue):\(roan.rawValue)"
}

/// Convert a phenotype key back to a display name.
func keyToDisplayName(_ key: String) -> String {
    let parts = key.split(separator: ":").map(String.init)
    guard parts.count == 4,
          let baseColor = BaseColor(rawValue: parts[0]),
          let pattern = Pattern(rawValue: parts[1]),
          let intensity = ColorIntensity(rawValue: parts[2]),
          let roan = RoanType(rawValue: parts[3]) else {
        return key
    }

    let rarity = calculateRarity(
        baseColor: baseColor, pattern: pattern,
        intensity: intensity, roan: roan
    )
    let phenotype = Phenotype(
        baseColor: baseColor, pattern: pattern,
        intensity: intensity, roan: roan, rarity: rarity
    )
    return phenotype.displayName
}

/// Get the rarity of a phenotype key.
func keyToRarity(_ key: String) -> Rarity {
    let parts = key.split(separator: ":").map(String.init)
    guard parts.count == 4,
          let baseColor = BaseColor(rawValue: parts[0]),
          let pattern = Pattern(rawValue: parts[1]),
          let intensity = ColorIntensity(rawValue: parts[2]),
          let roan = RoanType(rawValue: parts[3]) else {
        return .common
    }
    return calculateRarity(
        baseColor: baseColor, pattern: pattern,
        intensity: intensity, roan: roan
    )
}

/// Get all possible phenotype keys in a consistent order.
func getAllPhenotypeKeys() -> [String] {
    var keys: [String] = []
    for roan in RoanType.allCases {
        for intensity in ColorIntensity.allCases {
            for pattern in Pattern.allCases {
                for color in BaseColor.allCases {
                    keys.append(phenotypeKeyFromParts(
                        baseColor: color, pattern: pattern,
                        intensity: intensity, roan: roan
                    ))
                }
            }
        }
    }
    return keys
}

/// Get the Squeaks reward for discovering a phenotype of the given rarity.
func getDiscoveryReward(_ rarity: Rarity) -> Int {
    switch rarity {
    case .common: GameConfig.Pigdex.commonReward
    case .uncommon: GameConfig.Pigdex.uncommonReward
    case .rare: GameConfig.Pigdex.rareReward
    case .veryRare: GameConfig.Pigdex.veryRareReward
    case .legendary: GameConfig.Pigdex.legendaryReward
    }
}

/// Get the Squeaks reward for reaching a milestone percentage.
func getMilestoneReward(_ threshold: Int) -> Int {
    switch threshold {
    case 25: GameConfig.Pigdex.milestone25Reward
    case 50: GameConfig.Pigdex.milestone50Reward
    case 75: GameConfig.Pigdex.milestone75Reward
    case 100: GameConfig.Pigdex.milestone100Reward
    default: 0
    }
}
