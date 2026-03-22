/// SimulationRunner — Orchestrates per-tick simulation phases.
/// Maps from: simulation/simulation_runner.py
import Foundation
import QuartzCore

/// Runs all simulation subsystems in the correct order each tick.
///
/// Register via `GameEngine.registerTickCallback { [weak runner] in runner?.tick(gameMinutes: $0) }`.
///
/// Tick phase order (matches simulation/simulation_runner.py):
///  1/1b. Rebuild spatial grid + area populations
///  2/2a/2b. Needs, Farm Bell, AutoResources
///  3/3b. Behaviors + courtship → pregnancies
///  4/4b. Separation + rescue
///  5. Biome acclimation
///  6/7. Pregnancies + aging
///  8/9/10. Culling + selling + breeding check
///  11. Contract refresh
///  13. Auto-save counter
@MainActor
final class SimulationRunner {
    private weak var state: GameState?
    private let behaviorController: BehaviorController
    private let saveManager: SaveManager
    private var isSaving: Bool = false

    // MARK: - Event Callbacks

    /// Invoked when a pig is sold: (pigName, totalValue, contractBonus, pigID).
    var onPigSold: ((String, Int, Int, UUID) -> Void)?

    /// Invoked when a new pregnancy starts: (maleName, femaleName).
    var onPregnancy: ((String, String) -> Void)?

    /// Invoked when a birth event is logged: (eventMessage).
    var onBirth: ((String) -> Void)?

    /// Invoked when a new pigdex phenotype is discovered.
    var onPigdexDiscovery: (() -> Void)?

    // MARK: - Tick State

    private var saveCounter: Int = 0
    private var breedingCheckCounter: Int = 0
    private let breedingCheckInterval: Int = 10
    private var lastFarmBellHour: Int = -1

    // MARK: - TPS Measurement

    private var tickTimestamps: [CFTimeInterval] = []
    private let maxTimestamps: Int = 50

    /// Measured ticks per second, updated each tick.
    private(set) var currentTPS: Double = 0.0

    // MARK: - Performance Telemetry

    private var perfLogCounter: Int = 0
    private let perfLogInterval: Int = 100

    // MARK: - Init

    init(state: GameState, behaviorController: BehaviorController, saveManager: SaveManager) {
        self.state = state
        self.behaviorController = behaviorController
        self.saveManager = saveManager
    }

    // MARK: - Offline Progress

    /// Rebuild the spatial grid and resolve pig overlaps after offline
    /// repositioning. Call before `resetAfterOffline()` so separation
    /// operates on the post-catch-up positions.
    func rebuildAndSeparateAfterOffline() {
        behaviorController.collision.rebuildSpatialGrid()
        behaviorController.separateOverlappingPigs()
    }

    /// Clear all behavior tracking state after offline catch-up.
    /// Pigs have been repositioned to random locations, so pathfinding caches,
    /// unreachable-need backoffs, and failed-facility lists are all stale.
    /// Decision timers are staggered to prevent thundering-herd facility seeking.
    func resetAfterOffline() {
        behaviorController.resetAllTracking()
        guard let state else { return }
        behaviorController.staggerDecisionTimers(pigIds: state.guineaPigs.keys)
    }

    // MARK: - Tick Entry Point

