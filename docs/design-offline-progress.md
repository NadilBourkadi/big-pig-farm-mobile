# Design: Offline Progress

> Catch-up simulation that advances game state when the player returns after backgrounding or closing the app.

---

## 1. Problem

When the player backgrounds the app, the engine pauses and saves. On return, it resumes from exactly where it left off — no game time passes while away. Players expect idle/farming games to progress while closed.

The core challenge: the real-time simulation runs 13 ordered phases per tick at 10 TPS. Naively replaying all ticks for an hour of offline time at normal speed (3x) means 36,000 ticks × 50 pigs × behavior AI + pathfinding = millions of expensive operations. This must complete in under 3 seconds.

---

## 2. Time Model

### Conversion chain (existing)

```
timerFired():
  deltaTime = wall-clock seconds since last tick (~0.1s)
  gameDelta = deltaTime × speed.rawValue

tick(gameDelta):
  gameMinutes = gameDelta / realSecondsPerGameMinute (1.0)
```

| Speed | rawValue | 1 real hour = |
|-------|----------|---------------|
| normal | 3 | 180 game-min = 3 game-hours |
| fast | 6 | 6 game-hours |
| faster | 15 | 15 game-hours |
| fastest | 60 | 60 game-hours = 2.5 game-days |

### Offline speed

**Matches "1x" UI speed (rawValue 3).** The game progresses at the same rate offline as when the player watches at normal speed:

- **1 real second = 3 game-minutes**
- 1 real hour = 180 game-hours = **7.5 game-days**
- 8 hours overnight = **60 game-days**
- 24 hours = 4,320 game-hours = **180 game-days**

Rationale:
- Consistent with what the player sees at "1x" — offline feels like leaving the game running
- Player's speed setting at time of backgrounding is irrelevant — offline always uses the base "1x" rate

### Maximum offline duration

**Capped at 24 real hours (= 180 game-days).** Beyond 24 hours, no additional progression occurs. This prevents:
- Unbounded progression from week/month-long absences
- Excessive catch-up computation (though even 4,320 checkpoints is fast — see §4)

Note: 180 game-days is ~4× the max pig lifespan (45 days). Long absences will see full generational turnover — pigs born, grown, bred, and died. The summary popup (§5) must handle large event counts gracefully.

---

## 3. Architecture

### System classification

Every tick phase classified by offline strategy:

| Phase | System | Real-time cost | Offline strategy |
|-------|--------|----------------|------------------|
| 1/1b | Spatial grid + area populations | O(n) | **SKIP** — pigs don't move |
| 2 | Needs decay | O(n) per tick | **CHECKPOINT** — decay + equilibrate |
| 2a | Farm Bell | O(n) | **SKIP** — notification, no gameplay effect |
| 2b | AutoResources (drip/veggie/AoE) | O(facilities) | **SKIP** — facilities frozen offline |
| 3 | Behavior AI + pathfinding | **O(n × pathfind)** | **SKIP** — the expensive one |
| 3b | Courtship → pregnancy | Movement-dependent | **REPLACED** — instant breeding rolls |
| 4/4b | Separation + rescue | O(n²) | **SKIP** — collision irrelevant |
| 5 | Acclimation | O(n) per tick | **ANALYTICAL** — advance timers |
| 6 | Pregnancy advancement | O(pregnant) per tick | **ANALYTICAL** — advance by elapsed |
| 7 | Aging + death | O(n) per tick | **CHECKPOINT** — age + death rolls |
| 8 | Culling | O(n log n) | **CHECKPOINT** — run at intervals |
| 9 | Selling | O(marked) | **CHECKPOINT** — follows culling |
| 10 | Breeding check | O(n²) per 10 ticks | **CHECKPOINT** — run at intervals |
| 11 | Contracts | O(1) | **ANALYTICAL** — advance day counters |
| 13 | Auto-save | I/O | **SKIP** — save once at end |

### The core insight

**The two most expensive per-tick operations — behavior AI and pathfinding — are completely irrelevant offline.** Pigs don't need to visually walk anywhere. We only care about the *outcomes* of behavior (needs recovery, breeding) not the *process* (pathfinding to a food bowl, walking there, eating animation).

---

## 4. Hybrid Fast-Forward Design

### Checkpoint model

Divide elapsed offline time into **1 game-hour checkpoints**. At each checkpoint:

