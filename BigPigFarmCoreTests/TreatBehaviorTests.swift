/// TreatBehaviorTests — Tests for treat behavior AI integration.
import Testing
import Foundation

@testable import BigPigFarmCore

// MARK: - TreatManager Behavior Dispatch

@Test @MainActor func deliverTreatSetsTargetTreatPosition() {
    let state = GameState()
    state.remainingTreatsThisVisit = 2

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.behaviorState = .idle
    state.addGuineaPig(pig)

    let target = Position(x: 5.0, y: 5.0)
    let fed = TreatManager.deliverTreat(type: .leafyGreens, at: target, state: state)

    #expect(fed.count == 1)
    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.targetTreatPosition == target)
    #expect(updated.behaviorState == .wandering)
    #expect(updated.targetDescription == "going to treat")
}

@Test @MainActor func deliverTreatClearsFacilityTarget() {
    let state = GameState()
    state.remainingTreatsThisVisit = 1

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.targetFacilityId = UUID()
    state.addGuineaPig(pig)

    _ = TreatManager.deliverTreat(type: .leafyGreens, at: Position(x: 5.0, y: 5.0), state: state)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.targetFacilityId == nil)
    #expect(updated.targetTreatPosition != nil)
}

// MARK: - BehaviorDecision Integration

@Test func shouldKeepTravelingProtectsTreatSeeking() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.behaviorState = .wandering
    pig.targetTreatPosition = Position(x: 10.0, y: 10.0)
    pig.path = [GridPosition(x: 8, y: 8), GridPosition(x: 9, y: 9)]

    #expect(!BehaviorDecision.isContent(pig))
}

@Test func isContentFalseForPigWithTreatTarget() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.behaviorState = .wandering
    pig.targetTreatPosition = Position(x: 10.0, y: 10.0)
    pig.needs.hunger = 90; pig.needs.thirst = 90; pig.needs.energy = 90
    pig.needs.happiness = 90; pig.needs.health = 90; pig.needs.social = 90

    #expect(!BehaviorDecision.isContent(pig))
}

@Test func isContentTrueWhenNoTreatTarget() {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.behaviorState = .idle
    pig.targetTreatPosition = nil
    pig.targetFacilityId = nil
    pig.needs.hunger = 90; pig.needs.thirst = 90; pig.needs.energy = 90
    pig.needs.happiness = 90; pig.needs.health = 90; pig.needs.social = 90

    #expect(BehaviorDecision.isContent(pig))
}

// MARK: - Model Codable

@Test func targetTreatPositionCodableRoundTrip() throws {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.targetTreatPosition = Position(x: 12.5, y: 8.0)

    let data = try JSONEncoder().encode(pig)
    let decoded = try JSONDecoder().decode(GuineaPig.self, from: data)
    #expect(decoded.targetTreatPosition == pig.targetTreatPosition)
}

@Test func targetTreatPositionNilByDefault() {
    let pig = GuineaPig.create(name: "Test", gender: .female)
    #expect(pig.targetTreatPosition == nil)
}

// MARK: - Offline Reset

@Test @MainActor func resetBehaviorStatesClearsTreatTarget() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()

    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: 5.0, y: 5.0)
    pig.targetTreatPosition = Position(x: 10.0, y: 10.0)
    pig.behaviorState = .wandering
    state.addGuineaPig(pig)

    _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 3600)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.targetTreatPosition == nil)
    #expect(updated.behaviorState == .idle)
}
