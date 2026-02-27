# Spec 05 — Behavior AI

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** 02 (Data Models), 04 (Game Engine)
> **Blocks:** 06 (Farm Scene, alongside 04)

---

## 1. Overview

This document specifies the complete pig behavior AI system for the iOS port: the decision tree, movement, facility seeking, needs system, collision handling, breeding/birth lifecycle, culling, biome acclimation, auto resources, and the tick orchestration that ties them together.

The Python source uses a coordinator class (`BehaviorController`) with free functions spread across four behavior files, plus standalone modules for needs, breeding, birth, culling, collision, acclimation, and auto resources. The iOS port preserves this architecture — translating Python classes to Swift classes/structs and Python free functions to Swift free functions grouped in caseless `enum` namespaces.

### Scope

**In scope:**
- `BehaviorController` coordinator class with all tracking state
- Decision tree: priority-based need evaluation with personality modifiers and guard states
- Movement system: multi-waypoint path consumption, dodge, blocked handling, biome-biased wandering
- Seeking system: facility seeking, social seeking, courtship seeking
- Needs system: decay, recovery, personality modifiers, behavior-specific effects, wellbeing
- Collision system: `SpatialGrid` uniform hash, `CollisionHandler` separation and blocking
- Breeding system: pair selection, courtship, auto-pairing from breeding program
- Birth system: pregnancy advancement, birth processing, litter generation, aging, pigdex registration
- Culling system: surplus management, active replacement, scoring strategies
- Biome acclimation: timer-based biome adoption
- Auto resources: drip system, auto-feeders, veggie gardens, AoE facility effects
- `SimulationRunner` tick orchestration: 13-phase tick order
- Stub corrections for all 14 simulation files

**Out of scope:**
- Data model definitions (Doc 02 — already specified)
- Config constants values (Doc 02 — `GameConfig.Behavior`, `GameConfig.Needs`, etc.)
- FarmGrid, pathfinding, area management (Doc 04 — Game Engine)
- FacilityManager scoring and caching (Doc 04 — Game Engine)
- Economy logic: shop, market, contracts, upgrades (Doc 04 — Game Engine)
- SpriteKit rendering and animation (Doc 06 — Farm Scene)
- SwiftUI screens (Doc 07)
- Persistence (Doc 08)

### Deliverable Summary

| Category | Files | Lines (est.) |
|----------|-------|-------------|
| Behavior AI (4 files) | `BehaviorController.swift`, `BehaviorDecision.swift`, `BehaviorMovement.swift`, `BehaviorSeeking.swift` | ~900 |
| Needs system | `NeedsSystem.swift` | ~230 |
| Collision system | `Collision.swift` | ~250 |
| Breeding + Birth | `Breeding.swift`, `Birth.swift` | ~550 |
| Culling | `Culling.swift` | ~200 |
| Acclimation | `Acclimation.swift` | ~50 |
| Auto resources | `AutoResources.swift` | ~130 |
| Tick orchestration | `SimulationRunner.swift` | ~200 |
| Breeding program | `BreedingProgram.swift` | ~300 |
| **Total** | **14 files** | **~2,810** |

### Source File Mapping

| Python Source | Lines | Swift Target | Notes |
|---------------|-------|-------------|-------|
| `simulation/behavior_controller.py` | 168 | `Simulation/BehaviorController.swift` | Coordinator class |
| `simulation/behavior_decision.py` | 312 | `Simulation/BehaviorDecision.swift` | Decision tree functions |
| `simulation/behavior_movement.py` | 502 | `Simulation/BehaviorMovement.swift` | Movement + wandering |
| `simulation/behavior_seeking.py` | 285 | `Simulation/BehaviorSeeking.swift` | Facility + social seeking |
| `simulation/needs.py` | 227 | `Simulation/NeedsSystem.swift` | Needs decay/recovery |
| `simulation/collision.py` | 250 | `Simulation/Collision.swift` | Spatial hash + separation |
| `simulation/breeding.py` | 458 | `Simulation/Breeding.swift` | Pair selection + courtship |
| `simulation/birth.py` | 328 | `Simulation/Birth.swift` | Pregnancy + birth + aging |
| `simulation/culling.py` | 206 | `Simulation/Culling.swift` | Surplus management |
| `simulation/acclimation.py` | 46 | `Simulation/Acclimation.swift` | Biome acclimation |
| `simulation/auto_resources.py` | 134 | `Simulation/AutoResources.swift` | Drip, AoE, veggie |
| `simulation/runner.py` | 252 | `Simulation/SimulationRunner.swift` | Tick orchestration |
| `simulation/breeding_program.py` | 388 | `Simulation/BreedingProgram.swift` | Strategy + scoring |
| `simulation/facility_manager.py` | 858 | `Simulation/FacilityManager.swift` | Facility scoring (Doc 04) |

---

## 2. Architectural Decision: Enum + Switch over GKStateMachine

**Context:** The Python behavior system uses 8 states stored as an enum value on each `GuineaPig`, with a flat decision tree in `behavior_decision.py` that evaluates needs and picks the next state. There is no per-state class — all logic lives in the controller and its helper functions.

**Decision:** Use `enum BehaviorState` + `switch` statements in free functions, not `GKStateMachine`. This is architectural decision #3 from the ROADMAP.

**Rationale:**
1. The Python implementation is already a flat decision tree, not an object-oriented state pattern. Each tick evaluates needs and picks a state — there are no per-state `enter()`/`exit()`/`update()` methods.
2. `GKStateMachine` requires one `GKState` subclass per state (8 classes), each with `isValidNextState()`, `didEnter()`, `update()`, and `willExit()`. This adds ~400 lines of boilerplate for zero behavioral benefit.
3. The `switch` approach is a direct port of the Python pattern — easier to verify correctness by line-by-line comparison.
4. All 8 states share the same movement system. State-specific behavior is limited to guard conditions in the decision tree (e.g., "if sleeping and energy full, wake up"). A `switch` handles this naturally.
5. The `BehaviorState` enum is already defined in Doc 02 as a `String`-backed `Codable` enum on `GuineaPig`. `GKStateMachine` would require a parallel representation.

**Implementation pattern:** Free functions in caseless `enum` namespaces, operating on `GuineaPig` (mutated in place through `inout` or via reference through `GameState`). The `BehaviorController` class holds per-pig tracking state (decision timers, blocked timers, etc.) and delegates to these functions.

---

## 3. Stub Corrections

The Doc 01 stubs declared all simulation types as `struct: Sendable`. Several must change:

| Stub | Current | Correct | Reason |
|------|---------|---------|--------|
| `BehaviorController` | `struct` | `class` | Holds mutable dictionaries of per-pig tracking state; passed by reference to all behavior functions |
| `BehaviorDecision` | `struct` | `enum` (caseless) | Namespace for free functions only — no instances |
| `BehaviorMovement` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `BehaviorSeeking` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `NeedsSystem` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `Collision` | Two types needed | `SpatialGrid` (struct) + `CollisionHandler` (class) | SpatialGrid is value-type bucket storage; CollisionHandler holds mutable indices |
| `Breeding` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `Birth` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `Culling` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `Acclimation` | `struct` | `enum` (caseless) | Single free function |
| `AutoResources` | `struct` | `enum` (caseless) | Namespace for free functions only |
| `SimulationRunner` | `struct` | `class` | Holds mutable state (save counter, TPS measurement, breeding throttle) |
| `BreedingProgram` | `struct` | `struct` (correct) | Already correct — data model with computed properties |

**Why `class` for BehaviorController and SimulationRunner:** Both accumulate mutable state across ticks (timers, counters, caches) and are passed by reference to subsystems. Making them structs would require `mutating` throughout and would cause copy-on-write overhead when passed to functions. They are not `@Observable` — only `GameState` needs observation.

**Why caseless `enum` for function namespaces:** The Python source uses module-level free functions (e.g., `make_decision()`, `update_movement()`). In Swift, top-level functions work but pollute the global namespace. Caseless enums (`enum BehaviorDecision {}`) group related functions under a namespace without allowing accidental instantiation. This matches the convention established in Doc 02 for `GameConfig`.

---

## 4. BehaviorController

**Maps from:** `simulation/behavior_controller.py` (168 lines)
**Swift target:** `Simulation/BehaviorController.swift` (~200 lines)

The coordinator that drives per-pig AI updates each tick. Owns the collision handler and facility manager, holds per-pig tracking dictionaries, and delegates to the decision/movement/seeking subsystems.

> **Forward references:** Sections 4–7 reference `FacilityManager` and `FarmGrid` method signatures that are forward declarations. These types are specified in Doc 04 (Game Engine). Reconcile signatures with Doc 04 before implementing.

### Class Definition

```swift
import Foundation

final class BehaviorController {
    // Dependencies (set once, never reassigned)
    private unowned let gameState: GameState
    let collision: CollisionHandler
    let facilityManager: FacilityManager

    // Per-pig tracking state
    private var decisionTimers: [UUID: Double] = [:]
    private var blockedTimers: [UUID: Double] = [:]
    private var stuckPositions: [UUID: GridPosition] = [:]
    private var stuckTimers: [UUID: Double] = [:]

    // Unreachable facility backoff: pigId -> {needType: remainingCycles}
    private var unreachableNeeds: [UUID: [String: Int]] = [:]
    private var lastGridGeneration: Int = 0

    // Courtship pairs that completed the together phase (consumed by SimulationRunner)
    private(set) var completedCourtships: [(UUID, UUID)] = []

    init(gameState: GameState) { ... }
}
```

### Key Methods

```swift
extension BehaviorController {
    /// Update behavior for a single pig. Called once per pig per tick.
    func update(pig: inout GuineaPig, gameMinutes: Double) { ... }

    /// Remove all tracking state for a dead/sold pig.
    func cleanupDeadPig(_ pigId: UUID) { ... }

    /// Clear all internal tracking state (called after auto-arrange).
    func resetAllTracking() { ... }

    /// Delegate to collision handler for post-behavior separation.
    func separateOverlappingPigs() { ... }

    /// Post-collision sweep: rescue pigs on non-walkable cells.
    func rescueNonWalkablePigs(_ pigs: inout [GuineaPig]) { ... }

    /// Drain and return completed courtship pairs. Called by SimulationRunner.
    func drainCompletedCourtships() -> [(UUID, UUID)] {
        defer { completedCourtships.removeAll() }
        return completedCourtships
    }
}
```

