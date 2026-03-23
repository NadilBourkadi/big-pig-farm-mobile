/// Extended offline progress tests: birth, aging, breeding, economy, behavior, edge cases.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Pregnancy & Birth Tests

@Suite("Offline Birth")
struct OfflineBirthTests {
    @Test @MainActor func pregnancyAdvancesAndBirthFires() throws {
        let state = makeOfflineState(pigCount: 2)
        let pigs = state.getPigsList()
        let male = try #require(pigs.first { $0.gender == .male })
        var female = try #require(pigs.first { $0.gender == .female })

        // Set up pregnancy near term (gestation = 2 days = 48 hours)
        female.isPregnant = true
        female.pregnancyDays = 1.5  // 12 hours from term
        female.partnerId = male.id
        female.partnerGenotype = male.genotype
        female.partnerName = male.name
        state.updateGuineaPig(female)

        let pigCountBefore = state.pigCount
        // 24 game-hours (1 game-day) — well past 12h remaining gestation.
        // Tier 1 (6gh/2h) + tier 2 (8gh/4h) + tier 3 partial (10gh/6.67h) = 12.67h real.
        // Simpler: 2+4+6+1 = 13 real hours = 46800s for exactly 24 game-hours.
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 46_800)

        #expect(state.pigCount > pigCountBefore)
        #expect(!summary.pigsBorn.isEmpty)
    }
}

// MARK: - Aging & Death Tests

@Suite("Offline Aging")
struct OfflineAgingTests {
    @Test @MainActor func pigsAgeCorrectly() throws {
        let state = makeOfflineState(pigCount: 1)
        var pig = state.getPigsList()[0]
        pig.ageDays = 10.0
        state.updateGuineaPig(pig)

        // 24 game-hours = 1 game-day = 46800 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 46_800)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Should have aged by 1 day (24 hours / 24 hours per day)
        #expect(updated.ageDays > 10.9)
        #expect(updated.ageDays < 11.1)
    }

    @Test @MainActor func oldPigsCanDie() {
        // 46800s = 13 real hours = 24 game-hours (24 death-roll checkpoints per attempt).
        // 100 attempts × 24 rolls = 2400 chances — matches pre-rebalancing reliability.
        var diedAtLeastOnce = false
        for _ in 0..<100 {
            let freshState = makeOfflineState(pigCount: 1)
            var freshPig = freshState.getPigsList()[0]
            freshPig.ageDays = Double(GameConfig.Simulation.maxAgeDays) + 5
            freshState.updateGuineaPig(freshPig)

            let summary = OfflineProgressRunner.runCatchUp(
                state: freshState, wallClockSeconds: 46_800
            )
            if !summary.pigsDied.isEmpty {
                diedAtLeastOnce = true
                break
            }
        }
        #expect(diedAtLeastOnce)
    }
}

// MARK: - Breeding Tests

@Suite("Offline Breeding")
struct OfflineBreedingTests {
    @Test @MainActor func breedingCanProducePregnancies() {
        // Run enough checkpoints that at least one breeding roll should succeed
        var pregnancyOccurred = false
        for _ in 0..<5 {
            let state = makeOfflineState(pigCount: 2)
            // Add breeding den for higher chance
            _ = state.addFacility(Facility.create(type: .breedingDen, x: 3, y: 8))
            // Set high happiness for bonus
            for var pig in state.getPigsList() {
                pig.needs.happiness = 90.0
                state.updateGuineaPig(pig)
            }
            // ~8.7 game-hours via tier 1+2: 2h×3.0 + 1.33h×2.0 = 12000 wall seconds
            let summary = OfflineProgressRunner.runCatchUp(
                state: state, wallClockSeconds: 12_000
            )
            if !summary.pregnanciesStarted.isEmpty {
                pregnancyOccurred = true
                break
            }
        }
        #expect(pregnancyOccurred)
    }

    @Test @MainActor func breedingCappedToOnePerCheckpoint() {
        let state = makeOfflineState(pigCount: 10)
        // Add breeding den
        _ = state.addFacility(Facility.create(type: .breedingDen, x: 3, y: 8))
        for var pig in state.getPigsList() {
            pig.needs.happiness = 95.0
            state.updateGuineaPig(pig)
        }

        // 1 game-hour via tier 1 = 1200 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)

        // At most 1 pregnancy per checkpoint
        #expect(summary.pregnanciesStarted.count <= 1)
    }
}

// MARK: - Culling & Selling Tests

@Suite("Offline Economy")
struct OfflineEconomyTests {
    @Test @MainActor func surplusPigsAreSold() {
        let state = makeOfflineState(pigCount: 6)
        // Enable breeding program with low stock limit
        state.breedingProgram.enabled = true
        state.breedingProgram.stockLimit = 4

        let moneyBefore = state.money
        // 1 game-hour via tier 1 = 1200 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)

        // Surplus pigs should have been marked and sold
        #expect(!summary.pigsSold.isEmpty || state.pigCount <= 4)
        #expect(state.money >= moneyBefore)
    }

    @Test @MainActor func facilitiesEmptiedTrackedInSummary() {
        let state = makeOfflineState(pigCount: 10)
        // Set all pigs to critical hunger so they consume heavily
        for var pig in state.getPigsList() {
            pig.needs.hunger = 5.0
            state.updateGuineaPig(pig)
        }
        // Drain food bowl to near-empty so it empties quickly
        for facility in state.getFacilitiesByType(.foodBowl) {
            var mutable = facility
            _ = mutable.consume(mutable.currentAmount - 5)  // Leave just 5 units
            state.updateFacility(mutable)
        }

        // 5 game-hours via tier 1 = 6000 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 6000)

        #expect(summary.facilitiesEmptied > 0)
    }
}

