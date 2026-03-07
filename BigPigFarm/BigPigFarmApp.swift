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
    private let saveManager: SaveManager

    init() {
        let sm = SaveManager()
        let loaded = sm.load()
        let isNewGame = loaded == nil
        let state = loaded ?? GameState()
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView(gameState: gameState, engine: engine)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    @MainActor
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            engine.resume()
        case .inactive:
            engine.pause()
        case .background:
            lifecycleSave()
        @unknown default:
            break
        }
    }

    @MainActor
    private func lifecycleSave() {
        // Save errors are logged but not surfaced to the user.
        // The OS gives very limited time in background — a synchronous write
        // is the safest approach to ensure completion before suspension.
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
}