### Update Flow (per pig per tick)

The `update()` method executes this sequence:

1. **Grid generation check** — if `farm.gridGeneration` changed since last tick, clear all `unreachableNeeds` so pigs notice newly built facilities immediately.
2. **Decision timer** — accumulate `gameMinutes` into the pig's timer. Determine the decision interval:
   - `0.0` if hunger or thirst below `GameConfig.Needs.criticalThreshold` (emergency override)
   - `GameConfig.Behavior.contentDecisionInterval` (8.0s) if pig is content (all needs satisfied, not heading to a facility)
   - `GameConfig.Simulation.decisionIntervalSeconds` (2.0s) otherwise
3. **Make decision** — if timer >= interval, call `BehaviorDecision.makeDecision(controller:pig:)`. Reset timer with small random offset to prevent synchronized decisions.
4. **Update movement** — call `BehaviorMovement.updateMovement(controller:pig:gameMinutes:)`.
5. **Clamp to bounds** — call `BehaviorMovement.clampToBounds(controller:pig:)`.
6. **Rescue from non-walkable** — if pig is on a non-walkable cell, teleport to nearest walkable.
7. **Track current area** — update `pig.currentAreaId`. If area changed, clear unreachable backoff.
8. **Update current behavior** — state-specific effects:
   - `WANDERING` with empty path: reset blocked timers, check facility arrival via `facilityManager.checkArrivedAtFacility()`.
   - `COURTING` with empty path: advance courtship timer when both pigs are adjacent (distance <= `minPigDistance + 2.0`). Only the initiator advances the timer. Queue completion when timer crosses `courtshipTogetherSeconds`.
   - `EATING/DRINKING/SLEEPING/PLAYING` with empty path: consume resources via `facilityManager.consumeFromNearbyFacility()`.

### Content Check

```swift
extension BehaviorController {
    /// A content pig has no urgent needs, isn't heading to a facility,
    /// and is idle or wandering. Content pigs use a longer decision
    /// interval (8s vs 2s) to save CPU.
    static func isContent(_ pig: GuineaPig) -> Bool {
        guard pig.behaviorState == .idle || pig.behaviorState == .wandering else {
            return false
        }
        guard pig.targetFacilityId == nil else { return false }
        let needs = pig.needs
        return needs.hunger >= Double(GameConfig.Needs.highThreshold)
            && needs.thirst >= Double(GameConfig.Needs.highThreshold)
            && needs.energy >= Double(GameConfig.Needs.highThreshold)
            && needs.happiness >= Double(GameConfig.Needs.highThreshold)
            && needs.social >= Double(GameConfig.Needs.highThreshold)
            // Boredom is inverted: 0 = engaged, 100 = bored. Keep below play threshold.
            && needs.boredom < Double(GameConfig.Behavior.boredomPlayThreshold)
    }
}
```

### Accessing Per-Pig Tracking from Subsystems

The behavior subsystem functions (`BehaviorDecision`, `BehaviorMovement`, `BehaviorSeeking`) need access to the controller's tracking dictionaries. Rather than making them public, expose controlled accessors:

```swift
extension BehaviorController {
    // Blocked timer access (used by BehaviorMovement)
    func getBlockedTime(_ pigId: UUID) -> Double
    func setBlockedTime(_ pigId: UUID, _ time: Double)
    func resetBlockedState(_ pigId: UUID)

    // Stuck tracking (used by BehaviorMovement)
    func getStuckPosition(_ pigId: UUID) -> GridPosition?
    func setStuckPosition(_ pigId: UUID, _ position: GridPosition)
    func getStuckTime(_ pigId: UUID) -> Double
    func setStuckTime(_ pigId: UUID, _ time: Double)
    func clearStuckState(_ pigId: UUID)

    // Decision timer (used by BehaviorMovement for give-up reset)
    func resetDecisionTimer(_ pigId: UUID)

    // Unreachable backoff (used by BehaviorDecision and BehaviorSeeking)
    func getUnreachableBackoff(_ pigId: UUID, need: String) -> Int
    func setUnreachableBackoff(_ pigId: UUID, need: String, cycles: Int)
    func tickDownUnreachableBackoffs(_ pigId: UUID)
    func clearUnreachableBackoff(_ pigId: UUID)
}
```

---

## 5. Decision Tree (BehaviorDecision)

**Maps from:** `simulation/behavior_decision.py` (312 lines)
**Swift target:** `Simulation/BehaviorDecision.swift` (~250 lines)

The decision tree determines what a pig should do next. It is a priority-ordered sequence of checks, not a state machine. Each check either commits the pig to a behavior (and returns) or falls through to the next check.

### Entry Point

```swift
enum BehaviorDecision {
    /// Make a behavioral decision for the pig.
    /// Called when the pig's decision timer expires.
    static func makeDecision(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }
}
```

### Decision Flow (complete, in order)

**Phase 1 — Travel validation** (pig is wandering toward a facility with an active path):
- If the target facility still exists and is not empty (for consumable types: foodBowl, waterBottle, hayRack, feastTable), continue traveling (return early).
- If the facility was removed or became empty, mark it as failed, clear the path, and fall through to make a new decision.

**Phase 2 — Target cleanup** (pig had a target but lost its path):
- Clear `targetFacilityId` and `targetDescription`.
- If the pig has a failed facility cooldown, tick it down.
- Otherwise, clear the failed facilities list for a fresh decision.

**Phase 3 — Guard: Sleeping**
- If sleeping and energy >= `satisfactionThreshold` (90): wake up, set state to `.idle`.
- If sleeping and (hunger or thirst < `criticalThreshold`) and energy >= `emergencyWakeEnergy` (15): wake up for critical need.
- If sleeping and neither condition met: return (keep sleeping).

**Phase 4 — Guard: Courting**
- If courting and partner is gone or not courting: cancel courtship.
- If courting and (hunger or thirst critical): cancel courtship for both pigs.
- If courting and initiator with no path: seek partner via `BehaviorSeeking.seekCourtingPartner()`.
- Return (stay in courting state).

**Phase 5 — Guard: Eating/Drinking commitment**
- If eating and hunger < `satisfactionThreshold` (90): return (keep eating).
- If drinking and thirst < `satisfactionThreshold` (90): return (keep drinking).
- If finished eating/drinking (need >= 90): wander away to make room.

This is the **Buridan's ass prevention**: a pig that is both hungry and thirsty commits to its current action until the need reaches 90%. Without this, pigs with both needs critical oscillate forever between food and water.

**Phase 6 — Guard: Playing/Socializing commitment**
- If playing and boredom > `boredomKeepPlaying` (20): keep playing unless hunger/thirst critical.
- If socializing and social < `satisfactionThreshold` (90): keep socializing unless hunger/thirst critical.
- If finished playing: track affinity with nearby socializing pigs (only from smaller UUID to avoid double-counting), then wander away.
- If finished socializing: wander away.

**Phase 7 — Tick unreachable backoffs**
- Decrement all unreachable need backoff counters for this pig. Remove expired entries.

**Phase 8 — Urgent need evaluation**
- Call `NeedsSystem.getMostUrgentNeed(pig:)` to get the highest-priority unmet need.
- Handle by need type:
  - `"energy"` (energy < `energySleepThreshold` = 40): seek sleep. **Exception:** if happiness is critically low but energy is not critical, prioritize play over sleep to break the eat-sleep death spiral.
  - `"hunger"` or `"thirst"`: seek facility for that need.
  - `"happiness"`: seek play.
  - `"social"` (and pig does not have `.shy` personality): seek social interaction.

**Phase 9 — Boredom**
- If boredom > `boredomPlayThreshold` (30): seek play.

**Phase 10 — Personality defaults** (no urgent needs)
- If `.lazy` personality: 30% chance to seek sleep.
- If `.playful` personality: 40% chance to seek play.
- If `.social` personality: 30% chance to seek social interaction.

**Phase 11 — Nighttime campfire attraction**
- If not daytime: try to path idle/wandering pigs to nearby campfires (within `aoEAttractionRadius` = 10 cells).

**Phase 12 — Random wandering or idle**
- 80% chance (`wanderChance`): start wandering.
- 20% chance: idle. But if another pig is within `idleDriftRadius` (5.0), wander away instead to prevent clustering.

### Campfire Attraction (private helper)

```swift
extension BehaviorDecision {
    /// At night, bias idle/wandering pigs toward nearby campfires.
    private static func tryCampfireAttraction(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }
}
```

Only triggers if the pig has no target and no path. Finds campfires within 10 cells, attempts to path to an open interaction point.

---

## 6. Movement System (BehaviorMovement)

**Maps from:** `simulation/behavior_movement.py` (502 lines)
**Swift target:** `Simulation/BehaviorMovement.swift` (~300 lines)

Handles pig movement along paths, wandering, dodging, rescue, and blocked-movement fallbacks.

### Public API

```swift
enum BehaviorMovement {
    /// Move a pig along its path, consuming multiple waypoints per tick
    /// when game speed is high.
    static func updateMovement(
        controller: BehaviorController,
        pig: inout GuineaPig,
        gameMinutes: Double
    ) { ... }

    /// Clamp pig position to stay within the walkable area (inside walls).
    static func clampToBounds(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }

    /// Start random wandering using straight-line movement
    /// (no A* for the common ~60% of pigs that are wandering).
    static func startWandering(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }

    /// Calculate and set an A* path to a target grid position.
    static func setPathTo(
        controller: BehaviorController,
        pig: inout GuineaPig,
        target: GridPosition
    ) { ... }

    /// Teleport a pig from a non-walkable cell to a safe position.
    static func rescueToWalkable(
        controller: BehaviorController,
        pig: inout GuineaPig,
        farm: FarmGrid
    ) { ... }

    /// Post-collision sweep: rescue any pigs on non-walkable cells.
    static func rescueNonWalkablePigs(
        controller: BehaviorController,
        pigs: inout [GuineaPig]
    ) { ... }
}
```

### Movement Update Logic

`updateMovement()` consumes waypoints from `pig.path` until the movement budget is spent:

