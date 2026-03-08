/// GameEngineTests -- Unit tests for the GameEngine tick loop.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Lifecycle

@Test @MainActor func engineInitDoesNotStartTimer() {
    let engine = GameEngine(state: GameState())
    #expect(!engine.isRunning)
}

@Test @MainActor func engineStartSetsRunning() {
    let engine = GameEngine(state: GameState())
    engine.start()
    #expect(engine.isRunning)
    engine.stop()
}

@Test @MainActor func engineStartIdempotent() {
    let engine = GameEngine(state: GameState())
    engine.start()
    engine.start()
    #expect(engine.isRunning)
    engine.stop()
}

@Test @MainActor func engineStopClearsRunning() {
    let engine = GameEngine(state: GameState())
    engine.start()
    engine.stop()
    #expect(!engine.isRunning)
}

@Test @MainActor func engineStopIdempotent() {
    let engine = GameEngine(state: GameState())
    engine.stop()
    #expect(!engine.isRunning)
}

// MARK: - Pause / Resume

@Test @MainActor func pauseSetsFlag() {
    let state = GameState()
    let engine = GameEngine(state: state)
    engine.pause()
    #expect(state.isPaused)
}

@Test @MainActor func resumeClearsFlag() {
    let state = GameState()
    let engine = GameEngine(state: state)
    engine.pause()
    engine.resume()
    #expect(!state.isPaused)
}

@Test @MainActor func togglePauseFlips() {
    let state = GameState()
    let engine = GameEngine(state: state)
    let firstToggle = engine.togglePause()
    #expect(firstToggle == true)
    #expect(state.isPaused)
    let secondToggle = engine.togglePause()
    #expect(secondToggle == false)
    #expect(!state.isPaused)
}

// MARK: - Speed

@Test @MainActor func setSpeedUpdatesState() {
    let state = GameState()
    let engine = GameEngine(state: state)
    engine.setSpeed(.fast)
    #expect(state.speed == .fast)
}

@Test @MainActor func defaultSpeedIsNormal() {
    let state = GameState()
    #expect(state.speed == .normal)
}

@Test @MainActor func cycleSpeedProgression() {
    let state = GameState()
    let engine = GameEngine(state: state)
    #expect(state.speed == .normal)

    let speed1 = engine.cycleSpeed()
    #expect(speed1 == .fast)

    let speed2 = engine.cycleSpeed()
    #expect(speed2 == .faster)

    let speed3 = engine.cycleSpeed()
    #expect(speed3 == .fastest)

    let speed4 = engine.cycleSpeed()
    #expect(speed4 == .normal)
}

@Test @MainActor func cycleSpeedWithDebug() {
    let state = GameState()
    let engine = GameEngine(state: state)
    state.speed = .fastest

    let speed1 = engine.cycleSpeed(debug: true)
    #expect(speed1 == .debug)

    let speed2 = engine.cycleSpeed(debug: true)
    #expect(speed2 == .debugFast)

    let speed3 = engine.cycleSpeed(debug: true)
    #expect(speed3 == .normal)
}

@Test @MainActor func cycleSpeedSkipsPaused() {
    let state = GameState()
    let engine = GameEngine(state: state)
    state.speed = .paused
    let result = engine.cycleSpeed()
    #expect(result == .paused)
    #expect(state.speed == .paused)
}

@Test @MainActor func cycleSpeedNoOpWhilePaused() {
    let state = GameState()
    let engine = GameEngine(state: state)
    state.speed = .fast
    state.isPaused = true
    let result = engine.cycleSpeed()
    #expect(result == .fast)
    #expect(state.speed == .fast)
}

// MARK: - Speed Raw Values

@Test @MainActor func speedMultiplierValues() {
    #expect(GameSpeed.paused.rawValue == 0)
    #expect(GameSpeed.normal.rawValue == 3)
    #expect(GameSpeed.fast.rawValue == 6)
    #expect(GameSpeed.faster.rawValue == 15)
    #expect(GameSpeed.fastest.rawValue == 60)
    #expect(GameSpeed.debug.rawValue == 300)
    #expect(GameSpeed.debugFast.rawValue == 900)
}

@Test @MainActor func speedDisplayLabels() {
    #expect(GameSpeed.paused.displayLabel == "0x")
    #expect(GameSpeed.normal.displayLabel == "1x")
    #expect(GameSpeed.fast.displayLabel == "2x")
    #expect(GameSpeed.faster.displayLabel == "5x")
    #expect(GameSpeed.fastest.displayLabel == "20x")
    #expect(GameSpeed.debug.displayLabel == "100x")
    #expect(GameSpeed.debugFast.displayLabel == "300x")
}

