/// ProtocolsTests -- Verify GameState conforms to all context protocols and protocol contracts hold.
/// Tests call through protocol existentials to exercise witness table dispatch, not the concrete type.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - NeedsContext Conformance

@Test @MainActor func needsContextFarmIsAccessible() {
    let state = GameState()
    let context: any NeedsContext = state
    #expect(context.farm.width > 0)
    #expect(context.farm.height > 0)
}

@Test @MainActor func needsContextGetPigsListEmpty() {
    let state = GameState()
    let context: any NeedsContext = state
    #expect(context.getPigsList().isEmpty)
}

@Test @MainActor func needsContextGetPigsListReflectsState() {
    let state = GameState()
    let context: any NeedsContext = state
    let pig = GuineaPig.create(name: "Squeaky", gender: .female)
    state.addGuineaPig(pig)
    #expect(context.getPigsList().count == 1)
}

@Test @MainActor func needsContextHasUpgrade() {
    let state = GameState()
    let context: any NeedsContext = state
    #expect(!context.hasUpgrade("auto_feeder"))
    state.purchasedUpgrades.insert("auto_feeder")
    #expect(context.hasUpgrade("auto_feeder"))
}

// MARK: - BreedingContext Conformance

@Test @MainActor func breedingContextInitialState() {
    let state = GameState()
    let context: any BreedingContext = state
    #expect(context.breedingPair == nil)
    #expect(!context.isAtCapacity)
    #expect(context.getPigsList().isEmpty)
    #expect(context.getGuineaPig(UUID()) == nil)
    #expect(context.getFacilitiesByType(.foodBowl).isEmpty)
    #expect(!context.hasUpgrade("test"))
}

@Test @MainActor func breedingContextSetAndClearPair() {
    let state = GameState()
    let context: any BreedingContext = state
    let maleID = UUID()
    let femaleID = UUID()
    context.setBreedingPair(maleID: maleID, femaleID: femaleID)
    #expect(context.breedingPair?.maleId == maleID)
    #expect(context.breedingPair?.femaleId == femaleID)
    // Verify mutation propagates to the underlying GameState
    #expect(state.breedingPair?.maleId == maleID)
    context.clearBreedingPair()
    #expect(context.breedingPair == nil)
    #expect(state.breedingPair == nil)
}

@Test @MainActor func breedingContextGetAffinityDefault() {
    let state = GameState()
    let context: any BreedingContext = state
    #expect(context.getAffinity(UUID(), UUID()) == 0)
}

@Test @MainActor func breedingContextLogEvent() {
    let state = GameState()
    let context: any BreedingContext = state
    context.logEvent("Pair matched", eventType: "breeding")
    #expect(state.events.count == 1)
    #expect(state.events[0].eventType == "breeding")
    #expect(state.events[0].message == "Pair matched")
}

@Test @MainActor func breedingContextBreedingProgramWritable() {
    let state = GameState()
    let context: any BreedingContext = state
    #expect(!context.breedingProgram.enabled)
    context.breedingProgram.enabled = true
    #expect(state.breedingProgram.enabled)
}

// MARK: - BirthContext Conformance

@Test @MainActor func birthContextInitialState() {
    let state = GameState()
    let context: any BirthContext = state
    #expect(context.capacity > 0)
    #expect(context.pigCount == 0)
    #expect(!context.isAtCapacity)
    #expect(context.totalPigsBorn == 0)
    #expect(context.getPigsList().isEmpty)
    #expect(!context.hasUpgrade("test"))
}

@Test @MainActor func birthContextAddAndRemovePig() {
    let state = GameState()
    let context: any BirthContext = state
    let pig = GuineaPig.create(name: "Newborn", gender: .male)
    context.addGuineaPig(pig)
    #expect(context.pigCount == 1)
    #expect(context.getGuineaPig(pig.id) != nil)
    let removed = context.removeGuineaPig(pig.id)
    #expect(removed != nil)
    #expect(context.pigCount == 0)
}

@Test @MainActor func birthContextTotalPigsBornWritable() {
    let state = GameState()
    let context: any BirthContext = state
    context.totalPigsBorn = 5
    #expect(context.totalPigsBorn == 5)
    // Verify mutation propagates to the underlying GameState
    #expect(state.totalPigsBorn == 5)
}