1. If `pig.path` is empty or pig is sleeping, return immediately.
2. Calculate speed:
   - Base: `GameConfig.Simulation.baseMoveSpeed` (1.0 cells/game-minute)
   - Express Lanes perk: x1.5 (supersedes Paved Paths)
   - Paved Paths perk: x1.2
   - Tired (energy < `energySleepThreshold`): x0.5
   - Baby: x0.7
3. Calculate movement budget: `speed * gameMinutes`.
4. While path is not empty and budget remains:
   - Calculate distance to next waypoint.
   - If within `waypointReached` (0.1): snap to waypoint, pop it, continue.
   - If budget >= distance: move to waypoint if not blocked, pop it, deduct from budget.
   - If budget < distance: partial movement toward waypoint if target position is walkable and not blocked.
   - If blocked at any point: try dodge, then handle blocked.
5. After movement loop: if moved, clear "(blocked)" from `targetDescription` and reset blocked/stuck timers. If path is empty, clear `targetPosition`.

### Dodge System

```swift
extension BehaviorMovement {
    /// Try to sidestep perpendicular to the path direction
    /// to get around a blocking pig.
    private static func tryDodge(
        controller: BehaviorController,
        pig: inout GuineaPig,
        pathDx: Double,
        pathDy: Double,
        gameMinutes: Double,
        speed: Double
    ) -> Bool { ... }
}
```

Calculates two perpendicular directions (rotate path vector 90 degrees both ways). Moves in the first unblocked direction, capped at `dodgeMaxStep` (1.0).

### Blocked Handling

```swift
extension BehaviorMovement {
    /// Handle a pig that is blocked during movement.
    private static func handleMovementBlocked(
        controller: BehaviorController,
        pig: inout GuineaPig,
        dx: Double,
        dy: Double,
        gameMinutes: Double,
        speed: Double
    ) { ... }
}
```

Escalation sequence:
1. Try dodge first.
2. Accumulate blocked time in `controller.blockedTimers`.
3. Track stuck position in `controller.stuckPositions` — NOT reset by facility switches, only by actual physical movement.
4. Append "(blocked)" to `targetDescription`.
5. If stuck at same cell > `blockedTimeGiveUp` (5.0s): force give-up.
6. If blocked > `blockedTimeAlternative` (2.0s): try alternative facility via `facilityManager.tryAlternativeFacility()`.
7. If that fails and blocked > `blockedTimeGiveUp`: give up entirely.

### Give-Up Fallback

```swift
extension BehaviorMovement {
    /// Give up reaching a facility and apply a need-specific fallback.
    private static func giveUpAndFallback(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }
}
```

- Clear path, target, and blocked/stuck timers.
- Set failed facility cooldown: 1 cycle if critical hunger/thirst, 3 cycles otherwise.
- If target was a hideout/sleep: sleep where standing.
- Otherwise: go idle and start wandering with a longer cooldown before next decision.

### Wandering System

`startWandering()` uses simple straight-line paths instead of A* for the ~60% of pigs that are wandering at any given time:

1. Get the pig's biome wander target (color-matched area or preferred biome area).
2. If a color-matched area exists and the pig is outside it:
   - 70% chance (`biomeHomingChance`): A* pathfind home. This is the only way to cross rooms via tunnels.
   - Otherwise: biased straight-line wander toward the area.
3. If inside the target area or no target: pick a random cardinal direction (biased toward the area center if outside, biased inward if inside).
4. Build a straight-line path of 6-14 steps (`simpleWanderMinSteps`/`simpleWanderMaxSteps`).
5. If all directions are blocked: teleport to a random walkable cell in the current area.

### Biome Wander Target

```swift
extension BehaviorMovement {
    /// Find the target area for biome-biased wandering.
    /// Color is the primary driver; preferred_biome is the fallback.
    /// Returns (targetArea, isColorMatch).
    private static func getBiomeWanderTarget(
        controller: BehaviorController,
        pig: GuineaPig
    ) -> (FarmArea?, Bool) { ... }

    /// Return cardinal directions weighted toward the target area.
    private static func biasWanderDirections(
        controller: BehaviorController,
        pig: GuineaPig,
        targetArea: FarmArea
    ) -> [(Int, Int)] { ... }
}
```

Direction biasing uses weighted random selection:
- Outside target area: directions aligned with the vector toward the area center get weight `biomeWanderBiasOutside` (3.0), others get 1.0.
- Inside target area: directions pointing away from the nearest edge get weight `biomeWanderBiasInside` (1.5) if the pig is >3 cells from the edge, otherwise 1.0.

---

## 7. Seeking System (BehaviorSeeking)

**Maps from:** `simulation/behavior_seeking.py` (285 lines)
**Swift target:** `Simulation/BehaviorSeeking.swift` (~200 lines)

Handles finding facilities, social targets, and courting partners. Each seeking function follows the same pattern: find candidates, rank them, try to path to the best one, fall back to alternatives.

### Public API

```swift
enum BehaviorSeeking {
    /// Find and move toward a facility that addresses a need.
    static func seekFacilityForNeed(
        controller: BehaviorController,
        pig: inout GuineaPig,
        need: String
    ) { ... }

    /// Find a place to sleep (hideouts + hot springs).
    static func seekSleep(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }

    /// Find something to play with (5 facility types + fallbacks).
    static func seekPlay(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }

    /// Find another pig to socialize with.
    static func seekSocialInteraction(
        controller: BehaviorController,
        pig: inout GuineaPig
    ) { ... }

    /// Pathfind the initiator pig to its courting partner.
    static func seekCourtingPartner(
        controller: BehaviorController,
        pig: inout GuineaPig,
        partner: GuineaPig
    ) { ... }

    /// Find a walkable cell near a target with proper spacing.
    static func findAdjacentCell(
        controller: BehaviorController,
        target: GridPosition,
        pig: GuineaPig
    ) -> GridPosition? { ... }
}
```

### Facility Seeking Flow

`seekFacilityForNeed()`:
1. Check unreachable backoff — if active, wander instead.
2. Map need to facility types via `NeedsSystem.getTargetFacilityForNeed()`:
   - `"hunger"` -> `[.hayRack, .feastTable, .foodBowl]`
   - `"thirst"` -> `[.waterBottle]`
   - `"energy"` -> `[.hideout]`
   - `"happiness"` -> `[.playArea, .exerciseWheel, .tunnel]`
   - `"social"` -> `[.playArea]`
3. For each facility type, get ranked candidates from `facilityManager.getCandidateFacilitiesRanked()` (capped at `maxFacilityCandidates` = 4).
4. For each candidate, try to find an open interaction point with A* path.
5. If a path is found: set pig state to `.wandering`, set path, target, and description. Return.
6. If path fails: mark facility as failed and try next candidate.
7. If no reachable facility found: set unreachable backoff (5 cycles normal, 2 cycles critical) and wander.

### Sleep Seeking

`seekSleep()`: Collects both hideouts and hot springs, ranked. Tries each one. If none reachable, sleeps where standing (sets state to `.sleeping` with no path).

### Play Seeking

`seekPlay()`: Tries 5 facility types in order:
1. `.exerciseWheel`
2. `.playArea`
3. `.tunnel`
4. `.stage`
5. `.therapyGarden` (only if happiness < 50)

If no play facility found:
- If social need < `highThreshold` and pig is not shy: try socializing instead (prevents priority starvation where happiness blocks social).
- Otherwise: wander, with 10% chance of entering `.playing` state while wandering.

### Social Seeking

`seekSocialInteraction()`:
1. At night: try campfires first for social recovery.
2. Find nearest pig using spatial grid's `getNearby()`.
3. Fall back to full pig list if nobody nearby.
4. Find an adjacent walkable cell near the target pig (using `findAdjacentCell`).
5. Path to that cell, set state to `.socializing`.
6. If unreachable: wander instead.

### Adjacent Cell Finding

`findAdjacentCell()`: Checks 8 cells at `minPigDistance` (3) spacing from the target. Sorts by distance to the approaching pig (prefer closer cells). Returns the first walkable, unoccupied cell. Falls back to the original target position if all cells are occupied.

---

## 8. Needs System (NeedsSystem)

**Maps from:** `simulation/needs.py` (227 lines)
**Swift target:** `Simulation/NeedsSystem.swift` (~230 lines)

Handles per-tick need decay, behavior-based recovery, personality modifiers, and need urgency evaluation.

### Public API

```swift
enum NeedsSystem {
    /// Pre-compute nearby pig counts for every pig. O(n*k) with spatial grid.
    static func precomputeNearbyCounts(
        pigs: [GuineaPig],
        radius: Double,
        spatialGrid: SpatialGrid?
    ) -> [UUID: Int] { ... }

    /// Update all needs for a pig based on elapsed game time.
    static func updateAllNeeds(
        pig: inout GuineaPig,
        gameMinutes: Double,
        gameState: GameState,
        nearbyCount: Int
    ) { ... }

    /// Determine which need is most urgent and should be addressed.
    static func getMostUrgentNeed(pig: GuineaPig) -> String { ... }

    /// Get facility types that address a specific need (in priority order).
    static func getTargetFacilityForNeed(_ need: String) -> [FacilityType]? { ... }

    /// Calculate an overall wellbeing score (0-100).
    static func calculateOverallWellbeing(pig: GuineaPig) -> Double { ... }
}
```

### Need Decay (per game hour)

All decay rates are applied proportionally to elapsed game hours (`gameMinutes / 60.0`):

| Need | Base Decay | Personality Modifier |
|------|-----------|---------------------|
| Hunger | -0.6/hr | Greedy: x1.5 |
| Thirst | -0.8/hr | — |
| Energy | -0.6/hr | Lazy: x0.7 (slower decay) |
| Boredom | +2.0/hr (increases) | Playful: x1.5 (faster boredom) |
| Social | -2.0/hr alone, -0.5/hr with pigs | Social: x1.3; Shy: x0.5 |

### Passive Effects (per game hour)

- **Contentment recovery:** If hunger >= `lowThreshold` AND thirst >= `lowThreshold` AND energy >= `criticalThreshold`, happiness recovers at +2.0/hr.
- **Preferred biome bonus:** +1.5/hr happiness when in preferred biome.
- **Climate Control perk:** +0.3/hr happiness in all biomes.
- **Critical need drain:** Hunger/thirst/energy below `criticalThreshold` drain happiness at -2.0/-2.5/-1.5 per hour respectively.
- **Boredom drain:** Boredom > 70 drains happiness at -1.0/hr.
- **Enrichment Program perk:** Boredom grows 20% slower.
- **Social proximity:** Nearby pigs (within `socialRadius` = 8.0) provide passive social recovery: +3.0 per pig per hour, capped at +8.0/hr total.
- **Health drain:** Critical hunger drains health at -0.3/hr; critical thirst at -0.5/hr.
- **Health recovery:** When no primary need is critical, +1.0/hr passive recovery. Pig Spa perk doubles this.