    /// Process one simulation tick. `gameMinutes` is already speed-scaled by GameEngine.
    func tick(gameMinutes: Double) {
        guard let state else { return }
        let tickStart = CACurrentMediaTime()
        recordTimestamp(tickStart)
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        DebugLogger.shared.setGameDay(state.gameTime.day)
        #endif
        let gameHours = gameMinutes / 60.0

        // Phases 1/1b: Spatial grid + area populations
        behaviorController.collision.rebuildSpatialGrid()
        behaviorController.facilityManager.updateAreaPopulations()

        // Phases 2/2a/2b: Needs, Farm Bell, AutoResources
        // Each phase that calls getPigsList() gets its own batch scope so it
        // starts with a fresh snapshot. Sharing a scope would cause the second
        // reader to see stale data from the first reader's cache.
        state.withBatchUpdate { updateNeedsPhase(gameMinutes: gameMinutes) }
        checkFarmBell(pigs: state.getPigsList())
        state.withBatchUpdate { AutoResources.tickAutoResources(state: state, gameHours: gameHours) }
        state.withBatchUpdate { AutoResources.tickVeggieGardens(state: state, gameHours: gameHours) }
        state.withBatchUpdate { AutoResources.tickAoEFacilities(state: state, gameHours: gameHours) }

        // Phases 3/3b: Behaviors + courtship → pregnancies
        state.withBatchUpdate { updateBehaviorsPhase(gameMinutes: gameMinutes) }
        // BehaviorMovement calls notifyPigMoved() after each move, so the grid
        // is current going into separation. Note: separateOverlappingPigs() does
        // NOT call notifyPigMoved — the grid may be stale for boundary-crossing
        // pigs after separation, but rebuildSpatialGrid() at the top of the next
        // tick re-syncs everything before it matters.
        state.withBatchUpdate { behaviorController.separateOverlappingPigs() }
        state.withBatchUpdate { behaviorController.rescueNonWalkablePigs(state.getPigsList()) }

        // Phase 5: Biome acclimation
        state.withBatchUpdate { updateAcclimationPhase(gameHours: gameHours) }

        // Phases 6/7: Pregnancies + aging (separate batches — ageAllPigs must
        // see pregnancy updates from advancePregnancies via a fresh snapshot)
        state.withBatchUpdate { Birth.advancePregnancies(gameState: state, gameHours: gameHours) }
        // SAFE: ageAllPigs calls getPigsList() once at entry, then only updates/removes.
        // Do NOT add any getPigsList() call after removeGuineaPig inside this scope.
        state.withBatchUpdate {
            for deadPig in Birth.ageAllPigs(gameState: state, gameHours: gameHours) {
                behaviorController.cleanupDeadPig(deadPig.id)
            }
        }

        // Phases 8/9/10: Culling + selling + breeding check
        state.withBatchUpdate { processEconomyPhase() }

        // Phase 11: Contract refresh/expiry
        checkContractRefresh()

        // Phase 13: Auto-save every 300 ticks (~30 seconds at 10 TPS)
        saveCounter += 1
        if saveCounter >= 300 {
            saveCounter = 0
            backgroundSave()
            #if (DEBUG || INTERNAL) && canImport(UIKit)
            DebugLogger.shared.flush()
            DebugLogger.shared.syncToiCloud()
            #endif
        }

        #if (DEBUG || INTERNAL) && canImport(UIKit)
        logPerfTelemetry(tickStart: tickStart)
        #endif

        // Bump tick counter so FarmScene knows a new tick happened.
        state.advanceSimulationTick()
    }

    // MARK: - Phase Helpers

    private func updateNeedsPhase(gameMinutes: Double) {
        guard let state else { return }
        let pigs = state.getPigsList()
        let nearbyCounts = NeedsSystem.precomputeNearbyCounts(
            pigs: pigs,
            radius: GameConfig.Needs.socialRadius,
            spatialGrid: behaviorController.collision.spatialGrid,
            pigDict: state.guineaPigs
        )
        for var pig in pigs {
            NeedsSystem.updateAllNeeds(
                pig: &pig,
                gameMinutes: gameMinutes,
                state: state,
                nearbyCount: nearbyCounts[pig.id] ?? 0
            )
            state.updateGuineaPig(pig)
        }
    }

    private func updateBehaviorsPhase(gameMinutes: Double) {
        guard let state else { return }
        for var pig in state.getPigsList() {
            behaviorController.update(pig: &pig, gameMinutes: gameMinutes)
            state.updateGuineaPig(pig)
        }
        for (maleId, femaleId) in behaviorController.drainCompletedCourtships() {
            guard var male = state.getGuineaPig(maleId),
                  var female = state.getGuineaPig(femaleId) else { continue }
            Breeding.startPregnancyFromCourtship(male: &male, female: &female, gameState: state)
            state.updateGuineaPig(male)
            state.updateGuineaPig(female)
            onPregnancy?(male.name, female.name)
        }
    }

    private func updateAcclimationPhase(gameHours: Double) {
        guard let state else { return }
        for var pig in state.getPigsList() {
            guard pig.preferredBiome != nil
                || pig.acclimationTimer > 0.0
                || pig.acclimatingBiome != nil else { continue }
            var biomeString: String?
            if let areaId = pig.currentAreaId {
                biomeString = state.farm.getAreaByID(areaId)?.biome.rawValue
            }
            let oldBiome = pig.preferredBiome
            Acclimation.updateAcclimation(pig: &pig, currentBiome: biomeString, hoursPerTick: gameHours)
            if pig.preferredBiome != oldBiome {
                state.logEvent(
                    "\(pig.name) acclimated to the \(pig.preferredBiome ?? "unknown") biome!",
                    eventType: "acclimation"
                )
            }
            state.updateGuineaPig(pig)
        }
    }

    private func processEconomyPhase() {
        guard let state else { return }
        Culling.cullSurplusBreeders(gameState: state)
        for record in Culling.sellMarkedAdults(gameState: state) {
            behaviorController.cleanupDeadPig(record.pigID)
            onPigSold?(record.pigName, record.totalValue, record.contractBonus, record.pigID)
        }
        breedingCheckCounter += 1
        let runExpensive = breedingCheckCounter >= breedingCheckInterval
        if runExpensive { breedingCheckCounter = 0 }
        let eventCountBefore = state.events.count
        // Snapshot before checkBreedingOpportunities — the only path that
        // calls registerPigInPigdex. The culling phase above cannot add entries.
        let pigdexBefore = state.pigdex.discoveredCount
        _ = Breeding.checkBreedingOpportunities(gameState: state, runExpensive: runExpensive)
        for event in state.events[eventCountBefore...] where event.eventType == "birth" {
            onBirth?(event.message)
        }
        let newDiscoveries = state.pigdex.discoveredCount - pigdexBefore
        for _ in 0..<newDiscoveries {
            onPigdexDiscovery?()
        }
    }

