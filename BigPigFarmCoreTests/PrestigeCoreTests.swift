/// PrestigeCoreTests — Tests for prestige persistence, farm reset, Pigdex carry-over, biome mastery.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Prestige State Persistence

@Test @MainActor func prestigeStateRoundtrips() throws {
    let manager = makeTempSaveManager()
    var prestige = PrestigeState()
    prestige.rosetteBalance = 42
    prestige.farmCount = 3
    prestige.previousPigdexEntries = ["agouti:solid:normal:none", "black:spotted:dark:none"]
    prestige.lifetimeStats.totalPigsBred = 100
    prestige.lifetimeStats.totalSqueaksEarned = 50_000
    prestige.purchasedUpgrades = [.expandedHutch, .fertileGround]

    try manager.savePrestigeState(prestige)
    let loaded = try #require(manager.loadPrestigeState())

    #expect(loaded.rosetteBalance == 42)
    #expect(loaded.farmCount == 3)
    #expect(loaded.previousPigdexEntries.count == 2)
    #expect(loaded.previousPigdexEntries.contains("agouti:solid:normal:none"))
    #expect(loaded.lifetimeStats.totalPigsBred == 100)
    #expect(loaded.lifetimeStats.totalSqueaksEarned == 50_000)
    #expect(loaded.purchasedUpgrades.contains(.expandedHutch))
    #expect(loaded.purchasedUpgrades.contains(.fertileGround))
}

@Test @MainActor func prestigeStateSurvivesGameSaveDelete() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    state.money = 999
    try manager.save(state)

    var prestige = PrestigeState()
    prestige.rosetteBalance = 10
    try manager.savePrestigeState(prestige)

    manager.deleteGameSave()

    #expect(manager.hasSave() == false)
    let loaded = try #require(manager.loadPrestigeState())
    #expect(loaded.rosetteBalance == 10)
}

@Test @MainActor func loadPrestigeStateReturnsNilWhenNone() {
    let manager = makeTempSaveManager()
    #expect(manager.loadPrestigeState() == nil)
}

@Test @MainActor func hasPrestigeSaveReturnsFalseWhenEmpty() {
    let manager = makeTempSaveManager()
    #expect(manager.hasPrestigeSave() == false)
}

@Test @MainActor func deleteAllSavesRemovesBothFiles() throws {
    let manager = makeTempSaveManager()
    let state = makeGameState()
    try manager.save(state)
    try manager.savePrestigeState(PrestigeState())

    manager.deleteAllSaves()

    #expect(manager.hasSave() == false)
    #expect(manager.hasPrestigeSave() == false)
}

// MARK: - Farm Reset: State Clearing

@Test @MainActor func farmResetClearsGameState() {
    let state = makeGameState()
    state.money = 50_000
    state.farmTier = 3
    state.totalPigsBorn = 200
    state.totalPigsSold = 100
    state.totalEarnings = 30_000
    let pig = GuineaPig.create(name: "Biscuit", gender: .female)
    state.addGuineaPig(pig)
    state.socialAffinity["a:b"] = 5
    state.purchasedUpgrades = ["auto_feed"]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.guineaPigs.isEmpty == false) // setupNewGame adds 2 starter pigs
    #expect(state.pigCount == 2) // exactly 2 starter pigs
    #expect(state.money == GameConfig.Economy.startingMoney)
    #expect(state.farmTier == 1)
    #expect(state.totalPigsBorn == 0)
    #expect(state.totalPigsSold == 0)
    #expect(state.totalEarnings == 0)
    #expect(state.socialAffinity.isEmpty)
    #expect(state.purchasedUpgrades.isEmpty)
    #expect(state.gameTime.day == 1)
    #expect(state.speed == .normal)
    #expect(state.isPaused == false)
    #expect(state.simulationTick == 0)
    #expect(state.pigdex.discoveredCount == 0)
    #expect(state.breedingPair == nil)
}

// MARK: - Farm Reset: Pigdex Carry-Over