### Behavior Recovery (per game hour)

Applied via `_applyBehaviorRecovery()` based on current `behaviorState`:

| State | Effects |
|-------|---------|
| `.eating` | hunger +80.0/hr (x2 base), happiness +2.0/hr |
| `.drinking` | thirst +100.0/hr (x2 base) |
| `.sleeping` | energy +25.0/hr (Premium Bedding: x1.25), health +1.5/hr |
| `.playing` | happiness +15.0/hr, boredom -15.0/hr, energy -1.0/hr |
| `.socializing` | happiness +10.0/hr, social +10.0/hr |

### Urgency Evaluation

`getMostUrgentNeed()` uses a two-pass priority scan:

**Pass 1 — Critical needs** (below threshold):

| Priority | Need | Threshold |
|----------|------|-----------|
| 1 | thirst | `criticalThreshold` (20) | Thirst prioritized: decays 33% faster (0.8 vs 0.6/hr), faster path to health loss |
| 2 | hunger | `criticalThreshold` (20) | |
| 3 | energy | `lowThreshold` (40) |
| 4 | happiness | `lowThreshold` (40) |
| 5 | social | `lowThreshold` (40) |

**Pass 2 — Moderately low needs** (below `highThreshold` = 70):
Same priority order, checking against `highThreshold`.

Returns `"none"` if all needs are above `highThreshold`.

### Wellbeing Calculation

```swift
static func calculateOverallWellbeing(pig: GuineaPig) -> Double {
    pig.needs.hunger * 0.25
        + pig.needs.thirst * 0.25
        + pig.needs.energy * 0.15
        + pig.needs.happiness * 0.20
        + pig.needs.health * 0.15
}
```

> **Note:** `social` is intentionally excluded from the wellbeing score — this matches the Python source. Low social need is addressed indirectly through happiness drains and the passive social proximity bonus (+3.0/hr per nearby pig), so the happiness weight already encodes social state.

---

## 9. Collision System

**Maps from:** `simulation/collision.py` (250 lines)
**Swift target:** `Simulation/Collision.swift` (~250 lines)

### SpatialGrid

A uniform grid for O(n*k) spatial lookups instead of O(n^2) all-pairs.

```swift
struct SpatialGrid: Sendable {
    private static let cellSize: Int = 5
    private var cells: [GridPosition: [UUID]] = [:]
    private var pigPositions: [UUID: Position] = [:]

    /// Re-bin all pigs into grid cells. Call once per tick.
    mutating func rebuild(pigs: [GuineaPig]) { ... }

    /// Return all pig IDs in the same and 8 adjacent cells.
    func getNearby(x: Double, y: Double, pigs: [UUID: GuineaPig]) -> [GuineaPig] { ... }

    /// Yield unique (pigA, pigB) pairs that share the same or adjacent cells.
    func uniqueNearbyPairs(pigs: [UUID: GuineaPig]) -> [(GuineaPig, GuineaPig)] { ... }
}
```

**Implementation note:** The Python `SpatialGrid` stores `GuineaPig` references directly in buckets. In Swift, since `GuineaPig` is a struct (value type), storing copies would be wasteful. Instead, store `UUID`s in the grid and look up the actual pig from `GameState.pigs` when needed. Alternatively, since pigs are accessed through `GameState` (a reference type), the grid can store array indices or UUIDs. The implementer should profile both approaches — UUID lookups via dictionary are O(1) but have hash overhead; array indices are faster but require a stable ordering guarantee.

**Decision needed:** Whether `SpatialGrid` stores `UUID`s (simpler, matches Python semantics) or array indices into a `[GuineaPig]` snapshot (faster lookups, more complex lifetime management). Recommend starting with UUIDs and optimizing only if profiling shows spatial grid lookups as a bottleneck.

### CollisionHandler

```swift
final class CollisionHandler {
    private unowned let gameState: GameState
    var spatialGrid: SpatialGrid

    // Index: facility UUID -> set of pig UUIDs targeting that facility
    private var facilityTargets: [UUID: Set<UUID>] = [:]

    init(gameState: GameState) { ... }

    /// Re-bin all pigs and rebuild facility target index. Call once per tick.
    func rebuildSpatialGrid() { ... }

    /// Return pig IDs currently heading to a facility.
    func getPigsTargetingFacility(_ facilityId: UUID) -> Set<UUID> { ... }

    /// Check if a cell is occupied by another pig.
    func isCellOccupiedByPig(
        x: Int, y: Int, excludePig: GuineaPig?
    ) -> Bool { ... }

    /// Check if moving to a position would collide with another pig.
    func isPositionBlocked(
        targetX: Double, targetY: Double,
        excludePig: GuineaPig,
        minDistance: Double
    ) -> Bool { ... }

    /// Push apart any pigs that are too close.
    func separateOverlappingPigs() { ... }
}
```

### Blocking Logic

`isPositionBlocked()` uses tiered blocking distances:
- **Emergency override:** Pigs with health < `criticalThreshold` ignore blocking entirely (push through traffic to reach food/water).
- **Courting partner:** A pig never blocks its own courting partner.
- **Both moving:** `blockingBothMoving` (1.5) — allows pigs to squeeze past each other.
- **Facility use:** `blockingFacilityUse` (1.5) — pigs using facilities are "tucked in."
- **Default:** `blockingDefault` (2.5) — stationary pig blocks moving pig.

### Separation Logic

`separateOverlappingPigs()` uses tiered separation thresholds (must be < corresponding blocking thresholds to avoid separation-vs-pathfinding deadlock):

| Situation | Threshold | Corresponding Blocking |
|-----------|-----------|----------------------|
| Both moving | 1.0 | 1.5 |
| Both using facility | 1.0 | 1.5 |
| One moving | 2.0 | 2.5 |
| Both idle | 3.0 (`minPigDistance`) | 2.5 |
| Courting pair | skip entirely | — |

When pigs overlap (distance < threshold but > `overlapEpsilon` = 0.01):
1. Calculate separation needed: `(threshold - distance) / 2 + separationPadding`.
2. Normalize direction vector.
3. Move each pig half the overlap distance in opposite directions.
4. Only apply if BOTH new positions are walkable (prevents ratcheting near walls).

When pigs are exactly overlapping (distance <= `overlapEpsilon`):
- Push one pig in a random direction by `minPigDistance / 2`.

---

## 10. Breeding System

**Maps from:** `simulation/breeding.py` (458 lines)
**Swift target:** `Simulation/Breeding.swift` (~300 lines)

### Public API

```swift
enum Breeding {
    /// Check for and process breeding opportunities.
    /// Returns number of births.
    static func checkBreedingOpportunities(
        gameState: GameState,
        runExpensive: Bool
    ) -> Int { ... }

    /// Called when courtship completes — starts the actual pregnancy.
    static func startPregnancyFromCourtship(
        male: inout GuineaPig,
        female: inout GuineaPig,
        gameState: GameState
    ) { ... }

    /// Reset all courtship fields on a pig.
    static func clearCourtship(pig: inout GuineaPig) { ... }
}
```

### Breeding Opportunity Flow

`checkBreedingOpportunities(gameState:runExpensive:)`:
1. **Check births** — process existing pregnancies via `Birth.checkBirths()`.
2. **Manual breeding pair** — if `gameState.breedingPair` is set, validate both pigs exist and can breed, then initiate courtship.
3. **Auto-pair from program** (only if `runExpensive` is true) — if breeding program is enabled with auto-pair, find the best pair using the configured strategy.
4. **Check for new breeding** (only if `runExpensive` is true and not at capacity) — scan all eligible male/female pairs for proximity-based spontaneous breeding.

The `runExpensive` flag throttles the O(m*f) pair scans to every 10 ticks (~1 second) in the SimulationRunner. Manual pairs and births run every tick (cheap).

### Breeding Eligibility

`canBreedTogether(male:female:gameState:)`:
- Both must pass `canBreed` (adult, not senior, not locked, happiness >= 70, recovery cooldown elapsed).
- Must be within `breedingDistance` (3.0 cells).
- Inbreeding is checked but allowed (parent/child or siblings).

### Breeding Attempt

`_attemptBreeding(male:female:gameState:)`:
- Base chance: 5% (`baseBreedingChance`).
- Fertility Herbs perk: +5%.
- Breeding den on farm: +10%.
- High average happiness (>80): +5%.
- Affinity bonus: +1% per affinity point, capped at +5%.
- Random roll. If successful, initiate courtship.
- Guard: neither pig can already be courting.

### Courtship Initiation

`_initiateCourtship(male:female:gameState:)`:
- Set both pigs to `.courting` state.
- Set `courtingPartnerId` on each pig.
- Male is the initiator (will pathfind to female).
- Clear existing paths and targets.
- Log event.

The physical courtship phase is handled in `BehaviorController.updateCurrentBehavior()` — the initiator pathfinds to the partner, and when they are adjacent for `courtshipTogetherSeconds` (4.0s), the courtship completes and pregnancy starts.

### Auto-Pairing Strategies

`_autoPairFromProgram(gameState:)`:

**Target strategy:** For each male-female pair, calculate `calculateTargetProbability()` (analytical Punnett square) for the program's target phenotype. Add affinity bonus. Pair the highest-scoring couple.

**Diversity strategy:** Score pairs by genetic distance at color loci (e, b, d), rare-color production probability (scaled by 5.0), and affinity tiebreaker.

**Money strategy:** Derive implicit targets from active contracts (required_color, required_pattern, etc.) and score pairs by target probability toward those traits.

### Inbreeding Check

```swift
extension Breeding {
    /// Check if two pigs are closely related (parent/child or siblings).
    private static func areCloselyRelated(
        _ pig1: GuineaPig,
        _ pig2: GuineaPig,
        gameState: GameState
    ) -> Bool { ... }
}
```

