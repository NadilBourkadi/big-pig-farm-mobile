/// BigPigFarmApp — Main app entry point.
/// Bootstraps game objects and passes them to ContentView.
/// Maps from: app.py, main_game.py
import SwiftUI

@main
struct BigPigFarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var gameState: GameState
    @State private var engine: GameEngine
    // SimulationRunner must be retained here; the engine tick callback holds a weak ref.
    @State private var runner: SimulationRunner
    @State private var notificationManager: NotificationManager
    @State private var offlineSummary: OfflineProgressSummary?
    /// Guards against false catch-ups from inactive→active without a background transition
    /// (e.g. notification center pull-down, phone call popup).
    /// Initialised to `true` when loading an existing save so that a cold start
    /// (app terminated by iOS or force-quit) triggers catch-up on the first `.active`.
    @State private var didEnterBackground: Bool
    private let saveManager: SaveManager
    #if DEBUG || INTERNAL
    @State private var debugServer: DebugServer?
    #endif

    init() {
        let sm = SaveManager()
        let loaded = sm.load()
        let isNewGame = loaded == nil
        let state = loaded ?? GameState()
        // Load prestige state from its own save file (survives farm resets)
        state.prestigeState = sm.loadPrestigeState() ?? PrestigeState()
        // Defensive fallback: saves from before this fix may have nil lastSave.
        // Use sessionStart as a conservative approximation.
        if !isNewGame && state.lastSave == nil {
            state.lastSave = state.sessionStart
        }

        let (sim, eng) = Self.buildSimulationAndEngine(state: state, saveManager: sm)
        if isNewGame {
            setupNewGame(state: state)
        }
        let notifications = NotificationManager()
        state.notificationManager = notifications

        saveManager = sm
        _notificationManager = State(initialValue: notifications)
        _gameState = State(initialValue: state)
        _engine = State(initialValue: eng)
        _runner = State(initialValue: sim)
        // Cold start with existing save: treat as "returning from background"
        // so the first .active transition triggers offline catch-up.
        _didEnterBackground = State(initialValue: !isNewGame)

        #if DEBUG || INTERNAL
        DebugLogger.shared.open()
        DebugLogger.shared.initializeiCloudContainer()
        let server = DebugServer(logger: DebugLogger.shared)
        server.start()
        _debugServer = State(initialValue: server)
        #endif
    }

    /// Build and wire the SimulationRunner and GameEngine from a loaded state.
    @MainActor
    private static func buildSimulationAndEngine(
        state: GameState,
        saveManager: SaveManager
    ) -> (SimulationRunner, GameEngine) {
        let behaviorController = BehaviorController(gameState: state)
        let sim = SimulationRunner(
            state: state,
            behaviorController: behaviorController,
            saveManager: saveManager
        )
        sim.onPigSold = { _, _, contractBonus, _ in
            HapticManager.pigSold()
            if contractBonus > 0 {
                HapticManager.contractCompleted()
            }
        }
        sim.onBirth = { _ in
            HapticManager.birth()
        }
        sim.onPigdexDiscovery = {
            HapticManager.pigdexDiscovery()
        }
        let eng = GameEngine(state: state)
        eng.registerTickCallback { [weak sim] minutes in
            sim?.tick(gameMinutes: minutes)
        }
        eng.onPrestigeReset = { [saveManager] in
            try? saveManager.savePrestigeState(state.prestigeState)
        }
        return (sim, eng)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameState: gameState,
                engine: engine,
                notificationManager: notificationManager,
                offlineSummary: $offlineSummary,
                onResetFarm: { performFullReset() }
            )
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    @MainActor
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Only check for offline progress if we actually went to background.
            // Prevents false catch-ups from notification center or phone call popups
            // (inactive → active without a background transition).
            guard didEnterBackground else {
                #if DEBUG || INTERNAL
                DebugLogger.shared.log(
                    category: .offline, level: .info,
                    message: "Foreground: skipped catch-up (no background transition, "
                        + "oldPhase=\(oldPhase.debugLabel))"
                )
                #endif
                engine.resume()
                return
            }
            didEnterBackground = false

            // Visit detection runs independently of offline catch-up.
            // A 1-hour absence qualifies as a visit even if the offline
            // catch-up threshold (shorter) is not met.
            VisitManager.processVisit(state: gameState)

            let duration = computeOfflineDuration()
            #if DEBUG || INTERNAL
            DebugLogger.shared.log(
                category: .offline, level: .info,
                message: "Foreground: lastSave=\(gameState.lastSave.map { "\($0)" } ?? "nil"), "
                    + "duration=\(String(format: "%.1f", duration))s, "
                    + "threshold=\(GameConfig.Offline.minThresholdSeconds)s, "
                    + "triggered=\(duration >= GameConfig.Offline.minThresholdSeconds)",
                payload: [
                    "durationSeconds": String(format: "%.1f", duration),
                    "lastSave": gameState.lastSave.map { "\($0)" } ?? "nil",
                    "pigCount": String(gameState.pigCount),
                ]
            )
            #endif
            if duration >= GameConfig.Offline.minThresholdSeconds {
                runOfflineCatchUp(wallClockSeconds: duration)
            } else {
                engine.resume()
            }
        case .inactive:
            engine.pause()
        case .background:
            didEnterBackground = true
            gameState.lastBackgroundDate = Date()
            lifecycleSave()
            #if DEBUG || INTERNAL
            DebugLogger.shared.log(
                category: .offline, level: .info,
                message: "Background: saved, lastSave=\(gameState.lastSave.map { "\($0)" } ?? "nil"), "
                    + "pigCount=\(gameState.pigCount)"
            )
            DebugLogger.shared.flushBlocking()
            DebugLogger.shared.syncToiCloud()
            #endif
        @unknown default:
            break
        }
    }

    // MARK: - Offline Progress

    @MainActor
    private func computeOfflineDuration() -> TimeInterval {
        guard let lastSave = gameState.lastSave else { return 0 }
        return max(0, Date().timeIntervalSince(lastSave))
    }

    @MainActor
    private func runOfflineCatchUp(wallClockSeconds: TimeInterval) {
        notificationManager.isSuppressed = true
        notificationManager.dismissAll()
        let summary = OfflineProgressRunner.runCatchUp(
            state: gameState,
            wallClockSeconds: wallClockSeconds
        )
        // Resolve pig overlaps from random repositioning before the first tick.
        runner.rebuildAndSeparateAfterOffline()
        // Clear stale behavior tracking (pathfinding caches, unreachable-need
        // backoffs, failed facilities) and stagger decision timers to prevent
        // thundering-herd facility seeking.
        runner.resetAfterOffline()
        // Advance lastSave unconditionally so a failed disk write doesn't cause
        // the next foreground transition to re-simulate the same time window.
        // Note: save() also sets lastSave — the pre-set here is the safety net
        // for when the disk write inside save() fails.
        gameState.lastSave = Date()
        do {
            try saveManager.save(gameState)
        } catch {
            print("[BigPigFarmApp] post-catchup save failed: \(error)")
        }
        notificationManager.isSuppressed = false

        if summary.hasMeaningfulEvents {
            offlineSummary = summary
            // Engine stays paused — resumes when user taps "Continue"
        } else {
            #if DEBUG || INTERNAL
            DebugLogger.shared.log(
                category: .offline, level: .info,
                message: "No meaningful events — resuming engine without popup"
            )
            #endif
            engine.resume()
        }
    }

    // MARK: - Full Reset

    @MainActor
    private func performFullReset() {
        engine.pause()
        saveManager.deleteAllSaves()
        gameState.resetToNewGame()
        setupNewGame(state: gameState)
        runner.rebuildAndSeparateAfterOffline()
        runner.resetAfterOffline()
        notificationManager.isSuppressed = false
        notificationManager.dismissAll()
        engine.resume()
    }

    // MARK: - Persistence

    @MainActor
    private func lifecycleSave() {
        do {
            try saveManager.save(gameState)
            try saveManager.savePrestigeState(gameState.prestigeState)
        } catch {
            print("[BigPigFarmApp] lifecycleSave failed: \(error)")
        }
    }
}

// setupNewGame lives in Engine/NewGameSetup.swift (platform-agnostic, accessible from BigPigFarmCore)

// MARK: - ScenePhase Debug Label

extension ScenePhase {
    var debugLabel: String {
        switch self {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}
