/// Tests for auto-resource perks (drip system, auto-feeders, veggie gardens) during offline catch-up.
import Testing
import Foundation
@testable import BigPigFarmCore

@Suite("Offline Auto-Resources")
struct OfflineAutoResourcesTests {

    @Test @MainActor func dripSystemReplenishesDuringCatchUp() throws {
        let state = makeOfflineState(pigCount: 0)
        state.purchasedUpgrades.insert("drip_system")
        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        bowl.currentAmount = 50.0
        bowl.maxAmount = 200.0
        state.facilities[bowl.id] = bowl

        // 5 checkpoints = 5 game-hours. Drip rate = 2.0/hr → expect ~+10.0
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

        let updated = try #require(state.facilities[bowl.id])
        #expect(updated.currentAmount > 59.0)
        #expect(updated.currentAmount <= 60.0 + 1e-10)
    }

    @Test @MainActor func autoFeederRefillsWhenBelowThreshold() throws {
        let state = makeOfflineState(pigCount: 0)
        state.purchasedUpgrades.insert("auto_feeders")
        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        // 24% fill — below 25% threshold
        bowl.maxAmount = 200.0
        bowl.currentAmount = 48.0
        state.facilities[bowl.id] = bowl

        // 1 checkpoint
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

        let updated = try #require(state.facilities[bowl.id])
        #expect(updated.currentAmount == 200.0)
    }

    @Test @MainActor func veggieGardensDistributeDuringCatchUp() throws {
        let state = makeOfflineState(pigCount: 0)
        let garden = Facility.create(type: .veggieGarden, x: 0, y: 0)
        state.facilities[garden.id] = garden

        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        bowl.currentAmount = 0.0
        bowl.maxAmount = 200.0
        state.facilities[bowl.id] = bowl

        // 5 checkpoints = 5 game-hours. Garden produces 10.0/hr → 50.0 total
        // (distributed across all non-full food facilities)
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

        let updated = try #require(state.facilities[bowl.id])
        #expect(updated.currentAmount >= 50.0)
    }

    @Test @MainActor func noUpgradesNoAutoRefill() throws {
        let state = makeOfflineState(pigCount: 0)
        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        bowl.currentAmount = 50.0
        bowl.maxAmount = 200.0
        state.facilities[bowl.id] = bowl

        // 5 checkpoints — no pigs, no upgrades
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

        let updated = try #require(state.facilities[bowl.id])
        // No consumption (0 pigs), no refill (no upgrades) → unchanged
        #expect(updated.currentAmount == 50.0)
    }

    @Test @MainActor func dripReducesFacilitiesEmptiedCount() throws {
        let state = makeOfflineState(pigCount: 10)
        state.purchasedUpgrades.insert("drip_system")
        // Set all pigs to critical hunger
        for var pig in state.getPigsList() {
            pig.needs.hunger = 5.0
            state.updateGuineaPig(pig)
        }
        // Drain food bowl to near-empty
        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        _ = bowl.consume(bowl.currentAmount - 5)
        state.facilities[bowl.id] = bowl

        let summaryWithDrip = OfflineProgressRunner.runCatchUp(
            state: state, wallClockSeconds: 100
        )

        // Compare with a baseline without drip
        let baseState = makeOfflineState(pigCount: 10)
        for var pig in baseState.getPigsList() {
            pig.needs.hunger = 5.0
            baseState.updateGuineaPig(pig)
        }
        var baseBowl = try #require(baseState.getFacilitiesByType(.foodBowl).first)
        _ = baseBowl.consume(baseBowl.currentAmount - 5)
        baseState.facilities[baseBowl.id] = baseBowl

        let summaryWithout = OfflineProgressRunner.runCatchUp(
            state: baseState, wallClockSeconds: 100
        )

        // Drip should help — either fewer facilities emptied or same
        #expect(summaryWithDrip.facilitiesEmptied <= summaryWithout.facilitiesEmptied)
    }

    @Test @MainActor func dripAndConsumptionBothApply() throws {
        let state = makeOfflineState(pigCount: 2)
        state.purchasedUpgrades.insert("drip_system")
        // Set pigs to low hunger so they consume
        for var pig in state.getPigsList() {
            pig.needs.hunger = 20.0
            state.updateGuineaPig(pig)
        }
        var bowl = try #require(state.getFacilitiesByType(.foodBowl).first)
        bowl.currentAmount = 100.0
        bowl.maxAmount = 200.0
        state.facilities[bowl.id] = bowl

        // 5 checkpoints: consumption (needs equilibration) + drip (2.0/hr)
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

        let updated = try #require(state.facilities[bowl.id])
        // Bowl should reflect both consumption and drip replenishment
        // Exact value depends on consumption rate, but should be different from 100
        #expect(updated.currentAmount != 100.0)
    }
}
