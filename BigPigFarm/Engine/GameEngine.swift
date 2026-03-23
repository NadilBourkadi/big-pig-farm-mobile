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

    /// Called at the end of farmReset() so the UI layer can persist prestige state
    /// immediately. Without this, a crash between reset and the next lifecycleSave
    /// would silently lose the carried-over Pigdex and lifetime stats.
    var onPrestigeReset: (() -> Void)?

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

    // MARK: - Prestige: Farm Reset

    /// Reset the farm for a New Pastures prestige. Preserves PrestigeState, clears everything else,
    /// and applies any purchased Showroom starting bonuses.
    ///
    /// @MainActor isolation guarantees the timer callback cannot fire mid-reset.
    /// Do not introduce async suspension points inside this method.
    func farmReset() {
        // 1. Carry over current Pigdex entries into prestige state
        state.prestigeState.carryOverPigdex(state.pigdex)

        // 2. Accumulate lifetime stats
        state.prestigeState.lifetimeStats.totalPigsBred += state.totalPigsBorn
        state.prestigeState.lifetimeStats.totalSqueaksEarned += state.totalEarnings
        state.prestigeState.lifetimeStats.totalPigsSold += state.totalPigsSold

        // 3. Increment farm count
        state.prestigeState.farmCount += 1

        // 4. Clear all per-farm state
        state.guineaPigs = [:]
        state.facilities = [:]
        state.money = GameConfig.Economy.startingMoney
        state.gameTime = GameTime()
        state.speed = .normal
        state.isPaused = false
        state.sessionStart = Date()
        state.lastSave = nil
        state.events = []
        state.pigdex = Pigdex()
        state.contractBoard = ContractBoard()
        state.breedingProgram = BreedingProgram()
        state.breedingPair = nil
        state.socialAffinity = [:]
        state.farmTier = 1
        state.purchasedUpgrades = []
        state.totalPigsBorn = 0
        state.totalPigsSold = 0
        state.totalEarnings = 0
        state.simulationTick = 0

        // 5. Apply Showroom starting bonuses (modifies farmTier, farm)
        applyShowroomBonuses()

        // 6. Set up starter pigs and facilities
        setupNewGame(state: state)

        // 7. If Heritage Herd: add bonus pigs
        if state.prestigeState.hasUpgrade(.heritageHerd) {
            spawnHeritageHerdPigs()
        }

        // 8. Auto-Pilot: grant Bulk Feeders + Drip System on reset
        if state.prestigeState.hasUpgrade(.autoPilot) {
            applyAutoPilotPerks()
        }

        // 9. Keepsake Slot: restore carried-over perks
        if state.prestigeState.hasUpgrade(.keepsakeSlot) {
            applyKeepsakePerks()
        }

        state.logEvent(
            "Welcome to Farm #\(state.prestigeState.farmCount) — New Pastures!",
            eventType: "prestige"
        )

        // Persist prestige state immediately to prevent data loss on crash
        onPrestigeReset?()
    }

    /// Apply Showroom starting bonuses that affect farm setup.
    private func applyShowroomBonuses() {
        let upgrades = state.prestigeState.purchasedUpgrades

        // Grand Farm supersedes Established Farm
        if upgrades.contains(.grandFarm) {
            state.farmTier = 3
            state.farm = FarmGrid.createStarter(tier: 3)
            addBonusRooms(count: 2)
        } else if upgrades.contains(.establishedFarm) {
            state.farmTier = 2
            state.farm = FarmGrid.createStarter(tier: 2)
            addBonusRooms(count: 1)
        } else {
            state.farm = FarmGrid.createStarter()
        }
    }

    /// Add bonus rooms with random biomes (excluding meadow, which is the starter).
    private func addBonusRooms(count: Int) {
        let nonMeadowBiomes = BiomeType.allCases.filter { $0 != .meadow }
        for _ in 0..<count {
            guard let biome = nonMeadowBiomes.randomElement() else { continue }
            let result = GridExpansion.addRoom(&state.farm, biome: biome)
            assert(result != nil, "farmReset: bonus room creation failed unexpectedly")
        }
    }

    /// Grant Bulk Feeders and Drip System perks from Auto-Pilot.
    /// Called after setupNewGame so facilities exist for bulk_feeders to double.
    /// Note: bulk_feeders has an immediate effect (doubles facility capacity);
    /// drip_system has no immediate effect (its regen activates each tick via hasUpgrade).
    private func applyAutoPilotPerks() {
        let autoPilotPerks = ["bulk_feeders", "drip_system"]
        for perkId in autoPilotPerks where !state.purchasedUpgrades.contains(perkId) {
            state.purchasedUpgrades.insert(perkId)
            Upgrades.applyImmediateEffect(state: state, upgradeId: perkId)
        }
    }

    /// Restore perks stored in the Keepsake Slot across farm resets.
    private func applyKeepsakePerks() {
        for perkId in state.prestigeState.keepsakePerks where !state.purchasedUpgrades.contains(perkId) {
            state.purchasedUpgrades.insert(perkId)
            Upgrades.applyImmediateEffect(state: state, upgradeId: perkId)
        }
    }

    /// Spawn Heritage Herd bonus pigs: 3 extra pigs (2 uncommon+, 1 with bloodline allele).
    /// The base 2 pigs from setupNewGame are already present.
    private func spawnHeritageHerdPigs() {
        var existingNames = Set(state.getPigsList().map(\.name))

        // 2 uncommon+ pigs
        for _ in 0..<2 {
            let genotype = generateUncommonGenotype()
            let gender: Gender = Bool.random() ? .male : .female
            let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
            let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)
            existingNames.insert(name)
            var pig = GuineaPig.create(name: name, gender: gender, genotype: genotype)
            pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
            if let walkable = state.farm.findRandomWalkable() {
                pig.position = Position(x: Double(walkable.x), y: Double(walkable.y))
            }
            state.addGuineaPig(pig)
        }

        // 1 bloodline pig
        let availableBloodlines = getAvailableBloodlines(farmTier: state.farmTier)
        if let bloodline = availableBloodlines.randomElement() {
            let baseGenotype = Genotype.random()
            let genotype = bloodline.applyToGenotype(baseGenotype)
            let gender: Gender = Bool.random() ? .male : .female
            let prefixGender: PigNames.PrefixGender = gender == .male ? .male : .female
            let name = PigNames.generateUniqueName(existingNames: existingNames, gender: prefixGender)
            existingNames.insert(name)
            var pig = GuineaPig.create(name: name, gender: gender, genotype: genotype)
            pig.ageDays = Double(GameConfig.Simulation.adultAgeDays)
            if let walkable = state.farm.findRandomWalkable() {
                pig.position = Position(x: Double(walkable.x), y: Double(walkable.y))
            }
            state.addGuineaPig(pig)
        }
    }

    /// Generate a genotype that produces at least an uncommon phenotype.
    /// Common phenotypes are ~60-70% of random genotypes, so 100 attempts
    /// gives negligible miss probability; the fallback is a safety net.
    private func generateUncommonGenotype() -> Genotype {
        for _ in 0..<100 {
            let genotype = Genotype.random()
            let phenotype = calculatePhenotype(genotype)
            if phenotype.rarity != .common {
                return genotype
            }
        }
        // Fallback: force a non-common genotype by using chocolate (bb)
        return Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "b", second: "b"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "R", second: "R"),
            dLocus: AllelePair(first: "D", second: "D")
        )
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