// MARK: - Position & Behavior Tests

@Suite("Offline Post-Catchup")
struct OfflinePostCatchupTests {
    @Test @MainActor func pigPositionsChange() {
        let state = makeOfflineState(pigCount: 4)
        let positionsBefore = state.getPigsList().map { $0.position }

        // 1 game-hour via tier 1 = 1200 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)

        let positionsAfter = state.getPigsList().map { $0.position }
        // At least some pigs should have moved (randomized positions)
        let movedCount = zip(positionsBefore, positionsAfter).filter { $0 != $1 }.count
        #expect(movedCount > 0)
    }

    @Test @MainActor func behaviorStatesResetToIdle() {
        let state = makeOfflineState(pigCount: 3)
        for var pig in state.getPigsList() {
            pig.behaviorState = .eating
            pig.targetFacilityId = UUID()
            pig.path = [GridPosition(x: 1, y: 1)]
            pig.targetDescription = "eating at food bowl"
            state.updateGuineaPig(pig)
        }

        // 1 game-hour via tier 1 = 1200 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)

        for pig in state.getPigsList() {
            #expect(pig.behaviorState == .idle)
            #expect(pig.path.isEmpty)
            #expect(pig.targetPosition == nil)
            #expect(pig.targetFacilityId == nil)
            #expect(pig.targetDescription == nil)
            #expect(pig.courtingPartnerId == nil)
        }
    }
}

// MARK: - Edge Cases

@Suite("Offline Edge Cases")
struct OfflineEdgeCaseTests {
    @Test @MainActor func zeroPigsNoCrash() {
        let state = makeOfflineState(pigCount: 0)
        // 1 game-hour via tier 1 = 1200 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)
        #expect(!summary.hasMeaningfulEvents)
        #expect(summary.pigsBorn.isEmpty)
    }

    @Test @MainActor func noFacilitiesStillWorks() {
        let state = makeOfflineState(pigCount: 2, withFacilities: false)
        // 5 game-hours via tier 1 = 6000 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 6000)
        #expect(summary.gameHoursElapsed == 5.0)
    }

    @Test @MainActor func maxDurationCapped() {
        let state = makeOfflineState(pigCount: 1)
        // Pass more than max (86400 seconds)
        let summary = OfflineProgressRunner.runCatchUp(
            state: state, wallClockSeconds: 200_000
        )
        // Capped at 86400s = 24 real hours → 35 game-hours via diminishing returns
        #expect(summary.gameHoursElapsed == 35.0)
    }

    @Test @MainActor func veryShortDurationProducesOneCheckpoint() {
        let state = makeOfflineState(pigCount: 1)
        // 1 game-hour via tier 1 = 1200 wall seconds
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 1200)
        #expect(summary.gameHoursElapsed == 1.0)
    }

    @Test @MainActor func belowOneCheckpointReturnsEmpty() {
        let state = makeOfflineState(pigCount: 1)
        // 10 wall seconds = 10/3600 * 3.0 ≈ 0.0083 game-hours (< 1 checkpoint)
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 10)
        #expect(summary.gameHoursElapsed < 1.0)
        // No checkpoints ran, so no events
        #expect(!summary.hasMeaningfulEvents)
    }
}

// MARK: - Game Time Tests

@Suite("Offline Game Time")
struct OfflineGameTimeTests {
    @Test @MainActor func gameTimeAdvancesCorrectly() {
        let state = makeOfflineState(pigCount: 1)
        let minutesBefore = state.gameTime.totalGameMinutes

        // 24 game-hours = 1440 game-minutes = 46800 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 46_800)

        let minutesAdvanced = state.gameTime.totalGameMinutes - minutesBefore
        #expect(minutesAdvanced == 1440.0)
    }
}

// MARK: - Acclimation Tests

@Suite("Offline Acclimation")
struct OfflineAcclimationTests {
    @Test @MainActor func acclimationAdvancesDuringCatchUp() throws {
        let state = makeOfflineState(pigCount: 1)
        // The pig needs a currentAreaId pointing to a real area with a different biome
        // than its preferredBiome for acclimation to advance.
        let areas = state.farm.areas
        guard let area = areas.first else {
            // Starter farm should always have at least one area
            Issue.record("No areas in starter farm")
            return
        }
        var pig = state.getPigsList()[0]
        // Starter area is meadow — pig prefers forest, so it's in a foreign biome
        pig.preferredBiome = "forest"
        pig.acclimatingBiome = area.biome.rawValue  // "meadow"
        pig.acclimationTimer = 60.0  // 60 of 72 hours needed
        pig.currentAreaId = area.id
        state.updateGuineaPig(pig)

        // 24 game-hours — should push past 72-hour threshold = 46800 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 46_800)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Timer should have advanced past 72 (acclimation threshold = 3 days * 24 = 72 hours)
        // Either the timer advanced or acclimation completed (preferredBiome changed to meadow)
        #expect(updated.acclimationTimer > 60.0 || updated.preferredBiome == "meadow")
    }
}

// MARK: - Contract Tests

@Suite("Offline Contracts")
struct OfflineContractTests {
    @Test @MainActor func contractsRefreshAtDayBoundary() {
        let state = makeOfflineState(pigCount: 1)
        state.contractBoard.lastRefreshDay = 0
        state.contractBoard.activeContracts = []

        // 24 game-hours to cross a day boundary = 46800 wall seconds
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 46_800)

        // Contracts should have been refreshed
        #expect(!state.contractBoard.activeContracts.isEmpty)
    }
}