Checks shared `motherId`, shared `fatherId`, or direct parent-child relationship.

---

## 11. Birth and Aging

**Maps from:** `simulation/birth.py` (328 lines)
**Swift target:** `Simulation/Birth.swift` (~250 lines)

### Public API

```swift
enum Birth {
    /// Check for and process births from existing pregnancies.
    /// Returns number of births.
    static func checkBirths(gameState: GameState) -> Int { ... }

    /// Advance pregnancy progress for all pregnant pigs.
    static func advancePregnancies(
        gameState: GameState,
        gameHours: Double
    ) { ... }

    /// Age all guinea pigs. Returns list of pigs that died of old age.
    static func ageAllPigs(
        gameState: GameState,
        gameHours: Double
    ) -> [GuineaPig] { ... }

    /// Register a pig's phenotype in the pigdex with rewards.
    static func registerPigInPigdex(
        gameState: GameState,
        pig: GuineaPig
    ) { ... }
}
```

### Birth Processing

`_processBirth(mother:gameState:)`:
1. Check capacity — cancel pregnancy if at capacity.
2. Retrieve father genotype from stored `partnerGenotype` (works even if father was sold after conception).
3. Determine litter size: random 1-4 (`minLitterSize` to `maxLitterSize`). Litter Boost perk: +1 max. Clamp to available space.
4. For each baby:
   a. Call `breed()` from genetics system with mutation rates:
      - Base: 2% per locus. With Genetics Lab: 3%. Genetic Accelerator perk: x2.
      - Directional mutations for color loci in biome-specific directions.
      - Non-color loci (s/c/r) get random mutation boosts from biome.
   b. Random gender.
   c. Generate unique name via `PigNames.generateUniqueName()`.
   d. Position near mother (random offset -1 to +1 on each axis).
   e. Create baby via `GuineaPig.create()`.
   f. Set birth area, current area, preferred biome (from birth location, not color).
   g. Add to game state.
   h. Log mutations if any.
   i. Register in pigdex.
5. Apply breeding filter to newborns (mark non-matching babies for sale).
6. Reset mother's pregnancy state.
7. Log birth event.

### Pregnancy Advancement

`advancePregnancies()`: Increments `pregnancyDays` by `gameHours / 24.0` for all pregnant pigs. Speed Breeding perk: x1.333 accumulation rate (equivalent to -25% duration). Gestation period: 2 game days.

### Aging

`ageAllPigs()`:
1. For each pig, increment `ageDays` by `gameHours / 24.0`.
2. Baby pigs near a nursery (within 3 cells of any interaction point) age faster by the nursery's `growthBonus`.
3. If `ageDays >= maxAgeDays` (45): roll for death at `oldAgeDeathRate` (0.1) per game day.
4. Process deaths: remove from game state, log events.
5. Return list of dead pigs (for controller cleanup).

### Age Thresholds

| Age Group | Day Range | Source Constant |
|-----------|-----------|----------------|
| Baby | 0-2 | `babyAgeDays` = 0, `adultAgeDays` = 3 |
| Adult | 3-29 | `adultAgeDays` = 3, `seniorAgeDays` = 30 |
| Senior | 30+ | `seniorAgeDays` = 30 |
| Death eligible | 45+ | `maxAgeDays` = 45 |

### Pigdex Registration

`registerPigInPigdex()`:
1. Generate phenotype key from the pig's phenotype.
2. Register in pigdex. If new discovery:
   a. Award discovery reward based on rarity.
   b. Lucky Clover perk: 10% chance of bonus 50-200 Squeaks.
   c. Check and claim milestones (25/50/75/100% completion).

### Breeding Filter

`_applyBreedingFilter()`: If breeding program is enabled and adult population exceeds `stockLimit`, mark newborns that don't match the program target for auto-sale. Uses `BreedingProgram.shouldKeepPig()` to check phenotype + carrier status against targets.

---

## 12. Culling System

**Maps from:** `simulation/culling.py` (206 lines)
**Swift target:** `Simulation/Culling.swift` (~200 lines)

### Public API

```swift
enum Culling {
    /// Auto-sell pigs marked for sale that have reached adulthood.
    /// Returns list of (name, saleTotal, contractBonus, pigId).
    static func sellMarkedAdults(
        gameState: GameState
    ) -> [(String, Int, Int, UUID)] { ... }

    /// Mark surplus pigs for sale when over the program's stock limit.
    /// Also performs active replacement at the stock limit.
    static func cullSurplusBreeders(gameState: GameState) { ... }
}
```

### Surplus Culling Flow

`cullSurplusBreeders()`:
1. If breeding program is not enabled, return.
2. Get all non-baby, non-marked adults.
3. Effective limit: `max(program.stockLimit, minBreedingPopulation = 2)`.
4. If below limit: return (need more pigs).
5. If at limit: perform active replacement (see below).
6. If above limit: score all adults, keep the best N, mark the rest for sale.
7. Gender balance: ensure at least 1 male + 1 female in the kept set. Swap if necessary.
8. Skip pregnant pigs when marking.

### Scoring Strategies

Adults are scored differently based on the breeding program strategy:

**Target strategy** — `breedingValue()`:
- Count target alleles across all loci (0-10 base score).
- Senior penalty: -20 (ensures seniors are culled before breeders).
- Age tiebreaker: younger breeding-age pigs score higher (0-5 bonus).

**Diversity strategy** — `diversityValue()`:
- Phenotype uniqueness: `10.0 / count_of_pigs_sharing_phenotype`.
- Color uniqueness: `10.0 / count_of_pigs_sharing_base_color`.
- Heterozygosity bonus: 0-5 (more heterozygous loci = more varied offspring).
- Age tiebreaker: 0-3.
- Senior penalty: -20.

**Money strategy** — `moneyValue()`:
- Rarity allele scores: ch=3.0, s=2.0, R=2.0, b=1.0, e=0.5.
- Contract alignment: allele hits weighted by contract reward/100.
- Senior penalty: -20.
- Age tiebreaker: 0-5.

### Active Replacement

When at the stock limit (not above), replace the single worst non-matching adult to gradually turn over toward the target phenotype:
- **Target mode with targets:** Sell the worst non-matching adult.
- **Diversity mode:** Sell the worst-scoring adult only when the diversity gap (best - worst) exceeds 2.0 points (prevents oscillation when colors are balanced).
- **Money/Target without targets:** No active replacement (only surplus culling triggers above the limit).

Preserves gender balance (never sells the last male or last female). Skips pregnant pigs.

---

## 13. Biome Acclimation

**Maps from:** `simulation/acclimation.py` (46 lines)
**Swift target:** `Simulation/Acclimation.swift` (~50 lines)

```swift
enum Acclimation {
    /// Pre-computed acclimation threshold in game-hours.
    private static let acclimationHours: Double =
        GameConfig.Biome.acclimationDays * Double(GameConfig.Time.gameHoursPerDay)

    /// Advance a pig's biome acclimation timer.
    /// When a pig spends acclimationDays continuously in a biome
    /// that isn't its preferredBiome, it adopts the new biome.
    static func updateAcclimation(
        pig: inout GuineaPig,
        currentBiome: String?,
        hoursPerTick: Double
    ) { ... }
}
```

### Logic

1. If `preferredBiome` or `currentBiome` is nil: return.
2. If current biome matches preferred biome: reset timer and acclimating biome.
3. If acclimating to a different non-preferred biome: restart timer.
4. Increment `acclimationTimer` by `hoursPerTick`.
5. Calculate threshold: `acclimationHours` (3 days x 24 hrs = 72 hours).
6. If pig's base color matches the biome's signature color: threshold x `colorMatchAcclimationMultiplier` (0.5), so acclimation is 2x faster.
7. If timer >= threshold: adopt the new biome, reset timer.

---

## 14. Auto Resources

**Maps from:** `simulation/auto_resources.py` (134 lines)
**Swift target:** `Simulation/AutoResources.swift` (~130 lines)

### Public API

```swift
enum AutoResources {
    /// Food/water facility types affected by automation perks.
    static let foodWaterTypes: Set<FacilityType> = [
        .foodBowl, .hayRack, .waterBottle, .feastTable
    ]

    static let dripRatePerHour: Double = 2.0
    static let autoRefillThreshold: Double = 0.25

    /// Run all automatic resource systems for this tick.
    static func tickAutoResources(state: GameState, gameHours: Double) { ... }

    /// Double max capacity of all food/water facilities (Bulk Feeders perk).
    static func applyBulkFeeders(state: GameState) { ... }

    /// Veggie gardens produce food and distribute to nearby bowls/racks.
    static func tickVeggieGardens(state: GameState, gameHours: Double) { ... }

    /// Apply AoE effects from Stage and Campfire facilities.
    static func tickAoEFacilities(state: GameState, gameHours: Double) { ... }
}
```

### Auto Resource Systems

**Drip System perk:** All food/water facilities passively refill at 2.0 units per game hour.

**Auto Feeders perk:** When a food/water facility drops below 25% fill, instantly refill to max.

**Veggie Gardens:** Each garden produces food (from `FacilityInfo.foodProduction`) per game hour. Production is distributed evenly across all non-full food facilities (foodBowl, hayRack, feastTable).

### AoE Facility Effects

**Stage:** When a pig is `PLAYING` at a stage, all pigs within `stageAudienceRadius` (6.0) cells receive passive bonuses:
- Happiness: +2.0/hr
- Social: +1.5/hr
- The performer itself is excluded (already gets play bonuses).

**Campfire:** Night-time wander bias toward campfires is handled in `BehaviorDecision.tryCampfireAttraction()`, not here. The AoE function only applies passive proximity bonuses if needed (currently campfires only affect behavior, not needs directly).

### Constants

```swift
enum AutoResources {
    static let stageAudienceRadius: Double = 6.0
    static let aoEAttractionRadius: Double = 10.0
    static let stageAudienceHappinessPerHour: Double = 2.0
    static let stageAudienceSocialPerHour: Double = 1.5
}
```

---

## 15. Breeding Program

**Maps from:** `simulation/breeding_program.py` (388 lines)
**Swift target:** `Simulation/BreedingProgram.swift` (~300 lines)

The `BreedingProgram` struct is defined in Doc 02 as a data model. This section specifies the scoring and filtering functions that operate on it.

### Functions

