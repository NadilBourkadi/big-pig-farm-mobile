/// SavePerformanceTests — Benchmark JSON encode/decode with 50–500 pigs.
///
/// Measures serialization throughput, payload size, and round-trip correctness
/// for the auto-save hot path (GameState.encodeToJSON / fromSnapshot).
///
/// Performance budgets are deliberately loose to avoid CI flakes. The printed
/// timings give humans precise numbers to trend over time.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Save Performance

@Suite("Save/Load Performance")
@MainActor
struct SavePerformanceTests {

    // MARK: - Scaling Benchmark

    @Test("JSON encode/decode scaling: 50, 100, 200, 500 pigs")
    func jsonScaling() throws {
        let pigCounts = [50, 100, 200, 500]
        var results: [SaveBenchmarkResult] = []
        let clock = ContinuousClock()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for count in pigCounts {
            let state = makeBenchmarkState(pigCount: count)

            // Encode
            var encodeResult: Data?
            var encodeError: Error?
            let encodeElapsed = clock.measure {
                do { encodeResult = try state.encodeToJSON() } catch { encodeError = error }
            }
            let errorDesc = String(describing: encodeError)
            let encoded = try #require(
                encodeResult, "encodeToJSON failed for \(count) pigs: \(errorDesc)"
            )

            // Decode (decoder allocated once outside loop)
            var decodeResult: GameState?
            var decodeError: Error?
            let decodeElapsed = clock.measure {
                do {
                    let envelope = try decoder.decode(SaveEnvelope.self, from: encoded)
                    decodeResult = GameState.fromSnapshot(envelope.snapshot)
                } catch { decodeError = error }
            }
            let decodeDesc = String(describing: decodeError)
            try #require(decodeResult != nil, "Decode failed for \(count) pigs: \(decodeDesc)")

            results.append(SaveBenchmarkResult(
                count: count,
                encodeMs: encodeElapsed.milliseconds,
                decodeMs: decodeElapsed.milliseconds,
                sizeKB: Double(encoded.count) / 1_024.0
            ))
        }

        // Print scaling table
        print("[SavePerf] JSON scaling:")
        for result in results {
            let countStr = String(result.count).padding(toLength: 5, withPad: " ", startingAt: 0)
            print("  \(countStr) pigs:  encode=\(format(result.encodeMs))ms" +
                  "  decode=\(format(result.decodeMs))ms" +
                  "  size=\(format(result.sizeKB))KB")
        }