@Test @MainActor func farmResetPreservesPigdexInPrestigeState() {
    let state = makeGameState()
    _ = state.pigdex.registerPhenotype(key: "agouti:solid:normal:none", gameDay: 1)
    _ = state.pigdex.registerPhenotype(key: "black:spotted:dark:none", gameDay: 2)

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.prestigeState.previousPigdexEntries.contains("agouti:solid:normal:none"))
    #expect(state.prestigeState.previousPigdexEntries.contains("black:spotted:dark:none"))
    #expect(state.pigdex.discoveredCount == 0) // current-farm pigdex is fresh
}

@Test @MainActor func pigdexCarryOverAccumulatesAcrossFarms() {
    let state = makeGameState()
    _ = state.pigdex.registerPhenotype(key: "agouti:solid:normal:none", gameDay: 1)

    let engine = GameEngine(state: state)
    engine.farmReset()

    // Second farm discovers a different phenotype
    _ = state.pigdex.registerPhenotype(key: "black:spotted:dark:none", gameDay: 1)
    engine.farmReset()

    // Both entries should be in previousPigdexEntries
    #expect(state.prestigeState.previousPigdexEntries.count == 2)
    #expect(state.prestigeState.previousPigdexEntries.contains("agouti:solid:normal:none"))
    #expect(state.prestigeState.previousPigdexEntries.contains("black:spotted:dark:none"))
}

// MARK: - Farm Reset: Lifetime Stats

@Test @MainActor func farmResetAccumulatesLifetimeStats() {
    let state = makeGameState()
    state.totalPigsBorn = 50
    state.totalEarnings = 10_000
    state.totalPigsSold = 30

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.prestigeState.lifetimeStats.totalPigsBred == 50)
    #expect(state.prestigeState.lifetimeStats.totalSqueaksEarned == 10_000)
    #expect(state.prestigeState.lifetimeStats.totalPigsSold == 30)

    // Second farm adds more
    state.totalPigsBorn = 25
    state.totalEarnings = 5_000
    state.totalPigsSold = 15
    engine.farmReset()

    #expect(state.prestigeState.lifetimeStats.totalPigsBred == 75)
    #expect(state.prestigeState.lifetimeStats.totalSqueaksEarned == 15_000)
    #expect(state.prestigeState.lifetimeStats.totalPigsSold == 45)
}

// MARK: - Farm Reset: Farm Count

@Test @MainActor func farmResetIncrementsFarmCount() {
    let state = makeGameState()
    #expect(state.prestigeState.farmCount == 1)

    let engine = GameEngine(state: state)
    engine.farmReset()
    #expect(state.prestigeState.farmCount == 2)

    engine.farmReset()
    #expect(state.prestigeState.farmCount == 3)
}

// MARK: - Showroom Bonuses: Established Farm

@Test @MainActor func resetWithEstablishedFarmStartsAtTier2With2Rooms() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.establishedFarm]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.farmTier == 2)
    #expect(state.farm.tier == 2)
    #expect(state.farm.areas.count == 2)
}

// MARK: - Showroom Bonuses: Grand Farm

@Test @MainActor func resetWithGrandFarmStartsAtTier3With3Rooms() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.grandFarm]

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.farmTier == 3)
    #expect(state.farm.tier == 3)
    #expect(state.farm.areas.count == 3)
}

@Test @MainActor func grandFarmSupersedesEstablishedFarm() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.establishedFarm, .grandFarm]

    let engine = GameEngine(state: state)
    engine.farmReset()

    // Grand Farm should take precedence
    #expect(state.farmTier == 3)
    #expect(state.farm.areas.count == 3)
}

// MARK: - Showroom Bonuses: Heritage Herd

@Test @MainActor func resetWithHeritageHerdSpawns5Pigs() {
    let state = makeGameState()
    state.prestigeState.purchasedUpgrades = [.heritageHerd]

    let engine = GameEngine(state: state)
    engine.farmReset()

    // 2 from setupNewGame + 3 from Heritage Herd
    #expect(state.pigCount == 5)
}