```swift
extension BreedingProgram {
    /// Check if a pig passes the breeding program target filter.
    /// Returns true if the pig should be kept (not auto-sold).
    func shouldKeepPig(
        _ pig: GuineaPig,
        hasGeneticsLab: Bool
    ) -> Bool { ... }
}
```

### Scoring Functions (free functions in the file)

```swift
/// Score how useful a pig is for the breeding program (target allele count).
func breedingValue(
    pig: GuineaPig,
    program: BreedingProgram,
    hasLab: Bool
) -> Double { ... }

/// Score a pig's contribution to phenotype diversity.
func diversityValue(
    pig: GuineaPig,
    allPigs: [GuineaPig],
    phenotypeCounts: [String: Int]?,
    colorCounts: [BaseColor: Int]?
) -> Double { ... }

/// Score a pig's breeding potential for producing high-value offspring.
func moneyValue(
    pig: GuineaPig,
    program: BreedingProgram,
    hasLab: Bool,
    gameState: GameState
) -> Double { ... }

/// Pre-compute phenotype and color frequency counters. O(n).
func buildDiversityCounters(
    pigs: [GuineaPig]
) -> ([String: Int], [BaseColor: Int]) { ... }

/// Count how many loci are heterozygous (0-5).
func heterozygosityCount(_ genotype: Genotype) -> Int { ... }
```

### Carrier-Aware Matching

When `keepCarriers` is true and a Genetics Lab exists, the filter rescues pigs that don't display a target phenotype but carry alleles for it:

| Axis | Carrier Check |
|------|--------------|
| Color: chocolate | carries "b" allele |
| Color: golden | carries "e" allele |
| Color: cream | carries both "e" and "b" |
| Color: blue/lilac/saffron/smoke | carries "d" allele |
| Color: black | no carrier state (dominant) |
| Pattern: dutch/dalmatian | carries "s" allele |
| Pattern: solid | no carrier state (dominant) |
| Intensity: chinchilla/himalayan | carries "ch" allele |
| Intensity: full | no carrier state (dominant) |
| Roan | no carrier rescue (phenotype-only match) |

---

## 16. SimulationRunner Tick Orchestration

**Maps from:** `simulation/runner.py` (252 lines)
**Swift target:** `Simulation/SimulationRunner.swift` (~200 lines)

### Class Definition

```swift
final class SimulationRunner {
    private unowned let state: GameState
    private let behaviorController: BehaviorController

    // Callbacks (set once, called from tick)
    var onPigSold: ((String, Int, Int, UUID) -> Void)?
    var onPregnancy: ((String, String) -> Void)?
    var onBirth: ((String) -> Void)?

    // Tick state
    private var saveCounter: Int = 0
    private var breedingCheckCounter: Int = 0
    private let breedingCheckInterval: Int = 10
    private var lastFarmBellHour: Int = -1

    // TPS measurement
    private var tickTimestamps: [Double] = []  // Rolling window, max 50
    var currentTPS: Double = 0.0

    init(state: GameState, behaviorController: BehaviorController) { ... }

    /// Process one simulation tick. gameMinutes is already speed-scaled.
    func tick(gameMinutes: Double) { ... }
}
```

### 13-Phase Tick Order

Each call to `tick(gameMinutes:)` executes these phases in order:

| Phase | System | Details |
|-------|--------|---------|
| 1 | Spatial grid rebuild | `collision.rebuildSpatialGrid()` — O(n) re-binning |
| 1b | Area population cache | `facilityManager.updateAreaPopulations()` |
| 2 | Needs update | For each pig: `NeedsSystem.updateAllNeeds()` with pre-computed nearby counts |
| 2a | Farm Bell perk | If any pig is critically hungry/thirsty, log alert (throttled to 1x per game-hour) |
| 2b | Auto resources | `tickAutoResources()`, `tickVeggieGardens()`, `tickAoEFacilities()` |
| 3 | Behavior update | For each pig: `behaviorController.update()` |
| 3b | Courtship completion | Process `completedCourtships` list -> `startPregnancyFromCourtship()` |
| 4 | Collision separation | `separateOverlappingPigs()` |
| 4b | Non-walkable rescue | `rescueNonWalkablePigs()` |
| 5 | Biome acclimation | For each pig: `Acclimation.updateAcclimation()` |
| 6 | Pregnancy advancement | `Birth.advancePregnancies()` |
| 7 | Aging + death | `Birth.ageAllPigs()` + cleanup dead pig tracking |
| 8 | Surplus culling | `Culling.cullSurplusBreeders()` |
| 9 | Auto-sell marked adults | `Culling.sellMarkedAdults()` + cleanup + callbacks |
| 10 | Breeding opportunities | `Breeding.checkBreedingOpportunities()` (expensive scan throttled to every 10 ticks) |
| 11 | Contract refresh | Check expiry, generate new contracts if needed |
| 12 | Debug logging | (Optional) profiling info |
| 13 | Auto-save | Every 300 ticks (~30 seconds) |

### Breeding Check Throttling

The O(m*f) breeding pair scan runs every `breedingCheckInterval` (10) ticks, not every tick. Manual pairs and births still run every tick (they are O(1) and O(n) respectively). This is controlled by the `runExpensive` flag passed to `checkBreedingOpportunities()`.

### Time Units

The `gameMinutes` parameter passed to `tick()` is already speed-scaled by the `GameEngine` (Doc 04). It represents **game minutes** elapsed this tick:
- At 1x speed, 10 TPS: `gameMinutes = 3.0 / 10 = 0.3` game minutes per tick.
- At 20x speed: `gameMinutes = 60.0 / 10 = 6.0` game minutes per tick.
- Game hours = `gameMinutes / 60.0`.
- Game days = `gameMinutes / (60.0 * 24.0)`.

### Callbacks

Three optional closures allow the UI layer to react to simulation events without polling:
- `onPigSold(name, total, contractBonus, pigId)` — fired when a marked pig is auto-sold.
- `onPregnancy(maleName, femaleName)` — fired when courtship completes.
- `onBirth(message)` — fired when a birth event log contains "gave birth."

These replace the Python Textual message system. On iOS, they can trigger haptics, toast notifications, or SwiftUI state updates.

### Auto-Save

Every 300 ticks, `SimulationRunner` triggers a background save. The Python implementation serializes state on the main thread and writes to disk on a background thread. The iOS port should follow the same pattern via Doc 08 (Persistence).

**Implementation note:** The save system details (JSON encoding, file management, background threading) are specified in Doc 08. The `SimulationRunner` only needs to call `saveManager.save(state)` on a 300-tick cadence and skip if a previous save is still in progress.

---

## 17. Testing Strategy

### Headless Simulation Tests

Run a complete simulation without rendering to verify behavioral correctness:

```swift
@Test("1000-tick headless simulation produces reasonable behavior")
func testHeadlessSimulation() {
    let state = GameState.createNew()
    // Add 10 pigs, 2 food bowls, 2 water bottles, 1 hideout
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller)

    for _ in 0..<1000 {
        runner.tick(gameMinutes: 0.3)  // 1x speed
    }

    // Verify: no pig has hunger or thirst at 0
    // Verify: pigs have used different behavior states
    // Verify: at least one breeding attempt occurred (if eligible pair exists)
}
```

### Behavior Decision Tests

```swift
@Test("Pig with critical hunger seeks food facility")
func testCriticalHungerSeeksFood() {
    var pig = GuineaPig.create(...)
    pig.needs.hunger = 10.0  // Below criticalThreshold (20)
    pig.behaviorState = .idle

    // After decision, pig should be .wandering toward a food facility
    // or .eating if adjacent to one
}

@Test("Sleeping pig wakes up when energy full")
func testSleepWakeOnEnergyFull() { ... }

@Test("Eating pig commits until hunger >= 90")
func testEatingCommitment() { ... }

@Test("Content pig uses 8s decision interval")
func testContentPigThrottle() { ... }
```

### Needs Decay Tests

```swift
@Test("Hunger decays at correct rate per game hour")
func testHungerDecay() {
    var pig = GuineaPig.create(...)
    pig.needs.hunger = 100.0
    NeedsSystem.updateAllNeeds(pig: &pig, gameMinutes: 60.0, ...)
    // hunger should be ~99.4 (100 - 0.6)
    #expect(abs(pig.needs.hunger - 99.4) < 0.01)
}

@Test("Greedy personality accelerates hunger decay")
func testGreedyHungerDecay() { ... }

@Test("Social proximity provides passive social recovery")
func testSocialProximityBoost() { ... }
```

### Breeding Tests

```swift
@Test("Courtship completes after together seconds")
func testCourtshipCompletion() { ... }

@Test("Pregnancy advances and produces birth at gestation days")
func testPregnancyAndBirth() { ... }

@Test("Auto-pair selects highest-probability pair for target strategy")
func testAutoPairTargetStrategy() { ... }
```

### Collision Tests

```swift
@Test("Spatial grid correctly bins pigs into cells")
func testSpatialGridBinning() { ... }

@Test("Overlapping pigs are separated to minimum distance")
func testOverlapSeparation() { ... }

@Test("Both-moving pigs use tighter blocking threshold")
func testBothMovingBlocking() { ... }
```

---

## 18. Constants Reference

All behavior-related constants live in `GameConfig` (Doc 02, sections 5.1 and 5.2). This section provides a cross-reference from Python constant names to Swift paths.

