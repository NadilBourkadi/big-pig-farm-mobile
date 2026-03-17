/// Extended offline progress tests: birth, aging, breeding, economy, behavior, edge cases.
import Testing
import Foundation
@testable import BigPigFarm

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
        // 24 checkpoints = 24 game-hours = 1 game-day — well past gestation
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)

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

        // 24 checkpoints = 24 game-hours = 1 game-day
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)

        let updated = try #require(state.getGuineaPig(pig.id))
        // Should have aged by 1 day (24 hours / 24 hours per day)
        #expect(updated.ageDays > 10.9)
        #expect(updated.ageDays < 11.1)
    }

    @Test @MainActor func oldPigsCanDie() {
        let state = makeOfflineState(pigCount: 1)
        var pig = state.getPigsList()[0]
        pig.ageDays = Double(GameConfig.Simulation.maxAgeDays) + 1  // Past max age
        state.updateGuineaPig(pig)

        // Run many checkpoints to give death roll many chances
        // 4800 seconds * 3 / 60 = 240 game-hours = 10 game-days
        var diedAtLeastOnce = false
        for _ in 0..<10 {
            let freshState = makeOfflineState(pigCount: 1)
            var freshPig = freshState.getPigsList()[0]
            freshPig.ageDays = Double(GameConfig.Simulation.maxAgeDays) + 5
            freshState.updateGuineaPig(freshPig)

            let summary = OfflineProgressRunner.runCatchUp(
                state: freshState, wallClockSeconds: 4800
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
            // 100 checkpoints = 100 game-hours
            let summary = OfflineProgressRunner.runCatchUp(
                state: state, wallClockSeconds: 2000
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

        // Single checkpoint (20 wall seconds * 3 / 60 = 1 game-hour)
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

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
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

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

        // Several checkpoints — should drain the remaining 5 units
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

        #expect(summary.facilitiesEmptied > 0)
    }
}

// MARK: - Position & Behavior Tests

@Suite("Offline Post-Catchup")
struct OfflinePostCatchupTests {
    @Test @MainActor func pigPositionsChange() {
        let state = makeOfflineState(pigCount: 4)
        let positionsBefore = state.getPigsList().map { $0.position }

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)

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

        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)

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
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)
        #expect(!summary.hasMeaningfulEvents)
        #expect(summary.pigsBorn.isEmpty)
    }

    @Test @MainActor func noFacilitiesStillWorks() {
        let state = makeOfflineState(pigCount: 2, withFacilities: false)
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 100)
        #expect(summary.gameHoursElapsed == 5.0)
    }

    @Test @MainActor func maxDurationCapped() {
        let state = makeOfflineState(pigCount: 1)
        // Pass more than max (86400 seconds)
        let summary = OfflineProgressRunner.runCatchUp(
            state: state, wallClockSeconds: 200_000
        )
        // Should cap at 86400 * 3 / 60 = 4320 game-hours
        #expect(summary.gameHoursElapsed == 4320.0)
    }

    @Test @MainActor func veryShortDurationProducesOneCheckpoint() {
        let state = makeOfflineState(pigCount: 1)
        // 20 wall seconds * 3 / 60 = 1 game-hour = 1 checkpoint
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 20)
        #expect(summary.gameHoursElapsed == 1.0)
    }

    @Test @MainActor func belowOneCheckpointReturnsEmpty() {
        let state = makeOfflineState(pigCount: 1)
        // 10 wall seconds * 3 / 60 = 0.5 game-hours = 0 checkpoints
        let summary = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 10)
        #expect(summary.gameHoursElapsed == 0.5)
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

        // 24 checkpoints = 24 game-hours = 1440 game-minutes
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)

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

        // 24 checkpoints = 24 game-hours — should push past 72-hour threshold
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)

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

        // Run enough to cross a day boundary
        _ = OfflineProgressRunner.runCatchUp(state: state, wallClockSeconds: 480)

        // Contracts should have been refreshed
        #expect(!state.contractBoard.activeContracts.isEmpty)
    }
}