```
for each checkpoint (1 game-hour):
    1. Advance game time by 1 hour
    2. Decay needs (analytical — 1 hour of decay rates)
    3. Equilibrate needs (simplified behavior — see §4.1)
    4. Advance pregnancies by 1 hour, check births
    5. Age all pigs by 1 hour, roll death checks
    6. Advance acclimation timers by 1 hour
    7. Run breeding eligibility + roll chances
    8. Run culling/selling
    9. Advance contracts (check day boundary)
    10. Collect summary events

after all checkpoints:
    11. Randomize pig positions within their areas (see §4.5)
    12. Reset all behavior states to .idle
```

### Why 1 game-hour checkpoints?

- **Pregnancy gestation** is measured in days → hourly resolution is fine
- **Aging** is measured in days → hourly is fine
- **Need decay** rates are per-hour → aligns perfectly
- **Breeding checks** run every 10 ticks in real-time (1 second) → hourly is coarser but acceptable since we skip courtship walks (see §4.2)

### Performance budget

For maximum offline (24 real hours at 3x = 4,320 game-hours = **4,320 checkpoints**):

| Operation | Per checkpoint | Total (4,320) |
|-----------|---------------|---------------|
| Needs decay + equilibrate | 50 pigs × 6 needs = 300 | 1,296,000 |
| Pregnancy advance | O(pregnant) ≈ 5 | 21,600 |
| Aging + death rolls | 50 pigs | 216,000 |
| Breeding scan | O(males × females) ≈ 625 | 2,700,000 |
| Culling | O(n log n) ≈ 300 | 1,296,000 |
| Pig repositioning (final) | 50 pigs × 1 walkable lookup | 50 |
| **Total** | **~1,280** | **~5,530,000** |

**~5.5M simple arithmetic operations** (additions, comparisons, random rolls). On an A14 chip at ~3 GFLOPS single-thread, this completes in **well under 100ms**. No pathfinding, no spatial grid, no GKGridGraph — just math.

Common cases are much faster:

| Scenario | Real time | Checkpoints | Est. wall time |
|----------|-----------|-------------|----------------|
| Quick break (5 min) | 5 min | 15 | <1ms |
| Lunch (1 hour) | 1 hr | 180 | <5ms |
| Overnight (8 hours) | 8 hr | 1,440 | <30ms |
| Max cap (24 hours) | 24 hr | 4,320 | <100ms |

### 4.1 Needs equilibration (offline behavior substitute)

In real-time, behavior AI makes pigs seek food/water/sleep when needs drop. Offline, we simulate this with a priority-based recovery step at each checkpoint:

```swift
func equilibrateNeeds(pig: inout GuineaPig, state: GameState, hours: Double) {
    // After applying decay, check if pig "would have" sought a facility
    let priorities: [(need: WritableKeyPath<PigNeeds, Double>,
                      threshold: Double,
                      facilities: [FacilityType],
                      recovery: Double)] = [
        (\.thirst, lowThreshold, [.waterBottle], waterRecovery),
        (\.hunger, lowThreshold, [.foodBowl, .hayRack, .feastTable], foodRecovery),
        (\.energy, lowThreshold, [.hideout], sleepRecovery),
        (\.happiness, lowThreshold, [.playArea, .exerciseWheel], playRecovery),
    ]

    for (keyPath, threshold, facilityTypes, rate) in priorities {
        if pig.needs[keyPath: keyPath] < threshold {
            let hasRelevantFacility = facilityTypes.contains { type in
                !state.getFacilitiesByType(type).isEmpty
            }
            if hasRelevantFacility {
                pig.needs[keyPath: keyPath] += rate * hours
            }
        }
    }
    pig.needs.clampAll()
}
```

**Fidelity trade-off:** This assumes pigs always find a facility instantly (no walking time). In practice, real-time pigs spend some time walking, so offline needs will be slightly higher than real-time. This is acceptable — slightly higher needs is better than pigs starving because we didn't simulate eating at all.

**Facility depletion at 25% rate.** Food and water facilities are consumed during offline recovery at `consumptionRateMultiplier = 0.25` of the real-time recovery rate. This models pigs eating "sometimes" rather than continuously. When all facilities of a type are empty, recovery stops — needs decay freely from that point.

- Energy/happiness facilities (hideouts, play areas) don't deplete — they have no consumable resource in real-time either
- AutoResources (drip/auto-feed/veggie) are skipped offline — they're a perk for active play
- **Health mercy floor:** Health never drops below 10% (`healthMercyFloor`), even when facilities are empty. Pigs suffer but survive.

