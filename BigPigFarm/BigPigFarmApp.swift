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
    @State private var offlineSummary: OfflineProgressSummary?
    /// Guards against false catch-ups from inactive→active without a background transition
    /// (e.g. notification center pull-down, phone call popup).
    /// Initialised to `true` when loading an existing save so that a cold start
    /// (app terminated by iOS or force-quit) triggers catch-up on the first `.active`.
    @State private var didEnterBackground: Bool
    private let saveManager: SaveManager

    init() {
        let sm = SaveManager()
        let loaded = sm.load()
        let isNewGame = loaded == nil
        let state = loaded ?? GameState()
        // Defensive fallback: saves from before this fix may have nil lastSave.
        // Use sessionStart as a conservative approximation.
        if !isNewGame && state.lastSave == nil {
            state.lastSave = state.sessionStart
        }
        let behaviorController = BehaviorController(gameState: state)
        let sim = SimulationRunner(state: state, behaviorController: behaviorController, saveManager: sm)
        let eng = GameEngine(state: state)
        eng.registerTickCallback { [weak sim] minutes in
            sim?.tick(gameMinutes: minutes)
        }
        if isNewGame {
            setupNewGame(state: state)
        }
        saveManager = sm
        _gameState = State(initialValue: state)
        _engine = State(initialValue: eng)
        _runner = State(initialValue: sim)
        // Cold start with existing save: treat as "returning from background"
        // so the first .active transition triggers offline catch-up.
        _didEnterBackground = State(initialValue: !isNewGame)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                gameState: gameState,
                engine: engine,
                offlineSummary: $offlineSummary
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
                engine.resume()
                return
            }
            didEnterBackground = false
            let duration = computeOfflineDuration()
            if duration >= GameConfig.Offline.minThresholdSeconds {
                runOfflineCatchUp(wallClockSeconds: duration)
            } else {
                engine.resume()
            }
        case .inactive:
            engine.pause()
        case .background:
            didEnterBackground = true
            lifecycleSave()
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
        let summary = OfflineProgressRunner.runCatchUp(
            state: gameState,
            wallClockSeconds: wallClockSeconds
        )
        // Clear stale behavior tracking (pathfinding caches, unreachable-need
        // backoffs, failed facilities) — pigs have been repositioned.
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
        if summary.hasMeaningfulEvents {
            offlineSummary = summary
            // Engine stays paused — resumes when user taps "Continue"
        } else {
            engine.resume()
        }
    }

    // MARK: - Persistence

    @MainActor
    private func lifecycleSave() {
        do {
            try saveManager.save(gameState)
        } catch {
            print("[BigPigFarmApp] lifecycleSave failed: \(error)")
        }
    }
}

/// Place two starter pigs and basic facilities in a fresh game state.
///
/// Maps from: app.py initial setup and new_game.py (Python source).
/// Called once when a new game is started — not on load.
@MainActor
func setupNewGame(state: GameState) {
    var existingNames: Set<String> = []

    for gender in [Gender.male, Gender.female] {
        let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
        let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)
        existingNames.insert(name)

        let pos: Position
        if let walkable = state.farm.findRandomWalkable() {
            pos = Position(x: Double(walkable.x), y: Double(walkable.y))
        } else {
            pos = Position(x: 5.0, y: 5.0)
        }

        var pig = GuineaPig.create(name: name, gender: gender)
        pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)  // Start as young adults, not babies
        pig.position = pos
        state.addGuineaPig(pig)
    }

    let food = Facility.create(type: .foodBowl, x: 5, y: 3)
    let water = Facility.create(type: .waterBottle, x: 10, y: 3)
    let hideout = Facility.create(type: .hideout, x: 14, y: 3)
    _ = state.addFacility(food)
    _ = state.addFacility(water)
    _ = state.addFacility(hideout)

    state.logEvent("Welcome to Big Pig Farm!", eventType: "info")
    state.lastSave = Date()
}