        // Loose regression guards
        if let at200 = results.first(where: { $0.count == 200 }) {
            #expect(at200.encodeMs < 2_000, "Encode 200 pigs took \(format(at200.encodeMs))ms (budget: 2s)")
            #expect(at200.decodeMs < 2_000, "Decode 200 pigs took \(format(at200.decodeMs))ms (budget: 2s)")
        }
        if let at500 = results.first(where: { $0.count == 500 }) {
            #expect(at500.encodeMs < 5_000, "Encode 500 pigs took \(format(at500.encodeMs))ms (budget: 5s)")
            #expect(at500.decodeMs < 5_000, "Decode 500 pigs took \(format(at500.decodeMs))ms (budget: 5s)")
        }
    }

    // MARK: - Round-Trip Correctness

    @Test("Round-trip correctness with 200 pigs")
    func roundtripCorrectness200Pigs() throws {
        let state = makeBenchmarkState(pigCount: 200)

        let data = try state.encodeToJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SaveEnvelope.self, from: data)
        let restored = GameState.fromSnapshot(envelope.snapshot)

        #expect(restored.guineaPigs.count == 200)
        #expect(restored.money == state.money)
        #expect(restored.facilities.count == state.facilities.count)
        #expect(restored.farmTier == state.farmTier)
        #expect(restored.totalPigsBorn == state.totalPigsBorn)
        #expect(restored.purchasedUpgrades == state.purchasedUpgrades)
        #expect(restored.pigdex.discoveredCount == state.pigdex.discoveredCount)
        #expect(restored.contractBoard.activeContracts.count == state.contractBoard.activeContracts.count)
        #expect(restored.completedMilestones == state.completedMilestones)
        #expect(restored.socialAffinity == state.socialAffinity)
        #expect(restored.breedingProgram.enabled == state.breedingProgram.enabled)
        #expect(restored.events.count == state.events.count)

        // Spot-check: every pig ID survived with field fidelity
        for id in state.guineaPigs.keys {
            let original = try #require(state.guineaPigs[id])
            let roundTripped = try #require(restored.guineaPigs[id], "Pig \(id) missing after round-trip")
            #expect(roundTripped.name == original.name)
            #expect(roundTripped.gender == original.gender)
            #expect(roundTripped.genotype.eLocus == original.genotype.eLocus)
            #expect(roundTripped.genotype.bLocus == original.genotype.bLocus)
            #expect(roundTripped.isPregnant == original.isPregnant)
        }
    }

    // MARK: - Payload Size Breakdown

    @Test("Payload size breakdown: grid vs pigs vs metadata")
    func payloadSizeBreakdown() throws {
        let emptyState = makeBenchmarkState(pigCount: 0)
        let emptyData = try emptyState.encodeToJSON()
        let emptyKB = Double(emptyData.count) / 1_024.0

        let fullState = makeBenchmarkState(pigCount: 200)
        let fullData = try fullState.encodeToJSON()
        let fullKB = Double(fullData.count) / 1_024.0

        let pigOverheadKB = fullKB - emptyKB
        let perPigKB = pigOverheadKB / 200.0

        print("[SavePerf] Payload breakdown (200 pigs):")
        print("  Grid + metadata (0 pigs): \(format(emptyKB))KB")
        print("  Full state (200 pigs):    \(format(fullKB))KB")
        print("  Pig overhead:             \(format(pigOverheadKB))KB")
        print("  Per-pig:                  \(format(perPigKB))KB")

        // Sanity: full state should be larger than empty
        #expect(fullKB > emptyKB, "200-pig payload should be larger than empty")
        // Sanity: per-pig overhead should be reasonable (< 10KB each)
        #expect(perPigKB < 10.0, "Per-pig overhead \(format(perPigKB))KB seems excessive")
    }

    // MARK: - Encode Hot Path

    @Test("Encode-only timing at 200 pigs: 10-run average")
    func encodeTimingAt200Pigs() throws {
        let state = makeBenchmarkState(pigCount: 200)
        let clock = ContinuousClock()

        // Warmup: let encoder internals and reflection metadata settle
        _ = try state.encodeToJSON()

        var durations: [Double] = []
        for _ in 0..<10 {
            var encodeError: Error?
            let elapsed = clock.measure {
                do { _ = try state.encodeToJSON() } catch { encodeError = error }
            }
            #expect(encodeError == nil, "Encode failed during timing: \(String(describing: encodeError))")
            durations.append(elapsed.milliseconds)
        }

        let avg = durations.reduce(0, +) / Double(durations.count)
        let maxMs = durations.max() ?? 0
        let minMs = durations.min() ?? 0
        print("[SavePerf] Encode timing (200 pigs, 10 runs):")
        print("  avg=\(format(avg))ms  max=\(format(maxMs))ms  min=\(format(minMs))ms")

        // Regression guard: average encode should be under 2 seconds
        #expect(avg < 2_000, "Avg encode at 200 pigs: \(format(avg))ms (budget: 2s)")
    }
}

// MARK: - Result Type

private struct SaveBenchmarkResult {
    let count: Int
    let encodeMs: Double
    let decodeMs: Double
    let sizeKB: Double
}

// MARK: - Benchmark State Builder

/// Build a GameState populated with N pigs, varied facilities, 4 areas,
/// pigdex entries, contracts, upgrades, and event log — suitable for save benchmarks.
@MainActor
private func makeBenchmarkState(pigCount: Int) -> GameState {
    let state = GameState()
    // Disable New Farmer Spirit boosters (not serialized, but affects pig creation defaults)
    state.prestigeState.farmCount = 2
    state.farm = makeBenchmarkGrid()

    addBenchmarkFacilities(to: state)
    addBenchmarkPigs(to: state, count: pigCount)
    addBenchmarkMetadata(to: state, pigCount: pigCount)

    return state
}

/// 96x56 grid with 4 biome areas (matches Grand Master layout).
private func makeBenchmarkGrid() -> FarmGrid {
    var grid = FarmGrid(width: 96, height: 56)
    let areas = [
        FarmArea(id: UUID(), name: "Meadow", biome: .meadow,
                 x1: 0, y1: 0, x2: 43, y2: 24, gridCol: 0, gridRow: 0),
        FarmArea(id: UUID(), name: "Burrow", biome: .burrow,
                 x1: 48, y1: 0, x2: 91, y2: 24, gridCol: 1, gridRow: 0),
        FarmArea(id: UUID(), name: "Garden", biome: .garden,
                 x1: 0, y1: 28, x2: 43, y2: 52, gridCol: 0, gridRow: 1),
        FarmArea(id: UUID(), name: "Alpine", biome: .alpine,
                 x1: 48, y1: 28, x2: 91, y2: 52, gridCol: 1, gridRow: 1)
    ]
    for area in areas { grid.addArea(area) }
    return grid
}

