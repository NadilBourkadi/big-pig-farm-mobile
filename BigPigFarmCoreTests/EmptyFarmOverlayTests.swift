/// EmptyFarmOverlayTests — Tests for the empty-farm detection boundary.
///
/// The overlay trigger is `gameState.pigCount == 0`, evaluated in the view layer.
/// These tests verify the GameState boundary that drives it: pigCount accurately
/// reflects guinea pig additions/removals, and coexists correctly with the
/// soft-lock detection in EmergencyBailout.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Empty Farm Detection

@Test @MainActor func emptyFarmWhenNoPigs() {
    let state = makeGameState()
    #expect(state.pigCount == 0)
}

@Test @MainActor func emptyFarmClearedWhenPigAdded() {
    let state = makeGameState()
    #expect(state.pigCount == 0)

    let pig = GuineaPig.create(name: "Pioneer", gender: .female, ageDays: 25.0)
    state.addGuineaPig(pig)
    #expect(state.pigCount == 1)
}

@Test @MainActor func emptyFarmPigCountZeroAfterLastPigRemoved() {
    let state = makeGameState()
    let pig = GuineaPig.create(name: "LastOne", gender: .male, ageDays: 25.0)
    state.addGuineaPig(pig)
    #expect(state.pigCount == 1)

    state.removeGuineaPig(pig.id)
    #expect(state.pigCount == 0)
}

@Test @MainActor func emptyFarmWithPlentyOfMoney() {
    let state = makeGameState()
    state.money = 10_000
    // Empty farm overlay shows regardless of money — distinct from soft-lock
    #expect(state.pigCount == 0)
    #expect(!EmergencyBailout.isSoftLocked(state: state))
}

@Test @MainActor func emptyFarmWithZeroMoney() {
    let state = makeGameState()
    state.money = 0
    // Both conditions true: empty farm AND soft-locked (both overlays coexist)
    #expect(state.pigCount == 0)
    #expect(EmergencyBailout.isSoftLocked(state: state))
}

// MARK: - Not Empty (Overlay Hidden)

@Test @MainActor func notEmptyWithOnePig() {
    let state = makeGameState()
    let pig = GuineaPig.create(name: "Solo", gender: .female, ageDays: 25.0)
    state.addGuineaPig(pig)
    #expect(state.pigCount == 1)
}

@Test @MainActor func notEmptyWithManyPigs() {
    let state = makeGameState()
    for i in 0..<5 {
        let pig = GuineaPig.create(
            name: "Pig\(i)",
            gender: i.isMultiple(of: 2) ? .male : .female,
            ageDays: 25.0
        )
        state.addGuineaPig(pig)
    }
    #expect(state.pigCount == 5)
}

// MARK: - Reset Boundary

@Test @MainActor func emptyFarmAfterReset() {
    let state = makeGameState()
    let pig = GuineaPig.create(name: "BeforeReset", gender: .male, ageDays: 25.0)
    state.addGuineaPig(pig)
    #expect(state.pigCount == 1)

    state.resetToNewGame()
    #expect(state.pigCount == 0)
}
