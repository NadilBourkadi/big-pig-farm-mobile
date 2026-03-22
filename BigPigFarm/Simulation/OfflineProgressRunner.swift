/// OfflineProgressRunner — Checkpoint-based fast-forward for offline progress.
///
/// Simulates elapsed offline time by advancing game state in 1 game-hour
/// checkpoints. Skips pathfinding, behavior AI, spatial grid, and collision —
/// the expensive per-tick operations that are irrelevant when the player is away.
///
/// See `docs/design-offline-progress.md` for the full design document.
import Foundation

enum OfflineProgressRunner {

    // MARK: - Public API

    /// Fast-forward game state by the given wall-clock seconds of offline time.
    ///
    /// Converts wall-clock seconds to game-hours at the offline speed multiplier,
    /// then runs checkpoint-based simulation. Returns a summary of events for
    /// the summary popup.
    @MainActor
    static func runCatchUp(
        state: GameState,
        wallClockSeconds: TimeInterval
    ) -> OfflineProgressSummary {
        let clampedSeconds = min(wallClockSeconds, GameConfig.Offline.maxDurationSeconds)
        let gameMinutesTotal = clampedSeconds * Double(GameConfig.Offline.speedMultiplier)
            / GameConfig.Time.realSecondsPerGameMinute
        let gameHoursTotal = gameMinutesTotal / 60.0
        let checkpointCount = Int(gameHoursTotal / GameConfig.Offline.checkpointGameHours)

        var summary = OfflineProgressSummary(
            wallClockElapsed: clampedSeconds,
            gameHoursElapsed: gameHoursTotal
        )

        guard checkpointCount > 0 else { return summary }

        let moneyBefore = state.money
        let emptyBefore = state.getFacilitiesList().filter(\.isEmpty).count

        for _ in 0..<checkpointCount {
            runCheckpoint(state: state, summary: &summary)
        }

        repositionPigs(state: state)
        resetBehaviorStates(state: state)

        summary.totalMoneyEarned = max(0, state.money - moneyBefore)
        let emptyAfter = state.getFacilitiesList().filter(\.isEmpty).count
        summary.facilitiesEmptied = max(0, emptyAfter - emptyBefore)

        return summary
    }

    // MARK: - Checkpoint

    @MainActor
    private static func runCheckpoint(
        state: GameState,
        summary: inout OfflineProgressSummary
    ) {
        let hours: Double = GameConfig.Offline.checkpointGameHours

        // 1. Advance game time
        state.gameTime.advance(minutes: hours * 60.0)
        #if DEBUG || INTERNAL
        DebugLogger.shared.setGameDay(state.gameTime.day)
        #endif

        // 2-3. Decay needs + equilibrate
        decayAndEquilibrateNeeds(state: state, hours: hours)

        // 4. Auto-resource replenishment — runs after needs so replenished
        //    stock is available from the next checkpoint, matching live-tick order.
        //    tickAoEFacilities is intentionally skipped — stage AoE bonuses require
        //    an active .playing pig, which is absent during offline catch-up.
        AutoResources.tickAutoResources(state: state, gameHours: hours)
        AutoResources.tickVeggieGardens(state: state, gameHours: hours)

        // 5. Advance pregnancies + check births
        Birth.advancePregnancies(gameState: state, gameHours: hours)
        let pigIdsBefore = Set(state.guineaPigs.keys)
        let pigdexCountBefore = state.pigdex.discoveredCount
        _ = Birth.checkBirths(gameState: state)
        collectBirths(
            state: state,
            previousIds: pigIdsBefore,
            previousPigdexCount: pigdexCountBefore,
            summary: &summary
        )

        // 6. Age pigs + death rolls
        let deaths = Birth.ageAllPigs(gameState: state, gameHours: hours)
        for pig in deaths {
            summary.pigsDied.append(.init(name: pig.name, ageDays: Int(pig.ageDays)))
        }

        // 7. Acclimation
        advanceAcclimation(state: state, hours: hours)

        // 8. Offline breeding
        runOfflineBreeding(state: state, summary: &summary)

        // 9. Culling + selling
        Culling.cullSurplusBreeders(gameState: state)
        let soldRecords = Culling.sellMarkedAdults(gameState: state)
        for record in soldRecords {
            summary.pigsSold.append(.init(name: record.pigName, value: record.totalValue))
        }

        // 10. Contract refresh
        advanceContracts(state: state)
    }

    // MARK: - Contracts

    @MainActor
    private static func advanceContracts(state: GameState) {
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

    // MARK: - Post-Checkpoint

    @MainActor
    private static func repositionPigs(state: GameState) {
        for var pig in state.getPigsList() {
            if let areaId = pig.currentAreaId,
               let pos = state.farm.findRandomWalkableInArea(areaId) {
                pig.position = Position(x: Double(pos.x), y: Double(pos.y))
            } else if let pos = state.farm.findRandomWalkable() {
                pig.position = Position(x: Double(pos.x), y: Double(pos.y))
            }
            state.updateGuineaPig(pig)
        }
    }

    @MainActor
    private static func resetBehaviorStates(state: GameState) {
        for var pig in state.getPigsList() {
            pig.behaviorState = .idle
            pig.path = []
            pig.targetPosition = nil
            pig.targetFacilityId = nil
            pig.targetDescription = nil
            pig.courtingPartnerId = nil
            pig.courtingInitiator = false
            pig.courtingTimer = 0.0
            state.updateGuineaPig(pig)
        }
    }

    // MARK: - Event Collection

    @MainActor
    private static func collectBirths(
        state: GameState,
        previousIds: Set<UUID>,
        previousPigdexCount: Int,
        summary: inout OfflineProgressSummary
    ) {
        let currentIds = Set(state.guineaPigs.keys)
        let newIds = currentIds.subtracting(previousIds)
        for id in newIds {
            guard let pig = state.getGuineaPig(id) else { continue }
            summary.pigsBorn.append(.init(
                name: pig.name,
                phenotype: pig.phenotype.displayName
            ))
        }
        let newDiscoveries = state.pigdex.discoveredCount - previousPigdexCount
        if newDiscoveries > 0 {
            let recentEvents = state.events.suffix(newDiscoveries * 4)
            for event in recentEvents where event.eventType == "pigdex" {
                summary.pigdexDiscoveries.append(event.message)
            }
        }
    }
}