/// 30 facilities of varied types spread across 4 areas.
@MainActor
private func addBenchmarkFacilities(to state: GameState) {
    let types: [FacilityType] = [
        .foodBowl, .waterBottle, .hayRack, .hideout, .exerciseWheel,
        .playArea, .nursery, .veggieGarden, .groomingStation, .breedingDen
    ]
    let positions: [(Int, Int)] = [
        (5, 5), (10, 5), (15, 5), (20, 10), (25, 10),
        (30, 10), (5, 15), (10, 15), (15, 15), (20, 20),
        (55, 5), (60, 5), (65, 5), (70, 10), (75, 10),
        (80, 10), (55, 15), (60, 15), (65, 15), (70, 20),
        (5, 33), (10, 33), (15, 33), (20, 38), (25, 38),
        (55, 33), (60, 33), (65, 33), (70, 38), (75, 38)
    ]
    for (idx, pos) in positions.enumerated() {
        let facility = Facility.create(type: types[idx % types.count], x: pos.0, y: pos.1)
        _ = state.addFacility(facility)
    }
}

/// N pigs with varied genetics, ages, genders, and positions.
@MainActor
private func addBenchmarkPigs(to state: GameState, count: Int) {
    let interiorCols = (96 - 10) / 3
    for idx in 0..<count {
        let gender: Gender = idx.isMultiple(of: 2) ? .male : .female
        var pig = GuineaPig.create(
            name: "BenchPig\(idx)", gender: gender, genotype: Genotype.random()
        )

        // Distribute ages: ~20% babies, ~60% adults, ~20% seniors
        switch idx % 5 {
        case 0: pig.ageDays = Double.random(in: 0..<15)
        case 4: pig.ageDays = Double.random(in: 250..<400)
        default: pig.ageDays = Double.random(in: 15..<250)
        }

        if gender == .female && idx % 20 == 3 {
            pig.isPregnant = true
            pig.pregnancyDays = Double.random(in: 0..<21)
        }

        pig.position = Position(
            x: Double(5 + (idx % interiorCols) * 3),
            y: Double(min(5 + (idx / interiorCols) * 3, 52))
        )
        pig.needs.happiness = Double.random(in: 40...100)
        pig.needs.hunger = Double.random(in: 0...80)
        pig.needs.thirst = Double.random(in: 0...80)

        state.addGuineaPig(pig)
    }
}

/// Populate pigdex, contracts, social affinity, upgrades, events, and breeding program.
@MainActor
private func addBenchmarkMetadata(to state: GameState, pigCount: Int) {
    // Pigdex: 30 random phenotype discoveries
    let allKeys = getAllPhenotypeKeys()
    for idx in 0..<min(30, allKeys.count) {
        _ = state.pigdex.registerPhenotype(key: allKeys[idx], gameDay: idx + 1)
    }

    // Contracts: 3 active
    for idx in 0..<3 {
        let color = BaseColor.allCases[idx % BaseColor.allCases.count]
        let contract = BreedingContract(
            id: UUID(), description: "Deliver a \(color.rawValue) pig",
            requiredColor: color, difficulty: .medium,
            reward: 100 + idx * 50, deadlineDay: 30 + idx * 10, createdDay: 1
        )
        state.contractBoard.activeContracts.append(contract)
    }
    state.contractBoard.completedContracts = 5
    state.contractBoard.totalContractEarnings = 800

    // Social affinity: up to 20 pairs (needs at least 2 pigs)
    let pigIDs = Array(state.guineaPigs.keys)
    let pairLimit = min(39, pigIDs.count - 1)
    for idx in stride(from: 0, to: max(0, pairLimit), by: 2) {
        let key = "\(pigIDs[idx]):\(pigIDs[idx + 1])"
        state.socialAffinity[key] = Int.random(in: 1...10)
    }

    state.purchasedUpgrades = [
        "speed_boost", "hay_quality", "water_filter", "play_area_xl", "nursery_upgrade"
    ]
    state.farmTier = 3
    state.money = 5_000
    state.totalPigsBorn = pigCount + 50
    state.totalPigsSold = 30
    state.totalEarnings = 3_500
    state.completedMilestones = [.firstPigBorn, .firstPigSold, .firstFacilityPlaced]

    // Event log: 20 entries
    for idx in 0..<20 {
        let event = EventLog(
            timestamp: Date().addingTimeInterval(Double(-idx * 60)),
            gameDay: max(1, 20 - idx),
            message: "Event \(idx): pig activity",
            eventType: ["info", "birth", "sale"][idx % 3]
        )
        state.events.append(event)
    }

    state.breedingProgram.enabled = true
    state.breedingProgram.targetColors = [.golden, .chocolate]
    state.breedingProgram.strategy = .target
}

// MARK: - Formatting

private func format(_ value: Double) -> String {
    String(format: "%.2f", value)
}
