/// EmergencyBailoutTests -- Tests for soft-lock detection and emergency pig generation.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - isSoftLocked

@Test @MainActor func isSoftLockedWhenNoPigsAndNoMoney() {
    let state = makeGameState()
    state.money = 0
    #expect(EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func isSoftLockedWhenNoPigsAndMoneyBelowThreshold() {
    let state = makeGameState()
    state.money = GameConfig.Economy.adoptionBaseCost - 1
    #expect(EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func notSoftLockedWhenNoPigsButCanAfford() {
    let state = makeGameState()
    state.money = GameConfig.Economy.adoptionBaseCost
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func notSoftLockedWhenNoPigsAndRich() {
    let state = makeGameState()
    state.money = GameConfig.Economy.startingMoney
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func notSoftLockedWhenPigsExistEvenIfBroke() {
    let state = makeGameState()
    state.money = 0
    let pig = GuineaPig.create(name: "Survivor", gender: .female, ageDays: 5.0)
    state.addGuineaPig(pig)
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func notSoftLockedFreshGameState() {
    let state = makeGameState()
    // Default startingMoney (100) >= adoptionBaseCost (50)
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

// MARK: - generateEmergencyPigs

@Test func emergencyPigsProduceExactlyTwo() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    #expect(pigs.count == 2)
}

@Test func emergencyPigsHaveOneMaleOneFemale() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    #expect(pigs[0].gender == .male)
    #expect(pigs[1].gender == .female)
}

@Test func emergencyPigsAreAdults() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    for pig in pigs {
        #expect(pig.ageDays == 5.0)
        #expect(pig.isAdult)
    }
}

@Test func emergencyPigsHaveUniqueNames() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    #expect(pigs[0].name != pigs[1].name)
}

@Test func emergencyPigsRespectExistingNames() {
    let existing: Set<String> = ["Butterscotch", "Peanut", "Nugget"]
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: existing, farmTier: 1)
    for pig in pigs {
        #expect(!existing.contains(pig.name))
    }
}

@Test func emergencyPigsHaveUniqueIds() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    #expect(pigs[0].id != pigs[1].id)
}

@Test func emergencyPigsHaveValidPhenotype() {
    let pigs = EmergencyBailout.generateEmergencyPigs(existingNames: [], farmTier: 1)
    for pig in pigs {
        #expect(Rarity.allCases.contains(pig.phenotype.rarity))
        #expect(BaseColor.allCases.contains(pig.phenotype.baseColor))
    }
}

// MARK: - Adoption gender override

@Test func adoptionPigGenderOverrideMale() {
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1, gender: .male)
    #expect(pig.gender == .male)
}

@Test func adoptionPigGenderOverrideFemale() {
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1, gender: .female)
    #expect(pig.gender == .female)
}

@Test func adoptionPigGenderNilIsBackwardCompatible() {
    let pig = Adoption.generateAdoptionPig(existingNames: [], farmTier: 1, gender: nil)
    #expect(pig.gender == .male || pig.gender == .female)
}

// MARK: - Soft-lock transition

@Test @MainActor func adoptingOnePigClearsSoftLock() {
    let state = makeGameState()
    state.money = 0
    #expect(EmergencyBailout.isSoftLocked(state: state))

    let pig = GuineaPig.create(name: "Rescue", gender: .female, ageDays: 5.0)
    state.addGuineaPig(pig)
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func softLockBoundaryExactlyAtThreshold() {
    let state = makeGameState()
    // At exactly adoptionBaseCost, can afford — not soft-locked
    state.money = GameConfig.Economy.adoptionBaseCost
    #expect(!EmergencyBailout.isSoftLocked(state: state))

    // One below — soft-locked
    state.money = GameConfig.Economy.adoptionBaseCost - 1
    #expect(EmergencyBailout.isSoftLocked(state: state))
}
