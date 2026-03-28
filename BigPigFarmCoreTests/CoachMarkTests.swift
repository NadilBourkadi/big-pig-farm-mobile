/// CoachMarkTests — Tests for onboarding coach mark state and trigger logic.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - CoachMarkState Tests

@Test func stateStartsEmpty() {
    let state = CoachMarkState()
    #expect(state.dismissed.isEmpty)
    for id in CoachMarkID.allCases {
        #expect(!state.isShown(id))
    }
}

@Test func markShownRecordsDismissal() {
    var state = CoachMarkState()
    state.markShown(.welcomeTapPig)
    #expect(state.isShown(.welcomeTapPig))
    #expect(!state.isShown(.openShop))
}

@Test func markShownIsIdempotent() {
    var state = CoachMarkState()
    state.markShown(.welcomeTapPig)
    state.markShown(.welcomeTapPig)
    #expect(state.dismissed.count == 1)
}

@Test func resetAllClearsDismissed() {
    var state = CoachMarkState()
    state.markShown(.welcomeTapPig)
    state.markShown(.openShop)
    state.markShown(.editMode)
    state.resetAll()
    #expect(state.dismissed.isEmpty)
}

@Test func persistenceRoundTrip() {
    let defaults = UserDefaults(suiteName: "CoachMarkTests-\(UUID().uuidString)")!
    var state = CoachMarkState()
    state.markShown(.welcomeTapPig)
    state.markShown(.breedingReady)
    state.save(to: defaults)

    let loaded = CoachMarkState.load(from: defaults)
    #expect(loaded == state)
    #expect(loaded.isShown(.welcomeTapPig))
    #expect(loaded.isShown(.breedingReady))
    #expect(!loaded.isShown(.openShop))
}

@Test func loadReturnsEmptyWhenNoData() {
    let defaults = UserDefaults(suiteName: "CoachMarkTests-empty-\(UUID().uuidString)")!
    let loaded = CoachMarkState.load(from: defaults)
    #expect(loaded.dismissed.isEmpty)
}

// MARK: - CoachMarkTrigger Tests

@Test @MainActor func welcomeTapPigShowsOnFreshGame() {
    let state = makeGameState()
    // Fresh game: time < 5 minutes, 2 pigs
    state.gameTime = GameTime()
    var pig1 = GuineaPig.create(name: "Pig1", gender: .male)
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Pig2", gender: .female)
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: CoachMarkState())
    #expect(result == .welcomeTapPig)
}

@Test @MainActor func welcomeTapPigNotShownAfter5Minutes() {
    let state = makeGameState()
    // Boundary: exactly 5.0 minutes does NOT satisfy < 5, so mark is suppressed
    state.gameTime.advance(minutes: 5)
    var pig1 = GuineaPig.create(name: "Pig1", gender: .male)
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Pig2", gender: .female)
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: CoachMarkState())
    #expect(result != .welcomeTapPig)
}

@Test @MainActor func welcomeTapPigStillShowsJustBefore5Minutes() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 4.9)
    var pig1 = GuineaPig.create(name: "Pig1", gender: .male)
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Pig2", gender: .female)
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: CoachMarkState())
    #expect(result == .welcomeTapPig)
}

@Test @MainActor func openShopShowsWhen10MinutesAndFewFacilities() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 10)
    // 3 starter facilities
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 5))
    _ = state.addFacility(Facility.create(type: .hideout, x: 15, y: 5))

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .openShop)
}

@Test @MainActor func openShopNotShownWithMoreThan3Facilities() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    // Bypass grid placement — we only need the count in facilities dict
    let f1 = Facility.create(type: .foodBowl, x: 5, y: 5)
    let f2 = Facility.create(type: .waterBottle, x: 10, y: 5)
    let f3 = Facility.create(type: .hideout, x: 15, y: 5)
    let f4 = Facility.create(type: .foodBowl, x: 20, y: 5)
    state.facilities[f1.id] = f1
    state.facilities[f2.id] = f2
    state.facilities[f3.id] = f3
    state.facilities[f4.id] = f4

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result != .openShop)
}