@Test @MainActor func birthContextAddMoney() {
    let state = GameState()
    let context: any BirthContext = state
    let initial = state.money
    context.addMoney(100)
    #expect(state.money == initial + 100)
}

@Test @MainActor func birthContextLogEvent() {
    let state = GameState()
    let context: any BirthContext = state
    context.logEvent("Pup born", eventType: "birth")
    #expect(state.events.count == 1)
    #expect(state.events[0].eventType == "birth")
}

@Test @MainActor func birthContextPigdexWritable() {
    let state = GameState()
    let context: any BirthContext = state
    // Pigdex is { get set } — verify we can round-trip it through the protocol
    let original = context.pigdex
    context.pigdex = original
    #expect(state.pigdex.discoveredCount == original.discoveredCount)
}

// MARK: - CullingContext Conformance

@Test @MainActor func cullingContextInitialState() {
    let state = GameState()
    let context: any CullingContext = state
    #expect(!context.breedingProgram.enabled)
    #expect(context.contractBoard.activeContracts.isEmpty)
    #expect(context.getPigsList().isEmpty)
    #expect(context.getFacilitiesByType(.foodBowl).isEmpty)
}

@Test @MainActor func cullingContextLogEvent() {
    let state = GameState()
    let context: any CullingContext = state
    context.logEvent("Surplus pig sold", eventType: "sale")
    #expect(state.events.count == 1)
    #expect(state.events[0].eventType == "sale")
}

// CullingContext is intentionally narrow — it exposes no pig mutation methods.
// This is a compile-time guarantee enforced by Swift's type system:
// addGuineaPig, removeGuineaPig, addMoney, and totalPigsBorn are all absent,
// so the culling system cannot accidentally modify pig population directly.
// If any of those were added to CullingContext, the GameState conformance
// extensions would still compile, but callers accessing `any CullingContext`
// would gain unintended mutation power — a protocol design regression.
@Test @MainActor func cullingContextIsNarrow() {
    let state = GameState()
    let _: any CullingContext = state
    // Existential assignment succeeds: GameState satisfies CullingContext.
    // The absence of mutation methods on CullingContext is enforced at compile time.
}

// MARK: - Intermediate Protocol Conformance

@Test @MainActor func upgradeQueryContextConformance() {
    let state = GameState()
    let context: any UpgradeQueryContext = state
    #expect(!context.hasUpgrade("test_upgrade"))
    state.purchasedUpgrades.insert("test_upgrade")
    #expect(context.hasUpgrade("test_upgrade"))
}

@Test @MainActor func pigQueryContextConformance() {
    let state = GameState()
    let context: any PigQueryContext = state
    #expect(context.getPigsList().isEmpty)
    #expect(context.getGuineaPig(UUID()) == nil)
    let pig = GuineaPig.create(name: "Hazel", gender: .female)
    state.addGuineaPig(pig)
    #expect(context.getPigsList().count == 1)
    #expect(context.getGuineaPig(pig.id)?.name == "Hazel")
}

@Test @MainActor func eventLoggingContextConformance() {
    let state = GameState()
    let context: any EventLoggingContext = state
    context.logEvent("Test event", eventType: "test")
    #expect(state.events.count == 1)
    #expect(state.events[0].message == "Test event")
    #expect(state.events[0].eventType == "test")
}

// NeedsContext and CullingContext now inherit PigQueryContext, which includes
// getGuineaPig(_:). This is an intentional widening — read-only pig lookup
// does not weaken the mutation restrictions these protocols enforce.
// These tests document protocol surface, not production usage. getGuineaPig
// is unused by NeedsSystem and Culling today.

@Test @MainActor func needsContextProvidesGetGuineaPig() {
    let state = GameState()
    let context: any NeedsContext = state
    let pig = GuineaPig.create(name: "Clover", gender: .male)
    state.addGuineaPig(pig)
    #expect(context.getGuineaPig(pig.id)?.name == "Clover")
}

@Test @MainActor func cullingContextProvidesGetGuineaPig() {
    let state = GameState()
    let context: any CullingContext = state
    let pig = GuineaPig.create(name: "Bramble", gender: .female)
    state.addGuineaPig(pig)
    #expect(context.getGuineaPig(pig.id)?.name == "Bramble")
}