// MARK: - Showroom Bonuses: No Upgrades

@Test @MainActor func resetWithNoUpgradesStartsDefault() {
    let state = makeGameState()

    let engine = GameEngine(state: state)
    engine.farmReset()

    #expect(state.farmTier == 1)
    #expect(state.farm.areas.count == 1)
    #expect(state.pigCount == 2) // default setupNewGame pigs
}

// MARK: - Pigdex Rediscovery Rewards

@Test @MainActor func rediscoverPreviousPhenotypeAwards50Percent() {
    let state = makeGameState()
    state.money = 0

    // Use a common genotype and derive the key from it (don't hardcode phenotype mapping)
    let genotype = Genotype.randomCommon()
    let pig = GuineaPig.create(name: "Tester", gender: .female, genotype: genotype)
    let key = phenotypeKey(pig.phenotype)

    // Mark this key as previously discovered
    state.prestigeState.previousPigdexEntries = [key]

    Birth.registerPigInPigdex(gameState: state, pig: pig)

    let rarity = keyToRarity(key)
    let fullReward = getDiscoveryReward(rarity)
    let expectedReward = Int(Double(fullReward) * GameConfig.Prestige.rediscoveryRewardFraction)
    #expect(state.money == expectedReward)
}

@Test @MainActor func newDiscoveryAwardsFullReward() {
    let state = makeGameState()
    state.money = 0
    // No previous entries — empty prestige state

    let genotype = Genotype.randomCommon()
    let pig = GuineaPig.create(name: "Tester", gender: .female, genotype: genotype)
    let key = phenotypeKey(pig.phenotype)

    Birth.registerPigInPigdex(gameState: state, pig: pig)

    let rarity = keyToRarity(key)
    let fullReward = getDiscoveryReward(rarity)
    #expect(state.money == fullReward)
}

// MARK: - Pigdex Discovery Status

@Test func pigdexStatusUndiscovered() {
    let pigdex = Pigdex()
    let status = pigdex.status(for: "agouti:solid:normal:none", previousEntries: [])
    #expect(status == .undiscovered)
}

@Test func pigdexStatusPreviouslyDiscovered() {
    let pigdex = Pigdex()
    let status = pigdex.status(for: "agouti:solid:normal:none", previousEntries: ["agouti:solid:normal:none"])
    #expect(status == .previouslyDiscovered)
}

@Test func pigdexStatusDiscovered() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "agouti:solid:normal:none", gameDay: 1)
    let status = pigdex.status(for: "agouti:solid:normal:none", previousEntries: [])
    #expect(status == .discovered)
}

@Test func pigdexStatusRediscovered() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "agouti:solid:normal:none", gameDay: 1)
    let status = pigdex.status(for: "agouti:solid:normal:none", previousEntries: ["agouti:solid:normal:none"])
    #expect(status == .rediscovered)
}

// MARK: - Biome Mastery

@Test func biomeMasteryRecordBirthIncrementsCount() {
    var mastery = BiomeMastery()
    mastery.recordBirth(in: .meadow)
    mastery.recordBirth(in: .meadow)
    mastery.recordBirth(in: .alpine)

    #expect(mastery.pigsBred(in: .meadow) == 2)
    #expect(mastery.pigsBred(in: .alpine) == 1)
    #expect(mastery.pigsBred(in: .tropical) == 0)
}

@Test func biomeMasteryThresholdAt10() {
    var mastery = BiomeMastery()
    for _ in 0..<9 {
        mastery.recordBirth(in: .meadow)
    }
    #expect(mastery.isMastered(.meadow) == false)

    mastery.recordBirth(in: .meadow)
    #expect(mastery.isMastered(.meadow) == true)
}

@Test func biomeMasteryProgressFraction() {
    var mastery = BiomeMastery()
    for _ in 0..<5 {
        mastery.recordBirth(in: .alpine)
    }
    let progress = mastery.masteryProgress(for: .alpine)
    #expect(progress == 0.5)
}