**Balance curve:** Short absences (1-8 hours) barely affect facilities. Overnight (8h) may partially drain them. Max absence (24h = 180 game-days) will empty most facilities, leaving pigs in poor shape but alive. The summary popup reports how many facilities ran dry.

### 4.2 Breeding (offline courtship substitute)

Real-time breeding requires:
1. Proximity check (pigs within breedingDistance) → **skipped** (assume any pair can meet)
2. Breeding chance roll → **kept** (same probabilities)
3. Courtship walk + timer → **skipped** (instant)
4. Pregnancy start → **kept**

The offline breeding step at each checkpoint:
1. Find all eligible males and females (same filters as `checkForNewBreeding`)
2. For each eligible pair, roll `attemptBreeding` with the same chance formula
3. If successful, start pregnancy immediately (skip courtship walk)
4. Limit to 1 new pregnancy per checkpoint (matches real-time throttling)

This is slightly more generous than real-time (no proximity requirement, no courtship walk delay) but prevents population explosions via the 1-per-checkpoint cap and the existing capacity checks.

### 4.3 Acclimation (offline biome handling)

Acclimation tracks how long a pig stays in a foreign biome. Offline, pigs don't move, so we can:
- Advance timers by the elapsed time for pigs currently in a foreign biome
- Pigs in their preferred biome: no change
- This means pigs that were mid-acclimation when the player left may complete acclimation offline

### 4.4 AoE facilities (stage)

Stage bonuses require a pig to be actively performing (`.playing` state targeting the stage). Offline, no pigs are performing, so **AoE stage bonuses are skipped**. This is correct — the stage requires active play to benefit.

### 4.5 Pig repositioning (post-catch-up)

After all checkpoints complete, pigs should not appear frozen in their pre-offline positions. As a final step:

1. **Surviving pigs:** Randomize position to a walkable cell within their current area. Use `FarmGrid.findRandomWalkable(in:)` (or equivalent) scoped to the pig's `currentAreaId`.
2. **Newborn pigs:** Placed near the mother's (randomized) position during the birth step. After repositioning, they end up in a natural location.
3. **Dead pigs:** Already removed from `GameState.guineaPigs` during the aging/death checkpoint — they won't appear in the scene.
4. **Behavior state reset:** All pigs set to `.idle` with cleared movement targets (`path = []`, `targetPosition = nil`, `targetFacilityId = nil`). The behavior AI picks up naturally on the next real-time tick.

This ensures the farm looks "lived-in" when the player returns, not frozen in time.

---

## 5. Summary Events

### OfflineProgressSummary struct

```swift
struct OfflineProgressSummary: Sendable {
    let wallClockElapsed: TimeInterval      // Real seconds the player was away
    let gameHoursElapsed: Double             // Game hours simulated

    var pigsBorn: [(name: String, phenotype: String)] = []
    var pigsDied: [(name: String, ageDays: Int)] = []
    var pigsSold: [(name: String, value: Int)] = []
    var pregnanciesStarted: [(maleName: String, femaleName: String)] = []
    var pigdexDiscoveries: [String] = []

    var totalMoneyEarned: Int = 0
    var totalMoneySpent: Int = 0

    // Computed
    var netMoney: Int { totalMoneyEarned - totalMoneySpent }
    var hasMeaningfulEvents: Bool {
        !pigsBorn.isEmpty || !pigsDied.isEmpty || !pigsSold.isEmpty
        || !pregnanciesStarted.isEmpty || netMoney != 0
    }
}
```

### Event collection

Wire into existing callbacks and system return values:
- `Birth.checkBirths` → record births in summary
- `Birth.ageAllPigs` → record deaths
- `Culling.sellMarkedAdults` → record sales + gold
- `Breeding.startPregnancyFromCourtship` / direct pregnancy start → record pregnancies
- `Birth.registerPigInPigdex` → record discoveries

During fast-forward, these populate the summary instead of triggering haptics or event log entries (though events ARE still logged to `GameState.events` for the in-game log).

---

## 6. Lifecycle Integration

### Current flow
```
background → lifecycleSave() → pause
active     → resume()
```

### New flow
```
background → lifecycleSave() → pause
active     → detectOfflineDuration()
             if < 60 seconds → resume (no catch-up)
             if >= 60 seconds →
               show loading overlay
               run OfflineProgressRunner
               save state to disk
               show OfflineProgressView (summary)
               user taps "Continue"
               dismiss summary → resume engine
```

### Detection logic

