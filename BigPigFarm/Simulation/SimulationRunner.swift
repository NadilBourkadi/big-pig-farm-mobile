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

    // MARK: - Init

    init(state: GameState, behaviorController: BehaviorController, saveManager: SaveManager) {
        self.state = state
        self.behaviorController = behaviorController
        self.saveManager = saveManager
    }

    // MARK: - Tick Entry Point

    /// Process one simulation tick. `gameMinutes` is already speed-scaled by GameEngine.
    func tick(gameMinutes: Double) {
        guard let state else { return }
        recordTimestamp(CACurrentMediaTime())
        let gameHours = gameMinutes / 60.0

        // Phases 1/1b: Spatial grid + area populations
        behaviorController.collision.rebuildSpatialGrid()
        behaviorController.facilityManager.updateAreaPopulations()

        // Phases 2/2a/2b: Needs, Farm Bell, AutoResources
        updateNeedsPhase(gameMinutes: gameMinutes)
        checkFarmBell(pigs: state.getPigsList())
        AutoResources.tickAutoResources(state: state, gameHours: gameHours)
        AutoResources.tickVeggieGardens(state: state, gameHours: gameHours)
        AutoResources.tickAoEFacilities(state: state, gameHours: gameHours)

        // Phases 3/3b: Behaviors + courtship → pregnancies
        updateBehaviorsPhase(gameMinutes: gameMinutes)
        behaviorController.separateOverlappingPigs()
        behaviorController.rescueNonWalkablePigs(state.getPigsList())

        // Phase 5: Biome acclimation
        updateAcclimationPhase(gameHours: gameHours)

        // Phases 6/7: Pregnancies + aging
        Birth.advancePregnancies(gameState: state, gameHours: gameHours)
        for deadPig in Birth.ageAllPigs(gameState: state, gameHours: gameHours) {
            behaviorController.cleanupDeadPig(deadPig.id)
        }

        // Phases 8/9/10: Culling + selling + breeding check
        processEconomyPhase()

        // Phase 11: Contract refresh/expiry
        checkContractRefresh()

        // Phase 13: Auto-save every 300 ticks (~30 seconds at 10 TPS)
        saveCounter += 1
        if saveCounter >= 300 {
            saveCounter = 0
            backgroundSave()
        }
    }

    // MARK: - Phase Helpers

    private func updateNeedsPhase(gameMinutes: Double) {
        guard let state else { return }
        let pigs = state.getPigsList()
        let nearbyCounts = NeedsSystem.precomputeNearbyCounts(
            pigs: pigs,
            radius: GameConfig.Needs.socialRadius
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
            HapticManager.pigSold()
        }
        breedingCheckCounter += 1
        let runExpensive = breedingCheckCounter >= breedingCheckInterval
        if runExpensive { breedingCheckCounter = 0 }
        let eventCountBefore = state.events.count
        _ = Breeding.checkBreedingOpportunities(gameState: state, runExpensive: runExpensive)
        // Fire haptics for every birth, regardless of whether the UI callback is registered.
        for event in state.events[eventCountBefore...] where event.eventType == "birth" {
            onBirth?(event.message)
            HapticManager.birth()
        }
    }

    // MARK: - Private Helpers

    /// Encode game state and write to disk. Guards against re-entrant saves.
    private func backgroundSave() {
        guard let state else { return }
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        guard let data = try? state.encodeToJSON() else { return }
        try? saveManager.saveData(data)
        state.lastSave = Date()
    }

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