@Test @MainActor func refillFacilitiesShowsWhenBelowThreshold() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    var food = Facility.create(type: .foodBowl, x: 5, y: 5)
    // Drain to below 30%
    food.currentAmount = food.maxAmount * 0.2
    _ = state.addFacility(food)

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .refillFacilities)
}

@Test @MainActor func refillFacilitiesNotShownForNonRefillableFacility() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    // Hideouts have refillCost == 0, so even at low fill they should not trigger
    var hideout = Facility.create(type: .hideout, x: 5, y: 5)
    hideout.currentAmount = hideout.maxAmount * 0.1
    _ = state.addFacility(hideout)

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result != .refillFacilities)
}

@Test @MainActor func breedingReadyShowsWithTwoAdults() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    var pig1 = GuineaPig.create(name: "Adult1", gender: .male)
    pig1.ageDays = 25
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Adult2", gender: .female)
    pig2.ageDays = 25
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)
    coachState.markShown(.refillFacilities)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .breedingReady)
}

@Test @MainActor func breedingReadyNotShownWhenAlreadyEnabled() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    state.breedingProgram.enabled = true
    var pig1 = GuineaPig.create(name: "Adult1", gender: .male)
    pig1.ageDays = 25
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Adult2", gender: .female)
    pig2.ageDays = 25
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)
    coachState.markShown(.refillFacilities)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result != .breedingReady)
}

@Test @MainActor func editModeShowsWith5Facilities() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    // Bypass grid placement — we only need the count in facilities dict
    for i in 0..<5 {
        let f = Facility.create(type: .foodBowl, x: 5 + i * 5, y: 5)
        state.facilities[f.id] = f
    }

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)
    coachState.markShown(.refillFacilities)
    coachState.markShown(.breedingReady)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .editMode)
}

@Test @MainActor func firstSaleShowsWhen3BornAndNoneSold() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 15)
    state.totalPigsBorn = 3
    state.totalPigsSold = 0

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)
    coachState.markShown(.refillFacilities)
    coachState.markShown(.breedingReady)
    coachState.markShown(.editMode)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .firstSale)
}

@Test @MainActor func firstSaleNotShownWhenPigsSold() {
    let state = makeGameState()
    state.totalPigsBorn = 5
    state.totalPigsSold = 1

    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)
    coachState.markShown(.openShop)
    coachState.markShown(.refillFacilities)
    coachState.markShown(.breedingReady)
    coachState.markShown(.editMode)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result != .firstSale)
}

@Test @MainActor func allDismissedReturnsNil() {
    let state = makeGameState()
    var coachState = CoachMarkState()
    for id in CoachMarkID.allCases {
        coachState.markShown(id)
    }
    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == nil)
}

@Test @MainActor func priorityOrderHighestWins() {
    let state = makeGameState()
    // Set up conditions for both welcomeTapPig AND openShop
    state.gameTime = GameTime()
    var pig1 = GuineaPig.create(name: "Pig1", gender: .male)
    pig1.position = Position(x: 5, y: 5)
    state.addGuineaPig(pig1)
    var pig2 = GuineaPig.create(name: "Pig2", gender: .female)
    pig2.position = Position(x: 8, y: 5)
    state.addGuineaPig(pig2)

    // welcomeTapPig should win over anything else
    let result = CoachMarkTrigger.evaluate(state: state, coachState: CoachMarkState())
    #expect(result == .welcomeTapPig)
}

@Test @MainActor func skipsAlreadyDismissedAndShowsNext() {
    let state = makeGameState()
    state.gameTime.advance(minutes: 10)
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 5))
    _ = state.addFacility(Facility.create(type: .hideout, x: 15, y: 5))

    // Dismiss welcomeTapPig, openShop should come next
    var coachState = CoachMarkState()
    coachState.markShown(.welcomeTapPig)

    let result = CoachMarkTrigger.evaluate(state: state, coachState: coachState)
    #expect(result == .openShop)
}

@Test func messageAndIconNonEmptyForAllCases() {
    for id in CoachMarkID.allCases {
        #expect(!CoachMarkTrigger.message(for: id).isEmpty)
        #expect(!CoachMarkTrigger.icon(for: id).isEmpty)
    }
}