```swift
func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
    switch newPhase {
    case .active:
        let offlineDuration = computeOfflineDuration()
        if offlineDuration >= 60 {  // seconds
            runOfflineCatchUp(wallClockSeconds: offlineDuration)
        } else {
            engine.resume()
        }
    case .inactive:
        engine.pause()
    case .background:
        lifecycleSave()
    }
}

func computeOfflineDuration() -> TimeInterval {
    guard let lastSave = gameState.lastSave else { return 0 }
    return Date().timeIntervalSince(lastSave)
}
```

### UI state management

Add a `@State var offlineSummary: OfflineProgressSummary?` to `BigPigFarmApp` (or `ContentView`). When non-nil, the summary sheet is presented. The "Continue" button sets it to nil and calls `engine.resume()`.

---

## 7. File Plan

| File | Type | Purpose |
|------|------|---------|
| `BigPigFarm/Simulation/OfflineProgressRunner.swift` | New | Checkpoint loop, needs equilibration, offline breeding |
| `BigPigFarm/Simulation/OfflineProgressSummary.swift` | New | Summary data struct |
| `BigPigFarm/UI/OfflineProgressView.swift` | New | SwiftUI summary popup |
| `BigPigFarm/BigPigFarmApp.swift` | Modified | Lifecycle detection, summary state |
| `BigPigFarm/Engine/GameState.swift` | Modified | (maybe) add helper for offline duration |
| `BigPigFarm/Config/GameConfig.swift` | Modified | Add `Offline` namespace with constants |

---

## 8. Implementation Beads

### Bead 1: OfflineProgressRunner + OfflineProgressSummary

The fast-forward engine. This is the hard part — all the simulation logic.

**Deliverables:**
- `OfflineProgressRunner` with checkpoint-based simulation
- `OfflineProgressSummary` struct
- `GameConfig.Offline` constants (min threshold 60s, max duration 24h, speed rawValue 3)
- Post-catchup pig repositioning (randomize within area) and behavior state reset
- No facility depletion — facilities frozen at pre-offline levels
- Unit tests: verify needs equilibrate, pregnancies advance, births fire, deaths occur, breeding rolls happen, pig positions change, summary collects events

**No dependencies on other beads.**

### Bead 2: OfflineProgressView

The SwiftUI summary popup shown when returning.

**Deliverables:**
- `OfflineProgressView` showing: elapsed time, births, deaths, sales, gold earned, pigdex discoveries
- "Continue" button to dismiss
- Optional loading state (progress indicator) for long catch-ups
- Follows existing UI patterns (see ShopView, PigListView for style reference)

**Depends on bead 1** (needs `OfflineProgressSummary` type).

### Bead 3: Lifecycle integration + edge cases

Wire everything together.

**Deliverables:**
- `BigPigFarmApp` changes: detect offline duration, run catch-up, show summary
- Edge cases: nil `lastSave`, under threshold, first launch, app killed vs backgrounded
- Save after catch-up completes
- Suppress haptics during fast-forward
- Integration test: background → wait → foreground → verify state advanced

**Depends on beads 1 and 2.**

---

## 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 25% depletion too fast/slow | Balance off | Tunable via `consumptionRateMultiplier`. Short absences are harmless; 24h empties most facilities. Mercy floor prevents death spiral. |
| Breeding too generous (no proximity check) | Population explosion | Cap 1 pregnancy per checkpoint + existing capacity check |
| Generational turnover on long absences | Overwhelming summary | 180 game-days = ~4 full lifespans. Summary must aggregate gracefully (e.g. "12 pigs born, 8 died") rather than listing every event individually. |
| Pig repositioning onto occupied cells | Visual overlap | Use walkable-cell check; separate overlapping pigs on first real-time tick |
| Summary popup annoying for short absences | UX friction | Only show for ≥60 second absences; skip if no meaningful events |
| State corruption during catch-up | Data loss | Save backup before catch-up starts; restore on error |

---

## 10. Future Considerations

These are explicitly out of scope for v1 but worth noting:

1. **Configurable offline speed:** A settings toggle (Slow/Normal/Fast) for players who want more or less offline progression.

2. **Push notifications:** "Your pigs had 3 babies while you were away!" — local notifications triggered by offline catch-up producing interesting events. Could also predict when facilities will run dry and send a chaser notification to encourage the player to return.

3. **Depletion rate tuning:** The 25% consumption rate and 10% health mercy floor are initial values. May need adjustment based on playtesting — too fast punishes casual players, too slow removes tension.