### GameConfig.Needs (NeedsConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `NEEDS.HUNGER_DECAY` | `GameConfig.Needs.hungerDecay` | 0.6 |
| `NEEDS.THIRST_DECAY` | `GameConfig.Needs.thirstDecay` | 0.8 |
| `NEEDS.ENERGY_DECAY` | `GameConfig.Needs.energyDecay` | 0.6 |
| `NEEDS.CRITICAL_THRESHOLD` | `GameConfig.Needs.criticalThreshold` | 20 |
| `NEEDS.LOW_THRESHOLD` | `GameConfig.Needs.lowThreshold` | 40 |
| `NEEDS.HIGH_THRESHOLD` | `GameConfig.Needs.highThreshold` | 70 |
| `NEEDS.SATISFACTION_THRESHOLD` | `GameConfig.Needs.satisfactionThreshold` | 90 |
| `NEEDS.HEALTH_DRAIN_HUNGER` | `GameConfig.Needs.healthDrainHunger` | 0.3 |
| `NEEDS.HEALTH_DRAIN_THIRST` | `GameConfig.Needs.healthDrainThirst` | 0.5 |
| `NEEDS.HEALTH_PASSIVE_RECOVERY` | `GameConfig.Needs.healthPassiveRecovery` | 1.0 |
| `NEEDS.HEALTH_SLEEP_RECOVERY` | `GameConfig.Needs.healthSleepRecovery` | 1.5 |
| `NEEDS.FOOD_RECOVERY` | `GameConfig.Needs.foodRecovery` | 40.0 |
| `NEEDS.WATER_RECOVERY` | `GameConfig.Needs.waterRecovery` | 50.0 |
| `NEEDS.SLEEP_RECOVERY_PER_HOUR` | `GameConfig.Needs.sleepRecoveryPerHour` | 25.0 |
| `NEEDS.PLAY_HAPPINESS_BOOST` | `GameConfig.Needs.playHappinessBoost` | 15.0 |
| `NEEDS.SOCIAL_HAPPINESS_BOOST` | `GameConfig.Needs.socialHappinessBoost` | 10.0 |
| `NEEDS.BOREDOM_DECAY` | `GameConfig.Needs.boredomDecay` | 2.0 |
| `NEEDS.BOREDOM_EXTRA_HAPPINESS_THRESHOLD` | `GameConfig.Needs.boredomExtraHappinessThreshold` | 70 |
| `NEEDS.BOREDOM_EXTRA_HAPPINESS_DRAIN` | `GameConfig.Needs.boredomExtraHappinessDrain` | 1.0 |
| `NEEDS.BOREDOM_PLAY_RECOVERY` | `GameConfig.Needs.boredomPlayRecovery` | 15.0 |
| `NEEDS.PLAY_ENERGY_COST` | `GameConfig.Needs.playEnergyCost` | 1.0 |
| `NEEDS.SOCIAL_RECOVERY` | `GameConfig.Needs.socialRecovery` | 10.0 |
| `NEEDS.SOCIAL_RADIUS` | `GameConfig.Needs.socialRadius` | 8.0 |
| `NEEDS.SOCIAL_BOOST_PER_PIG` | `GameConfig.Needs.socialBoostPerPig` | 3.0 |
| `NEEDS.SOCIAL_BOOST_CAP` | `GameConfig.Needs.socialBoostCap` | 8.0 |
| `NEEDS.SOCIAL_DECAY_WITH_PIGS` | `GameConfig.Needs.socialDecayWithPigs` | 0.5 |
| `NEEDS.SOCIAL_DECAY_ALONE` | `GameConfig.Needs.socialDecayAlone` | 2.0 |
| `NEEDS.EATING_HAPPINESS_BOOST` | `GameConfig.Needs.eatingHappinessBoost` | 2.0 |
| `NEEDS.HAPPINESS_CONTENTMENT_RECOVERY` | `GameConfig.Needs.happinessContentmentRecovery` | 2.0 |
| `NEEDS.HUNGER_HAPPINESS_DRAIN` | `GameConfig.Needs.hungerHappinessDrain` | 2.0 |
| `NEEDS.THIRST_HAPPINESS_DRAIN` | `GameConfig.Needs.thirstHappinessDrain` | 2.5 |
| `NEEDS.ENERGY_HAPPINESS_DRAIN` | `GameConfig.Needs.energyHappinessDrain` | 1.5 |
| `NEEDS.GREEDY_HUNGER_MULT` | `GameConfig.Needs.greedyHungerMult` | 1.5 |
| `NEEDS.LAZY_ENERGY_MULT` | `GameConfig.Needs.lazyEnergyMult` | 0.7 |
| `NEEDS.PLAYFUL_BOREDOM_MULT` | `GameConfig.Needs.playfulBoredomMult` | 1.5 |
| `NEEDS.SOCIAL_SOCIAL_MULT` | `GameConfig.Needs.socialSocialMult` | 1.3 |
| `NEEDS.SHY_SOCIAL_MULT` | `GameConfig.Needs.shySocialMult` | 0.5 |
| `NEEDS.WELLBEING_HUNGER_WEIGHT` | `GameConfig.Needs.wellbeingHungerWeight` | 0.25 |
| `NEEDS.WELLBEING_THIRST_WEIGHT` | `GameConfig.Needs.wellbeingThirstWeight` | 0.25 |
| `NEEDS.WELLBEING_ENERGY_WEIGHT` | `GameConfig.Needs.wellbeingEnergyWeight` | 0.15 |
| `NEEDS.WELLBEING_HAPPINESS_WEIGHT` | `GameConfig.Needs.wellbeingHappinessWeight` | 0.20 |
| `NEEDS.WELLBEING_HEALTH_WEIGHT` | `GameConfig.Needs.wellbeingHealthWeight` | 0.15 |

### GameConfig.Behavior (BehaviorConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `BEHAVIOR.SEPARATION_BOTH_MOVING` | `GameConfig.Behavior.separationBothMoving` | 1.0 |
| `BEHAVIOR.SEPARATION_ONE_MOVING` | `GameConfig.Behavior.separationOneMoving` | 2.0 |
| `BEHAVIOR.MIN_PIG_DISTANCE` | `GameConfig.Behavior.minPigDistance` | 3.0 |
| `BEHAVIOR.BLOCKING_DEFAULT` | `GameConfig.Behavior.blockingDefault` | 2.5 |
| `BEHAVIOR.BLOCKING_BOTH_MOVING` | `GameConfig.Behavior.blockingBothMoving` | 1.5 |
| `BEHAVIOR.BLOCKING_FACILITY_USE` | `GameConfig.Behavior.blockingFacilityUse` | 1.5 |
| `BEHAVIOR.SEPARATION_FACILITY_USE` | `GameConfig.Behavior.separationFacilityUse` | 1.0 |
| `BEHAVIOR.OCCUPANCY_RADIUS` | `GameConfig.Behavior.occupancyRadius` | 2.0 |
| `BEHAVIOR.FACILITY_NEARBY_RADIUS` | `GameConfig.Behavior.facilityNearbyRadius` | 6.0 |
| `BEHAVIOR.FACILITY_HEADING_RADIUS` | `GameConfig.Behavior.facilityHeadingRadius` | 3.0 |
| `BEHAVIOR.CROWDING_PENALTY` | `GameConfig.Behavior.crowdingPenalty` | 25.0 |
| `BEHAVIOR.FACILITY_DISTANCE_WEIGHT` | `GameConfig.Behavior.facilityDistanceWeight` | 2.0 |
| `BEHAVIOR.SCORING_RANDOM_VARIANCE` | `GameConfig.Behavior.scoringRandomVariance` | 3.0 |
| `BEHAVIOR.UNCROWDED_CHANCE` | `GameConfig.Behavior.uncrowdedChance` | 0.3 |
| `BEHAVIOR.BLOCKED_TIME_ALTERNATIVE` | `GameConfig.Behavior.blockedTimeAlternative` | 2.0 |
| `BEHAVIOR.BLOCKED_TIME_GIVE_UP` | `GameConfig.Behavior.blockedTimeGiveUp` | 5.0 |
| `BEHAVIOR.FAILED_COOLDOWN_CYCLES` | `GameConfig.Behavior.failedCooldownCycles` | 3 |
| `BEHAVIOR.ENERGY_SLEEP_THRESHOLD` | `GameConfig.Behavior.energySleepThreshold` | 40 |
| `BEHAVIOR.EMERGENCY_WAKE_ENERGY` | `GameConfig.Behavior.emergencyWakeEnergy` | 15 |
| `BEHAVIOR.BOREDOM_PLAY_THRESHOLD` | `GameConfig.Behavior.boredomPlayThreshold` | 30 |
| `BEHAVIOR.BOREDOM_KEEP_PLAYING` | `GameConfig.Behavior.boredomKeepPlaying` | 20 |
| `BEHAVIOR.RESOURCE_CONSUME_RATE` | `GameConfig.Behavior.resourceConsumeRate` | 0.15 |
| `BEHAVIOR.FACILITY_BONUS_SCALE` | `GameConfig.Behavior.facilityBonusScale` | 10.0 |
| `BEHAVIOR.LAZY_SLEEP_CHANCE` | `GameConfig.Behavior.lazySleepChance` | 0.3 |
| `BEHAVIOR.PLAYFUL_PLAY_CHANCE` | `GameConfig.Behavior.playfulPlayChance` | 0.4 |
| `BEHAVIOR.SOCIAL_SOCIALIZE_CHANCE` | `GameConfig.Behavior.socialSocializeChance` | 0.3 |
| `BEHAVIOR.WANDER_CHANCE` | `GameConfig.Behavior.wanderChance` | 0.8 |
| `BEHAVIOR.NO_PLAY_FACILITY_PLAY_CHANCE` | `GameConfig.Behavior.noPlayFacilityPlayChance` | 0.1 |
| `BEHAVIOR.WANDER_ATTEMPTS` | `GameConfig.Behavior.wanderAttempts` | 8 |
| `BEHAVIOR.WANDER_MAX_DISTANCE` | `GameConfig.Behavior.wanderMaxDistance` | 30 |
| `BEHAVIOR.WANDER_DENSITY_RADIUS` | `GameConfig.Behavior.wanderDensityRadius` | 10.0 |
| `BEHAVIOR.WANDER_DENSITY_PENALTY` | `GameConfig.Behavior.wanderDensityPenalty` | 2.0 |
| `BEHAVIOR.SIMPLE_WANDER_MIN_STEPS` | `GameConfig.Behavior.simpleWanderMinSteps` | 6 |
| `BEHAVIOR.SIMPLE_WANDER_MAX_STEPS` | `GameConfig.Behavior.simpleWanderMaxSteps` | 14 |
| `BEHAVIOR.MAX_FACILITY_PATHFIND_DISTANCE` | `GameConfig.Behavior.maxFacilityPathfindDistance` | 100 |
| `BEHAVIOR.MAX_FACILITY_CANDIDATES` | `GameConfig.Behavior.maxFacilityCandidates` | 4 |
| `BEHAVIOR.STRAIGHT_LINE_MAX_DISTANCE` | `GameConfig.Behavior.straightLineMaxDistance` | 6 |
| `BEHAVIOR.CONTENT_DECISION_INTERVAL` | `GameConfig.Behavior.contentDecisionInterval` | 8.0 |
| `BEHAVIOR.CRITICAL_FAILED_COOLDOWN_CYCLES` | `GameConfig.Behavior.criticalFailedCooldownCycles` | 1 |
| `BEHAVIOR.UNREACHABLE_BACKOFF_CYCLES` | `GameConfig.Behavior.unreachableBackoffCycles` | 5 |
| `BEHAVIOR.UNREACHABLE_CRITICAL_CYCLES` | `GameConfig.Behavior.unreachableCriticalCycles` | 2 |
| `BEHAVIOR.BIOME_AFFINITY_PENALTY` | `GameConfig.Behavior.biomeAffinityPenalty` | 30.0 |
| `BEHAVIOR.ROOM_OVERCROWDING_PENALTY` | `GameConfig.Behavior.roomOvercrowdingPenalty` | 10.0 |
| `BEHAVIOR.IDLE_DRIFT_RADIUS` | `GameConfig.Behavior.idleDriftRadius` | 5.0 |
| `BEHAVIOR.BIOME_WANDER_BIAS_OUTSIDE` | `GameConfig.Behavior.biomeWanderBiasOutside` | 3.0 |
| `BEHAVIOR.BIOME_WANDER_BIAS_INSIDE` | `GameConfig.Behavior.biomeWanderBiasInside` | 1.5 |
| `BEHAVIOR.BIOME_HOMING_CHANCE` | `GameConfig.Behavior.biomeHomingChance` | 0.7 |
| `BEHAVIOR.COURTSHIP_TOGETHER_SECONDS` | `GameConfig.Behavior.courtshipTogetherSeconds` | 4.0 |
| `BEHAVIOR.COURTSHIP_HAPPINESS_BOOST` | `GameConfig.Behavior.courtshipHappinessBoost` | 5.0 |
| `BEHAVIOR.TIRED_SPEED_MULT` | `GameConfig.Behavior.tiredSpeedMult` | 0.5 |
| `BEHAVIOR.BABY_SPEED_MULT` | `GameConfig.Behavior.babySpeedMult` | 0.7 |
| `BEHAVIOR.DODGE_MAX_STEP` | `GameConfig.Behavior.dodgeMaxStep` | 1.0 |
| `BEHAVIOR.WAYPOINT_REACHED` | `GameConfig.Behavior.waypointReached` | 0.1 |
| `BEHAVIOR.OVERLAP_EPSILON` | `GameConfig.Behavior.overlapEpsilon` | 0.01 |
| `BEHAVIOR.SEPARATION_PADDING` | `GameConfig.Behavior.separationPadding` | 0.1 |
| `BEHAVIOR.PATH_VECTOR_EPSILON` | `GameConfig.Behavior.pathVectorEpsilon` | 0.01 |