    // MARK: - Private Helpers

    /// Encode game state on the main actor, then dispatch the file write to a
    /// background thread. Encoding is synchronous (needs @MainActor state reads),
    /// but the I/O is fire-and-forget — atomic writes handle concurrent safety.
    ///
    /// `isSaving` is cleared before dispatch. A Swift 6 strict-concurrency
    /// limitation prevents resetting it from inside `Task.detached` (capturing
    /// `@MainActor self` in a `@Sendable` closure is a sending violation).
    /// This is safe because saves are 300 ticks apart (~30 s) and file writes
    /// for 100–200 KB take < 10 ms — overlap is impossible in practice.
    private func backgroundSave() {
        guard let state else { return }
        guard !isSaving else { return }
        isSaving = true
        let previousLastSave = state.lastSave
        state.lastSave = Date()
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        let encodeStart = CACurrentMediaTime()
        #endif
        guard let data = try? state.encodeToJSON() else {
            state.lastSave = previousLastSave
            isSaving = false
            return
        }
        #if (DEBUG || INTERNAL) && canImport(UIKit)
        let encodeMs = (CACurrentMediaTime() - encodeStart) * 1000.0
        DebugLogger.shared.log(
            category: .performance, level: .info,
            message: "save: encode \(String(format: "%.1f", encodeMs))ms, \(data.count) bytes, \(state.pigCount) pigs",
            payload: [
                "encodeDurationMs": String(format: "%.2f", encodeMs),
                "dataBytes": String(data.count),
                "pigCount": String(state.pigCount),
            ]
        )
        #endif
        isSaving = false
        let manager = saveManager
        Task.detached(priority: .utility) {
            try? manager.saveData(data)
        }
    }

    #if (DEBUG || INTERNAL) && canImport(UIKit)
    /// Log tick duration, TPS, and pig count every `perfLogInterval` ticks.
    private func logPerfTelemetry(tickStart: CFTimeInterval) {
        guard let state else { return }
        perfLogCounter += 1
        guard perfLogCounter >= perfLogInterval else { return }
        perfLogCounter = 0
        let tickMs = (CACurrentMediaTime() - tickStart) * 1000.0
        let tpsStr = String(format: "%.1f", currentTPS)
        let msStr = String(format: "%.1f", tickMs)
        DebugLogger.shared.log(
            category: .performance, level: .verbose,
            message: "tick: \(msStr)ms, \(tpsStr) TPS, \(state.pigCount) pigs",
            payload: [
                "tickDurationMs": String(format: "%.2f", tickMs),
                "tps": tpsStr,
                "pigCount": String(state.pigCount),
                "facilityCount": String(state.facilities.count),
            ]
        )
    }
    #endif

    private func recordTimestamp(_ time: CFTimeInterval) {
        tickTimestamps.append(time)
        if tickTimestamps.count > maxTimestamps {
            tickTimestamps.removeFirst()
        }
        if tickTimestamps.count >= 2,
           let first = tickTimestamps.first,
           let last = tickTimestamps.last,
           last > first {
            currentTPS = Double(tickTimestamps.count - 1) / (last - first)
        }
    }

    /// Fire the Farm Bell perk notification when pigs have critical needs.
    /// Throttled to at most once per game-hour.
    private func checkFarmBell(pigs: [GuineaPig]) {
        guard let state else { return }
        guard state.hasUpgrade("farm_bell") else { return }
        let currentHour = state.gameTime.day * 24 + state.gameTime.hour
        guard currentHour != lastFarmBellHour else { return }
        let critical = Double(GameConfig.Needs.criticalThreshold)
        let criticalPigs = pigs.filter { $0.needs.hunger < critical || $0.needs.thirst < critical }
        guard !criticalPigs.isEmpty else { return }
        lastFarmBellHour = currentHour
        let names = criticalPigs.prefix(3).map(\.name).joined(separator: ", ")
        let suffix = criticalPigs.count > 3 ? " (+\(criticalPigs.count - 3) more)" : ""
        state.logEvent("Farm Bell: \(names)\(suffix) need food/water!", eventType: "farm_bell")
    }

    /// Expire and optionally refresh the contract board each tick.
    private func checkContractRefresh() {
        guard let state else { return }
        let gameDay = state.gameTime.day
        var board = state.contractBoard
        _ = board.checkExpiry(gameDay: gameDay)
        if board.needsRefresh(gameDay: gameDay) || board.activeContracts.isEmpty {
            let availableBiomes = state.farm.areas.map(\.biome)
            let newContracts = ContractGenerator.generateContracts(
                farmTier: state.farmTier,
                gameDay: gameDay,
                availableBiomes: availableBiomes,
                gameState: state
            )
            board.activeContracts = newContracts
            board.lastRefreshDay = gameDay
        }
        state.contractBoard = board
    }
}
