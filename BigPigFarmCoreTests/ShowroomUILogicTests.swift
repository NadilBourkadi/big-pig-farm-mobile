/// ShowroomUILogicTests — Tests for Showroom UI display logic.
/// Covers tier display names, upgrade metadata, display state resolution,
/// and tier grouping used by the Showroom view.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Tier Display Names

@Test func showroomTierDisplayNames() {
    #expect(ShowroomTier.newcomer.displayName == "Newcomer")
    #expect(ShowroomTier.apprentice.displayName == "Apprentice")
    #expect(ShowroomTier.expert.displayName == "Expert")
    #expect(ShowroomTier.master.displayName == "Master")
}

@Test func showroomTierDisplayNamesExhaustive() {
    for tier in ShowroomTier.allCases {
        #expect(!tier.displayName.isEmpty, "Tier \(tier) has empty displayName")
    }
}

// MARK: - Tier Grouping

@Test func tierGroupingCoversAllUpgrades() {
    let grouped = Dictionary(grouping: ShowroomUpgrade.allCases, by: \.tier)
    let totalGrouped = grouped.values.reduce(0) { $0 + $1.count }
    #expect(totalGrouped == ShowroomUpgrade.allCases.count)
}

@Test func tierGroupingHasAllTiers() {
    let grouped = Dictionary(grouping: ShowroomUpgrade.allCases, by: \.tier)
    for tier in ShowroomTier.allCases {
        let upgrades = grouped[tier] ?? []
        #expect(!upgrades.isEmpty, "Tier \(tier) has no upgrades")
    }
}

@Test func tierGroupingPreservesOrder() {
    let grouped = Dictionary(grouping: ShowroomUpgrade.allCases, by: \.tier)
    let ordered = ShowroomTier.allCases.map { tier in
        (tier, grouped[tier] ?? [])
    }
    #expect(ordered.count == 4)
    #expect(ordered[0].0 == .newcomer)
    #expect(ordered[1].0 == .apprentice)
    #expect(ordered[2].0 == .expert)
    #expect(ordered[3].0 == .master)
}

// MARK: - Upgrade Metadata Completeness

@Test func allUpgradesHaveNonEmptyDisplayName() {
    for upgrade in ShowroomUpgrade.allCases {
        #expect(!upgrade.displayName.isEmpty, "\(upgrade) has empty displayName")
    }
}

@Test func allUpgradesHaveNonEmptyDescription() {
    for upgrade in ShowroomUpgrade.allCases {
        #expect(
            !upgrade.info.description.isEmpty,
            "\(upgrade) has empty description"
        )
    }
}

@Test func allUpgradesHavePositiveCost() {
    for upgrade in ShowroomUpgrade.allCases {
        #expect(upgrade.cost > 0, "\(upgrade) has non-positive cost: \(upgrade.cost)")
    }
}

// MARK: - Cost Ranges by Tier

@Test func newcomerUpgradesCostRange() {
    let newcomer = ShowroomUpgrade.allCases.filter { $0.tier == .newcomer }
    for upgrade in newcomer {
        #expect(
            upgrade.cost >= 2 && upgrade.cost <= 4,
            "\(upgrade.displayName) cost \(upgrade.cost) outside newcomer range 2–4"
        )
    }
}

@Test func apprenticeUpgradesCostRange() {
    let apprentice = ShowroomUpgrade.allCases.filter { $0.tier == .apprentice }
    for upgrade in apprentice {
        #expect(
            upgrade.cost >= 5 && upgrade.cost <= 10,
            "\(upgrade.displayName) cost \(upgrade.cost) outside apprentice range 5–10"
        )
    }
}

@Test func expertUpgradesCostRange() {
    let expert = ShowroomUpgrade.allCases.filter { $0.tier == .expert }
    for upgrade in expert {
        #expect(
            upgrade.cost >= 12 && upgrade.cost <= 20,
            "\(upgrade.displayName) cost \(upgrade.cost) outside expert range 12–20"
        )
    }
}

@Test func masterUpgradesCostRange() {
    let master = ShowroomUpgrade.allCases.filter { $0.tier == .master }
    for upgrade in master {
        #expect(
            upgrade.cost >= 25 && upgrade.cost <= 50,
            "\(upgrade.displayName) cost \(upgrade.cost) outside master range 25–50"
        )
    }
}

// MARK: - Display State Logic (via PrestigeState)

@Test func displayStatePurchased() {
    var prestige = PrestigeState()
    prestige.rosetteBalance = 100
    prestige.purchasedUpgrades.insert(.expandedHutch)
    #expect(prestige.hasUpgrade(.expandedHutch))
}

@Test func displayStateAffordable() {
    let prestige = PrestigeState()
    var mutable = prestige
    mutable.rosetteBalance = 10
    #expect(!mutable.hasUpgrade(.fertileGround))
    #expect(mutable.rosetteBalance >= ShowroomUpgrade.fertileGround.cost)
}

@Test func displayStateUnaffordable() {
    let prestige = PrestigeState()
    #expect(!prestige.hasUpgrade(.grandFarm))
    #expect(prestige.rosetteBalance < ShowroomUpgrade.grandFarm.cost)
}

@Test func purchaseDeductsAndAddsUpgrade() {
    var prestige = PrestigeState()
    prestige.rosetteBalance = 10
    let success = prestige.purchaseUpgrade(.fertileGround)
    #expect(success)
    #expect(prestige.hasUpgrade(.fertileGround))
    #expect(prestige.rosetteBalance == 10 - ShowroomUpgrade.fertileGround.cost)
}

@Test func purchaseFailsWithInsufficientBalance() {
    var prestige = PrestigeState()
    prestige.rosetteBalance = 1
    let success = prestige.purchaseUpgrade(.grandFarm)
    #expect(!success)
    #expect(!prestige.hasUpgrade(.grandFarm))
    #expect(prestige.rosetteBalance == 1)
}

@Test func purchaseFailsIfAlreadyOwned() {
    var prestige = PrestigeState()
    prestige.rosetteBalance = 100
    _ = prestige.purchaseUpgrade(.rapidRecovery)
    let balance = prestige.rosetteBalance
    let secondAttempt = prestige.purchaseUpgrade(.rapidRecovery)
    #expect(!secondAttempt)
    #expect(prestige.rosetteBalance == balance)
}
