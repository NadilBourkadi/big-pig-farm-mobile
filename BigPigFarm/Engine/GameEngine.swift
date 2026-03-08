/// GameEngine — Timer-based tick loop driving the simulation.
/// Maps from: game/game_engine.py
import Foundation
import QuartzCore

/// Drives the game simulation at a configurable tick rate.
///
/// The engine fires a `Timer` at 10 TPS (100ms). Each tick computes a
/// speed-scaled delta, advances `GameTime`, and invokes registered callbacks.
/// Uses `.common` RunLoop mode so ticks continue during UI scrolling.
@MainActor
final class GameEngine {
    let state: GameState
    private var timer: Timer?
    private var tickCallbacks: [(Double) -> Void] = []
    private var lastTickTime: CFTimeInterval = 0

    init(state: GameState) {
        self.state = state
    }

    // MARK: - Tick Callback Registration

    /// Register a callback invoked each tick with the elapsed game-minutes.
    func registerTickCallback(_ callback: @escaping (Double) -> Void) {
        tickCallbacks.append(callback)
    }

    // MARK: - Lifecycle

    /// Start the tick loop. Idempotent — calling twice has no effect.
    func start() {
        guard timer == nil else { return }
        lastTickTime = CACurrentMediaTime()
        let interval = 1.0 / Double(GameConfig.Simulation.ticksPerSecond)
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.timerFired()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// Stop the tick loop. Idempotent — calling when stopped has no effect.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() { state.isPaused = true }
    func resume() { state.isPaused = false }

    /// Toggle pause state. Returns the new value of `isPaused`.
    func togglePause() -> Bool {
        state.isPaused.toggle()
        return state.isPaused
    }

    func setSpeed(_ speed: GameSpeed) {
        state.speed = speed
    }

    /// Cycle through speed settings. Returns the new speed.
    /// When currently paused, cycling does nothing — use `resume()` first.
    func cycleSpeed(debug: Bool = false) -> GameSpeed {
        guard !state.isPaused, state.speed != .paused else { return state.speed }
        var speeds: [GameSpeed] = [.normal, .fast, .faster, .fastest]
        if debug { speeds.append(contentsOf: [.debug, .debugFast]) }
        let currentIndex = speeds.firstIndex(of: state.speed) ?? 0
        let newIndex = (currentIndex + 1) % speeds.count
        state.speed = speeds[newIndex]
        return state.speed
    }

    // MARK: - Properties

    var isRunning: Bool { timer != nil }

    // MARK: - Tick Processing

    private func timerFired() {
        let now = CACurrentMediaTime()
        var deltaTime = now - lastTickTime
        lastTickTime = now

        // Clamp delta to prevent huge jumps after app sleep/wake
        deltaTime = min(deltaTime, 0.5)

        guard !state.isPaused, state.speed != .paused else { return }

        let gameDelta = deltaTime * Double(state.speed.rawValue)
        tick(gameDelta)
    }

    /// Process one tick with the given speed-scaled delta (in real seconds).
    /// Internal visibility for testing — not part of the public API.
    func tick(_ deltaSeconds: Double) {
        let gameMinutes = deltaSeconds / GameConfig.Time.realSecondsPerGameMinute

        state.gameTime.advance(minutes: gameMinutes)

        for callback in tickCallbacks {
            callback(gameMinutes)
        }
    }
}
