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

@Test @MainActor func deliverTreatFeedsPigsInRadius() {
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

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.hunger == 50.0 + TreatType.leafyGreens.info.hungerBoost)
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

@Test @MainActor func leafyGreensBoostsHungerAndHappiness() {
    let state = GameState()
    state.remainingTreatsThisVisit = 1

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.needs.hunger = 40.0
    pig.needs.happiness = 60.0
    state.addGuineaPig(pig)

    _ = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.hunger == 40.0 + TreatType.leafyGreens.info.hungerBoost)
    #expect(updated.needs.happiness == 60.0 + TreatType.leafyGreens.info.happinessBoost)
}

@Test @MainActor func watermelonBoostsSocial() {
    let state = GameState()
    state.remainingTreatsThisVisit = 1

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.needs.social = 30.0
    state.addGuineaPig(pig)

    _ = TreatManager.deliverTreat(type: .watermelon, at: Position(x: 5.0, y: 5.0), state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.social == 30.0 + TreatType.watermelon.info.socialBoost)
}

@Test @MainActor func treatEffectsClampsTo100() {
    let state = GameState()
    state.remainingTreatsThisVisit = 1

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.needs.hunger = 95.0
    state.addGuineaPig(pig)

    _ = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.needs.hunger == 100.0)
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