// MARK: - Tick Callback Registration

@Test @MainActor func tickCallbackInvoked() {
    let state = GameState()
    let engine = GameEngine(state: state)
    var receivedMinutes: Double?
    engine.registerTickCallback { minutes in
        receivedMinutes = minutes
    }
    engine.tick(1.0)
    #expect(receivedMinutes != nil)
}

@Test @MainActor func multipleCallbacksInvoked() {
    let state = GameState()
    let engine = GameEngine(state: state)
    var count = 0
    engine.registerTickCallback { _ in count += 1 }
    engine.registerTickCallback { _ in count += 1 }
    engine.tick(1.0)
    #expect(count == 2)
}

// MARK: - Tick Logic

@Test @MainActor func tickAdvancesGameTime() {
    let state = GameState()
    let engine = GameEngine(state: state)
    let initialMinutes = state.gameTime.totalGameMinutes

    // 1 real second of scaled delta converted to game minutes via realSecondsPerGameMinute
    engine.tick(1.0)

    let elapsed = state.gameTime.totalGameMinutes - initialMinutes
    let expected = 1.0 / GameConfig.Time.realSecondsPerGameMinute
    #expect(abs(elapsed - expected) < 0.001)
}

@Test @MainActor func tickPassesGameMinutesToCallbacks() {
    let state = GameState()
    let engine = GameEngine(state: state)
    var receivedMinutes: Double?
    engine.registerTickCallback { minutes in
        receivedMinutes = minutes
    }

    // 3.0 delta seconds converted to game minutes via realSecondsPerGameMinute
    engine.tick(3.0)

    let expected = 3.0 / GameConfig.Time.realSecondsPerGameMinute
    #expect(abs((receivedMinutes ?? 0) - expected) < 0.001)
}

@Test @MainActor func tickWithSmallDelta() {
    let state = GameState()
    let engine = GameEngine(state: state)
    let initialMinutes = state.gameTime.totalGameMinutes

    // Typical tick: 100ms * speed 3 = 0.3 delta seconds
    engine.tick(0.3)

    let elapsed = state.gameTime.totalGameMinutes - initialMinutes
    let expected = 0.3 / GameConfig.Time.realSecondsPerGameMinute
    #expect(abs(elapsed - expected) < 0.001)
}

@Test @MainActor func tickAdvancesDayCounterAtNormalSpeed() {
    // Regression guard: starting from midnight, exactly one full 24-hour cycle
    // (1440 game-minutes) must produce a day increment at normal speed.
    // The tick loop fires at 10 TPS; each tick passes delta = 0.1s * speed.rawValue.
    // ticks per day = 1440 / (scaledDelta / realSecondsPerGameMinute)
    let state = GameState()
    state.gameTime.hour = 0
    state.gameTime.minute = 0
    let engine = GameEngine(state: state)
    let scaledDeltaPerTick = 0.1 * Double(GameSpeed.normal.rawValue)
    let gameMinutesPerTick = scaledDeltaPerTick / GameConfig.Time.realSecondsPerGameMinute
    let minutesPerDay = Double(GameConfig.Time.gameMinutesPerHour * GameConfig.Time.gameHoursPerDay)
    let ticksPerDay = Int(ceil(minutesPerDay / gameMinutesPerTick))

    let initialDay = state.gameTime.day
    for _ in 0..<ticksPerDay {
        engine.tick(scaledDeltaPerTick)
    }
    #expect(state.gameTime.day > initialDay)
}

// MARK: - GameTime Advancement

@Test @MainActor func gameTimeAdvanceMinutes() {
    var time = GameTime()
    time.hour = 8
    time.minute = 0
    time.advance(minutes: 30)
    #expect(time.hour == 8)
    #expect(time.minute == 30)
}

@Test @MainActor func gameTimeAdvanceRollsOverHour() {
    var time = GameTime()
    time.hour = 8
    time.minute = 0
    time.advance(minutes: 90)
    #expect(time.hour == 9)
    #expect(time.minute == 30)
}

@Test @MainActor func gameTimeAdvanceRollsOverDay() {
    var time = GameTime()
    time.day = 1
    time.hour = 23
    time.minute = 0
    time.advance(minutes: 120)
    #expect(time.day == 2)
    #expect(time.hour == 1)
    #expect(time.minute == 0)
}

@Test @MainActor func gameTimeTracksTotalMinutes() {
    var time = GameTime()
    time.advance(minutes: 100)
    time.advance(minutes: 50)
    #expect(time.totalGameMinutes == 150)
}
