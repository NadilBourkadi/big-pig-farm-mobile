/// TreatManagerTests — Tests for treat delivery, cooldown, and capacity.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Cooldown

@Test func cooldownActiveWithinWindow() {
    var prestige = PrestigeState()
    prestige.visitStreak.lastVisitDate = Date().addingTimeInterval(-7200) // 2h ago
    #expect(TreatManager.isOnCooldown(prestige: prestige))
}

@Test func cooldownExpiredAfterWindow() {
    var prestige = PrestigeState()
    prestige.visitStreak.lastVisitDate = Date().addingTimeInterval(-18000) // 5h ago
    #expect(!TreatManager.isOnCooldown(prestige: prestige))
}

@Test func cooldownFalseWhenNeverVisited() {
    let prestige = PrestigeState()
    #expect(!TreatManager.isOnCooldown(prestige: prestige))
}

// MARK: - Treat Delivery

@Test @MainActor func deliverTreatClaimsPigsInRadius() {
    let state = GameState()
    state.remainingTreatsThisVisit = 2

    var pig = GuineaPig.create(name: "Nearby", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.needs.hunger = 50.0
    state.addGuineaPig(pig)

    let target = Position(x: 5.0, y: 5.0) // on top of pig
    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: target, state: state)

    #expect(fed.count == 1)
    #expect(fed.contains(pig.id))
    #expect(state.remainingTreatsThisVisit == 1)

    // Stat effects are deferred to arrival — needs should be unchanged
    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.hunger == 50.0)
}

@Test @MainActor func deliverTreatSkipsPigsOutsideRadius() {
    let state = GameState()
    state.remainingTreatsThisVisit = 2

    var nearPig = GuineaPig.create(name: "Near", gender: .female)
    nearPig.position = Position(x: 5.0, y: 5.0)
    state.addGuineaPig(nearPig)

    var farPig = GuineaPig.create(name: "Far", gender: .male)
    farPig.position = Position(x: 20.0, y: 20.0) // well outside 6 cells
    state.addGuineaPig(farPig)

    let target = Position(x: 5.0, y: 5.0)
    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: target, state: state)

    #expect(fed.count == 1)
    #expect(fed.contains(nearPig.id))
    #expect(!fed.contains(farPig.id))
}

@Test @MainActor func deliverTreatMaxFourPigs() {
    let state = GameState()
    state.remainingTreatsThisVisit = 2

    let target = Position(x: 10.0, y: 10.0)
    for i in 0..<6 {
        var pig = GuineaPig.create(name: "Pig\(i)", gender: .female)
        pig.position = Position(x: 10.0 + Double(i) * 0.5, y: 10.0)
        state.addGuineaPig(pig)
    }

    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: target, state: state)
    #expect(fed.count == GameConfig.Prestige.treatsPerScatter) // 4
}

@Test @MainActor func deliverTreatDecrementsRemainingCount() {
    let state = GameState()
    state.remainingTreatsThisVisit = 3

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    state.addGuineaPig(pig)

    _ = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)
    #expect(state.remainingTreatsThisVisit == 2)

    _ = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)
    #expect(state.remainingTreatsThisVisit == 1)
}

@Test @MainActor func deliverTreatReturnsEmptyWhenNoTreatsRemain() {
    let state = GameState()
    state.remainingTreatsThisVisit = 0

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    state.addGuineaPig(pig)

    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)
    #expect(fed.isEmpty)
}

@Test @MainActor func deliverTreatReturnsEmptyWhenNoPigsInRange() {
    let state = GameState()
    state.remainingTreatsThisVisit = 2

    var pig = GuineaPig.create(name: "Far", gender: .female)
    pig.position = Position(x: 50.0, y: 50.0)
    state.addGuineaPig(pig)

    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)
    #expect(fed.isEmpty)
    #expect(state.remainingTreatsThisVisit == 2) // not decremented
}

// MARK: - Treat Effects

@Test func leafyGreensBoostsHungerAndHappiness() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.hunger = 40.0
    pig.needs.happiness = 60.0

    TreatManager.applyTreatEffects(type: .leafyGreens, pig: &pig)

    #expect(pig.needs.hunger == 40.0 + TreatType.leafyGreens.info.hungerBoost)
    #expect(pig.needs.happiness == 60.0 + TreatType.leafyGreens.info.happinessBoost)
}

@Test func watermelonBoostsSocial() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.social = 30.0

    TreatManager.applyTreatEffects(type: .watermelon, pig: &pig)

    #expect(pig.needs.social == 30.0 + TreatType.watermelon.info.socialBoost)
}

@Test func treatEffectsClampsTo100() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.needs.hunger = 95.0

    TreatManager.applyTreatEffects(type: .leafyGreens, pig: &pig)

    #expect(pig.needs.hunger == 100.0)
}

@Test @MainActor func deliverTreatPrefersClosestPigs() {
    let state = GameState()
    state.remainingTreatsThisVisit = 1

    let target = Position(x: 10.0, y: 10.0)

    // Create 5 pigs at increasing distances
    var pigs: [GuineaPig] = []
    for i in 0..<5 {
        var pig = GuineaPig.create(name: "Pig\(i)", gender: .female)
        pig.position = Position(x: 10.0 + Double(i), y: 10.0)
        state.addGuineaPig(pig)
        pigs.append(pig)
    }

    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: target, state: state)
    #expect(fed.count == 4) // treatsPerScatter = 4

    // The closest 4 should be fed, the farthest should not
    #expect(fed.contains(pigs[0].id))
    #expect(fed.contains(pigs[1].id))
    #expect(fed.contains(pigs[2].id))
    #expect(fed.contains(pigs[3].id))
    #expect(!fed.contains(pigs[4].id))
}