### GameConfig.Breeding (BreedingConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `BREEDING.MIN_HAPPINESS_TO_BREED` | `GameConfig.Breeding.minHappinessToBreed` | 70 |
| `BREEDING.MIN_AGE_DAYS` | `GameConfig.Breeding.minAgeDays` | 3 |
| `BREEDING.MAX_AGE_DAYS` | `GameConfig.Breeding.maxAgeDays` | 30 |
| `BREEDING.GESTATION_DAYS` | `GameConfig.Breeding.gestationDays` | 2 |
| `BREEDING.MIN_LITTER_SIZE` | `GameConfig.Breeding.minLitterSize` | 1 |
| `BREEDING.MAX_LITTER_SIZE` | `GameConfig.Breeding.maxLitterSize` | 4 |
| `BREEDING.RECOVERY_DAYS` | `GameConfig.Breeding.recoveryDays` | 2 |
| `BREEDING.BREEDING_DISTANCE` | `GameConfig.Breeding.breedingDistance` | 3.0 |
| `BREEDING.BASE_BREEDING_CHANCE` | `GameConfig.Breeding.baseBreedingChance` | 0.05 |
| `BREEDING.BREEDING_DEN_BONUS` | `GameConfig.Breeding.breedingDenBonus` | 0.10 |
| `BREEDING.HIGH_HAPPINESS_THRESHOLD` | `GameConfig.Breeding.highHappinessThreshold` | 80 |
| `BREEDING.HIGH_HAPPINESS_BONUS` | `GameConfig.Breeding.highHappinessBonus` | 0.05 |
| `BREEDING.OLD_AGE_DEATH_RATE` | `GameConfig.Breeding.oldAgeDeathRate` | 0.1 |
| `BREEDING.MIN_BREEDING_POPULATION` | `GameConfig.Breeding.minBreedingPopulation` | 2 |
| `BREEDING.AFFINITY_WEIGHT` | `GameConfig.Breeding.affinityWeight` | 0.01 |
| `BREEDING.MAX_AFFINITY_SELECTION_BONUS` | `GameConfig.Breeding.maxAffinitySelectionBonus` | 0.05 |
| `BREEDING.AFFINITY_CHANCE_BONUS` | `GameConfig.Breeding.affinityChanceBonus` | 0.01 |
| `BREEDING.MAX_AFFINITY_CHANCE_BONUS` | `GameConfig.Breeding.maxAffinityChanceBonus` | 0.05 |

### GameConfig.Simulation (SimulationConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `SIMULATION.TICKS_PER_SECOND` | `GameConfig.Simulation.ticksPerSecond` | 10 |
| `SIMULATION.BASE_MOVE_SPEED` | `GameConfig.Simulation.baseMoveSpeed` | 1.0 |
| `SIMULATION.MAX_PATHFINDING_ITERATIONS` | `GameConfig.Simulation.maxPathfindingIterations` | 1500 |
| `SIMULATION.DECISION_INTERVAL_SECONDS` | `GameConfig.Simulation.decisionIntervalSeconds` | 2.0 |
| `SIMULATION.BABY_AGE_DAYS` | `GameConfig.Simulation.babyAgeDays` | 0 |
| `SIMULATION.ADULT_AGE_DAYS` | `GameConfig.Simulation.adultAgeDays` | 3 |
| `SIMULATION.SENIOR_AGE_DAYS` | `GameConfig.Simulation.seniorAgeDays` | 30 |
| `SIMULATION.MAX_AGE_DAYS` | `GameConfig.Simulation.maxAgeDays` | 45 |

### GameConfig.Genetics (GeneticsConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `GENETICS.MUTATION_RATE` | `GameConfig.Genetics.mutationRate` | 0.02 |
| `GENETICS.MUTATION_RATE_WITH_LAB` | `GameConfig.Genetics.mutationRateWithLab` | 0.03 |
| `GENETICS.DIRECTIONAL_MUTATION_RATE` | `GameConfig.Genetics.directionalMutationRate` | 0.06 |
| `GENETICS.DIRECTIONAL_MUTATION_RATE_WITH_LAB` | `GameConfig.Genetics.directionalMutationRateWithLab` | 0.09 |

### GameConfig.Biome (BiomeConfig)

| Python | Swift | Value |
|--------|-------|-------|
| `BIOME.PREFERRED_BIOME_HAPPINESS_BONUS` | `GameConfig.Biome.preferredBiomeHappinessBonus` | 1.5 |
| `BIOME.ACCLIMATION_DAYS` | `GameConfig.Biome.acclimationDays` | 3.0 |
| `BIOME.COLOR_MATCH_ACCLIMATION_MULTIPLIER` | `GameConfig.Biome.colorMatchAcclimationMultiplier` | 0.5 |

---

## 19. Decision Needed

### SpatialGrid Storage Strategy

The Python `SpatialGrid` stores `GuineaPig` object references directly in bucket lists. In Swift, `GuineaPig` is a value type (struct), so storing copies in the grid would be wasteful and stale after mutations.

**Options:**
1. **Store UUIDs** — Grid stores `[GridPosition: [UUID]]`. Lookups go through `gameState.pigs[uuid]`. Simpler, no stale data, but adds dictionary lookup overhead per spatial query.
2. **Store array indices** — Grid stores indices into a `[GuineaPig]` snapshot taken at rebuild time. Faster O(1) lookups, but the snapshot must be kept alive for the tick duration and is read-only.
3. **Store `UnsafeMutablePointer<GuineaPig>`** — Direct pointer into the dictionary's value storage. Fastest, but fragile and unsafe.

**Recommendation:** Start with option 1 (UUIDs). The spatial grid is rebuilt once per tick and queried O(n*k) times where k is the average bucket size (~3-5 pigs). The dictionary lookup overhead is unlikely to be a bottleneck for 50-80 pigs. Profile during Phase 1 headless simulation and switch to option 2 if needed.

### GuineaPig Mutation Pattern

Many behavior functions mutate `GuineaPig` fields (position, path, behaviorState, needs, etc.). In Python, `GuineaPig` is a Pydantic `BaseModel` with mutable fields — mutations happen in-place through references.

In Swift, `GuineaPig` is a struct stored in `GameState.pigs: [UUID: GuineaPig]`. Mutations require either:
1. **`inout` parameters** — Functions take `inout GuineaPig` and mutations propagate back. Requires careful call-site management: `behaviorController.update(pig: &gameState.pigs[pigId]!)`.
2. **Subscript mutation** — Functions access `gameState.pigs[pigId]` directly and mutate through the dictionary subscript.
3. **Copy-mutate-writeback** — `var pig = gameState.pigs[pigId]!; modify(&pig); gameState.pigs[pigId] = pig`. Explicit but verbose.

**Recommendation:** Use approach 2 (subscript mutation) as the primary pattern. The `SimulationRunner` iterates over pig IDs and passes the controller + pigId to subsystems, which access `gameState.pigs[pigId]` directly. This avoids `inout` gymnastics and matches the Python pattern of mutating through the state container. When a function needs a read-only snapshot (e.g., for distance checks against other pigs), it reads from the dictionary without `inout`.

---

## What's Next

With the behavior AI fully specified, the next steps are:
1. **Doc 04 (Game Engine)** — specifies `GameState`, `GameEngine`, `FarmGrid`, pathfinding, `FacilityManager`, and economy. Must be written before implementing Doc 05, since the behavior system depends on engine infrastructure.
2. **Doc 06 (Farm Scene)** — specifies SpriteKit rendering, which consumes behavior state to animate pigs. Depends on Docs 02, 03, 04, and 05.
