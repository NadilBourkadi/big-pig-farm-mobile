/// Market -- Pig selling result data type.
/// Maps from: economy/market.py
import Foundation

// MARK: - SaleResult

/// Result of selling a guinea pig, with value breakdown.
struct SaleResult: Sendable {
    let baseValue: Int
    let contractBonus: Int
    let matchedContract: BreedingContract?

    var total: Int { baseValue + contractBonus }
}

// MARK: - PigValueBreakdown

/// Detailed breakdown of all multipliers applied to a pig's sale value.
struct PigValueBreakdown: Sendable {
    let base: Int
    let rarityMultiplier: Double
    let ageMultiplier: Double
    let healthMultiplier: Double
    let groomingMultiplier: Double
    let perkMultiplier: Double
    let total: Int
}

// MARK: - MarketInfo

/// Aggregate market statistics for the current herd.
struct MarketInfo: Sendable {
    let totalValue: Int
    let pigCount: Int
    let rarityCounts: [Rarity: Int]
    let mostValuable: GuineaPig?
    let mostValuablePrice: Int
}

// MARK: - Market

/// Stateless namespace for pig valuation and sale logic.
enum Market {
    private static let rareAndAbove: Set<Rarity> = [.rare, .veryRare, .legendary]

    // MARK: - Valuation

    /// Calculate the total sale value of a pig including all multipliers.
    @MainActor
    static func calculatePigValue(pig: GuineaPig, state: any MarketContext) -> Int {
        calculatePigValueBreakdown(pig: pig, state: state).total
    }

    /// Full multiplier breakdown for a pig's sale value.
    @MainActor
    static func calculatePigValueBreakdown(pig: GuineaPig, state: any MarketContext) -> PigValueBreakdown {
        let base = GameConfig.Economy.commonPigValue

        let rarityMult: Double = switch pig.phenotype.rarity {
        case .common: 1.0
        case .uncommon: GameConfig.Economy.uncommonMultiplier
        case .rare: GameConfig.Economy.rareMultiplier
        case .veryRare: GameConfig.Economy.veryRareMultiplier
        case .legendary: GameConfig.Economy.legendaryMultiplier
        }

        let ageMult: Double = switch pig.ageGroup {
        case .baby: 0.5
        case .adult: 1.0
        case .senior: 0.8
        }

        let healthMult = max(0.5, pig.needs.health / 100.0)

        let groomingMult: Double = state.getFacilitiesByType(.groomingStation).isEmpty ? 1.0 : 1.15

        let perkMult = perkMultiplier(pig: pig, state: state)
        let total = max(1, Int(Double(base) * rarityMult * ageMult * healthMult * groomingMult * perkMult))

        return PigValueBreakdown(
            base: base,
            rarityMultiplier: rarityMult,
            ageMultiplier: ageMult,
            healthMultiplier: healthMult,
            groomingMultiplier: groomingMult,
            perkMultiplier: perkMult,
            total: total
        )
    }

    @MainActor
    private static func perkMultiplier(pig: GuineaPig, state: any MarketContext) -> Double {
        var mult = 1.0
        if state.hasUpgrade("market_connections") { mult *= 1.10 }
        if state.hasUpgrade("premium_branding") && rareAndAbove.contains(pig.phenotype.rarity) {
            mult *= 1.20
        }
        if state.hasUpgrade("influencer_pig") && pig.phenotype.rarity == .legendary { mult *= 1.50 }
        return mult
    }

    // MARK: - Sale

    // swiftlint:disable function_body_length
    /// Sell a pig: remove from state, pay out value + contract bonus, and log events.
    @discardableResult
    @MainActor
    static func sellPig(state: any MarketContext, pig: GuineaPig) -> SaleResult {
        let value = calculatePigValue(pig: pig, state: state)

        var contractBonus = 0
        var matchedContract: BreedingContract?
        if let contract = state.contractBoard.checkAndFulfill(pig, farm: state.farm) {
            var bonus = contract.reward
            if state.hasUpgrade("trade_network") {
                bonus = Int(Double(bonus) * 1.25)
            }
            contractBonus = bonus
            matchedContract = contract
            state.contractBoard.totalContractEarnings += contractBonus
            state.contractBoard.removeFulfilled()
        }

        let result = SaleResult(
            baseValue: value,
            contractBonus: contractBonus,
            matchedContract: matchedContract
        )

        _ = state.removeGuineaPig(pig.id)
        state.totalPigsSold += 1
        Currency.addMoney(state: state, amount: result.total)

        if contractBonus > 0 {
            state.logEvent(
                "Rehomed \(pig.name) (\(pig.phenotype.displayName)) for \(value) + \(contractBonus)"
                    + " contract bonus = \(result.total) Squeaks",
                eventType: "sale"
            )
            state.logEvent(
                "Contract fulfilled: \"\(matchedContract?.requirementsText ?? "")\" (+\(contractBonus) bonus)",
                eventType: "contract"
            )
            #if canImport(UIKit)
            HapticManager.contractCompleted()
            #endif
        } else {
            state.logEvent(
                "Rehomed \(pig.name) (\(pig.phenotype.displayName)) for \(value) Squeaks",
                eventType: "sale"
            )
        }

        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.log(
            category: .economy, level: .info,
            message: "Sold \(pig.name) for \(result.total) Squeaks",
            pigId: pig.id, pigName: pig.name,
            payload: [
                "baseValue": String(value),
                "contractBonus": String(contractBonus),
                "total": String(result.total),
                "rarity": pig.phenotype.rarity.rawValue,
            ]
        )
        #endif
        return result
    }
    // swiftlint:enable function_body_length

    // MARK: - Market Info

    /// Aggregate market data for the HUD and market screen.
    @MainActor
    static func getMarketInfo(state: any MarketContext) -> MarketInfo {
        let pigs = state.getPigsList()
        let totalValue = pigs.reduce(0) { $0 + calculatePigValue(pig: $1, state: state) }

        var rarityCounts: [Rarity: Int] = [:]
        for pig in pigs {
            rarityCounts[pig.phenotype.rarity, default: 0] += 1
        }

        let mostValuable = pigs.max {
            calculatePigValue(pig: $0, state: state) < calculatePigValue(pig: $1, state: state)
        }
        let mostValuablePrice = mostValuable.map { calculatePigValue(pig: $0, state: state) } ?? 0

        return MarketInfo(
            totalValue: totalValue,
            pigCount: pigs.count,
            rarityCounts: rarityCounts,
            mostValuable: mostValuable,
            mostValuablePrice: mostValuablePrice
        )
    }
}
